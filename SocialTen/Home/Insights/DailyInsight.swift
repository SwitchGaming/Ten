//
//  DailyInsight.swift
//  SocialTen
//

import SwiftUI

// MARK: - Daily Insight Model

enum InsightType: String, CaseIterable {
    case weekTrend           // Your rating trend this week
    case friendComparison    // Compare to friends average
    case streak              // Current streak insight
    case ratingPattern       // Day-of-week rating patterns
    case friendsActivity     // How many friends rated today
    case aiCoach             // Personalized AI insight/advice
    case friendshipMomentum  // Friendship growth tracking
}

// Celebration type for easter eggs
enum CelebrationType {
    case none
    case confetti
    case sparkle
    case heart
}

struct DailyInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let emoji: String
    let title: String
    let highlightedValue: String
    let subtitle: String
    let accentColor: Color
    let secondaryInfo: String?
    let visualData: InsightVisualData?
    let isPremium: Bool
    let aiInsight: String?           // Conversational one-liner
    let celebration: CelebrationType // Easter egg animation
    let friendName: String?          // For personalized friend insights
    let friendUser: User?            // For friend profile bubble display
    let isEmptyState: Bool           // True when prompting user to generate more data
    
    init(
        type: InsightType,
        emoji: String,
        title: String,
        highlightedValue: String,
        subtitle: String,
        accentColor: Color,
        secondaryInfo: String? = nil,
        visualData: InsightVisualData? = nil,
        isPremium: Bool = false,
        aiInsight: String? = nil,
        celebration: CelebrationType = .none,
        friendName: String? = nil,
        friendUser: User? = nil,
        isEmptyState: Bool = false
    ) {
        self.type = type
        self.emoji = emoji
        self.title = title
        self.highlightedValue = highlightedValue
        self.subtitle = subtitle
        self.accentColor = accentColor
        self.secondaryInfo = secondaryInfo
        self.visualData = visualData
        self.isPremium = isPremium
        self.aiInsight = aiInsight
        self.celebration = celebration
        self.friendName = friendName
        self.friendUser = friendUser
        self.isEmptyState = isEmptyState
    }
}

// MARK: - Visual Data Types

enum InsightVisualData {
    case comparison(current: Double, previous: Double, currentLabel: String, previousLabel: String)
    case grid(filled: Int, total: Int, average: Double? = nil)
    case progress(value: Double, max: Double)
    case bars(values: [(label: String, value: Double, color: Color)])
    case aiMessage // For AI coach card
    case weekdayHeatmap(data: [Int: Double]) // Day of week (1-7) -> average rating
    case momentum(previousScore: Int, currentScore: Int, level: String) // Friendship growth
    case unlock(progress: Int, goal: Int) // For "keep rating to unlock" placeholder
}

// MARK: - Insight Generator

class InsightGenerator {
    
    @MainActor
    static func generateInsights(
        ratingHistory: [RatingEntry],
        friends: [User],
        badgeManager: BadgeManager,
        isPremiumUser: Bool
    ) -> [DailyInsight] {
        // Gather friendship scores on main actor
        var friendshipScores: [String: FriendshipScore] = [:]
        for friend in friends {
            if let score = FriendshipScoreCache.shared.getScore(for: friend.id) {
                friendshipScores[friend.id] = score
            }
        }
        
        return generateInsightsInternal(
            ratingHistory: ratingHistory,
            friends: friends,
            badgeManager: badgeManager,
            isPremiumUser: isPremiumUser,
            friendshipScores: friendshipScores
        )
    }
    
    private static func generateInsightsInternal(
        ratingHistory: [RatingEntry],
        friends: [User],
        badgeManager: BadgeManager,
        isPremiumUser: Bool,
        friendshipScores: [String: FriendshipScore]
    ) -> [DailyInsight] {
        var insights: [DailyInsight] = []
        
        // 1. Week Trend Insight (Free)
        if let trendInsight = generateTrendInsight(ratingHistory: ratingHistory) {
            insights.append(trendInsight)
        }
        
        // 2. Friends Activity Insight (Free)
        if let friendsInsight = generateFriendsActivityInsight(friends: friends) {
            insights.append(friendsInsight)
        }
        
        // 3. AI Coach Insight (Premium) - personalized advice
        if let aiInsight = generateAICoachInsight(ratingHistory: ratingHistory, friends: friends, badgeManager: badgeManager) {
            insights.append(DailyInsight(
                type: aiInsight.type,
                emoji: aiInsight.emoji,
                title: aiInsight.title,
                highlightedValue: aiInsight.highlightedValue,
                subtitle: aiInsight.subtitle,
                accentColor: aiInsight.accentColor,
                secondaryInfo: aiInsight.secondaryInfo,
                visualData: aiInsight.visualData,
                isPremium: true,
                aiInsight: aiInsight.aiInsight,
                celebration: aiInsight.celebration,
                friendName: aiInsight.friendName
            ))
        }
        
        // 4. Pattern or Momentum Insight (Premium) - always shows, with fallback for new users
        let patternInsight = generatePatternOrMomentumInsight(ratingHistory: ratingHistory, friends: friends, friendshipScores: friendshipScores)
        insights.append(patternInsight)
        
        return insights
    }
    
    // MARK: - Trend Insight
    
    private static func generateTrendInsight(ratingHistory: [RatingEntry]) -> DailyInsight? {
        guard ratingHistory.count >= 2 else {
            // Aesthetic empty state prompting more ratings
            return DailyInsight(
                type: .weekTrend,
                emoji: "",
                title: "Rate daily to unlock",
                highlightedValue: "trends",
                subtitle: "",
                accentColor: Color(hex: "8B5CF6"),
                aiInsight: "\(max(0, 2 - ratingHistory.count)) more ratings to see your first trend",
                isEmptyState: true
            )
        }
        
        let recentRatings = Array(ratingHistory.prefix(7))
        let currentAvg = Double(recentRatings.reduce(0) { $0 + $1.rating }) / Double(recentRatings.count)
        
        if ratingHistory.count >= 4 {
            let olderRatings = Array(ratingHistory.dropFirst(min(3, ratingHistory.count)).prefix(4))
            let previousAvg = olderRatings.isEmpty ? currentAvg : Double(olderRatings.reduce(0) { $0 + $1.rating }) / Double(olderRatings.count)
            
            let change = currentAvg - previousAvg
            let changePercent = abs(change / max(previousAvg, 1)) * 100
            
            if change > 0.3 {
                // Celebration for big improvements
                let celebration: CelebrationType = changePercent >= 20 ? .confetti : .none
                let aiInsight = changePercent >= 20 
                    ? "This is your best week yet! 🎉" 
                    : "You're up \(String(format: "%.0f", changePercent))% from last week"
                
                return DailyInsight(
                    type: .weekTrend,
                    emoji: "🚀",
                    title: "Your vibe is",
                    highlightedValue: "+\(String(format: "%.0f", changePercent))%",
                    subtitle: "higher than last week",
                    accentColor: Color(hex: "4ADE80"),
                    visualData: .comparison(
                        current: currentAvg,
                        previous: previousAvg,
                        currentLabel: "This week",
                        previousLabel: "Last week"
                    ),
                    aiInsight: aiInsight,
                    celebration: celebration
                )
            } else if change < -0.3 {
                let aiInsight = changePercent >= 15 
                    ? "Tough week? Tomorrow's a fresh start" 
                    : "Slight dip, but you've got this"
                
                return DailyInsight(
                    type: .weekTrend,
                    emoji: "💭",
                    title: "Your vibe is",
                    highlightedValue: "-\(String(format: "%.0f", changePercent))%",
                    subtitle: "lower than last week",
                    accentColor: Color(hex: "FB923C"),
                    visualData: .comparison(
                        current: currentAvg,
                        previous: previousAvg,
                        currentLabel: "This week",
                        previousLabel: "Last week"
                    ),
                    aiInsight: aiInsight
                )
            }
        }
        
        return DailyInsight(
            type: .weekTrend,
            emoji: "✨",
            title: "Your weekly average is",
            highlightedValue: String(format: "%.1f", currentAvg),
            subtitle: "staying consistent",
            accentColor: Color(hex: "38BDF8"),
            visualData: .comparison(current: currentAvg, previous: currentAvg * 0.95, currentLabel: "This week", previousLabel: "Last week"),
            aiInsight: "Steady vibes — consistency is underrated"
        )
    }
    
    // MARK: - Friends Activity Insight
    
    private static func generateFriendsActivityInsight(friends: [User]) -> DailyInsight? {
        // No friends - show empty state prompting to add friends
        guard !friends.isEmpty else {
            return DailyInsight(
                type: .friendsActivity,
                emoji: "",
                title: "Add friends to see",
                highlightedValue: "their vibes",
                subtitle: "",
                accentColor: Color(hex: "EC4899"),
                visualData: .grid(filled: 0, total: 0, average: nil),
                aiInsight: "Your circle is waiting to be built",
                isEmptyState: true
            )
        }
        
        let ratedToday = friends.filter { $0.hasRatedToday }
        let ratedCount = ratedToday.count
        let totalFriends = friends.count
        
        let friendRatings = ratedToday.compactMap { $0.todayRating }
        let avgRating = friendRatings.isEmpty ? 0 : Double(friendRatings.reduce(0, +)) / Double(friendRatings.count)
        
        // Find a friend to highlight
        let highlightFriend = findHighlightFriend(friends: ratedToday)
        
        // No one rated yet - show waiting state
        if ratedCount == 0 {
            return DailyInsight(
                type: .friendsActivity,
                emoji: "",
                title: "0 of \(totalFriends) friends",
                highlightedValue: "rated yet",
                subtitle: "",
                accentColor: Color(hex: "64748B"),
                visualData: .grid(filled: 0, total: totalFriends, average: nil),
                aiInsight: "Be the first to spark today's vibes"
            )
        }
        
        // Generate personalized AI insight
        var aiInsight: String
        var friendName: String? = nil
        
        if let highlight = highlightFriend {
            friendName = highlight.name
            if let rating = highlight.rating {
                if rating >= 8 {
                    aiInsight = "\(highlight.name) is having a great day"
                } else if rating <= 4 {
                    aiInsight = "Maybe check in with \(highlight.name)"
                } else {
                    aiInsight = "\(highlight.name) checked in today"
                }
            } else {
                aiInsight = "\(ratedCount) friends shared their vibe"
            }
        } else {
            aiInsight = avgRating >= 7 ? "Your circle is feeling good today" : "Mixed vibes in your circle today"
        }
        
        return DailyInsight(
            type: .friendsActivity,
            emoji: ratedCount == totalFriends ? "🎉" : "👥",
            title: "\(ratedCount) of \(totalFriends) friends rated",
            highlightedValue: "Avg: \(String(format: "%.1f", avgRating))",
            subtitle: "",
            accentColor: Color(hex: "EC4899"),
            visualData: .grid(filled: ratedCount, total: totalFriends, average: avgRating > 0 ? avgRating : nil),
            aiInsight: aiInsight,
            celebration: ratedCount == totalFriends ? .heart : .none,
            friendName: friendName
        )
    }
    
    // Helper to find an interesting friend to highlight
    private static func findHighlightFriend(friends: [User]) -> (name: String, rating: Int?)? {
        // Prioritize: low ratings (need support) > high ratings (celebrate) > recent
        let withRatings = friends.compactMap { friend -> (name: String, rating: Int)? in
            guard let rating = friend.todayRating else { return nil }
            return (friend.displayName ?? friend.username ?? "Friend", rating)
        }
        
        // Find someone who might need support (rating <= 4)
        if let needsSupport = withRatings.first(where: { $0.rating <= 4 }) {
            return (needsSupport.name, needsSupport.rating)
        }
        
        // Find someone having a great day (rating >= 8)
        if let greatDay = withRatings.first(where: { $0.rating >= 8 }) {
            return (greatDay.name, greatDay.rating)
        }
        
        // Just return the first friend who rated
        if let first = withRatings.first {
            return (first.name, first.rating)
        }
        
        return nil
    }
    
    // MARK: - AI Coach Insight (Premium)
    
    private static func generateAICoachInsight(
        ratingHistory: [RatingEntry],
        friends: [User],
        badgeManager: BadgeManager
    ) -> DailyInsight? {
        let streak = badgeManager.currentStreak
        let recentRatings = Array(ratingHistory.prefix(7))
        let avgRecent = recentRatings.isEmpty ? 0 : Double(recentRatings.reduce(0) { $0 + $1.rating }) / Double(recentRatings.count)
        
        // Determine the best insight to show based on context
        
        // Check for streak milestone approaching
        if streak > 0 {
            let nextMilestone = streak < 7 ? 7 : (streak < 30 ? 30 : (streak < 100 ? 100 : 365))
            let daysToMilestone = nextMilestone - streak
            
            if daysToMilestone <= 3 && daysToMilestone > 0 {
                return DailyInsight(
                    type: .aiCoach,
                    emoji: "",
                    title: "\(streak)",
                    highlightedValue: "day streak",
                    subtitle: "",
                    accentColor: Color(hex: "FB923C"),
                    visualData: .progress(value: Double(streak), max: Double(nextMilestone)),
                    aiInsight: "\(daysToMilestone) day\(daysToMilestone == 1 ? "" : "s") until your \(nextMilestone)-day milestone!",
                    celebration: .sparkle
                )
            }
            
            // Just hit a milestone
            if streak == 7 || streak == 30 || streak == 100 || streak == 365 {
                return DailyInsight(
                    type: .aiCoach,
                    emoji: "",
                    title: "\(streak)",
                    highlightedValue: "days",
                    subtitle: "",
                    accentColor: Color(hex: "FB923C"),
                    visualData: .progress(value: Double(streak), max: Double(streak)),
                    aiInsight: "You hit \(streak) days! That's incredible 🎉",
                    celebration: .confetti
                )
            }
            
            // Regular streak display
            let milestoneText = streak < 30 ? "\(30 - streak) days to your first month" : "\(nextMilestone - streak) to hit \(nextMilestone)"
            return DailyInsight(
                type: .aiCoach,
                emoji: "",
                title: "\(streak)",
                highlightedValue: "day streak",
                subtitle: "",
                accentColor: Color(hex: "FB923C"),
                visualData: .progress(value: Double(streak), max: Double(nextMilestone)),
                aiInsight: milestoneText
            )
        }
        
        // Rough week detection
        if avgRecent > 0 && avgRecent < 5 && recentRatings.count >= 3 {
            return DailyInsight(
                type: .aiCoach,
                emoji: "",
                title: String(format: "%.1f", avgRecent),
                highlightedValue: "avg this week",
                subtitle: "",
                accentColor: Color(hex: "64748B"),
                visualData: .aiMessage,
                aiInsight: "It's been a tough week. Be kind to yourself."
            )
        }
        
        // Great week detection
        if avgRecent >= 8 && recentRatings.count >= 3 {
            return DailyInsight(
                type: .aiCoach,
                emoji: "",
                title: String(format: "%.1f", avgRecent),
                highlightedValue: "avg this week",
                subtitle: "",
                accentColor: Color(hex: "4ADE80"),
                visualData: .aiMessage,
                aiInsight: "What a week! You're radiating good energy ✨",
                celebration: .sparkle
            )
        }
        
        // Default encouraging message
        let encouragements = [
            "Every check-in is a small win",
            "You showed up today. That matters.",
            "Tracking your vibe builds awareness",
            "Small moments of reflection add up"
        ]
        
        return DailyInsight(
            type: .aiCoach,
            emoji: "",
            title: "",
            highlightedValue: "",
            subtitle: "",
            accentColor: Color(hex: "8B5CF6"),
            visualData: .aiMessage,
            aiInsight: encouragements.randomElement() ?? "Keep going"
        )
    }
    
    // MARK: - Pattern or Momentum Insight (Premium)
    
    private static func generatePatternOrMomentumInsight(
        ratingHistory: [RatingEntry],
        friends: [User],
        friendshipScores: [String: FriendshipScore]
    ) -> DailyInsight {
        // Try to generate both and pick the more interesting one
        let patternInsight = generateRatingPatternInsight(ratingHistory: ratingHistory)
        let momentumInsight = generateFriendshipMomentumInsight(friends: friends, friendshipScores: friendshipScores)
        
        // Alternate based on day of week, or pick whichever is available
        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        let preferPattern = dayOfWeek % 2 == 0 // Even days show patterns, odd days show momentum
        
        if preferPattern {
            if let insight = patternInsight ?? momentumInsight {
                return insight
            }
        } else {
            if let insight = momentumInsight ?? patternInsight {
                return insight
            }
        }
        
        // Fallback: Show a "coming soon" teaser when neither has enough data
        let currentRatings = ratingHistory.count
        let goalRatings = 10
        
        return DailyInsight(
            type: .ratingPattern,
            emoji: "🔮",
            title: "Personal patterns",
            highlightedValue: "unlock soon",
            subtitle: "",
            accentColor: Color(hex: "8B5CF6"),
            visualData: .unlock(progress: currentRatings, goal: goalRatings),
            isPremium: true,
            aiInsight: "\(goalRatings - currentRatings) more ratings to unlock your weekly patterns"
        )
    }
    
    // MARK: - Rating Pattern Insight
    
    private static func generateRatingPatternInsight(ratingHistory: [RatingEntry]) -> DailyInsight? {
        // Need at least 10 days of data to show meaningful patterns - otherwise hide card
        guard ratingHistory.count >= 10 else {
            return nil  // Hide card entirely when not enough data
        }
        
        // Group ratings by day of week (1 = Sunday, 7 = Saturday)
        var weekdayRatings: [Int: [Int]] = [:]
        for i in 1...7 {
            weekdayRatings[i] = []
        }
        
        for entry in ratingHistory {
            let weekday = Calendar.current.component(.weekday, from: entry.date)
            weekdayRatings[weekday]?.append(entry.rating)
        }
        
        // Calculate averages
        var weekdayAverages: [Int: Double] = [:]
        var bestDay: (day: Int, avg: Double) = (1, 0)
        var worstDay: (day: Int, avg: Double) = (1, 10)
        
        for (day, ratings) in weekdayRatings {
            if ratings.count >= 2 {
                let avg = Double(ratings.reduce(0, +)) / Double(ratings.count)
                weekdayAverages[day] = avg
                
                if avg > bestDay.avg {
                    bestDay = (day, avg)
                }
                if avg < worstDay.avg {
                    worstDay = (day, avg)
                }
            }
        }
        
        // Need at least 3 days with enough data
        guard weekdayAverages.count >= 3 else {
            return nil
        }
        
        // Day names
        let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let fullDayNames = ["", "Sundays", "Mondays", "Tuesdays", "Wednesdays", "Thursdays", "Fridays", "Saturdays"]
        
        // Generate AI insight
        let difference = bestDay.avg - worstDay.avg
        let aiInsight: String
        let celebration: CelebrationType
        
        if difference >= 2.0 {
            aiInsight = "\(fullDayNames[bestDay.day]) are your best days"
            celebration = .sparkle
        } else if difference >= 1.0 {
            aiInsight = "You tend to feel best on \(fullDayNames[bestDay.day])"
            celebration = .none
        } else {
            aiInsight = "Your week is pretty balanced"
            celebration = .none
        }
        
        return DailyInsight(
            type: .ratingPattern,
            emoji: "",
            title: "Best day",
            highlightedValue: dayNames[bestDay.day],
            subtitle: "",
            accentColor: Color(hex: "8B5CF6"),
            visualData: .weekdayHeatmap(data: weekdayAverages),
            isPremium: true,
            aiInsight: aiInsight,
            celebration: celebration
        )
    }
    
    // MARK: - Friendship Momentum Insight
    
    private static func generateFriendshipMomentumInsight(friends: [User], friendshipScores: [String: FriendshipScore]) -> DailyInsight? {
        // No friends - hide card entirely
        guard !friends.isEmpty else { return nil }
        
        // Find the friend with highest score (best friend)
        var bestFriend: (user: User, score: FriendshipScore)?
        
        for friend in friends {
            if let score = friendshipScores[friend.id] {
                if bestFriend == nil || score.score > bestFriend!.score.score {
                    bestFriend = (friend, score)
                }
            }
        }
        
        // No friendship scores available - hide card
        guard let topFriend = bestFriend else {
            return nil  // Hide card entirely when no friendship data
        }
        
        let friendName = topFriend.user.displayName ?? topFriend.user.username ?? "Friend"
        let score = topFriend.score
        let totalInteractions = score.breakdown.totalInteractions
        
        // Calculate growth message based on level
        let aiInsight: String
        let celebration: CelebrationType
        
        switch score.level {
        case .bestFriend:
            aiInsight = "\(friendName) is your #1 — \(totalInteractions) interactions!"
            celebration = .heart
        case .closeFriend:
            let toNext = 150 - score.score
            aiInsight = "\(toNext) more interactions to best friend status with \(friendName)"
            celebration = .none
        case .friend:
            aiInsight = "Your bond with \(friendName) is growing strong"
            celebration = .none
        case .acquaintance:
            aiInsight = "Keep engaging with \(friendName) to level up"
            celebration = .none
        case .newFriend:
            aiInsight = "Start your journey with \(friendName)"
            celebration = .none
        }
        
        // Calculate previous score estimate (based on weeks of friendship)
        let previousScore = max(0, score.score - (totalInteractions / max(1, score.breakdown.friendshipWeeks)))
        
        return DailyInsight(
            type: .friendshipMomentum,
            emoji: "",
            title: friendName,
            highlightedValue: score.level.rawValue,
            subtitle: "",
            accentColor: Color(hex: "EC4899"),
            visualData: .momentum(previousScore: previousScore, currentScore: score.score, level: score.level.rawValue),
            isPremium: true,
            aiInsight: aiInsight,
            celebration: celebration,
            friendName: friendName,
            friendUser: topFriend.user
        )
    }
}
