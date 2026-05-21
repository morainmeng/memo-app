import SwiftUI
import CryptoKit
import CloudKit

// MARK: - Referral Engine (Shared Component)
class ReferralEngine: ObservableObject {
    @Published var referralCode: String = ""
    @Published var referralCount: Int = 0
    @Published var freeMonthsEarned: Int = 0
    @Published var freeMonthsUsed: Int = 0
    @Published var referredBy: String?
    @Published var pendingReward = false
    
    private let defaults = UserDefaults.standard
    private let codeKey = "referral_code"
    private let countKey = "referral_count"
    private let earnedKey = "free_months_earned"
    private let usedKey = "free_months_used"
    private let referredByKey = "referred_by"
    private let referralsKey = "referral_list"
    
    init() { loadState() }
    
    // MARK: - Code Generation
    func generateReferralCode() -> String {
        if let existing = defaults.string(forKey: codeKey), !existing.isEmpty {
            return existing
        }
        // Generate a friendly code: 6 chars, uppercase alphanumeric
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let hash = SHA256.hash(data: Data((deviceID + Date().timeIntervalSince1970.description).utf8))
        let base62 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let bytes = Array(hash.prefix(4))
        let code = bytes.map { base62[Int($0) % 36] }.map(String.init).joined()
        defaults.set(code, forKey: codeKey)
        referralCode = code
        return code
    }
    
    // MARK: - Apply Referral Code (New User)
    func applyReferralCode(_ code: String) -> Bool {
        guard !code.isEmpty, code != referralCode else { return false }
        guard referredBy == nil else { return false } // Already used a code
        
        // In production, validate against CloudKit public database
        // For MVP: store locally, caller should validate via CloudKit
        defaults.set(code, forKey: referredByKey)
        referredBy = code
        
        // The referrer's count will be incremented via CloudKit sync
        syncReferralToCloud(code: code)
        return true
    }
    
    // MARK: - Record Referral (Referrer Side)
    func recordNewReferral(from newUserCode: String) {
        var list = getReferralList()
        guard !list.contains(newUserCode) else { return } // No duplicates
        
        list.append(newUserCode)
        defaults.set(list, forKey: referralsKey)
        
        referralCount = list.count
        defaults.set(referralCount, forKey: countKey)
        
        // Check for reward: every 2 referrals = 1 free month
        let newEarned = referralCount / 2
        if newEarned > freeMonthsEarned {
            let monthsAwarded = newEarned - freeMonthsEarned
            freeMonthsEarned = newEarned
            defaults.set(freeMonthsEarned, forKey: earnedKey)
            pendingReward = true
        }
    }
    
    // MARK: - Redeem Free Month
    func redeemFreeMonth() -> Bool {
        let available = freeMonthsEarned - freeMonthsUsed
        guard available > 0 else { return false }
        
        freeMonthsUsed += 1
        defaults.set(freeMonthsUsed, forKey: usedKey)
        pendingReward = false
        
        // Extend subscription by 1 month
        extendSubscription(by: 1)
        return true
    }
    
    var availableFreeMonths: Int {
        max(0, freeMonthsEarned - freeMonthsUsed)
    }
    
    var nextRewardAt: Int {
        ((freeMonthsEarned + 1) * 2) - referralCount
    }
    
    // MARK: - Family Subscription
    func getFamilyReferralBonus() -> Int {
        // Family plans get double referral credit
        return 2
    }
    
    var shareMessage: String {
        """
        🎤 I've been using VoiceMate to turn my voice into calendar events and reminders. 
        It's been a game-changer for my productivity!
        
        Use my referral code: **\(referralCode)**
        Get 7 days free trial + I earn a free month for every 2 friends who join!
        
        Download: https://apps.apple.com/app/voicemate
        """
    }
    
    // MARK: - Private
    private func loadState() {
        referralCode = defaults.string(forKey: codeKey) ?? ""
        referralCount = defaults.integer(forKey: countKey)
        freeMonthsEarned = defaults.integer(forKey: earnedKey)
        freeMonthsUsed = defaults.integer(forKey: usedKey)
        referredBy = defaults.string(forKey: referredByKey)
        if referralCode.isEmpty { _ = generateReferralCode() }
    }
    
    private func getReferralList() -> [String] {
        defaults.stringArray(forKey: referralsKey) ?? []
    }
    
    private func syncReferralToCloud(code: String) {
        // CloudKit sync for production
        let record = CKRecord(recordType: "Referral")
        record["referrerCode"] = code
        record["timestamp"] = Date()
        CKContainer.default().publicCloudDatabase.save(record) { _, _ in }
    }
    
    private func extendSubscription(by months: Int) {
        // Store the extended expiry in UserDefaults
        // In production, this would update the IAP receipt validation
        let currentExpiry = defaults.double(forKey: "subscription_expiry")
        let newExpiry = max(Date().timeIntervalSince1970, currentExpiry) + Double(months * 30 * 24 * 3600)
        defaults.set(newExpiry, forKey: "subscription_expiry")
    }
}

// MARK: - Family Subscription Manager
class FamilySubscriptionManager: ObservableObject {
    @Published var isFamilyPlan = false
    @Published var familyMembers: [FamilyMember] = []
    @Published var maxFamilyMembers = 5
    
    struct FamilyMember: Identifiable, Codable {
        let id = UUID()
        var name: String
        var email: String?
        var status: MemberStatus
    }
    
    enum MemberStatus: String, Codable {
        case active, pending, declined
    }
    
    func addFamilyMember(name: String, email: String? = nil) {
        guard familyMembers.count < maxFamilyMembers else { return }
        let member = FamilyMember(name: name, email: email, status: .pending)
        familyMembers.append(member)
        // Send invitation via CloudKit share
    }
    
    func removeFamilyMember(_ member: FamilyMember) {
        familyMembers.removeAll { $0.id == member.id }
    }
}

// MARK: - Referral Code Input View (Shared UI)
struct ReferralCodeInputView: View {
    @EnvironmentObject var referral: ReferralEngine
    @State private var codeInput = ""
    @State private var showSuccess = false
    @State private var showError = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.orange)
                
                Text("Got a Referral Code?")
                    .font(.title2).fontWeight(.bold)
                
                Text("Enter your friend's code to give them credit and unlock your free trial extension.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
                
                HStack(spacing: 12) {
                    ForEach(0..<6) { i in
                        let char = i < codeInput.count
                            ? String(codeInput[codeInput.index(codeInput.startIndex, offsetBy: i)])
                            : ""
                        Text(char)
                            .font(.title).fontWeight(.bold).monospaced()
                            .frame(width: 40, height: 52)
                            .background(Color(.systemGray6)).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(char.isEmpty ? Color.clear : Color.orange, lineWidth: 2))
                    }
                }
                
                TextField("Enter 6-character code", text: $codeInput)
                    .textFieldStyle(.roundedBorder).font(.title3).multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters).disableAutocorrection(true)
                    .frame(maxWidth: 280)
                    .onChange(of: codeInput) { _, new in
                        let filtered = new.uppercased().filter { "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".contains($0) }
                        if filtered.count <= 6 { codeInput = filtered }
                    }
                
                Button(action: submitCode) {
                    HStack {
                        Image(systemName: "checkmark.seal")
                        Text("Apply Code")
                    }
                    .font(.headline).foregroundColor(.white).padding().frame(maxWidth: .infinity)
                    .background(codeInput.count == 6 ? Color.orange : Color.gray).cornerRadius(14)
                }
                .disabled(codeInput.count != 6).padding(.horizontal)
                
                if showSuccess {
                    Label("Code applied! Your friend earned credit.", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green).font(.subheadline)
                }
                if showError {
                    Label("Invalid or already used code.", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red).font(.subheadline)
                }
                
                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Referral Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Skip") { dismiss() } } }
        }
    }
    
    private func submitCode() {
        guard codeInput.count == 6 else { return }
        if referral.applyReferralCode(codeInput) {
            showSuccess = true; showError = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
        } else {
            showError = true; showSuccess = false
        }
    }
}

// MARK: - Referral Share View (Shared UI)
struct ReferralShareView: View {
    @EnvironmentObject var referral: ReferralEngine
    @State private var showCopied = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Stats card
                VStack(spacing: 16) {
                    Text("Your Referral Code")
                        .font(.headline).foregroundColor(.secondary)
                    
                    Text(referral.referralCode)
                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                    
                    Button(action: { UIPasteboard.general.string = referral.referralCode; showCopied = true }) {
                        Label(showCopied ? "Copied!" : "Copy Code", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.subheadline)
                    }
                    .onChange(of: showCopied) { _, v in if v { DispatchQueue.main.asyncAfter(deadline: .now()+2) { showCopied = false } } }
                }
                .padding().frame(maxWidth: .infinity)
                .background(Color(.systemBackground)).cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 4)
                
                // Progress
                VStack(spacing: 12) {
                    Text("Share with friends, earn rewards")
                        .font(.headline)
                    
                    HStack(spacing: 0) {
                        ForEach(0..<10) { i in
                            ZStack {
                                Circle().fill(i < referral.referralCount ? Color.green : Color(.systemGray5)).frame(width: 28, height: 28)
                                if i < referral.referralCount {
                                    Image(systemName: "person.fill").font(.system(size: 14)).foregroundColor(.white)
                                }
                            }
                            if i < 9 { Rectangle().fill(Color(.systemGray5)).frame(height: 2).frame(maxWidth: 16) }
                        }
                    }
                    
                    HStack {
                        Text("\(referral.referralCount) referrals").font(.subheadline).foregroundColor(.secondary)
                        Spacer()
                        Text("\(referral.availableFreeMonths) free months earned").font(.subheadline).foregroundColor(.green).fontWeight(.medium)
                    }
                    
                    if referral.nextRewardAt > 0 {
                        Text("\(referral.nextRewardAt) more to earn your next free month! 🎁")
                            .font(.caption).foregroundColor(.orange)
                    }
                }
                .padding().background(Color(.systemBackground)).cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 4)
                
                // Share button
                Button(action: shareReferral) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Your Code")
                    }
                    .font(.headline).foregroundColor(.white)
                    .padding().frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(14)
                }
                
                // Redeem button
                if referral.availableFreeMonths > 0 {
                    Button(action: { _ = referral.redeemFreeMonth() }) {
                        HStack {
                            Image(systemName: "gift.fill")
                            Text("Redeem 1 Free Month (\(referral.availableFreeMonths) available)")
                        }
                        .font(.subheadline).foregroundColor(.green).padding().frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1)).cornerRadius(14)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func shareReferral() {
        let activityVC = UIActivityViewController(
            activityItems: [referral.shareMessage],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}
