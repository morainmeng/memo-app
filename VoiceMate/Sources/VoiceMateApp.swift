import SwiftUI
import Speech
import EventKit
import NaturalLanguage
import Vision
import VisionKit
import PhotosUI

// MARK: - App Entry
@main
struct VoiceMateApp: App {
    @StateObject private var store = VoiceStore()
    @StateObject private var iap = IAPManager()
    @StateObject private var referral = ReferralEngine()
    @StateObject private var emailManager = EmailManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(iap)
                .environmentObject(referral)
                .environmentObject(emailManager)
                .onAppear {
                    SFSpeechRecognizer.requestAuthorization { _ in }
                    iap.fetchProducts()
                }
                .onChange(of: store.notes.count) { _, newCount in
                    emailManager.checkBackupPrompt(after: newCount)
                }
        }
    }
}

// MARK: - Data Models
enum InputSource: String, Codable {
    case voice = "🎤 Voice"
    case image = "📷 Image"
    case webLink = "🌐 Web"
}

struct VoiceNote: Identifiable, Codable {
    let id = UUID()
    let rawText: String
    let summary: String
    let actionItems: [ActionItem]
    let language: String
    let createdAt: Date
    let audioURL: URL?
    let source: InputSource
    let sourceURL: String?
    let imageData: Data?
}

struct ActionItem: Identifiable, Codable {
    let id = UUID()
    let title: String
    let dueDate: Date?
    let type: ActionType
    var isDone: Bool = false
}

enum ActionType: String, Codable, CaseIterable {
    case calendar = "📅 Calendar"
    case reminder = "⏰ Reminder"
    case task = "✅ Task"
    case note = "📝 Note"
}

// MARK: - Media Processing (Image + Web)
class MediaProcessor: ObservableObject {
    @Published var isProcessing = false
    @Published var extractedText = ""
    @Published var errorMessage: String?
    
    func processImage(_ image: UIImage) async -> String {
        await MainActor.run { isProcessing = true; extractedText = ""; errorMessage = nil }
        defer { Task { @MainActor in isProcessing = false } }
        
        guard let cgImage = image.cgImage else {
            await MainActor.run { errorMessage = "Invalid image format" }
            return ""
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    Task { @MainActor in self.errorMessage = error.localizedDescription }
                    continuation.resume(returning: "")
                    return
                }
                let text = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                Task { @MainActor in self.extractedText = text }
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US","zh-Hans","zh-Hant","ja-JP","ko-KR",
                                            "fr-FR","de-DE","es-ES","pt-BR","it-IT","ru-RU"]
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    func analyzeImageContent(_ image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }
        return await withCheckedContinuation { continuation in
            var results: [String] = []
            let textRequest = VNRecognizeTextRequest { request, _ in
                let text = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                results.append(contentsOf: text)
            }
            textRequest.recognitionLevel = .fast
            let classifyRequest = VNClassifyImageRequest { request, _ in
                let classifications = (request.results as? [VNClassificationObservation] ?? [])
                    .prefix(5).map { "\($0.identifier)" }
                if !classifications.isEmpty {
                    results.append("[Image: \(classifications.joined(separator: ", "))]")
                }
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([textRequest, classifyRequest])
            continuation.resume(returning: results.joined(separator: "\n"))
        }
    }
    
    func fetchWebContent(_ urlString: String) async -> String {
        await MainActor.run { isProcessing = true; extractedText = ""; errorMessage = nil }
        defer { Task { @MainActor in isProcessing = false } }
        
        var urlStr = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlStr.hasPrefix("http") { urlStr = "https://" + urlStr }
        guard let url = URL(string: urlStr) else {
            await MainActor.run { errorMessage = "Invalid URL" }
            return ""
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else {
                await MainActor.run { errorMessage = "Cannot decode webpage" }
                return ""
            }
            let text = extractReadableText(from: html)
            await MainActor.run { self.extractedText = text }
            return text
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
            return ""
        }
    }
    
    private func extractReadableText(from html: String) -> String {
        var r = html
        r = r.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
        r = r.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
        r = r.replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: "", options: .regularExpression)
        
        var metaDesc = "", title = ""
        if let mr = r.range(of: "<meta[^>]*name=\"description\"[^>]*content=\"([^\"]+)\"", options: .regularExpression) {
            metaDesc = String(r[mr]).replacingOccurrences(of: ".*content=\"", with: "", options: .regularExpression).replacingOccurrences(of: "\".*", with: "", options: .regularExpression)
        }
        if let tr = r.range(of: "<title[^>]*>([^<]+)</title>", options: .regularExpression) {
            title = String(r[tr]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }
        
        r = r.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        r = r.replacingOccurrences(of: "&amp;", with: "&")
        r = r.replacingOccurrences(of: "&lt;", with: "<")
        r = r.replacingOccurrences(of: "&gt;", with: ">")
        r = r.replacingOccurrences(of: "&quot;", with: "\"")
        r = r.replacingOccurrences(of: "&#39;", with: "'")
        r = r.replacingOccurrences(of: "&nbsp;", with: " ")
        r = r.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        
        var out = ""
        if !title.isEmpty { out += "📄 \(title)\n\n" }
        if !metaDesc.isEmpty { out += "📝 \(metaDesc)\n\n" }
        out += String(r.prefix(2000))
        if r.count > 2000 { out += "\n\n...(truncated)" }
        return out
    }
}

// MARK: - Voice Store
class VoiceStore: ObservableObject {
    @Published var notes: [VoiceNote] = []
    @Published var isRecording = false
    @Published var liveText = ""
    @Published var currentLanguage = "en-US"
    @Published var selectedVoiceNote: VoiceNote?
    @Published var isProcessingImage = false
    @Published var isProcessingWeb = false
    @Published var mediaError: String?
    
    private let recognizer = SRSpeechRecognizer()
    private var recognitionRequest: SFSpeechBufferAudioRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let eventStore = EKEventStore()
    private let media = MediaProcessor()
    
    let supportedLanguages: [(code: String, name: String)] = [
        ("en-US","English (US)"),("en-GB","English (UK)"),
        ("zh-CN","中文普通话"),("zh-HK","中文粤语"),
        ("ja-JP","日本語"),("ko-KR","한국어"),
        ("es-ES","Español"),("fr-FR","Français"),
        ("de-DE","Deutsch"),("pt-BR","Português"),
        ("it-IT","Italiano"),("ru-RU","Русский"),
        ("ar-SA","العربية"),("hi-IN","हिन्दी"),
        ("th-TH","ไทย"),("vi-VN","Tiếng Việt")
    ]
    
    // MARK: Voice Recording
    func startRecording() {
        guard let rec = SFSpeechRecognizer(locale: Locale(identifier: currentLanguage)), rec.isAvailable else { return }
        liveText = ""; isRecording = true
        
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true)
        
        recognitionRequest = SFSpeechBufferAudioRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        recognitionRequest?.taskHint = .dictation
        
        let input = audioEngine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buf, _ in
            self.recognitionRequest?.append(buf)
        }
        audioEngine.prepare(); try? audioEngine.start()
        
        recognitionTask = rec.recognitionTask(with: recognitionRequest!) { result, error in
            if let r = result { DispatchQueue.main.async { self.liveText = r.bestTranscription.formattedString } }
            if error != nil { self.stopRecording() }
        }
    }
    
    func stopRecording() {
        audioEngine.stop(); audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio(); recognitionTask?.cancel(); isRecording = false
        if !liveText.isEmpty { createNote(liveText, source: .voice, sourceURL: nil, imageData: nil) }
    }
    
    // MARK: Image Processing
    func processImage(_ image: UIImage) async {
        await MainActor.run { isProcessingImage = true; mediaError = nil }
        let text = await media.processImage(image)
        if text.isEmpty {
            let scene = await media.analyzeImageContent(image)
            await MainActor.run { isProcessingImage = false }
            if !scene.isEmpty { createNote(scene, source: .image, sourceURL: nil, imageData: image.jpegData(compressionQuality: 0.7)) }
            return
        }
        await MainActor.run { isProcessingImage = false }
        createNote(text, source: .image, sourceURL: nil, imageData: image.jpegData(compressionQuality: 0.7))
    }
    
    // MARK: Web Link Processing
    func processWebLink(_ url: String) async {
        await MainActor.run { isProcessingWeb = true; mediaError = nil }
        let text = await media.fetchWebContent(url)
        await MainActor.run { isProcessingWeb = false }
        if let err = media.errorMessage { await MainActor.run { mediaError = err }; return }
        guard !text.isEmpty else { return }
        createNote(text, source: .webLink, sourceURL: url, imageData: nil)
    }
    
    // MARK: Unified Note Creation
    private func createNote(_ text: String, source: InputSource, sourceURL: String?, imageData: Data?) {
        let summary = generateSummary(text)
        let actions = extractActions(text)
        let note = VoiceNote(rawText: text, summary: summary, actionItems: actions,
                            language: currentLanguage, createdAt: Date(),
                            audioURL: nil, source: source, sourceURL: sourceURL, imageData: imageData)
        DispatchQueue.main.async {
            self.notes.insert(note, at: 0)
            self.selectedVoiceNote = note
        }
        for action in actions {
            switch action.type {
            case .calendar: createCalendarEvent(action)
            case .reminder: createReminder(action)
            default: break
            }
        }
    }
    
    // MARK: AI Summary
    func generateSummary(_ text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text
        var entities: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if tag == .personalName { entities.append("👤 \(String(text[range]))") }
            if tag == .organizationName { entities.append("🏢 \(String(text[range]))") }
            if tag == .placeName { entities.append("📍 \(String(text[range]))") }
            return true
        }
        let sentences = text.components(separatedBy: ". ")
        let summary = sentences.count > 2 ? "📋 \(sentences.prefix(2).joined(separator: ". "))." : "📋 \(text)"
        return summary + (entities.isEmpty ? "" : "\n\nDetected: \(entities.joined(separator: ", "))")
    }
    
    // MARK: Action Extraction
    func extractActions(_ text: String) -> [ActionItem] {
        var actions: [ActionItem] = []
        let patterns: [(String, ActionType)] = [
            ("meeting|call|conference|discuss|sync|standup", .calendar),
            ("remind|don't forget|remember|alert|notify", .reminder),
            ("todo|task|action item|follow.up|check", .task)
        ]
        for sentence in text.components(separatedBy: [".","!","?","\n"]) {
            let lower = sentence.lowercased().trimmingCharacters(in: .whitespaces)
            guard !lower.isEmpty else { continue }
            for (pat, type) in patterns {
                if lower.range(of: pat, options: .regularExpression) != nil {
                    actions.append(ActionItem(title: sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "remind me to |please |can you ", with: "", options: .regularExpression),
                        dueDate: extractDateTime(from: sentence), type: type))
                    break
                }
            }
        }
        if actions.isEmpty {
            actions.append(ActionItem(title: text.count > 100 ? String(text.prefix(100))+"..." : text,
                                     dueDate: extractDateTime(from: text), type: .note))
        }
        return actions
    }
    
    private func extractDateTime(from text: String) -> Date? {
        let lower = text.lowercased(); let now = Date(); let cal = Calendar.current
        if lower.contains("tomorrow") { return cal.date(byAdding: .day, value: 1, to: now) }
        if lower.contains("next week") { return cal.date(byAdding: .day, value: 7, to: now) }
        if let range = lower.range(of: "in (\\d+) (day|hour|week)s?", options: .regularExpression) {
            let m = String(lower[range]); let n = Int(m.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 1
            if m.contains("hour") { return cal.date(byAdding: .hour, value: n, to: now) }
            if m.contains("week") { return cal.date(byAdding: .day, value: n*7, to: now) }
            return cal.date(byAdding: .day, value: n, to: now)
        }
        return cal.date(byAdding: .hour, value: 1, to: now)
    }
    
    // MARK: Calendar & Reminders
    func createCalendarEvent(_ action: ActionItem) {
        eventStore.requestFullAccessToEvents { granted, _ in
            guard granted else { return }
            let ev = EKEvent(eventStore: self.eventStore)
            ev.title = action.title
            ev.startDate = action.dueDate ?? Date().addingTimeInterval(3600)
            ev.endDate = (action.dueDate ?? Date()).addingTimeInterval(3600)
            ev.calendar = self.eventStore.defaultCalendarForNewEvents
            ev.notes = "Created by VoiceMate"
            ev.addAlarm(EKAlarm(relativeOffset: -900))
            try? self.eventStore.save(ev, span: .thisEvent)
        }
    }
    
    func createReminder(_ action: ActionItem) {
        eventStore.requestFullAccessToReminders { granted, _ in
            guard granted else { return }
            let rem = EKReminder(eventStore: self.eventStore)
            rem.title = action.title
            rem.calendar = self.eventStore.defaultCalendarForNewReminders()
            if let d = action.dueDate {
                rem.dueDateComponents = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: d)
                rem.addAlarm(EKAlarm(absoluteDate: d))
            }
            try? self.eventStore.save(rem, commit: true)
        }
    }
}

// MARK: - IAP Manager
class IAPManager: NSObject, ObservableObject {
    @Published var products: [SKProduct] = []
    @Published var isSubscribed = false
    private let ids = ["com.voicemate.monthly.basic","com.voicemate.monthly.pro","com.voicemate.yearly.pro","com.voicemate.family.monthly"]
    func fetchProducts() {
        let r = SKProductsRequest(productIdentifiers: Set(ids)); r.delegate = self; r.start()
    }
}
extension IAPManager: SKProductsRequestDelegate {
    func productsRequest(_ r: SKProductsRequest, didReceive res: SKProductsResponse) {
        DispatchQueue.main.async { self.products = res.products.sorted { $0.price.doubleValue < $1.price.doubleValue } }
    }
}
