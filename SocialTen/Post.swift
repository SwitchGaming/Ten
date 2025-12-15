//
//  Post.swift
//  SocialTen
//

import SwiftUI

struct Post: Identifiable, Codable {
    let id: String
    let userId: String
    let timestamp: Date
    var imageData: Data?
    var caption: String?
    var plusOnes: [PlusOne]
    var replies: [Reply]
    var promptResponse: String?
    var promptId: String?
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        timestamp: Date = Date(),
        imageData: Data? = nil,
        caption: String? = nil,
        plusOnes: [PlusOne] = [],
        replies: [Reply] = [],
        promptResponse: String? = nil,
        promptId: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.timestamp = timestamp
        self.imageData = imageData
        self.caption = caption
        self.plusOnes = plusOnes
        self.replies = replies
        self.promptResponse = promptResponse
        self.promptId = promptId
    }
    
    var hasContent: Bool {
        imageData != nil || (caption != nil && !caption!.isEmpty)
    }
    
    var plusOneCount: Int {
        plusOnes.count
    }
    
    var replyCount: Int {
        replies.count
    }
}

// +1 reaction (like)
struct PlusOne: Identifiable, Codable {
    let id: String
    let userId: String
    let timestamp: Date
    
    init(id: String = UUID().uuidString, userId: String, timestamp: Date = Date()) {
        self.id = id
        self.userId = userId
        self.timestamp = timestamp
    }
}

// Reply/thread
struct Reply: Identifiable, Codable {
    let id: String
    let userId: String
    let text: String
    let timestamp: Date
    
    init(id: String = UUID().uuidString, userId: String, text: String, timestamp: Date = Date()) {
        self.id = id
        self.userId = userId
        self.text = text
        self.timestamp = timestamp
    }
}
