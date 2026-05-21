import SwiftUI
import PhotosUI

// MARK: - Main View (Elderly-Optimized)
struct MainEaseView: View {
    @EnvironmentObject var engine: MemoEngine
    @EnvironmentObject var iap: MemoIAPManager
    @EnvironmentObject var emailManager: EmailManager
    @State private var showHistory = false; @State private var showGuide = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var isExpanded = false
    @State private var showImagePicker = false
    @State private var showURLSheet = false
    @State private var showInviteSheet = false
    @State private var showReferralInput = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var urlInput = ""
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                topBar; Spacer()
                centralRecordButton; statusText; Spacer()
                
                // Processing indicator
                if engine.isProcessing {
                    HStack(spacing: 16) {
                        ProgressView()
                        Text("Working on it...").font(.system(size: 22, design: .rounded))
                    }.padding().background(Color(.systemBackground)).cornerRadius(16).padding(.horizontal)
                }
                
                bottomDock
            }
            if showGuide { guideOverlay }
            if engine.showAlert { successOverlay }
        }
        .sheet(isPresented: $showHistory) { HistoryEaseView() }
        .sheet(isPresented: $showURLSheet) {
            EaseURLSheet(urlInput: $urlInput) { url in
                showURLSheet = false
                Task { await engine.processWebLink(url) }
            }
        }
        .sheet(isPresented: $showInviteSheet) { ReferralShareView() }
        .sheet(isPresented: $showReferralInput) { ReferralCodeInputView() }
        .sheet(isPresented: $emailManager.showBackupPrompt) { BackupPromptView() }
        .photosPicker(isPresented: $showImagePicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, item in
            guard let item = item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await engine.processImageInput(image)
                }
            }
        }
    }
    
    private var topBar: some View {
        HStack {
            Text(Date(), style: .date).font(.system(size: 28, weight: .bold, design: .rounded))
            Spacer()
            if !engine.getTodayPills().isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "pills.fill").font(.title3).foregroundColor(.red)
                    Text("\(engine.getTodayPills().count)").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.red)
                }.padding(.horizontal,16).padding(.vertical,8).background(Color.red.opacity(0.1)).cornerRadius(20)
            }
        }.padding(.horizontal,32).padding(.top,60)
    }
    
    private var centralRecordButton: some View {
        Button(action: {
            if engine.isRecording { engine.stopEasyRecord() }
            else { engine.startEasyRecord() }
        }) {
            ZStack {
                Circle().fill(engine.isRecording ? Color.red : Color.blue).frame(width:200,height:200)
                    .shadow(color: (engine.isRecording ? Color.red : Color.blue).opacity(0.4), radius:20, y:8).scaleEffect(pulseScale)
                Circle().fill(Color.white).frame(width:170,height:170)
                Image(systemName: engine.isRecording ? "waveform" : "mic.fill").font(.system(size:64,weight:.medium))
                    .foregroundColor(engine.isRecording ? .red : .blue)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration:1.5).repeatForever(autoreverses:true)) { pulseScale = 1.05 } }
        .accessibilityLabel(engine.isRecording ? "Stop recording" : "Tap to speak")
    }
    
    private var statusText: some View {
        VStack(spacing:8) {
            if engine.isRecording {
                HStack(spacing:12) {
                    Circle().fill(Color.red).frame(width:12,height:12).opacity(pulseScale==1.05 ? 1.0 : 0.3)
                    Text("Listening...").font(.system(size:28,weight:.medium,design:.rounded)).foregroundColor(.red)
                }
                if !engine.liveText.isEmpty {
                    Text(engine.liveText).font(.system(size:22)).multilineTextAlignment(.center)
                        .padding(.horizontal,32).padding(.vertical,16).background(Color(.systemBackground)).cornerRadius(16)
                        .shadow(color:.black.opacity(0.1),radius:4).padding(.horizontal,24)
                }
            } else {
                Text("Tap the button, take a photo,\nor paste a link").font(.system(size:24,weight:.medium,design:.rounded))
                    .multilineTextAlignment(.center).foregroundColor(.secondary).padding(.top,24)
            }
        }
    }
    
    private var bottomDock: some View {
        HStack(spacing: 18) {
            // History
            Button(action: { showHistory = true }) {
                VStack(spacing:6) {
                    Image(systemName: "list.bullet.rectangle").font(.system(size:28))
                    Text("History").font(.system(size:14,weight:.medium,design:.rounded))
                }.foregroundColor(.primary).frame(width:80,height:72).background(Color(.systemBackground)).cornerRadius(16).shadow(color:.black.opacity(0.08),radius:4)
            }
            // Photo
            Button(action: { showImagePicker = true }) {
                VStack(spacing:6) {
                    Image(systemName: "camera.fill").font(.system(size:28)).foregroundColor(.orange)
                    Text("Photo").font(.system(size:14,weight:.medium,design:.rounded))
                }.foregroundColor(.primary).frame(width:80,height:72).background(Color(.systemBackground)).cornerRadius(16).shadow(color:.black.opacity(0.08),radius:4)
            }
            // Link
            Button(action: { showURLSheet = true }) {
                VStack(spacing:6) {
                    Image(systemName: "link").font(.system(size:28)).foregroundColor(.green)
                    Text("Link").font(.system(size:14,weight:.medium,design:.rounded))
                }.foregroundColor(.primary).frame(width:80,height:72).background(Color(.systemBackground)).cornerRadius(16).shadow(color:.black.opacity(0.08),radius:4)
            }
            // Invite
            Button(action: { showInviteSheet = true }) {
                VStack(spacing:6) {
                    Image(systemName: "gift.fill").font(.system(size:28)).foregroundColor(.pink)
                    Text("Invite").font(.system(size:14,weight:.medium,design:.rounded))
                }.foregroundColor(.primary).frame(width:80,height:72).background(Color(.systemBackground)).cornerRadius(16).shadow(color:.black.opacity(0.08),radius:4)
            }
        }.padding(.bottom,50)
    }
    
    private var guideOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { showGuide = false }
            VStack(spacing:24) {
                Text("👋 Welcome!").font(.system(size:36,weight:.bold,design:.rounded)).foregroundColor(.white)
                VStack(alignment:.leading,spacing:20) {
                    GuideRow(e:"🎤",t:"Tap the blue button to speak")
                    GuideRow(e:"📷",t:"Take a photo of a note or prescription")
                    GuideRow(e:"🔗",t:"Paste a link from family")
                    GuideRow(e:"🔔",t:"We'll remind you on time!")
                }
                Button(action: { showGuide = false }) {
                    Text("Got it!").font(.system(size:28,weight:.bold,design:.rounded)).foregroundColor(.blue)
                        .padding(.horizontal,48).padding(.vertical,16).background(Color.white).cornerRadius(30)
                }.padding(.top,16)
            }.padding(40).background(Color.blue.opacity(0.9)).cornerRadius(24).padding(32)
        }
    }
    
    private var successOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing:16) {
                Image(systemName: "checkmark.circle.fill").font(.system(size:56)).foregroundColor(.green)
                Text(engine.alertMessage).font(.system(size:22,weight:.medium,design:.rounded)).multilineTextAlignment(.center).foregroundColor(.white)
            }.padding(32).background(Color.black.opacity(0.85)).cornerRadius(24).padding(40)
            .onAppear { DispatchQueue.main.asyncAfter(deadline:.now()+2.5) { withAnimation { engine.showAlert = false } } }
            Spacer()
        }
    }
}

struct GuideRow: View { let e: String; let t: String
    var body: some View { HStack(spacing:16) { Text(e).font(.system(size:32)); Text(t).font(.system(size:22,weight:.medium,design:.rounded)).foregroundColor(.white) } }
}

// MARK: - URL Input Sheet (Elderly-Friendly)
struct EaseURLSheet: View {
    @Binding var urlInput: String; let onSubmit: (String) -> Void
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing:28) {
                Image(systemName: "link.circle.fill").font(.system(size:56)).foregroundColor(.blue)
                Text("Paste a Link").font(.system(size:32,weight:.bold,design:.rounded))
                Text("Your family sent you a link? Paste it here and we'll remind you about what's inside.")
                    .font(.system(size:18,design:.rounded)).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal,32)
                TextField("Paste link here...", text: $urlInput)
                    .textFieldStyle(.roundedBorder).font(.system(size:20,design:.rounded))
                    .keyboardType(.URL).autocapitalization(.none).padding(.horizontal,32)
                Button(action: { onSubmit(urlInput) }) {
                    Text("Read Link").font(.system(size:24,weight:.bold,design:.rounded)).foregroundColor(.white)
                        .padding().frame(maxWidth:.infinity).background(urlInput.isEmpty ? Color.gray : Color.blue).cornerRadius(16)
                }.disabled(urlInput.isEmpty).padding(.horizontal,32)
                Spacer()
            }.padding(.top,32)
            .navigationTitle("Web Link").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Cancel") { dismiss() }.font(.system(size:20,design:.rounded)) } }
        }.presentationDetents([.medium])
    }
}

// MARK: - History View
struct HistoryEaseView: View {
    @EnvironmentObject var engine: MemoEngine; @Environment(\.dismiss) var dismiss
    @State private var filter: MemoCategory? = nil
    var filtered: [EaseNote] { guard let f=filter else { return engine.notes }; return engine.notes.filter{$0.category==f} }
    var body: some View {
        NavigationStack {
            VStack(spacing:0) {
                ScrollView(.horizontal,showsIndicators:false) {
                    HStack(spacing:12) {
                        FilterChip(label:"All",isSelected:filter==nil){filter=nil}
                        ForEach(MemoCategory.allCases,id:\.self){c in FilterChip(label:c.rawValue,isSelected:filter==c){filter=c}}
                    }.padding(.horizontal,20).padding(.vertical,12)
                }.background(Color(.systemGroupedBackground))
                if filtered.isEmpty {
                    Spacer()
                    ContentUnavailableView("No reminders yet",systemImage:"tray",description:Text("Tap the button, camera, or link to create one!"))
                    Spacer()
                } else {
                    List { ForEach(filtered) { EaseNoteRow(note:$0).listRowSeparator(.hidden).listRowInsets(EdgeInsets(top:6,leading:16,bottom:6,trailing:16)) }
                        .onDelete { engine.notes.remove(atOffsets:$0) } }.listStyle(.plain)
                }
            }
            .navigationTitle("My Reminders").navigationBarTitleDisplayMode(.large)
            .toolbar { ToolbarItem(placement:.topBarTrailing){Button("Close"){dismiss()}.font(.system(size:20,weight:.medium,design:.rounded))} }
        }
    }
}

struct FilterChip: View { let label: String; let isSelected: Bool; let action: () -> Void
    var body: some View { Button(action:action){Text(label).font(.system(size:18,weight:isSelected ? .bold : .medium,design:.rounded)).padding(.horizontal,16).padding(.vertical,10).background(isSelected ? Color.blue : Color(.systemBackground)).foregroundColor(isSelected ? .white : .primary).cornerRadius(20).shadow(color:.black.opacity(isSelected ? 0.15 : 0.05),radius:3)} }
}

struct EaseNoteRow: View { let note: EaseNote
    var body: some View {
        HStack(spacing:16) {
            Text(String(note.category.rawValue.prefix(2))).font(.system(size:32)).frame(width:56,height:56).background(note.category.color.opacity(0.15)).cornerRadius(16)
            VStack(alignment:.leading,spacing:6) {
                HStack(spacing:6) {
                    Text(note.source.rawValue).font(.system(size:14,design:.rounded)).padding(.horizontal,6).padding(.vertical,2).background(Color(.systemGray5)).cornerRadius(4)
                    if note.isMedication { Label("Pill",systemImage:"pills.fill").font(.system(size:14,design:.rounded)).foregroundColor(.red) }
                }
                Text(note.coreIdea).font(.system(size:20,weight:.medium,design:.rounded)).lineLimit(2)
                HStack(spacing:8) {
                    if let d=note.reminderDate { Label(d.formatted(date:.omitted,time:.shortened),systemImage:"bell.fill").font(.system(size:16,design:.rounded)).foregroundColor(.orange) }
                }
                Text(note.createdAt.formatted(.relative(presentation:.named))).font(.system(size:14,design:.rounded)).foregroundColor(.secondary)
            }
            Spacer(); Image(systemName:"chevron.right").font(.caption).foregroundColor(.secondary)
        }.padding().background(Color(.systemBackground)).cornerRadius(16).shadow(color:.black.opacity(0.04),radius:3)
    }
}
