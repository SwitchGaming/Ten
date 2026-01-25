//
//  User.swift
//  SocialTen
//

import SwiftUI

// MARK: - User Roles
enum UserRole: String, Codable {
    case developer
    case ambassador
    
    var displayName: String {
        switch self {
        case .developer: return "developer"
        case .ambassador: return "ambassador"
        }
    }
    
    var icon: String {
        switch self {
        case .developer: return "hammer.fill"
        case .ambassador: return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .developer: return Color(red: 0.6, green: 0.4, blue: 1.0) // Purple
        case .ambassador: return Color(red: 1.0, green: 0.75, blue: 0.3) // Gold
        }
    }
}

struct User: Identifiable, Codable, Equatable {
    let id: String
    let username: String
    var displayName: String
    var bio: String
    var todayRating: Int?
    var ratingTimestamp: Date?
    var friendIds: [String]
    var ratingHistory: [RatingEntry]
    
    // Last rating from previous day (for stale state display)
    var lastRating: Int?
    
    // Premium status (visible to others)
    var premiumExpiresAt: Date?
    var selectedThemeId: String?
    
    // Role badges
    var isDeveloper: Bool
    var isAmbassador: Bool
    
    // Computed role - developer takes precedence
    var userRole: UserRole? {
        if isDeveloper { return .developer }
        if isAmbassador { return .ambassador }
        return nil
    }
    
    // Dynamic friend limit based on premium status
    static var maxFriends: Int {
        PremiumManager.shared.friendLimit
    }
    
    // Check if this user has premium (for display purposes)
    var isPremium: Bool {
        guard let expiresAt = premiumExpiresAt else { return false }
        return expiresAt > Date()
    }
    
    /// Returns true if the user has rated today (based on local device timezone)
    var hasRatedToday: Bool {
        guard let ratingTimestamp = ratingTimestamp else { return false }
        return Calendar.current.isDateInToday(ratingTimestamp)
    }
    
    // Get the user's selected theme
    var selectedTheme: AppTheme {
        guard let themeId = selectedThemeId else { return .default }
        return AppTheme.allThemes.first { $0.id == themeId } ?? .default
    }
    
    init(
        id: String = UUID().uuidString,
        username: String,
        displayName: String,
        bio: String = "",
        todayRating: Int? = nil,
        ratingTimestamp: Date? = nil,
        friendIds: [String] = [],
        ratingHistory: [RatingEntry] = [],
        lastRating: Int? = nil,
        premiumExpiresAt: Date? = nil,
        selectedThemeId: String? = nil,
        isDeveloper: Bool = false,
        isAmbassador: Bool = false
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.bio = bio
        self.todayRating = todayRating
        self.ratingTimestamp = ratingTimestamp
        self.friendIds = friendIds
        self.ratingHistory = ratingHistory
        self.lastRating = lastRating
        self.premiumExpiresAt = premiumExpiresAt
        self.selectedThemeId = selectedThemeId
        self.isDeveloper = isDeveloper
        self.isAmbassador = isAmbassador
    }
    
    var canAddMoreFriends: Bool {
        friendIds.count < User.maxFriends
    }
}

struct RatingEntry: Identifiable, Codable, Equatable {
    let id: String
    let rating: Int
    let date: Date
    
    init(id: String = UUID().uuidString, rating: Int, date: Date) {
        self.id = id
        self.rating = rating
        self.date = date
    }
}
