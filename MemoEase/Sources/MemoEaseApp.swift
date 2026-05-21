import SwiftUI
import Speech
import EventKit
import AVFoundation
import UserNotifications
import Vision
import PhotosUI

// MARK: - App Entry
@main
struct MemoEaseApp: App {
    @StateObject private var engine = MemoEngine()
    @StateObject private var iap = MemoIAPManager()
    @StateObject private var referral = ReferralEngine()
    @StateObject private var emailManager = EmailManager()
    var body: some Scene {
        WindowGroup {
            MainEaseView()
                .environmentObject(engine).environmentObject(iap).environmentObject(referral).environmentObject(emailManager)
                .preferredColorScheme(.light)
                .onAppear {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.sound]) { _,_ in }
                    SFSpeechRecognizer.requestAuthorization { _ in }
                    iap.fetchProducts()
                }
                .onChange(of: engine.notes.count) { _, newCount in
                    emailManager.checkBackupPrompt(after: newCount)
                }
        }
    }
}

// MARK: - Data Models
enum EaseInputSource: String, Codable {
    case voice = "🎤 Voice"
    case image = "📷 Photo"
    case webLink = "🌐 Link"
}

struct EaseNote: Identifiable, Codable {
    let id = UUID(); let spokenText: String; let coreIdea: String
    let category: MemoCategory; let createdAt: Date; let reminderDate: Date?
    let linkedReminderID: String?; let isMedication: Bool; let sharedWithFamily: Bool
    let source: EaseInputSource; let sourceURL: String?; let imageData: Data?
}

enum MemoCategory: String, Codable, CaseIterable {
    case health = "💊 Health"; case appointment = "🏥 Appointment"; case daily = "📋 Daily"
    case family = "👨‍👩‍👧 Family"; case shopping = "🛒 Shopping"; case other = "📌 Other"
    var color: Color {
        switch self { case .health: return .red; case .appointment: return .blue; case .daily: return .green; case .family: return .orange; case .shopping: return .purple; case .other: return .gray }
    }
}

// MARK: - Media Processor
class EaseMediaProcessor {
    func processImage(_ image: UIImage) async -> String {
        guard let cg = image.cgImage else { return "" }
        return await withCheckedContinuation { c in
            let req = VNRecognizeTextRequest { r, _ in
                let t = (r.results as? [VNRecognizedTextObservation] ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                c.resume(returning: t)
            }
            req.recognitionLevel = .accurate
            req.recognitionLanguages = ["en-US","zh-Hans","zh-Hant","ja-JP","ko-KR","fr-FR","de-DE","es-ES"]
            try? VNImageRequestHandler(cgImage: cg).perform([req])
        }
    }
    func fetchWebContent(_ url: String) async -> String {
        var s = url.trimmingCharacters(in: .whitespaces); if !s.hasPrefix("http") { s = "https://"+s }
        guard let u = URL(string: s) else { return "" }
        guard let (d,_) = try? await URLSession.shared.data(from: u),
              let html = String(data: d, encoding: .utf8) else { return "" }
        var r = html
        r = r.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
        r = r.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
        r = r.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        r = r.replacingOccurrences(of: "&amp;", with: "&"); r = r.replacingOccurrences(of: "&nbsp;", with: " ")
        r = r.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        var out = ""; if let tr = html.range(of: "<title[^>]*>([^<]+)</title>", options: .regularExpression) {
            out += "📄 "+String(html[tr]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)+"\n\n"
        }
        out += String(r.prefix(1500)); if r.count > 1500 { out += "\n\n...(truncated)" }
        return out
    }
}

// MARK: - Memo Engine
class MemoEngine: ObservableObject {
    @Published var notes: [EaseNote] = []
    @Published var isRecording = false; @Published var liveText = ""
    @Published var showAlert = false; @Published var alertMessage = ""
    @Published var isProcessing = false; @Published var processError: String?
    
    private let recognizer = SRSpeechRecognizer()
    private var recReq: SFSpeechBufferAudioRecognitionRequest?
    private var recTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synth = AVSpeechSynthesizer()
    private let media = EaseMediaProcessor()
    
    // MARK: Voice Recording
    func startEasyRecord() {
        let rec = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        liveText = ""; isRecording = true
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker,.allowBluetooth])
        try? s.setActive(true)
        recReq = SFSpeechBufferAudioRecognitionRequest(); recReq?.shouldReportPartialResults = true
        let input = audioEngine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { b,_ in self.recReq?.append(b) }
        audioEngine.prepare(); try? audioEngine.start()
        recTask = rec.recognitionTask(with: recReq!) { r, e in
            if let r = r { DispatchQueue.main.async { self.liveText = r.bestTranscription.formattedString } }
            if e != nil { self.stopEasyRecord() }
        }
    }
    
    func stopEasyRecord() {
        audioEngine.stop(); audioEngine.inputNode.removeTap(onBus: 0)
        recReq?.endAudio(); recTask?.cancel(); isRecording = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard !liveText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        createEaseNote(liveText, source: .voice, sourceURL: nil, imageData: nil)
    }
    
    // MARK: Image Processing
    func processImageInput(_ image: UIImage) async {
        await MainActor.run { isProcessing = true }
        let text = await media.processImage(image)
        await MainActor.run { isProcessing = false }
        guard !text.isEmpty else { return }
        createEaseNote(text, source: .image, sourceURL: nil, imageData: image.jpegData(compressionQuality: 0.7))
    }
    
    // MARK: Web Processing
    func processWebLink(_ url: String) async {
        await MainActor.run { isProcessing = true }
        let text = await media.fetchWebContent(url)
        await MainActor.run { isProcessing = false }
        guard !text.isEmpty else { return }
        createEaseNote(text, source: .webLink, sourceURL: url, imageData: nil)
    }
    
    // MARK: Unified Note Creation
    private func createEaseNote(_ text: String, source: EaseInputSource, sourceURL: String?, imageData: Data?) {
        let cat = classifyInput(text)
        let idea = extractCoreIdea(text)
        let date = extractDate(text, category: cat)
        let isMed = cat == .health && (text.lowercased().contains("pill")||text.lowercased().contains("medic")||text.lowercased().contains("tablet")||text.lowercased().contains("dose"))
        var note = EaseNote(spokenText: text, coreIdea: idea, category: cat, createdAt: Date(),
                            reminderDate: date, linkedReminderID: nil, isMedication: isMed,
                            sharedWithFamily: false, source: source, sourceURL: sourceURL, imageData: imageData)
        if date != nil || cat == .health || cat == .appointment {
            note.linkedReminderID = createReminder(for: note)
        }
        DispatchQueue.main.async {
            self.notes.insert(note, at: 0); self.speakConfirmation(note)
            self.alertMessage = note.isMedication ? "✅ Pill reminder set!\n\(note.coreIdea)" : "✅ Saved!\n\(note.coreIdea)"
            self.showAlert = true
        }
    }
    
    func classifyInput(_ text: String) -> MemoCategory {
        let l = text.lowercased()
        if ["pill","medication","medicine","doctor","hospital","clinic","prescription","pharmacy","pain","blood pressure","diabetes","insulin","vitamin","dose","tablet"].contains(where: {l.contains($0)}) { return .health }
        if ["appointment","dentist","optometrist","checkup","follow.up","exam"].contains(where: {l.contains($0)}) { return .appointment }
        if ["mom","dad","daughter","son","grandchild","family","birthday","anniversary"].contains(where: {l.contains($0)}) { return .family }
        if ["buy","grocery","shopping","milk","bread","store"].contains(where: {l.contains($0)}) { return .shopping }
        return .other
    }
    
    func extractCoreIdea(_ text: String) -> String {
        let l = text.lowercased()
        if l.contains("take") && (l.contains("pill")||l.contains("medicine")) {
            if let r = l.range(of: "take.*(pill|medicine|tablet|dose)", options: .regularExpression) { return "💊 Remember to "+String(text[r]).capitalized }
        }
        if l.contains("doctor")||l.contains("appointment") { return "🏥 "+text.trimmingCharacters(in: .whitespaces) }
        let s = text.components(separatedBy: [".","!","?"]).first?.trimmingCharacters(in: .whitespaces) ?? text
        return s.count > 80 ? String(s.prefix(80))+"..." : s
    }
    
    func extractDate(_ text: String, category: MemoCategory) -> Date? {
        let l = text.lowercased(); let now = Date(); let cal = Calendar.current
        if category == .health { var c = cal.dateComponents([.year,.month,.day], from: now); c.hour = 8; c.minute = 0; return cal.date(from: c) }
        if l.contains("morning")||l.contains("breakfast") { var c = cal.dateComponents([.year,.month,.day], from: now); c.hour = 8; return cal.date(from: c) }
        if l.contains("noon")||l.contains("lunch") { var c = cal.dateComponents([.year,.month,.day], from: now); c.hour = 12; return cal.date(from: c) }
        if l.contains("evening")||l.contains("dinner")||l.contains("night") { var c = cal.dateComponents([.year,.month,.day], from: now); c.hour = 18; return cal.date(from: c) }
        if l.contains("tomorrow") { return cal.date(byAdding: .day, value: 1, to: now) }
        return category == .appointment ? now.addingTimeInterval(3600) : nil
    }
    
    func createReminder(for note: EaseNote) -> String {
        let rid = UUID().uuidString
        let content = UNMutableNotificationContent()
        content.title = note.category.rawValue; content.body = note.coreIdea; content.sound = .default
        if let d = note.reminderDate {
            let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: d)
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: rid, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
        return rid
    }
    
    func speakConfirmation(_ note: EaseNote) {
        let u = AVSpeechUtterance(string: "Got it. \(note.coreIdea)")
        u.rate = 0.45; u.volume = 0.8; u.voice = AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(u)
    }
    
    func getTodayPills() -> [EaseNote] { notes.filter { $0.isMedication && Calendar.current.isDate($0.createdAt, inSameDayAs: Date()) } }
    func shareWithFamily(_ note: EaseNote) { /* CloudKit sync */ }
}

// MARK: - IAP Manager
class MemoIAPManager: NSObject, ObservableObject {
    @Published var products: [SKProduct] = []; @Published var isSubscribed = false
    private let ids = ["com.memoease.monthly.basic","com.memoease.monthly.pro","com.memoease.yearly.pro"]
    func fetchProducts() { let r = SKProductsRequest(productIdentifiers: Set(ids)); r.delegate = self; r.start() }
}
extension MemoIAPManager: SKProductsRequestDelegate {
    func productsRequest(_ r: SKProductsRequest, didReceive res: SKProductsResponse) {
        DispatchQueue.main.async { self.products = res.products.sorted { $0.price.doubleValue < $1.price.doubleValue } }
    }
}
