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
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        title: String,
        timeDescription: String,
        location: String,
        timestamp: Date = Date(),
        responses: [VibeResponse] = [],
        isActive: Bool = true
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.timeDescription = timeDescription
        self.location = location
        self.timestamp = timestamp
        self.responses = responses
        self.isActive = isActive
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
    
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    var yesCount: Int {
        responses.filter { $0.response == .yes }.count
    }
    
    var maybeCount: Int {
        responses.filter { $0.response == .maybe }.count
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
    case maybe
    case no
}

// Quick time presets for vibe creation
enum VibeTimePreset: String, CaseIterable {
    case now = "now"
    case in5 = "in 5 min"
    case in15 = "in 15 min"
    case in30 = "in 30 min"
    case in1hr = "in 1 hr"
    case later = "later"
}
