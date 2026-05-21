import SwiftUI
import PhotosUI

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var store: VoiceStore
    @EnvironmentObject var iap: IAPManager
    @EnvironmentObject var emailManager: EmailManager
    @State private var selectedTab = 0
    @State private var showPaywall = false
    @State private var showImagePicker = false
    @State private var showURLSheet = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var urlInput = ""
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                RecordView(showPaywall: $showPaywall,
                           showImagePicker: $showImagePicker,
                           showURLSheet: $showURLSheet)
                    .tabItem { Label("Record", systemImage: "mic.circle.fill") }.tag(0)
                
                NotesListView()
                    .tabItem { Label("History", systemImage: "list.bullet.rectangle") }.tag(1)
                
                CalendarView()
                    .tabItem { Label("Calendar", systemImage: "calendar") }.tag(2)
                
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }.tag(3)
            }
            .accentColor(.indigo)
            
            // Floating multi-mode input button
            VStack {
                Spacer()
                if !store.isRecording {
                    FloatingInputMenu(selectedTab: $selectedTab,
                                      showImagePicker: $showImagePicker,
                                      showURLSheet: $showURLSheet)
                        .padding(.bottom, 90)
                }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $emailManager.showBackupPrompt) { BackupPromptView() }
        .sheet(isPresented: $showURLSheet) {
            URLInputSheet(urlInput: $urlInput) { url in
                showURLSheet = false
                Task { await store.processWebLink(url) }
            }
        }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedPhoto,
                     matching: .images, photoLibrary: .shared())
        .onChange(of: selectedPhoto) { _, newItem in
            guard let item = newItem else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await store.processImage(image)
                }
            }
        }
    }
}

// MARK: - Floating Input Menu (Multi-mode)
struct FloatingInputMenu: View {
    @EnvironmentObject var store: VoiceStore
    @Binding var selectedTab: Int
    @Binding var showImagePicker: Bool
    @Binding var showURLSheet: Bool
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 12) {
            if isExpanded {
                // Image button
                Button(action: { showImagePicker = true; isExpanded = false }) {
                    Label("Image", systemImage: "camera.fill")
                        .font(.subheadline)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial).cornerRadius(20)
                }
                .transition(.scale.combined(with: .opacity))
                
                // URL button
                Button(action: { showURLSheet = true; isExpanded = false }) {
                    Label("Link", systemImage: "link")
                        .font(.subheadline)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial).cornerRadius(20)
                }
                .transition(.scale.combined(with: .opacity))
                
                // Voice button
                Button(action: { selectedTab = 0; store.startRecording(); isExpanded = false }) {
                    Label("Voice", systemImage: "mic.fill")
                        .font(.subheadline)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial).cornerRadius(20)
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Main toggle button
            Button(action: { withAnimation(.spring(response: 0.4)) { isExpanded.toggle() } }) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.indigo, .purple],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 64, height: 64)
                        .shadow(color: .indigo.opacity(0.4), radius: 10, y: 4)
                    
                    Image(systemName: isExpanded ? "xmark" : "plus")
                        .font(.title2).foregroundColor(.white)
                        .rotationEffect(.degrees(isExpanded ? 45 : 0))
                }
            }
        }
    }
}

// MARK: - URL Input Sheet
struct URLInputSheet: View {
    @Binding var urlInput: String
    let onSubmit: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 56)).foregroundColor(.indigo)
                
                Text("Paste a web link")
                    .font(.title2).fontWeight(.semibold)
                
                Text("VoiceMate will extract the page content and create action items from it.")
                    .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                TextField("https://example.com/article", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal)
                
                Button(action: { onSubmit(urlInput) }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Extract Content")
                    }
                    .font(.headline).foregroundColor(.white).padding().frame(maxWidth: .infinity)
                    .background(urlInput.isEmpty ? Color.gray : Color.indigo).cornerRadius(14)
                }
                .disabled(urlInput.isEmpty).padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Web Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Record View
struct RecordView: View {
    @EnvironmentObject var store: VoiceStore
    @Binding var showPaywall: Bool
    @Binding var showImagePicker: Bool
    @Binding var showURLSheet: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if store.isRecording {
                    recordingState
                } else {
                    idleState
                }
                
                // Processing indicators
                if store.isProcessingImage {
                    processingBanner(icon: "photo", text: "Reading image...")
                }
                if store.isProcessingWeb {
                    processingBanner(icon: "globe", text: "Fetching webpage...")
                }
                if let err = store.mediaError {
                    Text("⚠️ \(err)").font(.caption).foregroundColor(.red).padding(.horizontal)
                }
                
                if !store.notes.isEmpty { recentSection }
                Spacer()
            }
            .navigationTitle("VoiceMate")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { languagePicker } }
        }
    }
    
    private func processingBanner(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
            Image(systemName: icon)
            Text(text).font(.subheadline)
        }
        .padding().background(Color(.systemGray6)).cornerRadius(12).padding(.horizontal)
    }
    
    private var idleState: some View {
        VStack(spacing: 32) {
            Spacer().frame(height: 40)
            ZStack {
                Circle().fill(Color.indigo.opacity(0.1)).frame(width: 200, height: 200)
                Circle().fill(Color.indigo.opacity(0.2)).frame(width: 160, height: 160)
                Image(systemName: "waveform.circle.fill").font(.system(size: 80)).foregroundColor(.indigo)
            }
            Text("Choose your input").font(.title2).fontWeight(.medium)
            
            HStack(spacing: 20) {
                QuickActionChip(icon: "mic.fill", label: "Voice", color: .indigo) {
                    store.startRecording()
                }
                QuickActionChip(icon: "camera.fill", label: "Image", color: .orange) {
                    showImagePicker = true
                }
                QuickActionChip(icon: "link", label: "Web", color: .green) {
                    showURLSheet = true
                }
            }
        }.padding()
    }
    
    private var recordingState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)
            WaveformAnimation().frame(height: 60)
            ScrollView {
                Text(store.liveText.isEmpty ? "Listening..." : store.liveText)
                    .font(.title3).padding().frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeInOut, value: store.liveText)
            }
            .frame(maxHeight: 200).background(Color(.systemGray6)).cornerRadius(16).padding(.horizontal)
            
            Button(action: store.stopRecording) {
                ZStack {
                    Circle().fill(Color.red).frame(width: 80, height: 80)
                    RoundedRectangle(cornerRadius: 4).fill(Color.white).frame(width: 24, height: 24)
                }
            }
            Text("Tap to finish").font(.caption).foregroundColor(.secondary)
        }.padding()
    }
    
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent").font(.headline).padding(.horizontal)
            ForEach(store.notes.prefix(3)) { note in
                NoteCard(note: note).padding(.horizontal)
            }
        }
    }
    
    private var languagePicker: some View {
        Menu {
            ForEach(store.supportedLanguages, id: \.code) { lang in
                Button(action: { store.currentLanguage = lang.code }) {
                    HStack {
                        Text(lang.name)
                        if store.currentLanguage == lang.code { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) { Image(systemName: "globe"); Text(store.currentLanguage).font(.caption) }
        }
    }
}

// MARK: - Waveform Animation
struct WaveformAnimation: View {
    @State private var phase = 0.0
    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { ctx, size in
                let w = size.width / 5
                for i in 0..<5 {
                    let x = Double(i)*w + w/2
                    let h = sin(phase + Double(i)*0.7)*20 + 30
                    ctx.fill(Path(roundedRect: CGRect(x: x-2, y: size.height/2 - h/2, width: 4, height: h), cornerRadius: 2), with: .color(.indigo))
                }
            }
        }
        .onAppear { withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { phase += .pi*2 } }
    }
}

// MARK: - Quick Action Chip
struct QuickActionChip: View {
    let icon: String; let label: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title2).foregroundColor(color)
                Text(label).font(.caption)
            }
            .frame(width: 90, height: 90).background(Color(.systemGray6)).cornerRadius(16)
        }
    }
}

// MARK: - Note Card
struct NoteCard: View {
    let note: VoiceNote
    var body: some View {
        NavigationLink(destination: NoteDetailView(note: note)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(note.source.rawValue).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(sourceColor.opacity(0.15)).cornerRadius(4)
                    Spacer()
                    Text(note.createdAt, style: .relative).font(.caption2).foregroundColor(.secondary)
                }
                Text(note.summary).font(.subheadline).fontWeight(.medium).lineLimit(2)
                if !note.actionItems.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(note.actionItems) { ActionChip(item: $0) }
                        }
                    }
                }
            }
            .padding().background(Color(.systemBackground)).cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
    }
    private var sourceColor: Color {
        switch note.source { case .voice: return .indigo; case .image: return .orange; case .webLink: return .green }
    }
}

struct ActionChip: View {
    let item: ActionItem
    var body: some View {
        HStack(spacing: 4) {
            Text(item.type.rawValue.components(separatedBy: " ").last ?? "").font(.caption2)
            Text(item.title).font(.caption2).lineLimit(1)
        }
        .padding(.horizontal, 8).padding(.vertical, 4).background(chipColor.opacity(0.15)).cornerRadius(8)
    }
    private var chipColor: Color {
        switch item.type { case .calendar: return .blue; case .reminder: return .orange; case .task: return .green; case .note: return .gray }
    }
}

// MARK: - Note Detail View
struct NoteDetailView: View {
    let note: VoiceNote; @EnvironmentObject var store: VoiceStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack { Text(note.source.rawValue).font(.caption).padding(.horizontal,8).padding(.vertical,4).background(Color(.systemGray5)).cornerRadius(6); Spacer(); Text(note.language).font(.caption).foregroundColor(.secondary) }
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("AI Summary", systemImage: "sparkles").font(.headline).foregroundColor(.indigo)
                    Text(note.summary).font(.body)
                }
                
                // Show image if source is image
                if note.source == .image, let data = note.imageData, let uiImage = UIImage(data: data) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Source Image", systemImage: "photo").font(.headline)
                        Image(uiImage: uiImage).resizable().scaledToFit().cornerRadius(12).frame(maxHeight: 250)
                    }
                }
                
                // Show URL if source is web
                if note.source == .webLink, let url = note.sourceURL {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Source", systemImage: "link").font(.headline)
                        Text(url).font(.caption).foregroundColor(.blue)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Transcript", systemImage: "text.quote").font(.headline)
                    Text(note.rawText).font(.body).foregroundColor(.secondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Label("Action Items", systemImage: "checklist").font(.headline)
                    ForEach(note.actionItems) { ActionItemRow(item: $0) }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Created: \(note.createdAt.formatted())").font(.caption).foregroundColor(.secondary)
                }
            }.padding()
        }
        .navigationTitle("Detail").navigationBarTitleDisplayMode(.inline)
    }
}

struct ActionItemRow: View {
    @State var item: ActionItem
    var body: some View {
        HStack {
            Button(action: { item.isDone.toggle() }) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isDone ? .green : .gray)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.subheadline).strikethrough(item.isDone)
                if let d = item.dueDate { Text(d.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundColor(.secondary) }
            }
            Spacer(); Text(item.type.rawValue).font(.caption2).foregroundColor(.secondary)
        }
    }
}

// MARK: - Notes List View
struct NotesListView: View {
    @EnvironmentObject var store: VoiceStore
    var body: some View {
        NavigationStack {
            if store.notes.isEmpty {
                ContentUnavailableView("No recordings yet", systemImage: "mic.slash", description: Text("Use voice, image, or web link to create notes"))
            } else {
                List(store.notes) { note in NoteCard(note: note).listRowSeparator(.hidden) }.listStyle(.plain)
            }
            .navigationTitle("History")
        }
    }
}

// MARK: - Calendar View
struct CalendarView: View {
    @EnvironmentObject var store: VoiceStore
    var body: some View {
        NavigationStack {
            List {
                Section("Upcoming") {
                    let items = store.notes.flatMap { $0.actionItems }
                        .filter { $0.type == .calendar || $0.type == .reminder }
                        .filter { ($0.dueDate ?? .distantPast) > Date() }
                        .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
                    if items.isEmpty { Text("No upcoming events").foregroundColor(.secondary) }
                    else { ForEach(items) { ActionItemRow(item: $0) } }
                }
            }.navigationTitle("Calendar")
        }
    }
}

// MARK: - Paywall View
struct PaywallView: View {
    @Environment(\.dismiss) var dismiss; @EnvironmentObject var iap: IAPManager
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "crown.fill").font(.system(size: 60)).foregroundColor(.yellow)
            Text("Go Pro").font(.largeTitle).fontWeight(.bold)
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "infinity", text: "Unlimited recordings"); FeatureRow(icon: "camera.fill", text: "Image & Web OCR")
                FeatureRow(icon: "globe", text: "30+ languages"); FeatureRow(icon: "calendar.badge.plus", text: "Auto calendar sync")
                FeatureRow(icon: "sparkles", text: "AI-powered summaries"); FeatureRow(icon: "icloud", text: "Cloud sync")
                FeatureRow(icon: "gift.fill", text: "Earn free months by referring friends")
            }.padding()
            ForEach(iap.products, id: \.productIdentifier) { product in
                Button(action: {}) {
                    HStack {
                        VStack(alignment: .leading) { 
                            Text(product.localizedTitle).fontWeight(.semibold)
                            if product.productIdentifier.contains("family") {
                                Text("Up to 5 family members").font(.caption).foregroundColor(.orange)
                            } else {
                                Text(product.localizedDescription).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer(); Text("\(product.price)").fontWeight(.bold)
                    }.padding().background(Color(.systemGray6)).cornerRadius(12)
                }
            }.padding(.horizontal)
            Button("Continue with Free") { dismiss() }.foregroundColor(.secondary)
            Spacer()
        }
    }
}
struct FeatureRow: View { let icon: String; let text: String
    var body: some View { HStack(spacing: 12) { Image(systemName: icon).foregroundColor(.indigo); Text(text).font(.subheadline) } }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var store: VoiceStore; @EnvironmentObject var iap: IAPManager
    @EnvironmentObject var referral: ReferralEngine
    @EnvironmentObject var emailManager: EmailManager
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Default Language") {
                    Picker("Language", selection: $store.currentLanguage) {
                        ForEach(store.supportedLanguages, id: \.code) { Text($0.name).tag($0.code) }
                    }
                }
                Section("Subscription") {
                    HStack { Text("Status"); Spacer(); Text(iap.isSubscribed ? "Pro" : "Free").foregroundColor(iap.isSubscribed ? .green : .secondary) }
                    if !iap.isSubscribed { NavigationLink("Upgrade to Pro") { PaywallView() } }
                    NavigationLink("Enter Referral Code") { ReferralCodeInputView() }
                }
                
                Section {
                    NavigationLink(destination: ReferralShareView()) {
                        HStack {
                            Image(systemName: "gift.fill").foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Invite Friends, Earn Rewards").font(.subheadline).fontWeight(.medium)
                                Text("\(referral.referralCount) referrals · \(referral.availableFreeMonths) free months")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if referral.referralCount > 0 {
                                Text("🎁").font(.title3)
                            }
                        }
                    }
                } header: {
                    Text("Referral Program")
                } footer: {
                    Text("Share your code. Every 2 friends who join = 1 free month for you!")
                }
                
                EmailSettingsSection()
                
                Section("About") { LabeledContent("Version", value: "1.1.0"); LabeledContent("Build", value: "2026.3")
                    LabeledContent("Referral Code", value: referral.referralCode)
                }
            }.navigationTitle("Settings")
        }
    }
}
