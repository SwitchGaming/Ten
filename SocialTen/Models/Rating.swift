//
//  Rating.swift
//  SocialTen
//
//  Created on 12/3/25.
//

import Foundation

struct Rating: Identifiable, Codable {
    let id: String
    let userId: String
    let value: Int // 1-10
    let date: Date
    var note: String?
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        value: Int,
        date: Date = Date(),
        note: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.value = max(1, min(10, value)) // Clamp between 1-10
        self.date = date
        self.note = note
    }
}

extension Rating {
    var emoji: String {
        switch value {
        case 1: return "😢"
        case 2: return "😞"
        case 3: return "😔"
        case 4: return "😐"
        case 5: return "🙂"
        case 6: return "😊"
        case 7: return "😄"
        case 8: return "😁"
        case 9: return "🤩"
        case 10: return "🥳"
        default: return "🙂"
        }
    }
    
    var colorName: String {
        switch value {
        case 1...3: return "red"
        case 4...5: return "orange"
        case 6...7: return "yellow"
        case 8...9: return "green"
        case 10: return "mint"
        default: return "gray"
        }
    }
}
