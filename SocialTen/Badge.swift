//
//  Badge.swift
//  SocialTen
//

import SwiftUI

// MARK: - Badge Rarity

enum BadgeRarity: String, Codable, CaseIterable {
    case common
    case uncommon
    case rare
    case epic
    case legendary
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var color: Color {
        switch self {
        case .common: return Color(hex: "B8C5D6")      // Polished Silver
        case .uncommon: return Color(hex: "5EEAD4")    // Tiffany Teal
        case .rare: return Color(hex: "60A5FA")        // Sapphire Blue
        case .epic: return Color(hex: "C084FC")        // Amethyst Purple
        case .legendary: return Color(hex: "FCD34D")   // 24K Gold
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .common:
            return [Color(hex: "E8EEF5"), Color(hex: "94A3B8"), Color(hex: "64748B")]
        case .uncommon:
            return [Color(hex: "5EEAD4"), Color(hex: "2DD4BF"), Color(hex: "14B8A6")]
        case .rare:
            return [Color(hex: "93C5FD"), Color(hex: "60A5FA"), Color(hex: "3B82F6")]
        case .epic:
            return [Color(hex: "E879F9"), Color(hex: "C084FC"), Color(hex: "A855F7")]
        case .legendary:
            return [Color(hex: "FEF08A"), Color(hex: "FCD34D"), Color(hex: "F59E0B")]
        }
    }
    
    var glowIntensity: Double {
        switch self {
        case .common: return 0.12
        case .uncommon: return 0.18
        case .rare: return 0.25
        case .epic: return 0.35
        case .legendary: return 0.5
        }
    }
    
    var percentile: String {
        switch self {
        case .common: return "top 80%"
        case .uncommon: return "top 40%"
        case .rare: return "top 15%"
        case .epic: return "top 5%"
        case .legendary: return "top 1%"
        }
    }
}

// MARK: - Badge Category

enum BadgeCategory: String, Codable, CaseIterable {
    case streaks
    case social
    case vibes
    case milestones
    case rare
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .streaks: return "flame.fill"
        case .social: return "person.2.fill"
        case .vibes: return "sparkles"
        case .milestones: return "trophy.fill"
        case .rare: return "diamond.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .streaks: return Color(hex: "F97316")
        case .social: return Color(hex: "8B5CF6")
        case .vibes: return Color(hex: "FBBF24")
        case .milestones: return Color(hex: "3B82F6")
        case .rare: return Color(hex: "EC4899")
        }
    }
}

// MARK: - Badge Definition

struct BadgeDefinition: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let category: BadgeCategory
    let rarity: BadgeRarity
    let icon: String
    let requirement: BadgeRequirement
    
    var gradientColors: [Color] {
        switch category {
        case .streaks:
            return [Color(hex: "FDBA74"), Color(hex: "FB923C"), Color(hex: "EA580C")]
        case .social:
            return [Color(hex: "C4B5FD"), Color(hex: "A78BFA"), Color(hex: "8B5CF6")]
        case .vibes:
            return [Color(hex: "FDE68A"), Color(hex: "FBBF24"), Color(hex: "D97706")]
        case .milestones:
            return [Color(hex: "7DD3FC"), Color(hex: "38BDF8"), Color(hex: "0284C7")]
        case .rare:
            return [Color(hex: "F9A8D4"), Color(hex: "F472B6"), Color(hex: "DB2777")]
        }
    }
}

// MARK: - Badge Requirement

struct BadgeRequirement: Codable {
    let type: RequirementType
    let value: Int
    
    enum RequirementType: String, Codable {
        case streakDays
        case friendCount
        case likesGiven
        case repliesGiven
        case vibesCreated
        case vibesJoined
        case vibeAttendees
        case daysActive
        case ratingValue
        case nightRatings
        case morningRatings
        case consecutiveSameRating
        case totalRatings
        case weekendVibes
        case eveningVibes
    }
}

// MARK: - Earned Badge

struct EarnedBadge: Identifiable, Codable {
    let id: String
    let badgeId: String
    let earnedAt: Date
    
    init(badgeId: String, earnedAt: Date = Date()) {
        self.id = UUID().uuidString
        self.badgeId = badgeId
        self.earnedAt = earnedAt
    }
}

// MARK: - All Badge Definitions

struct BadgeLibrary {
    static let all: [BadgeDefinition] = [
        // MARK: Streak Badges
        BadgeDefinition(
            id: "first_spark",
            name: "first spark",
            description: "3 day rating streak",
            category: .streaks,
            rarity: .common,
            icon: "flame",
            requirement: BadgeRequirement(type: .streakDays, value: 3)
        ),
        BadgeDefinition(
            id: "on_fire",
            name: "on fire",
            description: "7 day rating streak",
            category: .streaks,
            rarity: .common,
            icon: "flame.fill",
            requirement: BadgeRequirement(type: .streakDays, value: 7)
        ),
        BadgeDefinition(
            id: "consistent",
            name: "consistent",
            description: "same rating 3 days in a row",
            category: .streaks,
            rarity: .common,
            icon: "equal.circle.fill",
            requirement: BadgeRequirement(type: .consecutiveSameRating, value: 3)
        ),
        BadgeDefinition(
            id: "blazing",
            name: "blazing",
            description: "14 day rating streak",
            category: .streaks,
            rarity: .uncommon,
            icon: "flame.fill",
            requirement: BadgeRequirement(type: .streakDays, value: 14)
        ),
        BadgeDefinition(
            id: "unstoppable",
            name: "unstoppable",
            description: "30 day rating streak",
            category: .streaks,
            rarity: .rare,
            icon: "flame.fill",
            requirement: BadgeRequirement(type: .streakDays, value: 30)
        ),
        BadgeDefinition(
            id: "half_century",
            name: "half century",
            description: "50 day rating streak",
            category: .streaks,
            rarity: .epic,
            icon: "flame.fill",
            requirement: BadgeRequirement(type: .streakDays, value: 50)
        ),
        BadgeDefinition(
            id: "legendary_streak",
            name: "legendary",
            description: "100 day rating streak",
            category: .streaks,
            rarity: .epic,
            icon: "flame.fill",
            requirement: BadgeRequirement(type: .streakDays, value: 100)
        ),
        BadgeDefinition(
            id: "eternal_flame",
            name: "eternal flame",
            description: "365 day rating streak",
            category: .streaks,
            rarity: .legendary,
            icon: "flame.fill",
            requirement: BadgeRequirement(type: .streakDays, value: 365)
        ),
        
        // MARK: Social Badges
        BadgeDefinition(
            id: "first_friend",
            name: "first friend",
            description: "add your first friend",
            category: .social,
            rarity: .common,
            icon: "person.badge.plus",
            requirement: BadgeRequirement(type: .friendCount, value: 1)
        ),
        BadgeDefinition(
            id: "inner_circle",
            name: "inner circle",
            description: "5 friends in your circle",
            category: .social,
            rarity: .common,
            icon: "person.2",
            requirement: BadgeRequirement(type: .friendCount, value: 5)
        ),
        BadgeDefinition(
            id: "full_ten",
            name: "full ten",
            description: "10 friends - circle complete",
            category: .social,
            rarity: .uncommon,
            icon: "person.3.fill",
            requirement: BadgeRequirement(type: .friendCount, value: 10)
        ),
        BadgeDefinition(
            id: "supporter",
            name: "supporter",
            description: "like 50 posts",
            category: .social,
            rarity: .common,
            icon: "heart",
            requirement: BadgeRequirement(type: .likesGiven, value: 50)
        ),
        BadgeDefinition(
            id: "conversationalist",
            name: "conversationalist",
            description: "reply to 25 posts",
            category: .social,
            rarity: .uncommon,
            icon: "bubble.left.and.bubble.right",
            requirement: BadgeRequirement(type: .repliesGiven, value: 25)
        ),
        BadgeDefinition(
            id: "cheerleader",
            name: "cheerleader",
            description: "like 200 posts",
            category: .social,
            rarity: .uncommon,
            icon: "heart.fill",
            requirement: BadgeRequirement(type: .likesGiven, value: 200)
        ),
        BadgeDefinition(
            id: "always_there",
            name: "always there",
            description: "reply to 100 posts",
            category: .social,
            rarity: .rare,
            icon: "bubble.left.fill",
            requirement: BadgeRequirement(type: .repliesGiven, value: 100)
        ),
        
        // MARK: Vibe Badges
        BadgeDefinition(
            id: "first_vibe",
            name: "first vibe",
            description: "create your first vibe",
            category: .vibes,
            rarity: .common,
            icon: "sparkle",
            requirement: BadgeRequirement(type: .vibesCreated, value: 1)
        ),
        BadgeDefinition(
            id: "night_out",
            name: "night out",
            description: "create a vibe after 8pm",
            category: .vibes,
            rarity: .common,
            icon: "moon.stars.fill",
            requirement: BadgeRequirement(type: .eveningVibes, value: 1)
        ),
        BadgeDefinition(
            id: "vibe_starter",
            name: "vibe starter",
            description: "create 10 vibes",
            category: .vibes,
            rarity: .uncommon,
            icon: "sparkles",
            requirement: BadgeRequirement(type: .vibesCreated, value: 10)
        ),
        BadgeDefinition(
            id: "weekend_warrior",
            name: "weekend warrior",
            description: "create 5 weekend vibes",
            category: .vibes,
            rarity: .uncommon,
            icon: "sun.max.fill",
            requirement: BadgeRequirement(type: .weekendVibes, value: 5)
        ),
        BadgeDefinition(
            id: "social_butterfly",
            name: "social butterfly",
            description: "create 50 vibes",
            category: .vibes,
            rarity: .rare,
            icon: "sparkles",
            requirement: BadgeRequirement(type: .vibesCreated, value: 50)
        ),
        BadgeDefinition(
            id: "yes_person",
            name: "yes person",
            description: "say yes to 25 vibes",
            category: .vibes,
            rarity: .uncommon,
            icon: "hand.thumbsup.fill",
            requirement: BadgeRequirement(type: .vibesJoined, value: 25)
        ),
        BadgeDefinition(
            id: "always_down",
            name: "always down",
            description: "say yes to 100 vibes",
            category: .vibes,
            rarity: .rare,
            icon: "hand.thumbsup.fill",
            requirement: BadgeRequirement(type: .vibesJoined, value: 100)
        ),
        BadgeDefinition(
            id: "vibe_magnet",
            name: "vibe magnet",
            description: "10 people join a single vibe",
            category: .vibes,
            rarity: .epic,
            icon: "star.fill",
            requirement: BadgeRequirement(type: .vibeAttendees, value: 10)
        ),
        
        // MARK: Milestone Badges
        BadgeDefinition(
            id: "day_one",
            name: "day one",
            description: "welcome to ten",
            category: .milestones,
            rarity: .common,
            icon: "door.left.hand.open",
            requirement: BadgeRequirement(type: .daysActive, value: 1)
        ),
        BadgeDefinition(
            id: "week_one",
            name: "week one",
            description: "active for 7 days",
            category: .milestones,
            rarity: .common,
            icon: "calendar",
            requirement: BadgeRequirement(type: .daysActive, value: 7)
        ),
        BadgeDefinition(
            id: "month_one",
            name: "month one",
            description: "active for 30 days",
            category: .milestones,
            rarity: .uncommon,
            icon: "calendar.badge.clock",
            requirement: BadgeRequirement(type: .daysActive, value: 30)
        ),
        BadgeDefinition(
            id: "centurion",
            name: "centurion",
            description: "100 total ratings",
            category: .milestones,
            rarity: .rare,
            icon: "100.circle.fill",
            requirement: BadgeRequirement(type: .totalRatings, value: 100)
        ),
        BadgeDefinition(
            id: "og",
            name: "OG",
            description: "active for 1 year",
            category: .milestones,
            rarity: .legendary,
            icon: "crown.fill",
            requirement: BadgeRequirement(type: .daysActive, value: 365)
        ),
        BadgeDefinition(
            id: "perfect_ten",
            name: "perfect ten",
            description: "rate yourself a 10",
            category: .milestones,
            rarity: .common,
            icon: "10.circle.fill",
            requirement: BadgeRequirement(type: .ratingValue, value: 10)
        ),
        
        // MARK: Rare/Hidden Badges
        BadgeDefinition(
            id: "night_owl",
            name: "night owl",
            description: "rate after midnight 10 times",
            category: .rare,
            rarity: .rare,
            icon: "moon.fill",
            requirement: BadgeRequirement(type: .nightRatings, value: 10)
        ),
        BadgeDefinition(
            id: "early_bird",
            name: "early bird",
            description: "rate before 7am 10 times",
            category: .rare,
            rarity: .rare,
            icon: "sunrise.fill",
            requirement: BadgeRequirement(type: .morningRatings, value: 10)
        ),
        BadgeDefinition(
            id: "morning_person",
            name: "morning person",
            description: "rate before 9am 5 times",
            category: .rare,
            rarity: .common,
            icon: "sun.horizon.fill",
            requirement: BadgeRequirement(type: .morningRatings, value: 5)
        ),
        BadgeDefinition(
            id: "lucky_seven",
            name: "lucky seven",
            description: "rate 7 for 7 days straight",
            category: .rare,
            rarity: .epic,
            icon: "7.circle.fill",
            requirement: BadgeRequirement(type: .consecutiveSameRating, value: 7)
        )
    ]
    
    static func badge(withId id: String) -> BadgeDefinition? {
        all.first { $0.id == id }
    }
    
    static func badges(in category: BadgeCategory) -> [BadgeDefinition] {
        all.filter { $0.category == category }
    }
}
