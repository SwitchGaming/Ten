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

