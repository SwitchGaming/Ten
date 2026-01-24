//
//  PremiumModels.swift
//  SocialTen
//
//  Models for premium membership, ambassadors, and referral codes
//

import Foundation

// MARK: - Ambassador Status

struct AmbassadorStatus: Codable {
    let isAmbassador: Bool
    let maxCodes: Int?
    let activeCodes: Int?
    let totalRedeemed: Int?
    let canGenerateCode: Bool?
    
    enum CodingKeys: String, CodingKey {
        case isAmbassador = "is_ambassador"
        case maxCodes = "max_codes"
        case activeCodes = "active_codes"
        case totalRedeemed = "total_redeemed"
        case canGenerateCode = "can_generate_code"
    }
    
    static let notAmbassador = AmbassadorStatus(
        isAmbassador: false,
        maxCodes: nil,
        activeCodes: nil,
        totalRedeemed: nil,
        canGenerateCode: nil
    )
}

// MARK: - Referral Code

struct ReferralCode: Codable, Identifiable {
    let id: UUID
    let code: String
    let status: ReferralCodeStatus
    let premiumDays: Int
    let createdAt: Date
    let expiresAt: Date
    let redeemedAt: Date?
    let redeemedByName: String?
    
    enum CodingKeys: String, CodingKey {
        case id, code, status
        case premiumDays = "premium_days"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case redeemedAt = "redeemed_at"
        case redeemedByName = "redeemed_by_name"
    }
    
    var isActive: Bool {
        status == .active && expiresAt > Date()
    }
    
    var displayStatus: String {
        switch status {
        case .active:
            return expiresAt > Date() ? "Active" : "Expired"
        case .redeemed:
            return "Redeemed"
        case .expired:
            return "Expired"
        case .revoked:
            return "Revoked"
        }
    }
}

enum ReferralCodeStatus: String, Codable {
    case active
    case redeemed
    case expired
    case revoked
}

// MARK: - Code Generation Result

struct CodeGenerationResult: Codable {
    let success: Bool
    let code: String?
    let expiresAt: Date?
    let premiumDays: Int?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success, code, error
        case expiresAt = "expires_at"
        case premiumDays = "premium_days"
    }
}

// MARK: - Code Redemption Result

struct CodeRedemptionResult: Codable {
    let success: Bool
    let premiumDays: Int?
    let expiresAt: Date?
    let referredByName: String?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success, error
        case premiumDays = "premium_days"
        case expiresAt = "expires_at"
        case referredByName = "referred_by_name"
    }
    
    var errorMessage: String? {
        guard let error = error else { return nil }
        switch error {
        case "already_used_referral":
            return "You've already used a referral code. Each user can only use one referral code."
        case "invalid_code":
            return "This code doesn't exist. Please check and try again."
        case "code_already_redeemed":
            return "This code has already been used by someone else."
        case "code_expired":
            return "This code has expired."
        case "code_revoked":
            return "This code is no longer valid."
        case "cannot_redeem_own_code":
            return "You can't redeem your own referral code."
        default:
            return "Something went wrong. Please try again."
        }
    }
}

// MARK: - Premium Validation Result

struct PremiumValidationResult: Codable {
    let isPremium: Bool
    let isAmbassador: Bool
    let expiresAt: Date?
    let selectedThemeId: String?
    let hasUsedReferral: Bool
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case error
        case isPremium = "is_premium"
        case isAmbassador = "is_ambassador"
        case expiresAt = "expires_at"
        case selectedThemeId = "selected_theme_id"
        case hasUsedReferral = "has_used_referral"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields with defaults for safety
        isPremium = (try? container.decode(Bool.self, forKey: .isPremium)) ?? false
        isAmbassador = (try? container.decode(Bool.self, forKey: .isAmbassador)) ?? false
        hasUsedReferral = (try? container.decode(Bool.self, forKey: .hasUsedReferral)) ?? false
        
        // Optional fields
        expiresAt = try? container.decode(Date.self, forKey: .expiresAt)
        selectedThemeId = try? container.decode(String.self, forKey: .selectedThemeId)
        error = try? container.decode(String.self, forKey: .error)
    }
}

// MARK: - Premium Transaction Type

enum PremiumTransactionType: String, Codable {
    case referral
    case promoCode = "promo_code"
    case purchase
    case ambassadorGrant = "ambassador_grant"
    case adminGrant = "admin_grant"
}

// MARK: - Downgrade State

enum DowngradeStep: Equatable {
    case none
    case friendSelection(currentCount: Int, maxAllowed: Int)
    case groupDeletion(currentCount: Int, maxAllowed: Int)
    case themeReset
    case complete
}

struct DowngradeState {
    var currentStep: DowngradeStep = .none
    var selectedFriendsToKeep: Set<String> = []
    var groupsToDelete: Set<UUID> = []
    var isProcessing: Bool = false
    
    var needsFriendSelection: Bool {
        if case .friendSelection = currentStep { return true }
        return false
    }
    
    var needsGroupDeletion: Bool {
        if case .groupDeletion = currentStep { return true }
        return false
    }
}
