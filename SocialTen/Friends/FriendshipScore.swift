//
//  FriendshipScore.swift
//  SocialTen
//

import Foundation
import SwiftUI

// MARK: - Friendship Score Model

struct FriendshipScore: Codable, Identifiable {
    let id: String  // friendId
    let score: Int
    let level: FriendshipLevel
    let breakdown: ScoreBreakdown
    let lastUpdated: Date
    
    var isStale: Bool {
        // Consider score stale after 1 hour
        Date().timeIntervalSince(lastUpdated) > 3600
    }
    
    struct ScoreBreakdown: Codable {
        let likesGiven: Int
        let likesReceived: Int
        let repliesGiven: Int
        let repliesReceived: Int
        let vibeResponsesGiven: Int   // They responded to your vibes
        let vibeResponsesReceived: Int // You responded to their vibes
        let matchingRatingDays: Int
        let friendshipWeeks: Int
        
        var totalInteractions: Int {
            likesGiven + likesReceived + repliesGiven + repliesReceived +
            vibeResponsesGiven + vibeResponsesReceived
        }
    }
    
    init(id: String, score: Int, breakdown: ScoreBreakdown, lastUpdated: Date = Date()) {
        self.id = id
        self.score = score
        self.breakdown = breakdown
        self.lastUpdated = lastUpdated
        self.level = FriendshipLevel.from(score: score)
    }
}

// MARK: - Friendship Levels

enum FriendshipLevel: String, Codable, CaseIterable {
    case newFriend = "new friend"
    case acquaintance = "acquaintance"
    case friend = "friend"
    case closeFriend = "close friend"
    case bestFriend = "best friend"
    
    var icon: String {
        switch self {
        case .newFriend: return "person.badge.plus"
        case .acquaintance: return "person"
        case .friend: return "person.fill"
        case .closeFriend: return "heart"
        case .bestFriend: return "heart.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .newFriend: return .gray
        case .acquaintance: return .blue
        case .friend: return .green
        case .closeFriend: return .orange
        case .bestFriend: return .pink
        }
    }
    
    var description: String {
        switch self {
        case .newFriend: return "just getting started"
        case .acquaintance: return "building connection"
        case .friend: return "solid friendship"
        case .closeFriend: return "strong bond"
        case .bestFriend: return "inseparable"
        }
    }
    
    var minScore: Int {
        switch self {
        case .newFriend: return 0
        case .acquaintance: return 10
        case .friend: return 30
        case .closeFriend: return 75
        case .bestFriend: return 150
        }
    }
    
    var nextLevelScore: Int? {
        switch self {
        case .newFriend: return 10
        case .acquaintance: return 30
        case .friend: return 75
        case .closeFriend: return 150
        case .bestFriend: return nil
        }
    }
    
    static func from(score: Int) -> FriendshipLevel {
        if score >= 150 { return .bestFriend }
        if score >= 75 { return .closeFriend }
        if score >= 30 { return .friend }
        if score >= 10 { return .acquaintance }
        return .newFriend
    }
    
    var progressToNextLevel: (current: Int, required: Int)? {
        guard let nextScore = nextLevelScore else { return nil }
        return (minScore, nextScore)
    }
}

// MARK: - Supabase RPC Response

struct FriendshipScoreResponse: Codable {
    let score: Int
    let likesGiven: Int
    let likesReceived: Int
    let repliesGiven: Int
    let repliesReceived: Int
    let vibeResponsesGiven: Int
    let vibeResponsesReceived: Int
    let matchingRatingDays: Int
    let friendshipWeeks: Int
    
    enum CodingKeys: String, CodingKey {
        case score
        case likesGiven = "likes_given"
        case likesReceived = "likes_received"
        case repliesGiven = "replies_given"
        case repliesReceived = "replies_received"
        case vibeResponsesGiven = "vibe_responses_given"
        case vibeResponsesReceived = "vibe_responses_received"
        case matchingRatingDays = "matching_rating_days"
        case friendshipWeeks = "friendship_weeks"
    }
    
    func toFriendshipScore(friendId: String) -> FriendshipScore {
        let breakdown = FriendshipScore.ScoreBreakdown(
            likesGiven: likesGiven,
            likesReceived: likesReceived,
            repliesGiven: repliesGiven,
            repliesReceived: repliesReceived,
            vibeResponsesGiven: vibeResponsesGiven,
            vibeResponsesReceived: vibeResponsesReceived,
            matchingRatingDays: matchingRatingDays,
            friendshipWeeks: friendshipWeeks
        )
        return FriendshipScore(id: friendId, score: score, breakdown: breakdown)
    }
}

// MARK: - Batch Friendship Score RPC Response

struct BatchFriendshipScoreResponse: Codable {
    let scores: [BatchScoreItem]
    
    struct BatchScoreItem: Codable {
        let friendId: String
        let score: Int
        let likesGiven: Int
        let likesReceived: Int
        let repliesGiven: Int
        let repliesReceived: Int
        let vibeResponsesGiven: Int
        let vibeResponsesReceived: Int
        let matchingRatingDays: Int
        let friendshipWeeks: Int
        
        enum CodingKeys: String, CodingKey {
            case friendId = "friend_id"
            case score
            case likesGiven = "likes_given"
            case likesReceived = "likes_received"
            case repliesGiven = "replies_given"
            case repliesReceived = "replies_received"
            case vibeResponsesGiven = "vibe_responses_given"
            case vibeResponsesReceived = "vibe_responses_received"
            case matchingRatingDays = "matching_rating_days"
            case friendshipWeeks = "friendship_weeks"
        }
    }
}

// MARK: - Friendship Score Cache Manager

@MainActor
class FriendshipScoreCache: ObservableObject {
    static let shared = FriendshipScoreCache()
    
    @Published private(set) var scores: [String: FriendshipScore] = [:]
    @Published private(set) var isLoading: Set<String> = []
    
    private let cacheKey = "friendshipScoresCache"
    private let cacheDuration: TimeInterval = 3600 // 1 hour
    
    init() {
        loadFromDisk()
    }
    
    // MARK: - Public API
    
    func getScore(for friendId: String) -> FriendshipScore? {
        guard let score = scores[friendId], !score.isStale else {
            return nil
        }
        return score
    }
    
    func isLoadingScore(for friendId: String) -> Bool {
        isLoading.contains(friendId)
    }
    
    func cacheScore(_ score: FriendshipScore) {
        scores[score.id] = score
        saveToDisk()
    }
    
    func setLoading(_ friendId: String, loading: Bool) {
        if loading {
            isLoading.insert(friendId)
        } else {
            isLoading.remove(friendId)
        }
    }
    
    func clearCache() {
        scores = [:]
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
    
    // MARK: - Persistence
    
    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([String: FriendshipScore].self, from: data) else {
            return
        }
        // Only load non-stale scores
        scores = cached.filter { !$0.value.isStale }
    }
    
    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(scores) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }
}

// MARK: - Friendship Score Card View

struct FriendshipScoreCard: View {
    let friendshipScore: FriendshipScore?
    let isLoading: Bool
    let friendName: String
    var colors: ThemeColors = ThemeManager.shared.colors
    
    @State private var showBreakdown = false
    @State private var animateProgress = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("connection")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(colors.textTertiary)
                    .textCase(.uppercase)
                
                Spacer()
                
                if friendshipScore != nil {
                    Button(action: { showBreakdown.toggle() }) {
                        Image(systemName: showBreakdown ? "chevron.up" : "info.circle")
                            .font(.system(size: 12))
                            .foregroundColor(colors.textTertiary)
                    }
                }
            }
            
            if isLoading {
                loadingView
            } else if let score = friendshipScore {
                scoreContent(score)
            } else {
                emptyView
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colors.cardBackground.opacity(0.5))
        )
        .animation(.spring(response: 0.3), value: showBreakdown)
    }
    
    // MARK: - Score Content
    
    @ViewBuilder
    private func scoreContent(_ score: FriendshipScore) -> some View {
        VStack(spacing: 12) {
            // Level icon and name
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(score.level.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: score.level.icon)
                        .font(.system(size: 18))
                        .foregroundColor(score.level.color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(score.level.rawValue)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(colors.textPrimary)
                    
                    Text(score.level.description)
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(colors.textTertiary)
                }
                
                Spacer()
                
                // Score number
                Text("\(score.score)")
                    .font(.system(size: 28, weight: .ultraLight))
                    .foregroundColor(score.level.color)
            }
            
            // Progress to next level
            if let progress = progressInfo(for: score) {
                VStack(spacing: 6) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            Capsule()
                                .fill(colors.cardBackground)
                                .frame(height: 4)
                            
                            // Progress fill
                            Capsule()
                                .fill(score.level.color)
                                .frame(width: animateProgress ? geometry.size.width * progress.percentage : 0, height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    HStack {
                        Text("\(progress.pointsToNext) points to \(progress.nextLevel)")
                            .font(.system(size: 10, weight: .light))
                            .foregroundColor(colors.textTertiary)
                        
                        Spacer()
                    }
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                        animateProgress = true
                    }
                }
            }
            
            // Breakdown section (collapsible)
            if showBreakdown {
                breakdownView(score.breakdown)
            }
        }
    }
    
    // MARK: - Breakdown View
    
    @ViewBuilder
    private func breakdownView(_ breakdown: FriendshipScore.ScoreBreakdown) -> some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(colors.textTertiary.opacity(0.1))
                .frame(height: 1)
                .padding(.vertical, 4)
            
            VStack(spacing: 6) {
                breakdownRow(
                    icon: "hand.thumbsup.fill",
                    label: "likes exchanged",
                    value: breakdown.likesGiven + breakdown.likesReceived,
                    color: .yellow
                )
                breakdownRow(
                    icon: "bubble.left.fill",
                    label: "replies exchanged",
                    value: breakdown.repliesGiven + breakdown.repliesReceived,
                    color: .blue
                )
                breakdownRow(
                    icon: "sparkles",
                    label: "vibe interactions",
                    value: breakdown.vibeResponsesGiven + breakdown.vibeResponsesReceived,
                    color: .purple
                )
                breakdownRow(
                    icon: "calendar",
                    label: "matching moods",
                    value: breakdown.matchingRatingDays,
                    color: .green
                )
                breakdownRow(
                    icon: "clock.fill",
                    label: "weeks as friends",
                    value: breakdown.friendshipWeeks,
                    color: .orange
                )
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private func breakdownRow(icon: String, label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color.opacity(0.7))
                .frame(width: 16)
            
            Text(label)
                .font(.system(size: 11, weight: .light))
                .foregroundColor(colors.textSecondary)
            
            Spacer()
            
            Text("\(value)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(colors.textPrimary)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: colors.textTertiary))
                .scaleEffect(0.8)
            
            Text("calculating connection...")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.slash")
                .font(.system(size: 20))
                .foregroundColor(colors.textTertiary.opacity(0.5))
            
            Text("no interactions yet")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
    
    // MARK: - Helpers
    
    private func progressInfo(for score: FriendshipScore) -> (percentage: CGFloat, pointsToNext: Int, nextLevel: String)? {
        guard let nextScore = score.level.nextLevelScore else { return nil }
        
        let nextLevel = FriendshipLevel.from(score: nextScore)
        let pointsInCurrentLevel = score.score - score.level.minScore
        let pointsNeededForLevel = nextScore - score.level.minScore
        let percentage = CGFloat(pointsInCurrentLevel) / CGFloat(pointsNeededForLevel)
        let pointsToNext = nextScore - score.score
        
        return (min(percentage, 1.0), pointsToNext, nextLevel.rawValue)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        FriendshipScoreCard(
            friendshipScore: FriendshipScore(
                id: "test",
                score: 45,
                breakdown: FriendshipScore.ScoreBreakdown(
                    likesGiven: 8,
                    likesReceived: 6,
                    repliesGiven: 3,
                    repliesReceived: 4,
                    vibeResponsesGiven: 2,
                    vibeResponsesReceived: 3,
                    matchingRatingDays: 5,
                    friendshipWeeks: 4
                )
            ),
            isLoading: false,
            friendName: "Alex"
        )
        
        FriendshipScoreCard(
            friendshipScore: nil,
            isLoading: true,
            friendName: "Loading"
        )
    }
    .padding()
    .background(Color.black)
}

