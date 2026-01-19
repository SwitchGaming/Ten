//
//  Post.swift
//  SocialTen
//

import Foundation

struct Post: Identifiable, Codable {
    let id: String
    let userId: String
    var imageData: Data?
    var imageUrl: String?
    var caption: String?
    var plusOnes: [PlusOne]
    var replies: [Reply]
    let timestamp: Date
    var promptResponse: String?
    var promptId: String?
    var promptText: String?  // The actual prompt text at time of post
    var rating: Int?  // Rating at time of post creation
    var groupId: String?  // Target group (nil = all friends)
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        imageData: Data? = nil,
        imageUrl: String? = nil,
        caption: String? = nil,
        plusOnes: [PlusOne] = [],
        replies: [Reply] = [],
        timestamp: Date = Date(),
        promptResponse: String? = nil,
        promptId: String? = nil,
        promptText: String? = nil,
        rating: Int? = nil,
        groupId: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.imageData = imageData
        self.imageUrl = imageUrl
        self.caption = caption
        self.plusOnes = plusOnes
        self.replies = replies
        self.timestamp = timestamp
        self.promptResponse = promptResponse
        self.promptId = promptId
        self.promptText = promptText
        self.rating = rating
        self.groupId = groupId
    }
    
    var plusOneCount: Int {
        plusOnes.count
    }
    
    var replyCount: Int {
        replies.count
    }
}

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
