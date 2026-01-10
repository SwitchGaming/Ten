//
//  WidgetDataManager.swift
//  SocialTen
//
//  Shared data layer for widget communication via App Group
//

import Foundation
import WidgetKit

// MARK: - Widget Theme Colors (Codable for sharing)

struct WidgetThemeColors: Codable {
    let background: String
    let cardBackground: String
    let surfaceLight: String
    let accent1: String
    let accent2: String
    let textPrimary: String
    let textSecondary: String
    let textTertiary: String
    let glowColor: String
    
    static let `default` = WidgetThemeColors(
        background: "0A0A0A",
        cardBackground: "141414",
        surfaceLight: "1C1C1E",
        accent1: "FFFFFF",
        accent2: "8B5CF6",
        textPrimary: "FFFFFF",
        textSecondary: "A1A1AA",
        textTertiary: "52525B",
        glowColor: "8B5CF6"
    )
}

// MARK: - Widget Data Models

struct WidgetUserData: Codable {
    let displayName: String
    let todayRating: Int?
    let ratingTimestamp: Date?
    let currentStreak: Int
    let isPremium: Bool
    
    var hasRatedToday: Bool {
        guard let timestamp = ratingTimestamp else { return false }
        return Calendar.current.isDateInToday(timestamp)
    }
}

struct WidgetFriendData: Codable, Identifiable {
    let id: String
    let username: String
    let displayName: String
    let todayRating: Int?
    let profileImageUrl: String?
    let isPremium: Bool?
    let themeAccent: String?
    
    var initial: String {
        String(displayName.prefix(1)).lowercased()
    }
    
    var hasRatedToday: Bool {
        todayRating != nil
    }
}

struct WidgetData: Codable {
    let user: WidgetUserData?
    let friends: [WidgetFriendData]
    let todaysPrompt: String
    let theme: WidgetThemeColors
    let lastUpdated: Date
    
    static let empty = WidgetData(
        user: nil,
        friends: [],
        todaysPrompt: "what made you smile today?",
        theme: .default,
        lastUpdated: Date()
    )
}

// MARK: - Widget Data Manager

class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    private let appGroupIdentifier = "group.com.joealapatSocialTen"
    private let widgetDataKey = "widgetData"
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    private init() {
        // Debug: Check if App Group is accessible
        if sharedDefaults == nil {
            print("⚠️ WidgetDataManager: Failed to access App Group '\(appGroupIdentifier)'")
        } else {
            print("✅ WidgetDataManager: App Group accessible")
        }
    }
    
    // MARK: - Write Data (Main App)
    
    /// Update widget data from main app
    func updateWidgetData(
        rating: Int?,
        ratingTimestamp: Date?,
        streak: Int,
        prompt: String,
        username: String,
        friends: [WidgetFriendData],
        theme: WidgetThemeColors = .default
    ) {
        let userData = WidgetUserData(
            displayName: username,
            todayRating: rating,
            ratingTimestamp: ratingTimestamp,
            currentStreak: streak,
            isPremium: false
        )
        
        // Pass all friends to widget (widget view will decide how many to display)
        let widgetData = WidgetData(
            user: userData,
            friends: friends,
            todaysPrompt: prompt,
            theme: theme,
            lastUpdated: Date()
        )
        
        saveWidgetData(widgetData)
        
        // Debug logging
        print("📱 Widget Data Updated:")
        print("   - Username: \(username)")
        print("   - Rating: \(rating ?? -1)")
        print("   - Streak: \(streak)")
        print("   - Prompt: \(prompt)")
        print("   - Friends count: \(friends.count)")
        
        // Tell widgets to refresh
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Quick update just for rating changes
    func updateRating(_ rating: Int?, timestamp: Date?) {
        var data = loadWidgetData()
        if let user = data.user {
            data = WidgetData(
                user: WidgetUserData(
                    displayName: user.displayName,
                    todayRating: rating,
                    ratingTimestamp: timestamp,
                    currentStreak: user.currentStreak,
                    isPremium: user.isPremium
                ),
                friends: data.friends,
                todaysPrompt: data.todaysPrompt,
                theme: data.theme,
                lastUpdated: Date()
            )
            saveWidgetData(data)
            WidgetCenter.shared.reloadAllTimelines()
            print("📱 Widget Rating Updated: \(rating ?? -1)")
        }
    }
    
    /// Update just theme
    func updateTheme(_ theme: WidgetThemeColors) {
        var data = loadWidgetData()
        data = WidgetData(
            user: data.user,
            friends: data.friends,
            todaysPrompt: data.todaysPrompt,
            theme: theme,
            lastUpdated: Date()
        )
        saveWidgetData(data)
        WidgetCenter.shared.reloadAllTimelines()
        print("📱 Widget Theme Updated")
    }
    
    // MARK: - Read Data (Widget)
    
    func loadWidgetData() -> WidgetData {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: widgetDataKey),
              let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            print("⚠️ Widget: No data found, returning empty")
            return .empty
        }
        return widgetData
    }
    
    // MARK: - Private
    
    private func saveWidgetData(_ data: WidgetData) {
        guard let defaults = sharedDefaults else {
            print("❌ WidgetDataManager: Cannot save - App Group not accessible")
            return
        }
        
        do {
            let encoded = try JSONEncoder().encode(data)
            defaults.set(encoded, forKey: widgetDataKey)
            defaults.synchronize() // Force immediate write
            print("✅ Widget data saved to App Group")
        } catch {
            print("❌ WidgetDataManager: Failed to encode data - \(error)")
        }
    }
}
