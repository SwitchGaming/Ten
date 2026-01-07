//
//  User.swift
//  SocialTen
//

import SwiftUI

struct User: Identifiable, Codable {
    let id: String
    let username: String
    var displayName: String
    var bio: String
    var todayRating: Int?
    var ratingTimestamp: Date?
    var friendIds: [String]
    var ratingHistory: [RatingEntry]
    
    // Premium status (visible to others)
    var premiumExpiresAt: Date?
    var selectedThemeId: String?
    
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
        premiumExpiresAt: Date? = nil,
        selectedThemeId: String? = nil
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.bio = bio
        self.todayRating = todayRating
        self.ratingTimestamp = ratingTimestamp
        self.friendIds = friendIds
        self.ratingHistory = ratingHistory
        self.premiumExpiresAt = premiumExpiresAt
        self.selectedThemeId = selectedThemeId
    }
    
    var canAddMoreFriends: Bool {
        friendIds.count < User.maxFriends
    }
}

struct RatingEntry: Identifiable, Codable {
    let id: String
    let rating: Int
    let date: Date
    
    init(id: String = UUID().uuidString, rating: Int, date: Date) {
        self.id = id
        self.rating = rating
        self.date = date
    }
}
