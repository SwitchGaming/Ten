//
//  TenWidgets.swift
//  TenWidgets
//
//  Beautiful, minimal widgets for Ten
//

import WidgetKit
import SwiftUI

// MARK: - Widget Theme Colors (Codable)

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
    
    // Convert to SwiftUI Colors
    var backgroundCol: Color { Color(hex: background) }
    var cardBackgroundCol: Color { Color(hex: cardBackground) }
    var surfaceLightCol: Color { Color(hex: surfaceLight) }
    var accent1Col: Color { Color(hex: accent1) }
    var accent2Col: Color { Color(hex: accent2) }
    var textPrimaryCol: Color { Color(hex: textPrimary) }
    var textSecondaryCol: Color { Color(hex: textSecondary) }
    var textTertiaryCol: Color { Color(hex: textTertiary) }
    var glowColorCol: Color { Color(hex: glowColor) }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
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
        todaysPrompt: "how are you today?",
        theme: .default,
        lastUpdated: Date()
    )
}

// MARK: - Widget Data Loader

struct WidgetDataLoader {
    static let appGroupIdentifier = "group.com.joealapatSocialTen"
    static let widgetDataKey = "widgetData"
    
    static func load() -> WidgetData {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: widgetDataKey),
              let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .empty
        }
        return widgetData
    }
}

// MARK: - Timeline Entry

struct TenWidgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
    
    var theme: WidgetThemeColors { data.theme }
    
    static let placeholder = TenWidgetEntry(
        date: Date(),
        data: WidgetData(
            user: WidgetUserData(
                displayName: "you",
                todayRating: 8,
                ratingTimestamp: Date(),
                currentStreak: 7,
                isPremium: false
            ),
            friends: [
                WidgetFriendData(id: "1", username: "alex", displayName: "alex", todayRating: 9, profileImageUrl: nil, isPremium: true, themeAccent: "8B5CF6"),
                WidgetFriendData(id: "2", username: "sam", displayName: "sam", todayRating: 7, profileImageUrl: nil, isPremium: false, themeAccent: nil),
                WidgetFriendData(id: "3", username: "taylor", displayName: "taylor", todayRating: 6, profileImageUrl: nil, isPremium: false, themeAccent: nil),
            ],
            todaysPrompt: "how are you today?",
            theme: .default,
            lastUpdated: Date()
        )
    )
}

// MARK: - Timeline Provider

struct TenTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TenWidgetEntry {
        .placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TenWidgetEntry) -> Void) {
        let entry = TenWidgetEntry(date: Date(), data: WidgetDataLoader.load())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TenWidgetEntry>) -> Void) {
        let data = WidgetDataLoader.load()
        let entry = TenWidgetEntry(date: Date(), data: data)
        
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Rating Widget (Small)

struct RatingWidget: Widget {
    let kind = "RatingWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TenTimelineProvider()) { entry in
            RatingWidgetView(entry: entry)
                .containerBackground(entry.theme.backgroundCol, for: .widget)
        }
        .configurationDisplayName("today's rating")
        .description("see your daily rating at a glance")
        .supportedFamilies([.systemSmall])
    }
}

struct RatingWidgetView: View {
    let entry: TenWidgetEntry
    
    var theme: WidgetThemeColors { entry.theme }
    
    var body: some View {
        ZStack {
            // Subtle glow using theme accent
            if entry.data.user?.todayRating != nil {
                Circle()
                    .fill(theme.accent2Col)
                    .blur(radius: 40)
                    .opacity(0.15)
                    .offset(y: -20)
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                if let rating = entry.data.user?.todayRating {
                    // Rated state - uses theme colors, not rating colors
                    Text("\(rating)")
                        .font(.system(size: 72, weight: .ultraLight))
                        .foregroundColor(theme.accent1Col)
                    
                    Text("today")
                        .font(.system(size: 11, weight: .light))
                        .tracking(2)
                        .foregroundColor(theme.textTertiaryCol)
                        .textCase(.lowercase)
                } else {
                    // Not rated state
                    Circle()
                        .strokeBorder(theme.textTertiaryCol.opacity(0.3), lineWidth: 1)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Text("?")
                                .font(.system(size: 32, weight: .ultraLight))
                                .foregroundColor(theme.textTertiaryCol)
                        )
                    
                    Text("tap to rate")
                        .font(.system(size: 11, weight: .light))
                        .tracking(2)
                        .foregroundColor(theme.textTertiaryCol)
                        .padding(.top, 8)
                }
                
                Spacer()
                
                // ten branding with accent color
                Text("ten")
                    .font(.system(size: 10, weight: .light))
                    .tracking(4)
                    .foregroundColor(theme.accent2Col.opacity(0.6))
            }
            .padding()
        }
        .widgetURL(URL(string: "socialten://rate"))
    }
}

// MARK: - Prompt Widget (Small)

struct PromptWidget: Widget {
    let kind = "PromptWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TenTimelineProvider()) { entry in
            PromptWidgetView(entry: entry)
                .containerBackground(entry.theme.backgroundCol, for: .widget)
        }
        .configurationDisplayName("daily prompt")
        .description("today's reflection question")
        .supportedFamilies([.systemSmall])
    }
}

struct PromptWidgetView: View {
    let entry: TenWidgetEntry
    
    var theme: WidgetThemeColors { entry.theme }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("prompt")
                    .font(.system(size: 10, weight: .light))
                    .tracking(2)
                    .foregroundColor(theme.textTertiaryCol)
                    .textCase(.uppercase)
                
                Spacer()
                
                Image(systemName: "pencil.line")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(theme.accent2Col)
            }
            
            Spacer()
            
            // Prompt text
            Text(entry.data.todaysPrompt)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(theme.textPrimaryCol)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            // Subtle hint
            Text("tap to respond")
                .font(.system(size: 9, weight: .light))
                .tracking(1)
                .foregroundColor(theme.textTertiaryCol.opacity(0.6))
        }
        .padding()
        .widgetURL(URL(string: "socialten://prompt"))
    }
}

// MARK: - Friends Widget (Medium)

struct FriendsWidget: Widget {
    let kind = "FriendsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TenTimelineProvider()) { entry in
            FriendsWidgetView(entry: entry)
                .containerBackground(entry.theme.backgroundCol, for: .widget)
        }
        .configurationDisplayName("friends")
        .description("see how your friends are doing")
        .supportedFamilies([.systemMedium])
    }
}

struct FriendsWidgetView: View {
    let entry: TenWidgetEntry
    
    var theme: WidgetThemeColors { entry.theme }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row with user's rating
            HStack {
                // User's rating - uses theme colors
                if let rating = entry.data.user?.todayRating {
                    HStack(spacing: 6) {
                        Text("\(rating)")
                            .font(.system(size: 28, weight: .ultraLight))
                            .foregroundColor(theme.accent1Col)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("you")
                                .font(.system(size: 11, weight: .light))
                                .foregroundColor(theme.textSecondaryCol)
                            Text("today")
                                .font(.system(size: 9, weight: .light))
                                .foregroundColor(theme.textTertiaryCol)
                        }
                    }
                } else {
                    Text("rate today")
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(theme.textTertiaryCol)
                }
                
                Spacer()
                
                Text("ten")
                    .font(.system(size: 10, weight: .light))
                    .tracking(4)
                    .foregroundColor(theme.accent2Col.opacity(0.5))
            }
            
            // Divider
            Rectangle()
                .fill(theme.surfaceLightCol)
                .frame(height: 0.5)
            
            // Friends row
            if entry.data.friends.isEmpty {
                HStack {
                    Spacer()
                    Text("friends' ratings will appear here")
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(theme.textTertiaryCol)
                    Spacer()
                }
            } else {
                HStack(spacing: 16) {
                    ForEach(entry.data.friends.prefix(4)) { friend in
                        FriendBubbleWidget(friend: friend, defaultTheme: theme)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .widgetURL(URL(string: "socialten://home"))
    }
}

struct FriendBubbleWidget: View {
    let friend: WidgetFriendData
    let defaultTheme: WidgetThemeColors
    
    // Use friend's premium theme accent or default to user's theme
    var accentColor: Color {
        if let isPremium = friend.isPremium, isPremium, let themeAccent = friend.themeAccent {
            return Color(hex: themeAccent)
        }
        return defaultTheme.accent2Col
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Premium glow effect
                if friend.isPremium == true {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 40, height: 40)
                        .blur(radius: 8)
                        .opacity(0.4)
                }
                
                // Main bubble
                Circle()
                    .fill(defaultTheme.cardBackgroundCol)
                    .frame(width: 36, height: 36)
                
                // Rating number using theme accent (not rating color)
                if let rating = friend.todayRating {
                    Text("\(rating)")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(friend.isPremium == true ? accentColor : defaultTheme.accent1Col)
                } else {
                    Text(friend.initial)
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(defaultTheme.textTertiaryCol)
                }
            }
            
            Text(friend.displayName.prefix(6).lowercased())
                .font(.system(size: 9, weight: .light))
                .foregroundColor(defaultTheme.textTertiaryCol)
                .lineLimit(1)
        }
    }
}

// MARK: - Streak Widget (Small)

struct StreakWidget: Widget {
    let kind = "StreakWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TenTimelineProvider()) { entry in
            StreakWidgetView(entry: entry)
                .containerBackground(entry.theme.backgroundCol, for: .widget)
        }
        .configurationDisplayName("streak")
        .description("your daily rating streak")
        .supportedFamilies([.systemSmall])
    }
}

struct StreakWidgetView: View {
    let entry: TenWidgetEntry
    
    var theme: WidgetThemeColors { entry.theme }
    
    var streak: Int {
        entry.data.user?.currentStreak ?? 0
    }
    
    var body: some View {
        ZStack {
            // Glow effect for active streaks
            if streak > 0 {
                Circle()
                    .fill(theme.accent2Col)
                    .blur(radius: 40)
                    .opacity(0.15)
                    .offset(y: -10)
            }
            
            VStack(spacing: 4) {
                Spacer()
                
                // Fire icon with theme color
                Image(systemName: streak > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(streak > 0 ? theme.accent2Col : theme.textTertiaryCol.opacity(0.5))
                
                // Streak number
                Text("\(streak)")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundColor(streak > 0 ? theme.accent1Col : theme.textTertiaryCol)
                
                // Label
                Text(streak == 1 ? "day" : "days")
                    .font(.system(size: 11, weight: .light))
                    .tracking(2)
                    .foregroundColor(theme.textTertiaryCol)
                
                Spacer()
                
                // Branding
                Text("ten")
                    .font(.system(size: 10, weight: .light))
                    .tracking(4)
                    .foregroundColor(theme.accent2Col.opacity(0.5))
            }
            .padding()
        }
        .widgetURL(URL(string: "socialten://home"))
    }
}
