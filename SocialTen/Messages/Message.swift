//
//  Message.swift
//  SocialTen
//

import Foundation

// MARK: - Message Status

enum MessageStatus: String, Codable, CaseIterable {
    case sent
    case delivered
    case read
}

// MARK: - Reaction Models

struct DBReaction: Codable, Identifiable {
    let id: UUID?
    let messageId: UUID
    let userId: UUID
    let emoji: String
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case messageId = "message_id"
        case userId = "user_id"
        case emoji
        case createdAt = "created_at"
    }
}

struct Reaction: Identifiable, Equatable {
    let id: String
    let messageId: String
    let userId: String
    let emoji: String
    let createdAt: Date
    
    init(from dbReaction: DBReaction) {
        self.id = dbReaction.id?.uuidString ?? UUID().uuidString
        self.messageId = dbReaction.messageId.uuidString
        self.userId = dbReaction.userId.uuidString
        self.emoji = dbReaction.emoji
        self.createdAt = dbReaction.createdAt ?? Date()
    }
    
    init(id: String, messageId: String, userId: String, emoji: String, createdAt: Date = Date()) {
        self.id = id
        self.messageId = messageId
        self.userId = userId
        self.emoji = emoji
        self.createdAt = createdAt
    }
}

// MARK: - Database Models

struct DBConversation: Codable, Identifiable {
    let id: UUID?
    let participantIds: [UUID]
    let lastMessagePreview: String?
    let lastMessageSenderId: UUID?
    let lastMessageAt: Date?
    let updatedAt: Date?
    let unreadCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case participantIds = "participant_ids"
        case lastMessagePreview = "last_message_preview"
        case lastMessageSenderId = "last_message_sender_id"
        case lastMessageAt = "last_message_at"
        case updatedAt = "updated_at"
        case unreadCount = "unread_count"
    }
}

struct DBMessage: Codable, Identifiable {
    let id: UUID?
    let conversationId: UUID
    let senderId: UUID
    let content: String
    let status: String
    let createdAt: Date?
    let readAt: Date?
    let replyToId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case content
        case status
        case createdAt = "created_at"
        case readAt = "read_at"
        case replyToId = "reply_to_id"
    }
}

// MARK: - Send Message Response

struct SendMessageResponse: Codable {
    let messageId: UUID
    let conversationId: UUID
    let senderId: UUID
    let content: String
    let status: String
    let createdAt: Date
    let replyToId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case content
        case status
        case createdAt = "created_at"
        case replyToId = "reply_to_id"
    }
}

// MARK: - Toggle Reaction Response

struct ToggleReactionResponse: Codable {
    let action: String
    let reactionId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case action
        case reactionId = "reaction_id"
    }
}

// MARK: - Local Models (for UI)

struct Conversation: Identifiable {
    let id: String
    let participantIds: [String]
    var lastMessagePreview: String?
    var lastMessageSenderId: String?
    var lastMessageAt: Date?
    var updatedAt: Date?
    var unreadCount: Int
    
    // Computed property to get the other participant's ID
    func otherParticipantId(currentUserId: String) -> String? {
        participantIds.first { $0 != currentUserId }
    }
    
    init(from dbConversation: DBConversation) {
        self.id = dbConversation.id?.uuidString ?? UUID().uuidString
        self.participantIds = dbConversation.participantIds.map { $0.uuidString }
        self.lastMessagePreview = dbConversation.lastMessagePreview
        self.lastMessageSenderId = dbConversation.lastMessageSenderId?.uuidString
        self.lastMessageAt = dbConversation.lastMessageAt
        self.updatedAt = dbConversation.updatedAt
        self.unreadCount = dbConversation.unreadCount ?? 0
    }
    
    init(id: String, participantIds: [String], lastMessagePreview: String? = nil, 
         lastMessageSenderId: String? = nil, lastMessageAt: Date? = nil,
         updatedAt: Date? = nil, unreadCount: Int = 0) {
        self.id = id
        self.participantIds = participantIds
        self.lastMessagePreview = lastMessagePreview
        self.lastMessageSenderId = lastMessageSenderId
        self.lastMessageAt = lastMessageAt
        self.updatedAt = updatedAt
        self.unreadCount = unreadCount
    }
}

struct Message: Identifiable, Equatable {
    let id: String
    let conversationId: String
    let senderId: String
    let content: String
    var status: MessageStatus
    let createdAt: Date
    var readAt: Date?
    let replyToId: String?
    
    // For optimistic updates
    var isOptimistic: Bool = false
    
    init(from dbMessage: DBMessage) {
        self.id = dbMessage.id?.uuidString ?? UUID().uuidString
        self.conversationId = dbMessage.conversationId.uuidString
        self.senderId = dbMessage.senderId.uuidString
        self.content = dbMessage.content
        self.status = MessageStatus(rawValue: dbMessage.status) ?? .sent
        self.createdAt = dbMessage.createdAt ?? Date()
        self.readAt = dbMessage.readAt
        self.replyToId = dbMessage.replyToId?.uuidString
        self.isOptimistic = false
    }
    
    init(from response: SendMessageResponse) {
        self.id = response.messageId.uuidString
        self.conversationId = response.conversationId.uuidString
        self.senderId = response.senderId.uuidString
        self.content = response.content
        self.status = MessageStatus(rawValue: response.status) ?? .sent
        self.createdAt = response.createdAt
        self.readAt = nil
        self.replyToId = response.replyToId?.uuidString
        self.isOptimistic = false
    }
    
    init(id: String, conversationId: String, senderId: String, content: String,
         status: MessageStatus = .sent, createdAt: Date = Date(), 
         readAt: Date? = nil, replyToId: String? = nil, isOptimistic: Bool = false) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.content = content
        self.status = status
        self.createdAt = createdAt
        self.readAt = readAt
        self.replyToId = replyToId
        self.isOptimistic = isOptimistic
    }
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status
    }
}
