//
//  Vibe.swift
//  SocialTen
//

import SwiftUI

struct Vibe: Identifiable, Codable {
    let id: String
    let userId: String
    let title: String
    let timeDescription: String
    let location: String
    let timestamp: Date
    var responses: [VibeResponse]
    var isActive: Bool
    var groupId: String?
    
    init(   
        id: String = UUID().uuidString,
        userId: String,
        title: String,
        timeDescription: String,
        location: String,
        timestamp: Date = Date(),
        responses: [VibeResponse] = [],
        isActive: Bool = true,
        groupId: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.timeDescription = timeDescription
        self.location = location
        self.timestamp = timestamp
        self.responses = responses
        self.isActive = isActive
        self.groupId = groupId
    }
    
    // Computed expiration date based on timeDescription
    var expiresAt: Date {
        switch timeDescription.lowercased() {
        case "now":
            return timestamp.addingTimeInterval(30 * 60) // 30 minutes
        case "in 5 min":
            return timestamp.addingTimeInterval(35 * 60) // 35 minutes
        case "in 15 min":
            return timestamp.addingTimeInterval(45 * 60) // 45 minutes
        case "in 30 min":
            return timestamp.addingTimeInterval(60 * 60) // 1 hour
        case "in 1 hr":
            return timestamp.addingTimeInterval(90 * 60) // 1.5 hours
        case "later":
            return timestamp.addingTimeInterval(4 * 60 * 60) // 4 hours
        default:
            return timestamp.addingTimeInterval(2 * 60 * 60) // Default 2 hours
        }
    }
    
    // Computed scheduled time (when the vibe is happening)
    var scheduledTime: Date {
        switch timeDescription.lowercased() {
        case "now":
            return timestamp // Happening now
        case "in 5 min":
            return timestamp.addingTimeInterval(5 * 60)
        case "in 15 min":
            return timestamp.addingTimeInterval(15 * 60)
        case "in 30 min":
            return timestamp.addingTimeInterval(30 * 60)
        case "in 1 hr":
            return timestamp.addingTimeInterval(60 * 60)
        case "later":
            return timestamp.addingTimeInterval(2 * 60 * 60)
        default:
            // For custom time descriptions like "at 3:00 PM", parse or use expiresAt - 30min
            return expiresAt.addingTimeInterval(-30 * 60)
        }
    }
    
    // User-friendly time display in viewer's local timezone
    var localTimeDisplay: String {
        let now = Date()
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        // If scheduled time is in the past or very close to now, show "now"
        if scheduledTime.timeIntervalSince(now) < 60 {
            return "now"
        }
        
        // Calculate minutes until scheduled time
        let minutesUntil = Int(scheduledTime.timeIntervalSince(now) / 60)
        
        // If less than 60 minutes away, show relative time
        if minutesUntil > 0 && minutesUntil < 60 {
            return "in \(minutesUntil) min"
        }
        
        // If less than 2 hours away, show relative time in hours/minutes
        if minutesUntil >= 60 && minutesUntil < 120 {
            let hours = minutesUntil / 60
            let mins = minutesUntil % 60
            if mins == 0 {
                return "in \(hours) hr"
            }
            return "in \(hours) hr \(mins) min"
        }
        
        // For times further out, show the actual time
        if calendar.isDateInToday(scheduledTime) {
            return "at \(formatter.string(from: scheduledTime))"
        } else if calendar.isDateInTomorrow(scheduledTime) {
            return "tomorrow at \(formatter.string(from: scheduledTime))"
        } else {
            formatter.dateFormat = "MMM d 'at' h:mm a"
            return formatter.string(from: scheduledTime).lowercased()
        }
    }
    
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    var yesCount: Int {
        responses.filter { $0.response == .yes }.count
    }
    
    var noCount: Int {
        responses.filter { $0.response == .no }.count
    }
}

struct VibeResponse: Identifiable, Codable {
    let id: String
    let userId: String
    let response: VibeResponseType
    let timestamp: Date
    
    init(id: String = UUID().uuidString, userId: String, response: VibeResponseType, timestamp: Date = Date()) {
        self.id = id
        self.userId = userId
        self.response = response
        self.timestamp = timestamp
    }
}

enum VibeResponseType: String, Codable {
    case yes
    case no
}

// Quick time presets for vibe creation
enum VibeTimePreset: String, CaseIterable {
    case in5 = "in 5 min"
    case in1hr = "in 1 hr"
    case custom = "choose a time"
}
