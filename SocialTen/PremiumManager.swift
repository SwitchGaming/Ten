//
//  PremiumManager.swift
//  SocialTen
//

import SwiftUI
import Foundation

// MARK: - Premium Manager

class PremiumManager: ObservableObject {
    static let shared = PremiumManager()
    
    @Published var isPremium: Bool = false
    @Published var premiumExpiresAt: Date?
    @Published var selectedThemeId: String = "default"
    
    // Premium limits
    static let standardFriendLimit = 10
    static let premiumFriendLimit = 25
    
    var friendLimit: Int {
        isPremium ? PremiumManager.premiumFriendLimit : PremiumManager.standardFriendLimit
    }
    
    // Keys for UserDefaults
    private let premiumKey = "ten_plus_premium"
    private let expiryKey = "ten_plus_expiry"
    private let themeKey = "ten_plus_theme"
    private let redeemedCodesKey = "ten_plus_redeemed_codes"
    
    private init() {
        loadPremiumStatus()
    }
    
    // MARK: - Promo Code System
    
    /// Promo code format: XXYYZZ where:
    /// - XX: Random alphanumeric (for uniqueness)
    /// - YY: Encoded month (01-12 as A-L, or hex for extended)
    /// - ZZ: Encoded year offset from 2025 (00-99)
    /// Example: AB0126 = expires Jan 2026
    
    enum PromoCodeResult {
        case success(expiryDate: Date)
        case expired
        case alreadyRedeemed
        case invalid
    }
    
    func redeemPromoCode(_ code: String) -> PromoCodeResult {
        let cleanCode = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate format: 6 alphanumeric characters
        guard cleanCode.count == 6,
              cleanCode.allSatisfy({ $0.isLetter || $0.isNumber }) else {
            return .invalid
        }
        
        // Check if already redeemed
        let redeemedCodes = getRedeemedCodes()
        if redeemedCodes.contains(cleanCode) {
            return .alreadyRedeemed
        }
        
        // Parse expiry date from code
        guard let expiryDate = parseExpiryFromCode(cleanCode) else {
            return .invalid
        }
        
        // Check if expired
        if expiryDate < Date() {
            return .expired
        }
        
        // Activate premium!
        activatePremium(until: expiryDate, code: cleanCode)
        return .success(expiryDate: expiryDate)
    }
    
    private func parseExpiryFromCode(_ code: String) -> Date? {
        // Code format: XXYYZZ
        // XX = random prefix
        // YY = month (01-12)
        // ZZ = year offset from 2025 (00 = 2025, 01 = 2026, etc.)
        
        let chars = Array(code)
        guard chars.count == 6 else { return nil }
        
        // Extract month (positions 2-3)
        let monthStr = String(chars[2...3])
        guard let month = Int(monthStr), month >= 1, month <= 12 else { return nil }
        
        // Extract year offset (positions 4-5)
        let yearStr = String(chars[4...5])
        guard let yearOffset = Int(yearStr) else { return nil }
        
        let year = 2025 + yearOffset
        
        // Create date at end of the month
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        components.hour = 23
        components.minute = 59
        components.second = 59
        
        guard let startOfMonth = Calendar.current.date(from: components),
              let endOfMonth = Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return nil
        }
        
        return endOfMonth
    }
    
    private func activatePremium(until expiryDate: Date, code: String) {
        isPremium = true
        premiumExpiresAt = expiryDate
        
        // Save to UserDefaults
        UserDefaults.standard.set(true, forKey: premiumKey)
        UserDefaults.standard.set(expiryDate, forKey: expiryKey)
        
        // Track redeemed code
        var codes = getRedeemedCodes()
        codes.insert(code)
        UserDefaults.standard.set(Array(codes), forKey: redeemedCodesKey)
        
        // Apply premium theme if not already set
        if selectedThemeId == "default" {
            setTheme("ocean")
        }
    }
    
    private func getRedeemedCodes() -> Set<String> {
        let codes = UserDefaults.standard.stringArray(forKey: redeemedCodesKey) ?? []
        return Set(codes)
    }
    
    private func loadPremiumStatus() {
        isPremium = UserDefaults.standard.bool(forKey: premiumKey)
        premiumExpiresAt = UserDefaults.standard.object(forKey: expiryKey) as? Date
        selectedThemeId = UserDefaults.standard.string(forKey: themeKey) ?? "default"
        
        // Check if premium has expired
        if let expiry = premiumExpiresAt, expiry < Date() {
            deactivatePremium()
        }
        
        // Apply saved theme
        if isPremium {
            applySelectedTheme()
        }
    }
    
    func deactivatePremium() {
        isPremium = false
        premiumExpiresAt = nil
        selectedThemeId = "default"
        
        UserDefaults.standard.set(false, forKey: premiumKey)
        UserDefaults.standard.removeObject(forKey: expiryKey)
        UserDefaults.standard.set("default", forKey: themeKey)
        
        // Reset to default theme
        ThemeManager.shared.setTheme(.default)
    }
    
    // MARK: - Theme Management
    
    func setTheme(_ themeId: String) {
        guard isPremium || themeId == "default" else { return }
        
        selectedThemeId = themeId
        UserDefaults.standard.set(themeId, forKey: themeKey)
        applySelectedTheme()
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
        guard let expiry = premiumExpiresAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day
        return max(0, days ?? 0)
    }
    
    var expiryDateString: String? {
        guard let expiry = premiumExpiresAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: expiry)
    }
}

// MARK: - Promo Code Generator (for testing/admin)

extension PremiumManager {
    /// Generate a promo code that expires at the end of a given month/year
    static func generatePromoCode(expiryMonth: Int, expiryYear: Int) -> String {
        let randomPrefix = String((0..<2).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
        let monthStr = String(format: "%02d", expiryMonth)
        let yearOffset = expiryYear - 2025
        let yearStr = String(format: "%02d", yearOffset)
        return "\(randomPrefix)\(monthStr)\(yearStr)"
    }
}

