//
//  PremiumManager.swift
//  SocialTen
//

import SwiftUI
import Foundation

// MARK: - Premium Manager

class PremiumManager: ObservableObject {
    static let shared = PremiumManager()
    
    // Core premium state
    @Published var isPremium: Bool = false
    @Published var isAmbassador: Bool = false
    @Published var premiumExpiresAt: Date?
    @Published var selectedThemeId: String = "default"
    @Published var hasUsedReferral: Bool = false
    
    // Ambassador state
    @Published var ambassadorStatus: AmbassadorStatus = .notAmbassador
    @Published var referralCodes: [ReferralCode] = []
    
    // Downgrade state
    @Published var downgradeState: DowngradeState = DowngradeState()
    @Published var showDowngradeFlow: Bool = false
    
    // Premium limits
    static let standardFriendLimit = 10
    static let premiumFriendLimit = 25
    static let standardGroupLimit = 1
    static let premiumGroupLimit = 3
    
    var friendLimit: Int {
        isPremium ? PremiumManager.premiumFriendLimit : PremiumManager.standardFriendLimit
    }
    
    var groupLimit: Int {
        isPremium ? PremiumManager.premiumGroupLimit : PremiumManager.standardGroupLimit
    }
    
    // Keys for UserDefaults (local cache)
    private let premiumKey = "ten_plus_premium"
    private let expiryKey = "ten_plus_expiry"
    private let themeKey = "ten_plus_theme"
    private let ambassadorKey = "ten_plus_ambassador"
    private let hasUsedReferralKey = "ten_plus_has_used_referral"
    
    private let supabase = SupabaseManager.shared.client
    
    private init() {
        loadCachedStatus()
    }
    
    // MARK: - Server-Side Validation (Source of Truth)
    
    /// Validate premium status from server - call this on app launch
    @MainActor
    func validatePremiumStatus() async {
        do {
            guard let authUser = try? await supabase.auth.session.user else {
                print("❌ Premium: No auth user")
                return
            }
            
            // Debug: print auth user ID
            print("🔑 Auth user ID: \(authUser.id.uuidString)")
            
            // Get raw data first to debug
            let response = try await supabase
                .rpc("validate_premium_status", params: ["p_user_id": authUser.id.uuidString])
                .execute()
            
            // Debug: print raw response
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("📦 Raw premium response: \(jsonString)")
            }
            
            // Decode manually with date handling
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try ISO8601 with fractional seconds
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: dateString) {
                    return date
                }
                
                // Try without fractional seconds
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) {
                    return date
                }
                
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
            }
            
            let result = try decoder.decode(PremiumValidationResult.self, from: response.data)
            
            // Update local state from server
            isPremium = result.isPremium
            isAmbassador = result.isAmbassador
            premiumExpiresAt = result.expiresAt
            hasUsedReferral = result.hasUsedReferral
            
            if let themeId = result.selectedThemeId, isPremium {
                selectedThemeId = themeId
                applySelectedTheme()
            } else if !isPremium {
                // Reset theme if not premium
                selectedThemeId = "default"
                ThemeManager.shared.setTheme(.default)
            }
            
            // Cache locally
            cacheStatus()
            
            print("✅ Premium validated: isPremium=\(isPremium), isAmbassador=\(isAmbassador)")
            
            // Check if downgrade is needed
            if !isPremium {
                await checkDowngradeNeeded()
            }
            
        } catch {
            print("❌ Premium validation error: \(error)")
            // Fall back to cached status
            loadCachedStatus()
        }
    }
    
    // MARK: - Referral Code Redemption
    
    /// Redeem a referral code from an ambassador
    @MainActor
    func redeemReferralCode(_ code: String) async -> CodeRedemptionResult {
        do {
            guard let authUser = try? await supabase.auth.session.user else {
                return CodeRedemptionResult(
                    success: false,
                    premiumDays: nil,
                    expiresAt: nil,
                    referredByName: nil,
                    error: "Not authenticated"
                )
            }
            
            print("🎟️ Redeeming code: \(code) for auth ID: \(authUser.id.uuidString)")
            
            let response = try await supabase
                .rpc("redeem_referral_code", params: [
                    "p_user_id": authUser.id.uuidString,
                    "p_code": code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                ])
                .execute()
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("📦 Redeem response: \(jsonString)")
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: dateString) { return date }
                
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) { return date }
                
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date")
            }
            
            let result = try decoder.decode(CodeRedemptionResult.self, from: response.data)
            
            print("✅ Redemption result: success=\(result.success), referredBy=\(result.referredByName ?? "nil")")
            
            if result.success {
                // Update local state immediately
                isPremium = true
                premiumExpiresAt = result.expiresAt
                hasUsedReferral = true
                cacheStatus()
                
                // Apply default premium theme
                if selectedThemeId == "default" {
                    setTheme("ocean")
                } else {
                    // Re-apply current theme to ensure premium features activate
                    applySelectedTheme()
                }
                
                // Notify app of premium status change
                objectWillChange.send()
            }
            
            return result
            
        } catch {
            print("❌ Referral redemption error: \(error)")
            return CodeRedemptionResult(
                success: false,
                premiumDays: nil,
                expiresAt: nil,
                referredByName: nil,
                error: error.localizedDescription
            )
        }
    }
    
    // MARK: - Ambassador Functions
    
    /// Check ambassador status
    @MainActor
    func checkAmbassadorStatus() async {
        do {
            guard let authUser = try? await supabase.auth.session.user else { return }
            
            let status: AmbassadorStatus = try await supabase
                .rpc("check_ambassador_status", params: ["p_user_id": authUser.id.uuidString])
                .execute()
                .value
            
            ambassadorStatus = status
            isAmbassador = status.isAmbassador
            
            // Ambassadors always have premium
            if isAmbassador {
                isPremium = true
                cacheStatus()
            }
            
            if isAmbassador {
                await loadReferralCodes()
            }
            
        } catch {
            print("❌ Ambassador status error: \(error)")
        }
    }
    
    /// Generate a new referral code (ambassadors only)
    @MainActor
    func generateReferralCode() async -> CodeGenerationResult? {
        do {
            guard let authUser = try? await supabase.auth.session.user else {
                print("❌ Generate code: No auth user")
                return nil
            }
            
            print("🎫 Generating code for auth ID: \(authUser.id.uuidString)")
            
            let response = try await supabase
                .rpc("generate_referral_code", params: ["p_user_id": authUser.id.uuidString])
                .execute()
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("📦 Generate code response: \(jsonString)")
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: dateString) { return date }
                
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) { return date }
                
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date")
            }
            
            let result = try decoder.decode(CodeGenerationResult.self, from: response.data)
            
            if result.success {
                await loadReferralCodes()
                await checkAmbassadorStatus()
            }
            
            return result
            
        } catch {
            print("❌ Code generation error: \(error)")
            return nil
        }
    }
    
    /// Load ambassador's referral codes
    @MainActor
    func loadReferralCodes() async {
        do {
            guard let authUser = try? await supabase.auth.session.user else { return }
            
            print("📥 Loading referral codes...")
            
            let response = try await supabase
                .rpc("get_ambassador_codes", params: ["p_user_id": authUser.id.uuidString])
                .execute()
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("📦 Codes response: \(jsonString)")
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: dateString) { return date }
                
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) { return date }
                
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date")
            }
            
            let codes = try decoder.decode([ReferralCode].self, from: response.data)
            print("✅ Loaded \(codes.count) codes")
            referralCodes = codes
            
        } catch {
            print("❌ Load codes error: \(error)")
        }
    }
    
    /// Revoke/delete a referral code (optimistic update)
    @MainActor
    func revokeReferralCode(_ codeId: UUID) async -> Bool {
        // Optimistic update - remove from list immediately
        let originalCodes = referralCodes
        referralCodes.removeAll { $0.id == codeId }
        
        // Update ambassador status optimistically
        if let status = ambassadorStatus as? AmbassadorStatus,
           let activeCodes = status.activeCodes {
            ambassadorStatus = AmbassadorStatus(
                isAmbassador: true,
                maxCodes: status.maxCodes,
                activeCodes: max(0, activeCodes - 1),
                totalRedeemed: status.totalRedeemed,
                canGenerateCode: true
            )
        }
        
        do {
            guard let authUser = try? await supabase.auth.session.user else {
                referralCodes = originalCodes
                return false
            }
            
            let response = try await supabase
                .rpc("revoke_referral_code", params: [
                    "p_user_id": authUser.id.uuidString,
                    "p_code_id": codeId.uuidString
                ])
                .execute()
            
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("📦 Revoke code response: \(jsonString)")
            }
            
            // Refresh to get accurate state
            await checkAmbassadorStatus()
            return true
            
        } catch {
            print("❌ Revoke code error: \(error)")
            // Revert on failure
            referralCodes = originalCodes
            await checkAmbassadorStatus()
            return false
        }
    }
    
    /// Get current premium user count for welcome message
    @MainActor
    func getPremiumUserCount() async -> Int {
        do {
            let count: Int = try await supabase
                .rpc("get_premium_user_count")
                .execute()
                .value
            return count
        } catch {
            return 100 // Fallback number
        }
    }
    
    // MARK: - Downgrade Flow
    
    /// Check if user needs to go through downgrade flow
    @MainActor
    func checkDowngradeNeeded() async {
        // This will be called with actual friend/group counts from SupabaseAppViewModel
        // For now, just set up the initial state
        downgradeState = DowngradeState()
    }
    
    /// Initialize downgrade flow based on current limits
    @MainActor
    func initializeDowngradeFlow(friendCount: Int, groupCount: Int) {
        downgradeState = DowngradeState()
        
        if friendCount > PremiumManager.standardFriendLimit {
            downgradeState.currentStep = .friendSelection(
                currentCount: friendCount,
                maxAllowed: PremiumManager.standardFriendLimit
            )
            showDowngradeFlow = true
        } else if groupCount > PremiumManager.standardGroupLimit {
            downgradeState.currentStep = .groupDeletion(
                currentCount: groupCount,
                maxAllowed: PremiumManager.standardGroupLimit
            )
            showDowngradeFlow = true
        } else {
            // Just reset theme, no blocking needed
            selectedThemeId = "default"
            ThemeManager.shared.setTheme(.default)
            downgradeState.currentStep = .complete
        }
    }
    
    /// Complete friend selection step
    @MainActor
    func completeFriendSelection(groupCount: Int) {
        if groupCount > PremiumManager.standardGroupLimit {
            downgradeState.currentStep = .groupDeletion(
                currentCount: groupCount,
                maxAllowed: PremiumManager.standardGroupLimit
            )
        } else {
            downgradeState.currentStep = .themeReset
        }
    }
    
    /// Complete group deletion step
    @MainActor
    func completeGroupDeletion() {
        downgradeState.currentStep = .themeReset
    }
    
    /// Complete theme reset and finish downgrade
    @MainActor
    func completeDowngrade() {
        selectedThemeId = "default"
        ThemeManager.shared.setTheme(.default)
        downgradeState.currentStep = .complete
        showDowngradeFlow = false
        cacheStatus()
    }
    
    // MARK: - Legacy Promo Code System (Backwards Compatibility)
    
    // MARK: - Local Cache Management
    
    private func loadCachedStatus() {
        isPremium = UserDefaults.standard.bool(forKey: premiumKey)
        premiumExpiresAt = UserDefaults.standard.object(forKey: expiryKey) as? Date
        selectedThemeId = UserDefaults.standard.string(forKey: themeKey) ?? "default"
        isAmbassador = UserDefaults.standard.bool(forKey: ambassadorKey)
        hasUsedReferral = UserDefaults.standard.bool(forKey: hasUsedReferralKey)
        
        // Check if premium has expired
        if let expiry = premiumExpiresAt, expiry < Date(), !isAmbassador {
            deactivatePremiumLocally()
        }
        
        if isPremium {
            applySelectedTheme()
        }
    }
    
    private func cacheStatus() {
        UserDefaults.standard.set(isPremium, forKey: premiumKey)
        UserDefaults.standard.set(premiumExpiresAt, forKey: expiryKey)
        UserDefaults.standard.set(selectedThemeId, forKey: themeKey)
        UserDefaults.standard.set(isAmbassador, forKey: ambassadorKey)
        UserDefaults.standard.set(hasUsedReferral, forKey: hasUsedReferralKey)
    }
    
    func deactivatePremiumLocally() {
        isPremium = false
        premiumExpiresAt = nil
        selectedThemeId = "default"
        
        UserDefaults.standard.set(false, forKey: premiumKey)
        UserDefaults.standard.removeObject(forKey: expiryKey)
        UserDefaults.standard.set("default", forKey: themeKey)
        
        ThemeManager.shared.setTheme(.default)
    }
    
    // Keep old method name for compatibility
    func deactivatePremium() {
        deactivatePremiumLocally()
    }
    
    // MARK: - Theme Management
    
    func setTheme(_ themeId: String) {
        guard isPremium || themeId == "default" else { return }
        
        selectedThemeId = themeId
        UserDefaults.standard.set(themeId, forKey: themeKey)
        applySelectedTheme()
        
        Task {
            await syncPremiumToDatabase()
        }
    }
    
    private func applySelectedTheme() {
        guard let theme = AppTheme.allThemes.first(where: { $0.id == selectedThemeId }) else {
            ThemeManager.shared.setTheme(.default)
            return
        }
        ThemeManager.shared.setTheme(theme)
    }
    
    // MARK: - Premium Features Check
    
    var canUseGlowingVibes: Bool {
        isPremium
    }
    
    var canUsePremiumAnimations: Bool {
        isPremium
    }
    
    var daysRemaining: Int? {
        guard !isAmbassador else { return nil } // Ambassadors have unlimited
        guard let expiry = premiumExpiresAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day
        return max(0, days ?? 0)
    }
    
    var expiryDateString: String? {
        guard !isAmbassador else { return "Ambassador (never expires)" }
        guard let expiry = premiumExpiresAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: expiry)
    }
    
    // MARK: - Database Sync
    
    func syncPremiumToDatabase() async {
        do {
            guard let authUser = try? await supabase.auth.session.user else { return }
            
            try await supabase
                .from("users")
                .update([
                    "premium_expires_at": isPremium ? premiumExpiresAt?.ISO8601Format() : nil as String?,
                    "selected_theme_id": isPremium ? selectedThemeId : nil as String?
                ])
                .eq("auth_id", value: authUser.id)
                .execute()
            
            print("✨ Premium status synced to database")
        } catch {
            print("Error syncing premium status: \(error)")
        }
    }
}

// MARK: - Promo Code Generator (for testing/admin)

extension PremiumManager {
    static func generatePromoCode(expiryMonth: Int, expiryYear: Int) -> String {
        let randomPrefix = String((0..<2).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
        let monthStr = String(format: "%02d", expiryMonth)
        let yearOffset = expiryYear - 2025
        let yearStr = String(format: "%02d", yearOffset)
        return "\(randomPrefix)\(monthStr)\(yearStr)"
    }
}

