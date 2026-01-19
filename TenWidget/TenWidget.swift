//
//  TenWidget.swift
//  TenWidget
//
//  Beautiful, minimal widgets for Ten
//  Free: Rating, Prompt, Friends
//  Premium: Latest Post, Overview
//

import WidgetKit
import SwiftUI

// ═══════════════════════════════════════════════════════════════════
// MARK: - Data Models
// ═══════════════════════════════════════════════════════════════════

struct WidgetUserData: Codable {
    let displayName: String
    let todayRating: Int?
    let ratingTimestamp: Date?
    let currentStreak: Int
    let isPremium: Bool
    let themeId: String
}

struct WidgetFriendData: Codable, Identifiable {
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
    
    var initial: String { String(displayName.prefix(1)).lowercased() }
    
    var accentColor: Color {
        if let hex = themeAccent { return Color(hex: hex) }
        return Color(hex: "8B5CF6")
    }
    
    var cardColor: Color {
        if let hex = themeCardBackground { return Color(hex: hex) }
        return Color(hex: "141414")
    }
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
    
    var bg: Color { Color(hex: background) }
    var card: Color { Color(hex: cardBackground) }
    var surface: Color { Color(hex: surfaceLight) }
    var accent: Color { Color(hex: accent2) }
    var glow: Color { Color(hex: glowColor) }
    var text1: Color { Color(hex: textPrimary) }
    var text2: Color { Color(hex: textSecondary) }
    var text3: Color { Color(hex: textTertiary) }
}

struct WidgetData: Codable {
    let user: WidgetUserData?
    let friends: [WidgetFriendData]
    let todaysPrompt: String
    let latestPost: WidgetPostData?
    let theme: WidgetThemeColors
    let lastUpdated: Date
    
    static let empty = WidgetData(
        user: nil,
        friends: [],
        todaysPrompt: "how are you feeling today?",
        latestPost: nil,
        theme: .default,
        lastUpdated: Date()
    )
    
    static let preview = WidgetData(
        user: WidgetUserData(
            displayName: "you",
            todayRating: 8,
            ratingTimestamp: Date(),
            currentStreak: 7,
            isPremium: true,
            themeId: "default"
        ),
        friends: [
            WidgetFriendData(id: "1", username: "alex", displayName: "alex", todayRating: 9, ratingTimestamp: Date(), profileImageUrl: nil, isPremium: true, themeId: "ocean", themeAccent: "38BDF8", themeCardBackground: "132035"),
            WidgetFriendData(id: "2", username: "sam", displayName: "sam", todayRating: 7, ratingTimestamp: Date(), profileImageUrl: nil, isPremium: false, themeId: nil, themeAccent: nil, themeCardBackground: nil),
            WidgetFriendData(id: "3", username: "taylor", displayName: "taylor", todayRating: 6, ratingTimestamp: Date(), profileImageUrl: nil, isPremium: true, themeId: "forest", themeAccent: "4ADE80", themeCardBackground: "132016"),
            WidgetFriendData(id: "4", username: "jordan", displayName: "jordan", todayRating: nil, ratingTimestamp: nil, profileImageUrl: nil, isPremium: false, themeId: nil, themeAccent: nil, themeCardBackground: nil),
            WidgetFriendData(id: "5", username: "casey", displayName: "casey", todayRating: 8, ratingTimestamp: Date(), profileImageUrl: nil, isPremium: true, themeId: "sunset", themeAccent: "FB923C", themeCardBackground: "251414"),
        ],
        todaysPrompt: "what made you smile today?",
        latestPost: WidgetPostData(
            id: "1",
            authorName: "alex",
            authorIsPremium: true,
            authorThemeAccent: "38BDF8",
            content: "had an amazing day at the beach with friends. sometimes the simple things are the best 🌊",
            rating: 9,
            promptText: "what made you smile today?",
            createdAt: Date().addingTimeInterval(-3600),
            replyCount: 3
        ),
        theme: .default,
        lastUpdated: Date()
    )
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Data Loader & Timeline
// ═══════════════════════════════════════════════════════════════════

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

struct TenWidgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
    var theme: WidgetThemeColors { data.theme }
    var isPremium: Bool { data.user?.isPremium ?? false }
}

struct TenTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> TenWidgetEntry {
        TenWidgetEntry(date: Date(), data: .preview)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TenWidgetEntry) -> Void) {
        completion(TenWidgetEntry(date: Date(), data: WidgetDataLoader.load()))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TenWidgetEntry>) -> Void) {
        let entry = TenWidgetEntry(date: Date(), data: WidgetDataLoader.load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Color Extension
// ═══════════════════════════════════════════════════════════════════

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Shared Components
// ═══════════════════════════════════════════════════════════════════

struct TenBranding: View {
    let theme: WidgetThemeColors
    var size: CGFloat = 10
    
    var body: some View {
        Text("ten")
            .font(.system(size: size, weight: .light))
            .tracking(4)
            .foregroundColor(theme.glow.opacity(0.5))
    }
}

struct FriendBubble: View {
    let friend: WidgetFriendData
    let defaultTheme: WidgetThemeColors
    var size: CGFloat = 40
    var fontSize: CGFloat = 16
    var showName: Bool = true
    
    private var bubbleColor: Color {
        friend.isPremium ? friend.accentColor : defaultTheme.accent
    }
    
    private var bubbleBg: Color {
        friend.isPremium ? friend.cardColor : defaultTheme.card
    }
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Premium glow
                if friend.isPremium {
                    Circle()
                        .fill(bubbleColor)
                        .frame(width: size + 8, height: size + 8)
                        .blur(radius: 8)
                        .opacity(0.4)
                    
                    Circle()
                        .stroke(bubbleColor.opacity(0.6), lineWidth: 1)
                        .frame(width: size + 4, height: size + 4)
                }
                
                // Main bubble
                Circle()
                    .fill(friend.isPremium ? bubbleColor.opacity(0.15) : bubbleBg)
                    .frame(width: size, height: size)
                
                // Rating or initial
                if let rating = friend.todayRating {
                    Text("\(rating)")
                        .font(.system(size: fontSize, weight: .light))
                        .foregroundColor(bubbleColor)
                } else {
                    Text(friend.initial)
                        .font(.system(size: fontSize - 2, weight: .light))
                        .foregroundColor(defaultTheme.text3)
                }
            }
            
            if showName {
                HStack(spacing: 2) {
                    Text(friend.displayName.prefix(6).lowercased())
                        .font(.system(size: 9, weight: .light))
                        .foregroundColor(defaultTheme.text3)
                        .lineLimit(1)
                    
                    if friend.isPremium {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 6))
                            .foregroundColor(bubbleColor.opacity(0.8))
                    }
                }
            }
        }
    }
}

struct PremiumUpgradeOverlay: View {
    let theme: WidgetThemeColors
    
    var body: some View {
        ZStack {
            // Frosted glass background
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
            
            VStack(spacing: 8) {
                // Premium badge
                ZStack {
                    Circle()
                        .fill(theme.glow)
                        .frame(width: 36, height: 36)
                        .blur(radius: 12)
                        .opacity(0.5)
                    
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(theme.glow)
                }
                
                Text("ten+")
                    .font(.system(size: 14, weight: .medium))
                    .tracking(2)
                    .foregroundColor(theme.text1)
                
                Text("unlock premium widgets")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(theme.text3)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - FREE WIDGET 1: Rating (Small)
// ═══════════════════════════════════════════════════════════════════

struct RatingWidget: Widget {
    let kind = "RatingWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TenTimelineProvider()) { entry in
            RatingWidgetView(entry: entry)
                .containerBackground(entry.theme.bg, for: .widget)
        }
        .configurationDisplayName("today's rating")
        .description("your daily rating at a glance")
        .supportedFamilies([.systemSmall])
    }
}

struct RatingWidgetView: View {
    let entry: TenWidgetEntry
    private var theme: WidgetThemeColors { entry.theme }
    
    var body: some View {
        ZStack {
            // Subtle glow
            if entry.data.user?.todayRating != nil {
                Circle()
                    .fill(theme.glow)
                    .blur(radius: 50)
                    .opacity(0.15)
                    .offset(y: -20)
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                if let rating = entry.data.user?.todayRating {
                    // Rated state
                    Text("\(rating)")
                        .font(.system(size: 72, weight: .ultraLight))
                        .foregroundColor(theme.text1)
                    
                    Text("today")
                        .font(.system(size: 11, weight: .light))
                        .tracking(2)
                        .foregroundColor(theme.text3)
                } else {
                    // Unrated state
                    ZStack {
                        Circle()
                            .stroke(theme.text3.opacity(0.3), lineWidth: 1)
                            .frame(width: 64, height: 64)
                        
                        Text("?")
                            .font(.system(size: 32, weight: .ultraLight))
                            .foregroundColor(theme.text3)
                    }
                    
                    Text("tap to rate")
                        .font(.system(size: 11, weight: .light))
                        .tracking(2)
                        .foregroundColor(theme.text3)
                        .padding(.top, 8)
                }
                
                Spacer()
                TenBranding(theme: theme)
            }
            .padding()
        }
        .widgetURL(URL(string: "socialten://rate"))
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - FREE WIDGET 2: Prompt (Small)
// ═══════════════════════════════════════════════════════════════════

struct PromptWidget: Widget {
    let kind = "PromptWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TenTimelineProvider()) { entry in
            PromptWidgetView(entry: entry)
                .containerBackground(entry.theme.bg, for: .widget)
        }
        .configurationDisplayName("daily prompt")
        .description("today's reflection question")
        .supportedFamilies([.systemSmall])
    }
}

struct PromptWidgetView: View {
    let entry: TenWidgetEntry
    private var theme: WidgetThemeColors { entry.theme }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(theme.glow)
                    
                    Text("prompt")
                        .font(.system(size: 10, weight: .light))
                        .tracking(2)
                        .foregroundColor(theme.text3)
                        .textCase(.uppercase)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(theme.glow.opacity(0.6))
            }
            
            Spacer()
            
            // Prompt text
            Text(entry.data.todaysPrompt.lowercased())
                .font(.system(size: 15, weight: .light))
                .foregroundColor(theme.text2)
                .lineLimit(3)
                .lineSpacing(3)
            
            Spacer()
            
            // Footer
            Text("tap to respond")
                .font(.system(size: 9, weight: .light))
                .tracking(1)
                .foregroundColor(theme.text3.opacity(0.6))
        }
        .padding(14)
        .widgetURL(URL(string: "socialten://prompt"))
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - FREE WIDGET 3: Friends (Medium)
// ═══════════════════════════════════════════════════════════════════

struct FriendsWidget: Widget {
    let kind = "FriendsWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TenTimelineProvider()) { entry in
            FriendsWidgetView(entry: entry)
                .containerBackground(entry.theme.bg, for: .widget)
        }
        .configurationDisplayName("friends")
        .description("see how your friends are doing")
        .supportedFamilies([.systemMedium])
    }
}

struct FriendsWidgetView: View {
    let entry: TenWidgetEntry
    private var theme: WidgetThemeColors { entry.theme }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with user's rating
            HStack {
                if let rating = entry.data.user?.todayRating {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(theme.glow)
                                .frame(width: 40, height: 40)
                                .blur(radius: 10)
                                .opacity(0.3)
                            
                            Circle()
                                .fill(theme.card)
                                .frame(width: 36, height: 36)
                            
                            Text("\(rating)")
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(theme.glow)
                        }
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("you")
                                .font(.system(size: 12, weight: .light))
                                .foregroundColor(theme.text2)
                            Text("today")
                                .font(.system(size: 9, weight: .light))
                                .foregroundColor(theme.text3)
                        }
                    }
                } else {
                    Text("rate your day")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(theme.text3)
                }
                
                Spacer()
                TenBranding(theme: theme)
            }
            
            // Divider
            Rectangle()
                .fill(theme.surface.opacity(0.5))
                .frame(height: 0.5)
            
            // Friends row
            if entry.data.friends.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "person.2")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(theme.text3.opacity(0.5))
                        Text("add friends to see their ratings")
                            .font(.system(size: 10, weight: .light))
                            .foregroundColor(theme.text3)
                    }
                    Spacer()
                }
            } else {
                HStack(spacing: 16) {
                    ForEach(entry.data.friends.prefix(5)) { friend in
                        FriendBubble(friend: friend, defaultTheme: theme, size: 36, fontSize: 15)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(14)
        .widgetURL(URL(string: "socialten://home"))
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - PREMIUM WIDGET 1: Latest Post (Medium)
// ═══════════════════════════════════════════════════════════════════

struct LatestPostWidget: Widget {
    let kind = "LatestPostWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TenTimelineProvider()) { entry in
            LatestPostWidgetView(entry: entry)
                .containerBackground(entry.theme.bg, for: .widget)
        }
        .configurationDisplayName("latest post")
        .description("see the latest from your feed")
        .supportedFamilies([.systemMedium])
    }
}

struct LatestPostWidgetView: View {
    let entry: TenWidgetEntry
    private var theme: WidgetThemeColors { entry.theme }
    
    var body: some View {
        ZStack {
            if entry.isPremium {
                premiumContent
            } else {
                PremiumUpgradeOverlay(theme: theme)
            }
        }
        .widgetURL(URL(string: entry.isPremium ? "socialten://feed" : "socialten://premium"))
    }
    
    private var premiumContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "square.stack")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(theme.glow)
                    
                    Text("feed")
                        .font(.system(size: 10, weight: .light))
                        .tracking(2)
                        .foregroundColor(theme.text3)
                        .textCase(.uppercase)
                }
                
                Spacer()
                TenBranding(theme: theme)
            }
            
            if let post = entry.data.latestPost {
                // Author row
                HStack(spacing: 6) {
                    // Author bubble
                    ZStack {
                        if post.authorIsPremium, let accentHex = post.authorThemeAccent {
                            Circle()
                                .fill(Color(hex: accentHex))
                                .frame(width: 26, height: 26)
                                .blur(radius: 6)
                                .opacity(0.4)
                        }
                        
                        Circle()
                            .fill(theme.card)
                            .frame(width: 22, height: 22)
                        
                        if let rating = post.rating {
                            Text("\(rating)")
                                .font(.system(size: 10, weight: .light))
                                .foregroundColor(post.authorIsPremium && post.authorThemeAccent != nil ? Color(hex: post.authorThemeAccent!) : theme.glow)
                        } else {
                            Text(String(post.authorName.prefix(1)).lowercased())
                                .font(.system(size: 10, weight: .light))
                                .foregroundColor(theme.text3)
                        }
                    }
                    
                    Text(post.authorName.lowercased())
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(theme.text2)
                    
                    Text("•")
                        .foregroundColor(theme.text3.opacity(0.5))
                    
                    Text(timeAgo(post.createdAt))
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(theme.text3)
                    
                    Spacer()
                }
                
                // Post content
                Text(post.content)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(theme.text1)
                    .lineLimit(2)
                    .lineSpacing(2)
                
                Spacer(minLength: 0)
                
                // Reply count
                if post.replyCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 9, weight: .light))
                        Text("\(post.replyCount)")
                            .font(.system(size: 10, weight: .light))
                    }
                    .foregroundColor(theme.text3)
                }
            } else {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "square.stack")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(theme.text3.opacity(0.5))
                        Text("no posts yet")
                            .font(.system(size: 11, weight: .light))
                            .foregroundColor(theme.text3)
                    }
                    Spacer()
                }
                Spacer()
            }
        }
        .padding(14)
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        return "\(Int(interval / 86400))d"
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Previews
// ═══════════════════════════════════════════════════════════════════

#Preview("Rating", as: .systemSmall) {
    RatingWidget()
} timeline: {
    TenWidgetEntry(date: Date(), data: .preview)
}

#Preview("Prompt", as: .systemSmall) {
    PromptWidget()
} timeline: {
    TenWidgetEntry(date: Date(), data: .preview)
}

#Preview("Friends", as: .systemMedium) {
    FriendsWidget()
} timeline: {
    TenWidgetEntry(date: Date(), data: .preview)
}

#Preview("Latest Post", as: .systemMedium) {
    LatestPostWidget()
} timeline: {
    TenWidgetEntry(date: Date(), data: .preview)
}
