//
//  DailyPrompt.swift
//  SocialTen
//

import Foundation

struct DailyPrompt: Identifiable, Codable {
    let id: String
    let text: String
    let date: Date
    
    init(id: String = UUID().uuidString, text: String, date: Date = Date()) {
        self.id = id
        self.text = text
        self.date = date
    }
    
    static let prompts: [String] = [
        "one word for today?",
        "what made you smile?",
        "what's on your mind?",
        "highlight of the day?",
        "what are you grateful for?",
        "how are you really?",
        "what's your vibe?",
        "best moment today?",
        "what do you need right now?",
        "describe today in 3 words",
        "what surprised you?",
        "who made your day better?",
        "what's inspiring you?",
        "biggest win today?",
        "what would make tomorrow better?"
    ]
    
    static func todaysPrompt() -> DailyPrompt {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let promptIndex = dayOfYear % prompts.count
        return DailyPrompt(text: prompts[promptIndex])
    }
}
