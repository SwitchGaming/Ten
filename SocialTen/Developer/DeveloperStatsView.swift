//
//  DeveloperStatsView.swift
//  SocialTen
//
//  Beautiful developer stats dashboard with animated metrics and visual map
//

import SwiftUI
import MapKit

// MARK: - Stats Model

struct AppStats: Codable {
    // Core user stats
    let totalUsers: Int
    let usersRatedToday: Int
    let newUsersThisWeek: Int
    let newUsersLastWeek: Int
    let premiumUsers: Int
    
    // Content stats
    let totalPosts: Int
    let postsToday: Int
    let totalReplies: Int
    let repliesToday: Int
    let totalLikes: Int
    
    // Messaging stats
    let totalMessages: Int
    let messagesToday: Int
    let totalConversations: Int
    
    // Vibe stats
    let totalVibes: Int
    let activeVibes: Int
    let totalVibeResponses: Int
    
    // Rating stats
    let totalRatings: Int
    let averageRatingToday: Double
    let averageRatingAllTime: Double
    
    // Top streaks (anonymized)
    let topStreaks: [Int]
    
    // Badge distribution
    let badgeDistribution: [String: Int]
    
    // Friendship stats
    let totalFriendships: Int
    let friendRequestsPending: Int
    
    // Timezone distribution for map
    let timezoneDistribution: [TimezoneData]
    
    // Changelog stats
    let totalChangelogs: Int
    let totalChangelogViews: Int
    let uniqueChangelogViewers: Int
    let changelogViewRate: Double
    let changelogStats: [ChangelogStatItem]
    
    enum CodingKeys: String, CodingKey {
        case totalUsers = "total_users"
        case usersRatedToday = "users_rated_today"
        case newUsersThisWeek = "new_users_this_week"
        case newUsersLastWeek = "new_users_last_week"
        case premiumUsers = "premium_users"
        case totalPosts = "total_posts"
        case postsToday = "posts_today"
        case totalReplies = "total_replies"
        case repliesToday = "replies_today"
        case totalLikes = "total_likes"
        case totalMessages = "total_messages"
        case messagesToday = "messages_today"
        case totalConversations = "total_conversations"
        case totalVibes = "total_vibes"
        case activeVibes = "active_vibes"
        case totalVibeResponses = "total_vibe_responses"
        case totalRatings = "total_ratings"
        case averageRatingToday = "average_rating_today"
        case averageRatingAllTime = "average_rating_all_time"
        case topStreaks = "top_streaks"
        case badgeDistribution = "badge_distribution"
        case totalFriendships = "total_friendships"
        case friendRequestsPending = "friend_requests_pending"
        case timezoneDistribution = "timezone_distribution"
        case totalChangelogs = "total_changelogs"
        case totalChangelogViews = "total_changelog_views"
        case uniqueChangelogViewers = "unique_changelog_viewers"
        case changelogViewRate = "changelog_view_rate"
        case changelogStats = "changelog_stats"
    }
}

struct ChangelogStatItem: Codable, Identifiable {
    let version: String
    let title: String
    let views: Int
    let published_at: String?
    
    var id: String { version }
}

struct TimezoneData: Codable, Identifiable {
    let timezone: String
    let count: Int
    
    var id: String { timezone }
    
    // Convert timezone to approximate coordinates
    var coordinate: CLLocationCoordinate2D {
        TimezoneMapper.coordinate(for: timezone)
    }
    
    var cityName: String {
        TimezoneMapper.cityName(for: timezone)
    }
}

// MARK: - Hourly Activity Model

struct HourlyActivity: Codable {
    let timezone: String
    let totalByHour: [String: Int]
    let peakHour: Int?
    let activityByDay: [String: Int]
    
    enum CodingKeys: String, CodingKey {
        case timezone
        case totalByHour = "total_by_hour"
        case peakHour = "peak_hour"
        case activityByDay = "activity_by_day"
    }
    
    // Get activity for a specific hour (0-23)
    func activity(for hour: Int) -> Int {
        totalByHour[String(hour)] ?? 0
    }
    
    // Get max activity value for normalization
    var maxHourlyActivity: Int {
        totalByHour.values.max() ?? 1
    }
    
    // Get activity for a day (0=Sunday, 6=Saturday)
    func activity(forDay day: Int) -> Int {
        activityByDay[String(day)] ?? 0
    }
    
    // Get max daily activity
    var maxDailyActivity: Int {
        activityByDay.values.max() ?? 1
    }
    
    // Format hour for display
    static func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        var components = DateComponents()
        components.hour = hour
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date).lowercased()
        }
        return "\(hour)"
    }
    
    // Day name
    static func dayName(_ day: Int) -> String {
        let days = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        return days[day]
    }
}

// MARK: - Timezone to Location Mapper

struct TimezoneMapper {
    static let timezoneCoordinates: [String: (lat: Double, lon: Double, city: String)] = [
        // Americas
        "America/New_York": (40.7128, -74.0060, "New York"),
        "America/Los_Angeles": (34.0522, -118.2437, "Los Angeles"),
        "America/Chicago": (41.8781, -87.6298, "Chicago"),
        "America/Denver": (39.7392, -104.9903, "Denver"),
        "America/Phoenix": (33.4484, -112.0740, "Phoenix"),
        "America/Toronto": (43.6532, -79.3832, "Toronto"),
        "America/Vancouver": (49.2827, -123.1207, "Vancouver"),
        "America/Mexico_City": (19.4326, -99.1332, "Mexico City"),
        "America/Sao_Paulo": (-23.5505, -46.6333, "São Paulo"),
        "America/Buenos_Aires": (-34.6037, -58.3816, "Buenos Aires"),
        "America/Lima": (-12.0464, -77.0428, "Lima"),
        "America/Bogota": (4.7110, -74.0721, "Bogotá"),
        "America/Santiago": (-33.4489, -70.6693, "Santiago"),
        "America/Caracas": (10.4806, -66.9036, "Caracas"),
        "America/Montreal": (45.5017, -73.5673, "Montreal"),
        "America/Seattle": (47.6062, -122.3321, "Seattle"),
        "America/Miami": (25.7617, -80.1918, "Miami"),
        "America/Atlanta": (33.7490, -84.3880, "Atlanta"),
        "America/Boston": (42.3601, -71.0589, "Boston"),
        "America/Dallas": (32.7767, -96.7970, "Dallas"),
        "America/Houston": (29.7604, -95.3698, "Houston"),
        "America/Detroit": (42.3314, -83.0458, "Detroit"),
        "America/Minneapolis": (44.9778, -93.2650, "Minneapolis"),
        
        // Europe
        "Europe/London": (51.5074, -0.1278, "London"),
        "Europe/Paris": (48.8566, 2.3522, "Paris"),
        "Europe/Berlin": (52.5200, 13.4050, "Berlin"),
        "Europe/Rome": (41.9028, 12.4964, "Rome"),
        "Europe/Madrid": (40.4168, -3.7038, "Madrid"),
        "Europe/Amsterdam": (52.3676, 4.9041, "Amsterdam"),
        "Europe/Brussels": (50.8503, 4.3517, "Brussels"),
        "Europe/Vienna": (48.2082, 16.3738, "Vienna"),
        "Europe/Zurich": (47.3769, 8.5417, "Zurich"),
        "Europe/Stockholm": (59.3293, 18.0686, "Stockholm"),
        "Europe/Oslo": (59.9139, 10.7522, "Oslo"),
        "Europe/Copenhagen": (55.6761, 12.5683, "Copenhagen"),
        "Europe/Dublin": (53.3498, -6.2603, "Dublin"),
        "Europe/Lisbon": (38.7223, -9.1393, "Lisbon"),
        "Europe/Moscow": (55.7558, 37.6173, "Moscow"),
        "Europe/Istanbul": (41.0082, 28.9784, "Istanbul"),
        "Europe/Athens": (37.9838, 23.7275, "Athens"),
        "Europe/Warsaw": (52.2297, 21.0122, "Warsaw"),
        "Europe/Prague": (50.0755, 14.4378, "Prague"),
        "Europe/Budapest": (47.4979, 19.0402, "Budapest"),
        
        // Asia
        "Asia/Tokyo": (35.6762, 139.6503, "Tokyo"),
        "Asia/Shanghai": (31.2304, 121.4737, "Shanghai"),
        "Asia/Hong_Kong": (22.3193, 114.1694, "Hong Kong"),
        "Asia/Singapore": (1.3521, 103.8198, "Singapore"),
        "Asia/Seoul": (37.5665, 126.9780, "Seoul"),
        "Asia/Mumbai": (19.0760, 72.8777, "Mumbai"),
        "Asia/Delhi": (28.7041, 77.1025, "New Delhi"),
        "Asia/Bangalore": (12.9716, 77.5946, "Bangalore"),
        "Asia/Dubai": (25.2048, 55.2708, "Dubai"),
        "Asia/Bangkok": (13.7563, 100.5018, "Bangkok"),
        "Asia/Jakarta": (-6.2088, 106.8456, "Jakarta"),
        "Asia/Manila": (14.5995, 120.9842, "Manila"),
        "Asia/Taipei": (25.0330, 121.5654, "Taipei"),
        "Asia/Kuala_Lumpur": (3.1390, 101.6869, "Kuala Lumpur"),
        "Asia/Ho_Chi_Minh": (10.8231, 106.6297, "Ho Chi Minh City"),
        "Asia/Kolkata": (22.5726, 88.3639, "Kolkata"),
        "Asia/Tel_Aviv": (32.0853, 34.7818, "Tel Aviv"),
        "Asia/Riyadh": (24.7136, 46.6753, "Riyadh"),
        
        // Oceania
        "Australia/Sydney": (-33.8688, 151.2093, "Sydney"),
        "Australia/Melbourne": (-37.8136, 144.9631, "Melbourne"),
        "Australia/Brisbane": (-27.4698, 153.0251, "Brisbane"),
        "Australia/Perth": (-31.9505, 115.8605, "Perth"),
        "Pacific/Auckland": (-36.8485, 174.7633, "Auckland"),
        "Pacific/Honolulu": (21.3069, -157.8583, "Honolulu"),
        
        // Africa
        "Africa/Cairo": (30.0444, 31.2357, "Cairo"),
        "Africa/Johannesburg": (-26.2041, 28.0473, "Johannesburg"),
        "Africa/Lagos": (6.5244, 3.3792, "Lagos"),
        "Africa/Nairobi": (-1.2921, 36.8219, "Nairobi"),
        "Africa/Casablanca": (33.5731, -7.5898, "Casablanca")
    ]
    
    static func coordinate(for timezone: String) -> CLLocationCoordinate2D {
        if let coords = timezoneCoordinates[timezone] {
            return CLLocationCoordinate2D(latitude: coords.lat, longitude: coords.lon)
        }
        // Default to center of map if unknown
        return CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }
    
    static func cityName(for timezone: String) -> String {
        if let coords = timezoneCoordinates[timezone] {
            return coords.city
        }
        // Extract city from timezone string
        return timezone.split(separator: "/").last.map(String.init) ?? timezone
    }
}

// MARK: - Main Stats View

struct DeveloperStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var stats: AppStats?
    @State private var hourlyActivity: HourlyActivity?
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedTimezone: TimezoneData?
    @State private var showMapDetail = false
    @State private var selectedHour: Int? = nil
    @State private var selectedDay: Int? = nil
    
    var body: some View {
        ZStack {
            themeManager.colors.background.ignoresSafeArea()
            
            if isLoading {
                loadingView
            } else if let error = error {
                errorView(error)
            } else if let stats = stats {
                statsContent(stats)
            }
        }
        .task {
            await loadStats()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: themeManager.spacing.lg) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.colors.accent1))
                .scaleEffect(1.5)
            
            Text("loading stats...")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(themeManager.colors.textSecondary)
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: themeManager.spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(themeManager.colors.textTertiary)
            
            Text(message)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(themeManager.colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("retry") {
                Task { await loadStats() }
            }
            .foregroundColor(themeManager.colors.accent1)
        }
        .padding()
    }
    
    // MARK: - Stats Content
    
    private func statsContent(_ stats: AppStats) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: themeManager.spacing.xl) {
                // Header
                header
                
                // Overview Cards
                overviewSection(stats)
                
                // Growth Section
                growthSection(stats)
                
                // Activity Hours
                if let activity = hourlyActivity {
                    activityHoursSection(activity)
                }
                
                // Engagement Section
                engagementSection(stats)
                
                // Rating Insights
                ratingSection(stats)
                
                // Changelog Analytics
                changelogSection(stats)
                
                // World Map
                worldMapSection(stats)
                
                // Top Streaks
                streaksSection(stats)
                
                // Badge Distribution
                badgeSection(stats)
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, themeManager.spacing.screenHorizontal)
            .padding(.top, themeManager.spacing.md)
        }
        .refreshable {
            await loadStats()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(themeManager.colors.textSecondary)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("developer stats")
                    .font(themeManager.fonts.headline)
                    .foregroundColor(themeManager.colors.textPrimary)
                
                Text("real-time analytics")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(themeManager.colors.textTertiary)
            }
            
            Spacer()
            
            Button(action: { Task { await loadStats() } }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(themeManager.colors.textSecondary)
            }
        }
    }
    
    // MARK: - Overview Section
    
    private func overviewSection(_ stats: AppStats) -> some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            sectionHeader("overview", icon: "chart.bar.fill")
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: themeManager.spacing.md),
                GridItem(.flexible(), spacing: themeManager.spacing.md)
            ], spacing: themeManager.spacing.md) {
                StatCard(
                    title: "total users",
                    value: "\(stats.totalUsers)",
                    icon: "person.2.fill",
                    color: themeManager.colors.accent1
                )
                
                StatCard(
                    title: "active today",
                    value: "\(stats.usersRatedToday)",
                    icon: "sun.max.fill",
                    color: Color(hex: "FB923C"),
                    subtitle: "\(percentOf(stats.usersRatedToday, of: stats.totalUsers))% of users"
                )
                
                StatCard(
                    title: "ten+ members",
                    value: "\(stats.premiumUsers)",
                    icon: "crown.fill",
                    color: Color(hex: "FBBF24"),
                    subtitle: "\(percentOf(stats.premiumUsers, of: stats.totalUsers))% conversion"
                )
                
                StatCard(
                    title: "friendships",
                    value: "\(stats.totalFriendships)",
                    icon: "heart.fill",
                    color: Color(hex: "F472B6")
                )
            }
        }
    }
    
    // MARK: - Growth Section
    
    private func growthSection(_ stats: AppStats) -> some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            sectionHeader("growth", icon: "chart.line.uptrend.xyaxis")
            
            HStack(spacing: themeManager.spacing.md) {
                GrowthCard(
                    title: "this week",
                    value: stats.newUsersThisWeek,
                    previousValue: stats.newUsersLastWeek,
                    icon: "person.badge.plus"
                )
                
                GrowthCard(
                    title: "pending requests",
                    value: stats.friendRequestsPending,
                    previousValue: nil,
                    icon: "person.wave.2"
                )
            }
        }
    }
    
    // MARK: - Activity Hours Section
    
    private func activityHoursSection(_ activity: HourlyActivity) -> some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            sectionHeader("peak activity", icon: "clock.fill")
            
            // Explanation text
            Text("when users submit their daily ratings (last 30 days)")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            
            // Main hourly chart card
            VStack(alignment: .leading, spacing: themeManager.spacing.sm) {
                // Header row
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("peak hour")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        Text(HourlyActivity.formatHour(activity.peakHour ?? 12))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.colors.accent1)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("your timezone")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        Text(activity.timezone.replacingOccurrences(of: "_", with: " ").components(separatedBy: "/").last ?? activity.timezone)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.bottom, themeManager.spacing.xs)
                
                // Selected hour detail card (shows when hour is tapped)
                if let hour = selectedHour {
                    let count = activity.activity(for: hour)
                    let total = activity.totalByHour.values.reduce(0, +)
                    let percentage = total > 0 ? Int((Double(count) / Double(total)) * 100) : 0
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(HourlyActivity.formatHour(hour))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(themeManager.colors.accent1)
                            Text("selected hour")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()
                            .frame(height: 30)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(count)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Text("ratings")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()
                            .frame(height: 30)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(percentage)%")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Text("of total")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedHour = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(themeManager.colors.accent1.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
                
                // Tap instruction
                if selectedHour == nil {
                    Text("tap a bar to see details")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                
                // 24-hour bar chart (interactive)
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<24, id: \.self) { hour in
                        InteractiveHourBar(
                            hour: hour,
                            value: activity.activity(for: hour),
                            maxValue: activity.maxHourlyActivity,
                            isPeak: hour == (activity.peakHour ?? -1),
                            isSelected: hour == selectedHour
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                if selectedHour == hour {
                                    selectedHour = nil
                                } else {
                                    selectedHour = hour
                                }
                            }
                        }
                    }
                }
                .frame(height: 100)
                
                // Hour labels
                HStack {
                    Text("12am")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("6am")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("12pm")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("6pm")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("11pm")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(themeManager.spacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: themeManager.radius.lg))
            
            // Day of week breakdown
            if !activity.activityByDay.isEmpty {
                VStack(alignment: .leading, spacing: themeManager.spacing.sm) {
                    HStack {
                        Text("by day of week")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if selectedDay != nil {
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedDay = nil
                                }
                            } label: {
                                Text("clear")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(themeManager.colors.accent1)
                            }
                        }
                    }
                    
                    // Selected day detail
                    if let day = selectedDay {
                        let value = activity.activity(forDay: day)
                        let total = activity.activityByDay.values.reduce(0, +)
                        let percentage = total > 0 ? Int((Double(value) / Double(total)) * 100) : 0
                        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                        
                        HStack(spacing: 16) {
                            Text(dayNames[day])
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(themeManager.colors.accent1)
                            
                            Text("•")
                                .foregroundStyle(.tertiary)
                            
                            Text("\(value) ratings")
                                .font(.system(size: 14, weight: .medium))
                            
                            Text("•")
                                .foregroundStyle(.tertiary)
                            
                            Text("\(percentage)% of week")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                        .transition(.opacity)
                    }
                    
                    let maxDayValue = activity.maxDailyActivity
                    
                    HStack(spacing: themeManager.spacing.xs) {
                        ForEach(0..<7, id: \.self) { day in
                            let value = activity.activity(forDay: day)
                            let isSelected = day == selectedDay
                            let isBusiest = value == maxDayValue
                            
                            VStack(spacing: 4) {
                                Text("\(value)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(isSelected || isBusiest ? themeManager.colors.accent1 : .secondary)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isSelected ? themeManager.colors.accent1 : (isBusiest ? themeManager.colors.accent1 : themeManager.colors.accent1.opacity(0.3)))
                                    .frame(height: CGFloat(value) / CGFloat(max(1, maxDayValue)) * 40)
                                    .frame(maxHeight: 40)
                                    .scaleEffect(isSelected ? 1.1 : 1.0)
                                
                                Text(HourlyActivity.dayName(day))
                                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                    .foregroundStyle(isSelected || isBusiest ? .primary : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    if selectedDay == day {
                                        selectedDay = nil
                                    } else {
                                        selectedDay = day
                                    }
                                }
                            }
                        }
                    }
                    
                    // Insight text
                    if let peakDay = activity.activityByDay.max(by: { $0.value < $1.value })?.key,
                       let dayIndex = Int(peakDay) {
                        let dayNames = ["Sundays", "Mondays", "Tuesdays", "Wednesdays", "Thursdays", "Fridays", "Saturdays"]
                        Text("💡 Users are most active on \(dayNames[dayIndex])")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding(themeManager.spacing.md)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: themeManager.radius.lg))
            }
        }
    }
    
    // MARK: - Engagement Section
    
    private func engagementSection(_ stats: AppStats) -> some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            sectionHeader("engagement", icon: "bubble.left.and.bubble.right.fill")
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: themeManager.spacing.md),
                GridItem(.flexible(), spacing: themeManager.spacing.md),
                GridItem(.flexible(), spacing: themeManager.spacing.md)
            ], spacing: themeManager.spacing.md) {
                MiniStatCard(title: "posts", value: stats.totalPosts, today: stats.postsToday, icon: "square.stack.fill")
                MiniStatCard(title: "replies", value: stats.totalReplies, today: stats.repliesToday, icon: "text.bubble.fill")
                MiniStatCard(title: "likes", value: stats.totalLikes, today: nil, icon: "heart.fill")
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: themeManager.spacing.md),
                GridItem(.flexible(), spacing: themeManager.spacing.md),
                GridItem(.flexible(), spacing: themeManager.spacing.md)
            ], spacing: themeManager.spacing.md) {
                MiniStatCard(title: "messages", value: stats.totalMessages, today: stats.messagesToday, icon: "message.fill")
                MiniStatCard(title: "convos", value: stats.totalConversations, today: nil, icon: "bubble.left.and.bubble.right.fill")
                MiniStatCard(title: "vibes", value: stats.totalVibes, today: stats.activeVibes, icon: "sparkles", todayLabel: "active")
            }
        }
    }
    
    // MARK: - Rating Section
    
    private func ratingSection(_ stats: AppStats) -> some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            sectionHeader("ratings", icon: "star.fill")
            
            HStack(spacing: themeManager.spacing.md) {
                RatingCard(
                    title: "today's average",
                    rating: stats.averageRatingToday,
                    subtitle: "from \(stats.usersRatedToday) ratings"
                )
                
                RatingCard(
                    title: "all-time average",
                    rating: stats.averageRatingAllTime,
                    subtitle: "\(stats.totalRatings) total ratings"
                )
            }
        }
    }
    
    // MARK: - World Map Section
    
    private func worldMapSection(_ stats: AppStats) -> some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            sectionHeader("global reach", icon: "globe.americas.fill")
            
            ZStack {
                // Map
                Map {
                    ForEach(stats.timezoneDistribution) { tz in
                        Annotation(tz.cityName, coordinate: tz.coordinate) {
                            MapPin(count: tz.count, isSelected: selectedTimezone?.id == tz.id)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedTimezone = selectedTimezone?.id == tz.id ? nil : tz
                                    }
                                }
                        }
                    }
                }
                .mapStyle(.imagery(elevation: .realistic))
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: themeManager.radius.lg))
                
                // Selected detail overlay
                if let selected = selectedTimezone {
                    VStack {
                        Spacer()
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selected.cityName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("\(selected.count) user\(selected.count == 1 ? "" : "s")")
                                    .font(.system(size: 13, weight: .light))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Spacer()
                            
                            Button(action: { selectedTimezone = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: themeManager.radius.md))
                        .padding(themeManager.spacing.sm)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // Location summary
            let topLocations = stats.timezoneDistribution.prefix(5)
            if !topLocations.isEmpty {
                VStack(spacing: themeManager.spacing.sm) {
                    ForEach(Array(topLocations.enumerated()), id: \.element.id) { index, tz in
                        HStack {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(themeManager.colors.textTertiary)
                                .frame(width: 20)
                            
                            Text(tz.cityName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(themeManager.colors.textPrimary)
                            
                            Spacer()
                            
                            Text("\(tz.count)")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(themeManager.colors.accent1)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(index == 0 ? themeManager.colors.accent1.opacity(0.1) : themeManager.colors.cardBackground)
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Streaks Section
    
    private func streaksSection(_ stats: AppStats) -> some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            sectionHeader("top streaks", icon: "flame.fill")
            
            HStack(spacing: themeManager.spacing.sm) {
                ForEach(Array(stats.topStreaks.prefix(5).enumerated()), id: \.offset) { index, streak in
                    StreakBadge(rank: index + 1, days: streak)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Changelog Section
    
    private func changelogSection(_ stats: AppStats) -> some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            sectionHeader("changelog analytics", icon: "doc.text.fill")
            
            // Overview stats
            HStack(spacing: themeManager.spacing.md) {
                StatCard(
                    title: "total views",
                    value: "\(stats.totalChangelogViews)",
                    icon: "eye.fill",
                    color: Color(hex: "8B5CF6"),
                    subtitle: "\(stats.uniqueChangelogViewers) unique users"
                )
                
                StatCard(
                    title: "view rate",
                    value: "\(Int(stats.changelogViewRate))%",
                    icon: "chart.pie.fill",
                    color: Color(hex: "60A5FA"),
                    subtitle: "of all users"
                )
            }
            
            // Per-version breakdown
            if !stats.changelogStats.isEmpty {
                VStack(alignment: .leading, spacing: themeManager.spacing.sm) {
                    Text("views by version")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(themeManager.colors.textSecondary)
                        .padding(.top, themeManager.spacing.sm)
                    
                    ForEach(stats.changelogStats) { item in
                        changelogStatRow(item, totalUsers: stats.totalUsers)
                    }
                }
                .padding(themeManager.spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: themeManager.radius.md)
                        .fill(themeManager.colors.cardBackground)
                )
            }
        }
    }
    
    private func changelogStatRow(_ item: ChangelogStatItem, totalUsers: Int) -> some View {
        HStack(spacing: 12) {
            // Version badge
            Text("v\(item.version)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(hex: "8B5CF6"))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(themeManager.colors.textPrimary)
                    .lineLimit(1)
                
                Text("\(item.views) views")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(themeManager.colors.textSecondary)
            }
            
            Spacer()
            
            // View percentage
            let percentage = totalUsers > 0 ? Int(Double(item.views) / Double(totalUsers) * 100) : 0
            Text("\(percentage)%")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "8B5CF6"))
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Badge Section
    
    private func badgeSection(_ stats: AppStats) -> some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            sectionHeader("badge distribution", icon: "medal.fill")
            
            if stats.badgeDistribution.isEmpty {
                Text("no badges unlocked yet")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(themeManager.colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                let sorted = stats.badgeDistribution.sorted { $0.value > $1.value }
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: themeManager.spacing.sm) {
                    ForEach(sorted.prefix(8), id: \.key) { badgeId, count in
                        BadgeStatRow(badgeId: badgeId, count: count, total: stats.totalUsers)
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(themeManager.colors.accent1)
            
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(themeManager.colors.textSecondary)
                .textCase(.uppercase)
                .tracking(1)
        }
    }
    
    private func percentOf(_ value: Int, of total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(value) / Double(total)) * 100)
    }
    
    // MARK: - Data Loading
    
    private func loadStats() async {
        isLoading = true
        error = nil
        
        do {
            // Fetch main stats
            let result: AppStats = try await SupabaseManager.shared.client
                .rpc("get_app_stats")
                .execute()
                .value
            
            // Fetch hourly activity in user's timezone
            let timezone = TimeZone.current.identifier
            let activityResult: HourlyActivity = try await SupabaseManager.shared.client
                .rpc("get_hourly_activity", params: ["user_timezone": timezone])
                .execute()
                .value
            
            await MainActor.run {
                self.stats = result
                self.hourlyActivity = activityResult
                self.isLoading = false
            }
        } catch {
            print("❌ Error loading stats: \(error)")
            await MainActor.run {
                self.error = "Failed to load stats: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var subtitle: String? = nil
    
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var isAnimated = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.colors.textPrimary)
                .scaleEffect(isAnimated ? 1 : 0.5)
                .opacity(isAnimated ? 1 : 0)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.colors.textSecondary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(themeManager.colors.textTertiary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: themeManager.radius.md)
                .fill(themeManager.colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: themeManager.radius.md)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                isAnimated = true
            }
        }
    }
}

struct GrowthCard: View {
    let title: String
    let value: Int
    let previousValue: Int?
    let icon: String
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var growthPercent: Int? {
        guard let prev = previousValue, prev > 0 else { return nil }
        return Int(((Double(value) - Double(prev)) / Double(prev)) * 100)
    }
    
    private var isPositive: Bool {
        guard let growth = growthPercent else { return true }
        return growth >= 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(themeManager.colors.accent1)
                
                Spacer()
                
                if let growth = growthPercent {
                    HStack(spacing: 2) {
                        Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(abs(growth))%")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(isPositive ? Color(hex: "4ADE80") : Color(hex: "F87171"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill((isPositive ? Color(hex: "4ADE80") : Color(hex: "F87171")).opacity(0.15))
                    )
                }
            }
            
            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.colors.textPrimary)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeManager.colors.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: themeManager.radius.md)
                .fill(themeManager.colors.cardBackground)
        )
    }
}

struct MiniStatCard: View {
    let title: String
    let value: Int
    let today: Int?
    let icon: String
    var todayLabel: String = "today"
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(themeManager.colors.accent1)
            
            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.colors.textPrimary)
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(themeManager.colors.textSecondary)
            
            if let today = today {
                Text("+\(today) \(todayLabel)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color(hex: "4ADE80"))
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: themeManager.radius.md)
                .fill(themeManager.colors.cardBackground)
        )
    }
}

struct RatingCard: View {
    let title: String
    let rating: Double
    let subtitle: String
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var ratingColor: Color {
        switch rating {
        case 0..<4: return Color(hex: "F87171")
        case 4..<6: return Color(hex: "FBBF24")
        case 6..<8: return Color(hex: "4ADE80")
        default: return Color(hex: "38BDF8")
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text(String(format: "%.1f", rating))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(ratingColor)
            
            // Rating bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(themeManager.colors.surfaceLight)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ratingColor)
                        .frame(width: geometry.size.width * (rating / 10))
                }
            }
            .frame(height: 8)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeManager.colors.textSecondary)
            
            Text(subtitle)
                .font(.system(size: 10, weight: .light))
                .foregroundColor(themeManager.colors.textTertiary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: themeManager.radius.md)
                .fill(themeManager.colors.cardBackground)
        )
    }
}

struct MapPin: View {
    let count: Int
    let isSelected: Bool
    
    private var size: CGFloat {
        switch count {
        case 1: return 16
        case 2...5: return 20
        case 6...10: return 26
        case 11...25: return 32
        default: return 40
        }
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "8B5CF6").opacity(0.3))
                .frame(width: size + 8, height: size + 8)
                .scaleEffect(isSelected ? 1.3 : 1)
            
            Circle()
                .fill(Color(hex: "8B5CF6"))
                .frame(width: size, height: size)
                .shadow(color: Color(hex: "8B5CF6").opacity(0.5), radius: isSelected ? 8 : 4)
            
            if count > 1 && size >= 20 {
                Text("\(count)")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct StreakBadge: View {
    let rank: Int
    let days: Int
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var medal: (icon: String, color: Color) {
        switch rank {
        case 1: return ("crown.fill", Color(hex: "FBBF24"))
        case 2: return ("medal.fill", Color(hex: "9CA3AF"))
        case 3: return ("medal.fill", Color(hex: "CD7F32"))
        default: return ("flame.fill", Color(hex: "FB923C"))
        }
    }
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: medal.icon)
                .font(.system(size: 20))
                .foregroundColor(medal.color)
            
            Text("\(days)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.colors.textPrimary)
            
            Text("days")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(themeManager.colors.textTertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: themeManager.radius.md)
                .fill(themeManager.colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: themeManager.radius.md)
                        .stroke(medal.color.opacity(0.3), lineWidth: rank <= 3 ? 2 : 0)
                )
        )
    }
}

struct BadgeStatRow: View {
    let badgeId: String
    let count: Int
    let total: Int
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var percent: Int {
        guard total > 0 else { return 0 }
        return Int((Double(count) / Double(total)) * 100)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Badge icon placeholder
            Image(systemName: "medal.fill")
                .font(.system(size: 14))
                .foregroundColor(themeManager.colors.accent1)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(badgeId.replacingOccurrences(of: "_", with: " "))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(themeManager.colors.textPrimary)
                    .lineLimit(1)
                
                Text("\(count) (\(percent)%)")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(themeManager.colors.textTertiary)
            }
            
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeManager.colors.cardBackground)
        )
    }
}

// MARK: - Interactive Hour Bar

struct InteractiveHourBar: View {
    let hour: Int
    let value: Int
    let maxValue: Int
    let isPeak: Bool
    let isSelected: Bool
    
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var animatedHeight: CGFloat = 0
    
    private var normalizedHeight: CGFloat {
        guard maxValue > 0 else { return 0.05 }
        return max(0.05, CGFloat(value) / CGFloat(maxValue))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    isSelected
                        ? LinearGradient(
                            colors: [themeManager.colors.accent1, themeManager.colors.accent1.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                          )
                        : isPeak 
                            ? LinearGradient(
                                colors: [themeManager.colors.accent1, themeManager.colors.accent1.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                              )
                            : LinearGradient(
                                colors: [themeManager.colors.accent1.opacity(0.5), themeManager.colors.accent1.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                              )
                )
                .frame(height: animatedHeight * 100)
                .frame(maxWidth: .infinity)
                .scaleEffect(x: isSelected ? 1.3 : 1.0, y: 1.0)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .contentShape(Rectangle())
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(hour) * 0.02)) {
                animatedHeight = normalizedHeight
            }
        }
        .overlay(alignment: .top) {
            if isPeak && !isSelected {
                Circle()
                    .fill(themeManager.colors.accent1)
                    .frame(width: 6, height: 6)
                    .offset(y: -8)
            }
            
            if isSelected {
                // Selected indicator
                VStack(spacing: 2) {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(themeManager.colors.accent1)
                }
                .offset(y: -12)
            }
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Activity Hour Bar (Legacy)

struct ActivityHourBar: View {
    let hour: Int
    let value: Int
    let maxValue: Int
    let isPeak: Bool
    
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var animatedHeight: CGFloat = 0
    
    private var normalizedHeight: CGFloat {
        guard maxValue > 0 else { return 0.05 }
        return max(0.05, CGFloat(value) / CGFloat(maxValue))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    isPeak 
                        ? LinearGradient(
                            colors: [themeManager.colors.accent1, themeManager.colors.accent1.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                          )
                        : LinearGradient(
                            colors: [themeManager.colors.accent1.opacity(0.5), themeManager.colors.accent1.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                          )
                )
                .frame(height: animatedHeight * 100)
                .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(hour) * 0.02)) {
                animatedHeight = normalizedHeight
            }
        }
        .overlay(alignment: .top) {
            if isPeak {
                Circle()
                    .fill(themeManager.colors.accent1)
                    .frame(width: 6, height: 6)
                    .offset(y: -8)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DeveloperStatsView()
}
