//
//  BadgeManager.swift
//  SocialTen
//

import SwiftUI
import Combine
import Supabase

// MARK: - Database Models for Badges

struct DBUserBadge: Codable {
    let id: UUID?
    let userId: UUID
    let badgeId: String
    let earnedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case badgeId = "badge_id"
        case earnedAt = "earned_at"
    }
}

struct DBUserStats: Codable {
    let id: UUID?
    let userId: UUID
    var currentStreak: Int
    var likesGiven: Int
    var repliesGiven: Int
    var vibesCreated: Int
    var vibesJoined: Int
    var nightRatings: Int
    var morningRatings: Int
    var daysActive: Int
    var consecutiveSameRating: Int
    var lastRating: Int?
    var lastRatingDate: String?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case currentStreak = "current_streak"
        case likesGiven = "likes_given"
        case repliesGiven = "replies_given"
        case vibesCreated = "vibes_created"
        case vibesJoined = "vibes_joined"
        case nightRatings = "night_ratings"
        case morningRatings = "morning_ratings"
        case daysActive = "days_active"
        case consecutiveSameRating = "consecutive_same_rating"
        case lastRating = "last_rating"
        case lastRatingDate = "last_rating_date"
        case updatedAt = "updated_at"
    }
}

// MARK: - Supabase Insert Models

struct UserBadgeInsert: Codable {
    let userId: String
    let badgeId: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case badgeId = "badge_id"
    }
}

struct UserStatsInsert: Codable {
    let userId: String
    let currentStreak: Int
    let likesGiven: Int
    let repliesGiven: Int
    let vibesCreated: Int
    let vibesJoined: Int
    let nightRatings: Int
    let morningRatings: Int
    let daysActive: Int
    let consecutiveSameRating: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case currentStreak = "current_streak"
        case likesGiven = "likes_given"
        case repliesGiven = "replies_given"
        case vibesCreated = "vibes_created"
        case vibesJoined = "vibes_joined"
        case nightRatings = "night_ratings"
        case morningRatings = "morning_ratings"
        case daysActive = "days_active"
        case consecutiveSameRating = "consecutive_same_rating"
    }
}

struct UserStatsUpdate: Codable {
    let currentStreak: Int
    let likesGiven: Int
    let repliesGiven: Int
    let vibesCreated: Int
    let vibesJoined: Int
    let nightRatings: Int
    let morningRatings: Int
    let daysActive: Int
    let consecutiveSameRating: Int
    let lastRating: Int?
    let lastRatingDate: String?
    
    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case likesGiven = "likes_given"
        case repliesGiven = "replies_given"
        case vibesCreated = "vibes_created"
        case vibesJoined = "vibes_joined"
        case nightRatings = "night_ratings"
        case morningRatings = "morning_ratings"
        case daysActive = "days_active"
        case consecutiveSameRating = "consecutive_same_rating"
        case lastRating = "last_rating"
        case lastRatingDate = "last_rating_date"
    }
}

// MARK: - Badge Manager

class BadgeManager: ObservableObject {
    static let shared = BadgeManager()
    
    @Published var earnedBadges: [EarnedBadge] = []
    @Published var newlyEarnedBadge: BadgeDefinition? = nil
    @Published var showBadgeCelebration: Bool = false
    
    // Stats tracking
    @Published var currentStreak: Int = 0
    @Published var likesGiven: Int = 0
    @Published var repliesGiven: Int = 0
    @Published var vibesCreated: Int = 0
    @Published var vibesJoined: Int = 0
    @Published var nightRatings: Int = 0
    @Published var morningRatings: Int = 0
    @Published var daysActive: Int = 0
    @Published var consecutiveSameRating: Int = 0
    @Published var lastRating: Int? = nil
    @Published var lastRatingDate: Date? = nil
    @Published var totalRatings: Int = 0
    @Published var weekendVibes: Int = 0
    @Published var eveningVibes: Int = 0
    
    private var currentUserId: String? = nil
    
    private init() {
        // Load from UserDefaults as fallback/cache
        loadFromUserDefaults()
    }
    
    // MARK: - Load from Supabase
    
    func loadFromSupabase(userId: String) async {
        guard let userUUID = UUID(uuidString: userId) else { return }
        currentUserId = userId
        
        do {
            // Load earned badges
            let badges: [DBUserBadge] = try await SupabaseManager.shared.client
                .from("user_badges")
                .select()
                .eq("user_id", value: userUUID)
                .execute()
                .value
            
            DispatchQueue.main.async {
                self.earnedBadges = badges.map { dbBadge in
                    EarnedBadge(
                        badgeId: dbBadge.badgeId,
                        earnedAt: dbBadge.earnedAt ?? Date()
                    )
                }
                self.saveToUserDefaults() // Cache locally
            }
            
            // Load user stats
            let stats: [DBUserStats] = try await SupabaseManager.shared.client
                .from("user_stats")
                .select()
                .eq("user_id", value: userUUID)
                .execute()
                .value
            
            if let userStats = stats.first {
                DispatchQueue.main.async {
                    self.currentStreak = userStats.currentStreak
                    self.likesGiven = userStats.likesGiven
                    self.repliesGiven = userStats.repliesGiven
                    self.vibesCreated = userStats.vibesCreated
                    self.vibesJoined = userStats.vibesJoined
                    self.nightRatings = userStats.nightRatings
                    self.morningRatings = userStats.morningRatings
                    self.daysActive = userStats.daysActive
                    self.consecutiveSameRating = userStats.consecutiveSameRating
                    self.lastRating = userStats.lastRating
                    if let dateStr = userStats.lastRatingDate {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd"
                        self.lastRatingDate = formatter.date(from: dateStr)
                    }
                    self.saveToUserDefaults() // Cache locally
                }
            } else {
                // Create initial stats record
                await createInitialStats(userId: userUUID)
            }
            
            print("Loaded \(badges.count) badges from Supabase")
            
            // Also load badge stats for dynamic percentiles
            await BadgeStatsCache.shared.fetchIfNeeded()
        } catch {
            print("Error loading badges from Supabase: \(error)")
            // Fall back to UserDefaults data
        }
    }
    
    private func createInitialStats(userId: UUID) async {
        let initialStats = UserStatsInsert(
            userId: userId.uuidString,
            currentStreak: 0,
            likesGiven: 0,
            repliesGiven: 0,
            vibesCreated: 0,
            vibesJoined: 0,
            nightRatings: 0,
            morningRatings: 0,
            daysActive: 1,
            consecutiveSameRating: 0
        )
        
        do {
            try await SupabaseManager.shared.client
                .from("user_stats")
                .insert(initialStats)
                .execute()
            
            DispatchQueue.main.async {
                self.daysActive = 1
                self.saveToUserDefaults()
            }
        } catch {
            print("Error creating initial stats: \(error)")
        }
    }
    
    // MARK: - Save to Supabase
    
    private func saveStatsToSupabase() async {
        guard let userId = currentUserId,
              let userUUID = UUID(uuidString: userId) else { return }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let statsUpdate = UserStatsUpdate(
            currentStreak: currentStreak,
            likesGiven: likesGiven,
            repliesGiven: repliesGiven,
            vibesCreated: vibesCreated,
            vibesJoined: vibesJoined,
            nightRatings: nightRatings,
            morningRatings: morningRatings,
            daysActive: daysActive,
            consecutiveSameRating: consecutiveSameRating,
            lastRating: lastRating,
            lastRatingDate: lastRatingDate != nil ? dateFormatter.string(from: lastRatingDate!) : nil
        )
        
        do {
            try await SupabaseManager.shared.client
                .from("user_stats")
                .update(statsUpdate)
                .eq("user_id", value: userUUID)
                .execute()
        } catch {
            print("Error saving stats to Supabase: \(error)")
        }
    }
    
    private func saveBadgeToSupabase(_ badgeId: String) async {
        guard let userId = currentUserId,
              let userUUID = UUID(uuidString: userId) else { return }
        
        let badgeInsert = UserBadgeInsert(
            userId: userUUID.uuidString,
            badgeId: badgeId
        )
        
        do {
            try await SupabaseManager.shared.client
                .from("user_badges")
                .insert(badgeInsert)
                .execute()
            
            print("Badge \(badgeId) saved to Supabase")
        } catch {
            print("Error saving badge to Supabase: \(error)")
        }
    }
    
    // MARK: - Check for New Badges
    
    func checkForNewBadges(
        userId: String? = nil,
        friendCount: Int = 0,
        rating: Int? = nil,
        maxVibeAttendees: Int = 0
    ) async {
        if let userId = userId {
            currentUserId = userId
        }
        
        var newBadges: [BadgeDefinition] = []
        
        for badge in BadgeLibrary.all {
            // Skip if already earned
            if earnedBadges.contains(where: { $0.badgeId == badge.id }) {
                continue
            }
            
            // Check requirement
            let requirementMet = checkRequirement(
                badge.requirement,
                friendCount: friendCount,
                rating: rating,
                maxVibeAttendees: maxVibeAttendees
            )
            
            if requirementMet {
                let earned = EarnedBadge(badgeId: badge.id)
                
                DispatchQueue.main.async {
                    self.earnedBadges.append(earned)
                }
                
                newBadges.append(badge)
                
                // Save to Supabase
                await saveBadgeToSupabase(badge.id)
                
                // Invalidate badge stats cache so percentile updates
                BadgeStatsCache.shared.invalidate(badgeId: badge.id)
            }
        }
        
        // Celebrate the first new badge (most important one)
        if let firstNewBadge = newBadges.sorted(by: { $0.rarity.glowIntensity > $1.rarity.glowIntensity }).first {
            DispatchQueue.main.async {
                self.celebrateBadge(firstNewBadge)
            }
        }
        
        saveToUserDefaults()
    }
    
    // Synchronous version for backward compatibility
    func checkForNewBadges(
        friendCount: Int = 0,
        rating: Int? = nil,
        maxVibeAttendees: Int = 0
    ) {
        Task {
            await checkForNewBadges(
                userId: currentUserId,
                friendCount: friendCount,
                rating: rating,
                maxVibeAttendees: maxVibeAttendees
            )
        }
    }
    
    private func checkRequirement(
        _ requirement: BadgeRequirement,
        friendCount: Int,
        rating: Int?,
        maxVibeAttendees: Int
    ) -> Bool {
        switch requirement.type {
        case .streakDays:
            return currentStreak >= requirement.value
        case .friendCount:
            return friendCount >= requirement.value
        case .likesGiven:
            return likesGiven >= requirement.value
        case .repliesGiven:
            return repliesGiven >= requirement.value
        case .vibesCreated:
            return vibesCreated >= requirement.value
        case .vibesJoined:
            return vibesJoined >= requirement.value
        case .vibeAttendees:
            return maxVibeAttendees >= requirement.value
        case .daysActive:
            return daysActive >= requirement.value
        case .ratingValue:
            return rating == requirement.value
        case .nightRatings:
            return nightRatings >= requirement.value
        case .morningRatings:
            return morningRatings >= requirement.value
        case .consecutiveSameRating:
            return consecutiveSameRating >= requirement.value
        case .totalRatings:
            return totalRatings >= requirement.value
        case .weekendVibes:
            return weekendVibes >= requirement.value
        case .eveningVibes:
            return eveningVibes >= requirement.value
        }
    }
    
    func trackRating(_ rating: Int, userId: String? = nil) async {
        if let userId = userId {
            currentUserId = userId
        }
        
        let hour = Calendar.current.component(.hour, from: Date())
        let today = Calendar.current.startOfDay(for: Date())
        
        // Check if this is a new day (for daysActive tracking)
        let isNewDay: Bool
        if let lastDate = lastRatingDate {
            isNewDay = !Calendar.current.isDate(lastDate, inSameDayAs: today)
        } else {
            isNewDay = true // First rating ever
        }
        
        // Night owl (midnight - 4am)
        if hour >= 0 && hour < 4 && isNewDay {
            nightRatings += 1
        }
        
        // Early bird / Morning person (before 9am)
        if hour >= 5 && hour < 9 && isNewDay {
            morningRatings += 1
        }
        
        // Check streak - only update on new days
        if isNewDay {
            if let lastDate = lastRatingDate {
                let daysSinceLastRating = Calendar.current.dateComponents([.day], from: lastDate, to: today).day ?? 0
                
                if daysSinceLastRating == 1 {
                    // Consecutive day - continue streak
                    currentStreak += 1
                } else if daysSinceLastRating > 1 {
                    // Streak broken
                    currentStreak = 1
                }
                // If daysSinceLastRating == 0, we shouldn't be here (isNewDay would be false)
            } else {
                // First rating ever
                currentStreak = 1
            }
            
            // Only increment daysActive on NEW days
            daysActive += 1
        }
        
        // Consecutive same rating (can update on same day)
        if let last = lastRating, last == rating {
            consecutiveSameRating += 1
        } else {
            consecutiveSameRating = 1
        }
        
        lastRating = rating
        lastRatingDate = today
        totalRatings += 1
        
        saveToUserDefaults()
        await saveStatsToSupabase()
    }
    
    // Synchronous version for backward compatibility
    func trackRating(_ rating: Int) {
        Task {
            await trackRating(rating, userId: currentUserId)
        }
    }
    
    func trackLike(userId: String? = nil) async {
        if let userId = userId {
            currentUserId = userId
        }
        likesGiven += 1
        saveToUserDefaults()
        await saveStatsToSupabase()
    }
    
    func trackLike() {
        Task {
            await trackLike(userId: currentUserId)
        }
    }
    
    func trackReply(userId: String? = nil) async {
        if let userId = userId {
            currentUserId = userId
        }
        repliesGiven += 1
        saveToUserDefaults()
        await saveStatsToSupabase()
    }
    
    func trackReply() {
        Task {
            await trackReply(userId: currentUserId)
        }
    }
    
    func trackVibeCreated(userId: String? = nil) async {
        if let userId = userId {
            currentUserId = userId
        }
        vibesCreated += 1
        
        // Check if weekend (Saturday = 7, Sunday = 1)
        let weekday = Calendar.current.component(.weekday, from: Date())
        if weekday == 1 || weekday == 7 {
            weekendVibes += 1
        }
        
        // Check if evening (after 8pm)
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 20 {
            eveningVibes += 1
        }
        
        saveToUserDefaults()
        await saveStatsToSupabase()
    }
    
    func trackVibeCreated() {
        Task {
            await trackVibeCreated(userId: currentUserId)
        }
    }
    
    func trackVibeJoined(userId: String? = nil) async {
        if let userId = userId {
            currentUserId = userId
        }
        vibesJoined += 1
        saveToUserDefaults()
        await saveStatsToSupabase()
    }
    
    func trackVibeJoined() {
        Task {
            await trackVibeJoined(userId: currentUserId)
        }
    }
    
    // MARK: - Celebration
    
    private func celebrateBadge(_ badge: BadgeDefinition) {
        newlyEarnedBadge = badge
        showBadgeCelebration = true
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func dismissCelebration() {
        withAnimation(.easeOut(duration: 0.3)) {
            showBadgeCelebration = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.newlyEarnedBadge = nil
        }
    }
    
    // MARK: - Local Persistence (Cache/Fallback)
    
    private func saveToUserDefaults() {
        let defaults = UserDefaults.standard
        
        if let encoded = try? JSONEncoder().encode(earnedBadges) {
            defaults.set(encoded, forKey: "earnedBadges")
        }
        
        defaults.set(currentStreak, forKey: "currentStreak")
        defaults.set(likesGiven, forKey: "likesGiven")
        defaults.set(repliesGiven, forKey: "repliesGiven")
        defaults.set(vibesCreated, forKey: "vibesCreated")
        defaults.set(vibesJoined, forKey: "vibesJoined")
        defaults.set(nightRatings, forKey: "nightRatings")
        defaults.set(morningRatings, forKey: "morningRatings")
        defaults.set(daysActive, forKey: "daysActive")
        defaults.set(consecutiveSameRating, forKey: "consecutiveSameRating")
        defaults.set(lastRating, forKey: "lastRating")
        defaults.set(totalRatings, forKey: "totalRatings")
        defaults.set(weekendVibes, forKey: "weekendVibes")
        defaults.set(eveningVibes, forKey: "eveningVibes")
        
        if let date = lastRatingDate {
            defaults.set(date, forKey: "lastRatingDate")
        }
    }
    
    private func loadFromUserDefaults() {
        let defaults = UserDefaults.standard
        
        if let data = defaults.data(forKey: "earnedBadges"),
           let decoded = try? JSONDecoder().decode([EarnedBadge].self, from: data) {
            earnedBadges = decoded
        }
        
        currentStreak = defaults.integer(forKey: "currentStreak")
        likesGiven = defaults.integer(forKey: "likesGiven")
        repliesGiven = defaults.integer(forKey: "repliesGiven")
        vibesCreated = defaults.integer(forKey: "vibesCreated")
        vibesJoined = defaults.integer(forKey: "vibesJoined")
        nightRatings = defaults.integer(forKey: "nightRatings")
        morningRatings = defaults.integer(forKey: "morningRatings")
        daysActive = defaults.integer(forKey: "daysActive")
        consecutiveSameRating = defaults.integer(forKey: "consecutiveSameRating")
        lastRating = defaults.object(forKey: "lastRating") as? Int
        lastRatingDate = defaults.object(forKey: "lastRatingDate") as? Date
        totalRatings = defaults.integer(forKey: "totalRatings")
        weekendVibes = defaults.integer(forKey: "weekendVibes")
        eveningVibes = defaults.integer(forKey: "eveningVibes")
    }
    
    // MARK: - Helpers
    
    func hasBadge(_ badgeId: String) -> Bool {
        earnedBadges.contains { $0.badgeId == badgeId }
    }
    
    func earnedDate(for badgeId: String) -> Date? {
        earnedBadges.first { $0.badgeId == badgeId }?.earnedAt
    }
    
    var earnedBadgeDefinitions: [BadgeDefinition] {
        earnedBadges.compactMap { earned in
            BadgeLibrary.badge(withId: earned.badgeId)
        }
    }
    
    // MARK: - Set User ID (call this after login)
    
    func setCurrentUser(_ userId: String) {
        currentUserId = userId
        Task {
            await loadFromSupabase(userId: userId)
        }
    }
}
