//
//  WidgetManager.swift
//  SocialTen
//
//  Manages data sharing between the main app and the widget extension
//

import Foundation
import WidgetKit
import SwiftUI

// MARK: - Widget Data Models (Must match TenWidget.swift)

struct WidgetUserData: Codable {
    let displayName: String
    let todayRating: Int?
    let ratingTimestamp: Date?
    let currentStreak: Int
    let isPremium: Bool
    let themeId: String
}

struct WidgetFriendData: Codable {
    let id: String
    let username: String
    let displayName: String
    let todayRating: Int?
    let ratingTimestamp: Date?
    let profileImageUrl: String?
    let isPremium: Bool
    let themeId: String?
    let themeAccent: String?
    let themeCardBackground: String?
}

struct WidgetPostData: Codable {
    let id: String
    let authorName: String
    let authorIsPremium: Bool
    let authorThemeAccent: String?
    let content: String
    let rating: Int?
    let promptText: String?
    let createdAt: Date
    let replyCount: Int
}

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
}

struct WidgetData: Codable {
    let user: WidgetUserData?
    let friends: [WidgetFriendData]
    let todaysPrompt: String
    let latestPost: WidgetPostData?
    let theme: WidgetThemeColors
    let lastUpdated: Date
}

// MARK: - Widget Data Manager

class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    private let appGroupIdentifier = "group.com.joealapatSocialTen"
    private let widgetDataKey = "widgetData"
    
    private init() {}
    
    /// Updates the widget with current user data
    func updateWidgetData(
        user: WidgetUserData?,
        friends: [WidgetFriendData],
        todaysPrompt: String,
        latestPost: WidgetPostData?,
        theme: WidgetThemeColors
    ) {
        let widgetData = WidgetData(
            user: user,
            friends: friends,
            todaysPrompt: todaysPrompt,
            latestPost: latestPost,
            theme: theme,
            lastUpdated: Date()
        )
        
        saveWidgetData(widgetData)
        refreshWidgets()
    }
    
    private func saveWidgetData(_ data: WidgetData) {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("⚠️ Failed to access shared UserDefaults for App Group: \(appGroupIdentifier)")
            return
        }
        
        do {
            let encoded = try JSONEncoder().encode(data)
            sharedDefaults.set(encoded, forKey: widgetDataKey)
            sharedDefaults.synchronize()
            print("✅ Widget data saved to App Group")
        } catch {
            print("❌ Failed to encode widget data: \(error)")
        }
    }
    
    func refreshWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Color Hex Extension

extension Color {
    var hexString: String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return String(format: "%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}
