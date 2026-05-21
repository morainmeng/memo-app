import SwiftUI
import MessageUI

// MARK: - Email Collection Manager
class EmailManager: ObservableObject {
    @Published var userEmail: String = ""
    @Published var newsletterOptIn: Bool = false
    @Published var hasSeenBackupPrompt: Bool = false
    @Published var backupCount: Int = 0
    @Published var showBackupPrompt: Bool = false
    @Published var showEmailSheet: Bool = false
    
    private let defaults = UserDefaults.standard
    private let emailKey = "user_email"
    private let newsletterKey = "newsletter_optin"
    private let backupPromptSeenKey = "backup_prompt_seen"
    private let backupCountKey = "backup_count"
    
    // Anti-spam: track when user was last asked
    private let lastPromptKey = "last_email_prompt_date"
    
    init() {
        userEmail = defaults.string(forKey: emailKey) ?? ""
        newsletterOptIn = defaults.bool(forKey: newsletterKey)
        hasSeenBackupPrompt = defaults.bool(forKey: backupPromptSeenKey)
        backupCount = defaults.integer(forKey: backupCountKey)
    }
    
    var hasEmail: Bool {
        !userEmail.trimmingCharacters(in: .whitespaces).isEmpty && isValidEmail(userEmail)
    }
    
    func saveEmail(_ email: String) {
        let trimmed = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard isValidEmail(trimmed) else { return }
        userEmail = trimmed
        defaults.set(trimmed, forKey: emailKey)
    }
    
    func toggleNewsletter(_ on: Bool) {
        newsletterOptIn = on
        defaults.set(on, forKey: newsletterKey)
    }
    
    // MARK: - Smart Backup Prompt Logic
    
    /// Called after user completes their 3rd recording → show backup prompt
    func checkBackupPrompt(after recordingCount: Int) {
        guard !hasEmail else { return } // Already has email
        guard !hasSeenBackupPrompt else { return } // Already seen
        
        // Debounce: only prompt once per 7 days
        if let lastDate = defaults.object(forKey: lastPromptKey) as? Date {
            let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            guard daysSince >= 7 else { return }
        }
        
        // Trigger at 3rd, 10th, 25th recording milestones
        let milestones = [3, 10, 25]
        guard milestones.contains(recordingCount) else { return }
        
        showBackupPrompt = true
        defaults.set(Date(), forKey: lastPromptKey)
    }
    
    func dismissBackupPrompt() {
        showBackupPrompt = false
        defaults.set(true, forKey: backupPromptSeenKey)
        hasSeenBackupPrompt = true
    }
    
    // MARK: - Backup Export
    func generateBackupCSV(from notes: [Any]) -> String {
        var csv = "Date,Source,Content,Category,Reminder\n"
        
        for note in notes {
            if let n = note as? VoiceNote {
                let date = n.createdAt.ISO8601Format()
                let source = n.source.rawValue
                let content = n.rawText.replacingOccurrences(of: "\"", with: "\"\"")
                let category = "Voice"
                let reminder = n.actionItems.first?.dueDate?.ISO8601Format() ?? ""
                csv += "\(date),\(source),\"\(content)\",\(category),\(reminder)\n"
            } else if let n = note as? EaseNote {
                let date = n.createdAt.ISO8601Format()
                let source = n.source.rawValue
                let content = n.spokenText.replacingOccurrences(of: "\"", with: "\"\"")
                let category = n.category.rawValue
                let reminder = n.reminderDate?.ISO8601Format() ?? ""
                csv += "\(date),\(source),\"\(content)\",\(category),\(reminder)\n"
            }
        }
        return csv
    }
    
    func backupRecorded() {
        backupCount += 1
        defaults.set(backupCount, forKey: backupCountKey)
    }
    
    // MARK: - Export Reminders to Email
    func composeBackupEmailBody(appName: String, noteCount: Int) -> String {
        """
        <html>
        <body style="font-family: -apple-system, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; border-radius: 16px; text-align: center;">
                <h1 style="color: white; margin: 0;">📋 Your \(appName) Backup</h1>
                <p style="color: rgba(255,255,255,0.9);">\(noteCount) reminders exported on \(Date().formatted(date: .long, time: .shortened))</p>
            </div>
            
            <div style="padding: 20px;">
                <p>Hi there! 👋</p>
                <p>Your reminders backup is attached as a CSV file. You can open it with any spreadsheet app.</p>
                
                <div style="background: #f0f0f5; padding: 16px; border-radius: 12px; margin: 20px 0;">
                    <h3 style="margin-top: 0;">📊 Your Stats</h3>
                    <p>📝 Total reminders: <strong>\(noteCount)</strong></p>
                    <p>💾 Backups made: <strong>\(backupCount)</strong></p>
                </div>
                
                <div style="background: #fff3e0; padding: 16px; border-radius: 12px; margin: 20px 0;">
                    <h3 style="margin-top: 0;">🎁 Want weekly tips?</h3>
                    <p>Reply "YES" to this email to get:
                    <br>• Productivity hacks for busy professionals
                    <br>• Early access to new features  
                    <br>• Exclusive discount offers</p>
                </div>
                
                <p style="color: #888; font-size: 12px;">
                    You received this email because you requested a backup from \(appName).
                    <br>To stop receiving emails, reply "STOP".
                </p>
            </div>
        </body>
        </html>
        """
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}

// MARK: - Backup Prompt Sheet (Shared UI)
struct BackupPromptView: View {
    @EnvironmentObject var emailManager: EmailManager
    @State private var emailInput: String = ""
    @State private var newsletterChecked: Bool = true
    @State private var showSuccess: Bool = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.indigo)
                
                Text("Never Lose Your Reminders")
                    .font(.title2).fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Get a backup of your reminders sent to your email. We'll also let you know about new features and tips.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
                
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "envelope.fill").foregroundColor(.indigo)
                        TextField("your@email.com", text: $emailInput)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    Toggle(isOn: $newsletterChecked) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Send me weekly productivity tips")
                                .font(.subheadline)
                            Text("You can unsubscribe anytime")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }.padding().background(Color(.systemGray6)).cornerRadius(12)
                
                Button(action: saveAndBackup) {
                    HStack {
                        if showSuccess {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Sent!")
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Backup My Reminders")
                        }
                    }
                    .font(.headline).foregroundColor(.white)
                    .padding().frame(maxWidth: .infinity)
                    .background(isValidInput ? Color.indigo : Color.gray).cornerRadius(14)
                }
                .disabled(!isValidInput).padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Maybe Later") { emailManager.dismissBackupPrompt(); dismiss() }
                }
            }
        }
    }
    
    private var isValidInput: Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return emailInput.range(of: pattern, options: .regularExpression) != nil
    }
    
    private func saveAndBackup() {
        emailManager.saveEmail(emailInput)
        emailManager.toggleNewsletter(newsletterChecked)
        emailManager.backupRecorded()
        showSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            emailManager.showBackupPrompt = false
            dismiss()
        }
    }
}

// MARK: - Email Settings Section (Reusable)
struct EmailSettingsSection: View {
    @EnvironmentObject var emailManager: EmailManager
    @State private var editEmail: String = ""
    @State private var isEditing = false
    
    var body: some View {
        Section {
            if emailManager.hasEmail && !isEditing {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(emailManager.userEmail).font(.subheadline)
                        Text("\(emailManager.backupCount) backups made").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Edit") { editEmail = emailManager.userEmail; isEditing = true }
                        .font(.caption)
                }
            } else {
                HStack {
                    Image(systemName: "envelope.fill").foregroundColor(.indigo)
                    TextField("your@email.com", text: $editEmail)
                        .keyboardType(.emailAddress).autocapitalization(.none)
                    Button("Save") {
                        emailManager.saveEmail(editEmail)
                        isEditing = false
                    }.font(.caption).disabled(editEmail.isEmpty)
                }
            }
            
            Toggle("Weekly productivity tips", isOn: Binding(
                get: { emailManager.newsletterOptIn },
                set: { emailManager.toggleNewsletter($0) }
            ))
            
            if emailManager.hasEmail {
                Button(action: { emailManager.showEmailSheet = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Backup to Email")
                    }
                }
            }
        } header: {
            Text("Email & Backup")
        } footer: {
            Text(emailManager.hasEmail
                 ? "Backups and tips sent to \(emailManager.userEmail). Unsubscribe anytime."
                 : "Add your email to back up reminders and get weekly tips.")
        }
    }
}
