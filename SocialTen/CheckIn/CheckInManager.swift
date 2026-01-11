import Foundation
import SwiftUI

/// Manages check-in logic for detecting when users might need support
class CheckInManager: ObservableObject {
    static let shared = CheckInManager()
    
    @Published var shouldShowCheckIn = false
    @Published var currentSession: CheckInSession?
    
    private let cooldownKey = "lastCheckInDate"
    private let cooldownHours: Double = 24 // Only show once per day max
    
    // MARK: - Debug
    
    /// Reset cooldown for testing - call this to allow check-in to trigger again
    func resetCooldown() {
        UserDefaults.standard.removeObject(forKey: cooldownKey)
        print("🔍 CheckIn: Cooldown reset!")
    }
    
    // MARK: - Trigger Logic
    
    /// Determines if a check-in should be triggered based on recent ratings
    /// Triggers if: average of last 3 ratings < 5 OR rating dropped 4+ points
    func shouldTriggerCheckIn(ratings: [RatingEntry]) -> Bool {
        print("🔍 CheckIn: Evaluating \(ratings.count) ratings")
        
        // Need at least 1 rating
        guard !ratings.isEmpty else {
            print("🔍 CheckIn: No ratings found, skipping")
            return false
        }
        
        // Check cooldown first
        if let lastCheckIn = UserDefaults.standard.object(forKey: cooldownKey) as? Date {
            let hoursSinceLastCheckIn = Date().timeIntervalSince(lastCheckIn) / 3600
            print("🔍 CheckIn: Hours since last check-in: \(hoursSinceLastCheckIn)")
            if hoursSinceLastCheckIn < cooldownHours {
                print("🔍 CheckIn: Still in cooldown, skipping")
                return false
            }
        } else {
            print("🔍 CheckIn: No previous check-in found")
        }
        
        // Sort by date, most recent first
        let sortedRatings = ratings.sorted { $0.date > $1.date }
        
        // Debug: print ratings
        for (index, rating) in sortedRatings.prefix(5).enumerated() {
            print("🔍 CheckIn: Rating[\(index)]: \(rating.rating) on \(rating.date)")
        }
        
        // Check 1: Average of last 3 ratings < 5
        let recentRatings = Array(sortedRatings.prefix(3))
        if recentRatings.count >= 2 {
            let average = Double(recentRatings.reduce(0) { $0 + $1.rating }) / Double(recentRatings.count)
            print("🔍 CheckIn: Average of last \(recentRatings.count) ratings: \(average)")
            if average < 5.0 {
                print("✅ CheckIn: TRIGGERED - Average below 5")
                return true
            }
        }
        
        // Check 2: Rating dropped 4+ points from previous
        if sortedRatings.count >= 2 {
            let current = sortedRatings[0].rating
            let previous = sortedRatings[1].rating
            let drop = previous - current
            print("🔍 CheckIn: Drop detection - Current: \(current), Previous: \(previous), Drop: \(drop)")
            if drop >= 4 {
                print("✅ CheckIn: TRIGGERED - Drop of \(drop) points")
                return true
            }
        }
        
        print("🔍 CheckIn: No trigger conditions met")
        return false
    }
    
    /// Start a new check-in session
    func startCheckIn(hasBestFriend: Bool, bestFriendName: String?) {
        currentSession = CheckInSession(
            hasBestFriend: hasBestFriend,
            bestFriendName: bestFriendName
        )
        shouldShowCheckIn = true
        
        // Record check-in time for cooldown
        UserDefaults.standard.set(Date(), forKey: cooldownKey)
    }
    
    /// Complete the check-in session
    func completeCheckIn() {
        shouldShowCheckIn = false
        currentSession = nil
    }
    
    /// Skip/dismiss the check-in
    func skipCheckIn() {
        shouldShowCheckIn = false
        currentSession = nil
    }
    
    // MARK: - Curated Prompts for Difficult Moments
    
    /// Gentle, reflective prompts for when someone is struggling
    static let checkInPrompts: [String] = [
        "What's one small thing that brought you comfort today?",
        "If you could talk to yourself from this morning, what would you say?",
        "What's something you're looking forward to, even if it's small?",
        "What would feel like a tiny win right now?",
        "Is there something weighing on you that you'd like to let go of?",
        "What's one thing you wish others understood about how you're feeling?",
        "If today had a color, what would it be and why?",
        "What's something kind you could do for yourself in the next hour?",
        "What part of your day do you wish had gone differently?",
        "Is there someone you'd like to connect with right now?"
    ]
    
    /// Gratitude pivot prompts - gentle reframing
    static let gratitudePrompts: [String] = [
        "Even on hard days, is there one tiny thing you're grateful for?",
        "What's something simple that made today a little easier?",
        "Is there someone who cares about you that you're thankful for?",
        "What's one thing about yourself you appreciate today?",
        "Is there a small comfort you have access to right now?",
        "What's something you did today, even if small, that you can be proud of?"
    ]
    
    /// Get a random check-in prompt
    static func getRandomCheckInPrompt() -> String {
        checkInPrompts.randomElement() ?? checkInPrompts[0]
    }
    
    /// Get a random gratitude prompt
    static func getRandomGratitudePrompt() -> String {
        gratitudePrompts.randomElement() ?? gratitudePrompts[0]
    }
    
    // MARK: - Quick Response Templates for Friends
    
    /// Pre-written supportive messages friends can send
    static let quickResponses: [QuickResponse] = [
        QuickResponse(
            emoji: "💙",
            shortText: "Thinking of you",
            fullMessage: "Hey, just wanted you to know I'm thinking of you. No pressure to respond - just here if you need anything."
        ),
        QuickResponse(
            emoji: "☕️",
            shortText: "Coffee soon?",
            fullMessage: "Hey! Would love to catch up over coffee or a walk sometime soon. Let me know if you're up for it!"
        ),
        QuickResponse(
            emoji: "🫂",
            shortText: "Sending support",
            fullMessage: "Sending you a virtual hug. Whatever you're going through, I'm in your corner."
        ),
        QuickResponse(
            emoji: "📞",
            shortText: "Call me anytime",
            fullMessage: "Hey, call me whenever you need to talk - no topic too small, no hour too late."
        ),
        QuickResponse(
            emoji: "🌟",
            shortText: "You've got this",
            fullMessage: "Just a reminder that you're stronger than you know. I believe in you!"
        )
    ]
}

// MARK: - Supporting Types

struct CheckInSession {
    let id = UUID()
    let startedAt = Date()
    var currentStep: CheckInStep = .welcome
    var hasBestFriend: Bool
    var bestFriendName: String?
    var notifyFriend: Bool = false
    var selectedPromptResponse: String?
    var gratitudeResponse: String?
}

enum CheckInStep: Int, CaseIterable {
    case welcome = 0
    case acknowledgment = 1
    case friendNotice = 2  // Only shown if has best friend
    case reflection = 3
    case gratitude = 4
    case closing = 5
    
    var title: String {
        switch self {
        case .welcome: return "Hey there"
        case .acknowledgment: return "It's okay"
        case .friendNotice: return "Your people"
        case .reflection: return "A moment to reflect"
        case .gratitude: return "Finding light"
        case .closing: return "You matter"
        }
    }
}

struct QuickResponse: Identifiable {
    let id = UUID()
    let emoji: String
    let shortText: String
    let fullMessage: String
}
