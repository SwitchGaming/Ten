//
//  DatabaseModels.swift
//  SocialTen
//

import Foundation

// MARK: - Database User Model
struct DBUser: Codable, Identifiable {
    let id: UUID?
    let username: String
    let displayName: String
    let bio: String
    let todayRating: Int?
    let ratingTimestamp: Date?
    let createdAt: Date?
    let authId: UUID?
    let premiumExpiresAt: Date?
    let selectedThemeId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case bio
        case todayRating = "today_rating"
        case ratingTimestamp = "rating_timestamp"
        case createdAt = "created_at"
        case authId = "auth_id"
        case premiumExpiresAt = "premium_expires_at"
        case selectedThemeId = "selected_theme_id"
    }
}

// MARK: - Database Vibe Model
struct DBVibe: Codable, Identifiable {
    let id: UUID?
    let userId: UUID
    let title: String
    let timeDescription: String
    let location: String
    let timestamp: Date?
    let expiresAt: Date
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case timeDescription = "time_description"
        case location
        case timestamp
        case expiresAt = "expires_at"
        case isActive = "is_active"
    }
}

// MARK: - Database Vibe Response Model
struct DBVibeResponse: Codable, Identifiable {
    let id: UUID?
    let vibeId: UUID
    let userId: UUID
    let response: String
    let timestamp: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case vibeId = "vibe_id"
        case userId = "user_id"
        case response
        case timestamp
    }
}

// MARK: - Database Post Model
struct DBPost: Codable, Identifiable {
    let id: UUID?
    let userId: UUID
    let imageUrl: String?
    let caption: String?
    let promptResponse: String?
    let promptId: String?
    let promptText: String?
    let timestamp: Date?
    let rating: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case imageUrl = "image_url"
        case caption
        case promptResponse = "prompt_response"
        case promptId = "prompt_id"
        case promptText = "prompt_text"
        case timestamp
        case rating
    }
}

// MARK: - Database Post Like Model
struct DBPostLike: Codable, Identifiable {
    let id: UUID?
    let postId: UUID
    let userId: UUID
    let timestamp: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case timestamp
    }
}

// MARK: - Database Post Reply Model
struct DBPostReply: Codable, Identifiable {
    let id: UUID?
    let postId: UUID
    let userId: UUID
    let text: String
    let timestamp: Date?
    var authorName: String?
    var authorUsername: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case text
        case timestamp
        case authorName = "author_name"
        case authorUsername = "author_username"
    }
}

// MARK: - Database Post Reply With Author (for joined queries)
struct DBPostReplyWithAuthor: Codable, Identifiable {
    let id: UUID?
    let postId: UUID
    let userId: UUID
    let text: String
    let timestamp: Date?
    let users: ReplyAuthor?
    
    struct ReplyAuthor: Codable {
        let displayName: String
        let username: String
        
        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case username
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case text
        case timestamp
        case users
    }
    
    func toDBPostReply() -> DBPostReply {
        var reply = DBPostReply(
            id: id,
            postId: postId,
            userId: userId,
            text: text,
            timestamp: timestamp,
            authorName: users?.displayName,
            authorUsername: users?.username
        )
        return reply
    }
}

// MARK: - Database Friend Request Model
struct DBFriendRequest: Codable, Identifiable {
    let id: UUID?
    let fromUserId: UUID
    let toUserId: UUID
    let status: String
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case status
        case createdAt = "created_at"
    }
}

// MARK: - Database Friendship Model
struct DBFriendship: Codable, Identifiable {
    let id: UUID?
    let userId: UUID
    let friendId: UUID
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case friendId = "friend_id"
        case createdAt = "created_at"
    }
}

// MARK: - Database Rating History Model
struct DBRatingHistory: Codable, Identifiable {
    let id: UUID?
    let userId: UUID
    let rating: Int
    let date: Date
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case rating
        case date
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        rating = try container.decode(Int.self, forKey: .rating)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        
        // Handle date - could be ISO8601 or simple date string
        if let dateValue = try? container.decode(Date.self, forKey: .date) {
            date = dateValue
        } else if let dateString = try? container.decode(String.self, forKey: .date) {
            // Try simple date format first (2026-01-10)
            let simpleFormatter = DateFormatter()
            simpleFormatter.dateFormat = "yyyy-MM-dd"
            if let parsedDate = simpleFormatter.date(from: dateString) {
                date = parsedDate
            } else {
                // Try ISO8601
                let isoFormatter = ISO8601DateFormatter()
                if let parsedDate = isoFormatter.date(from: dateString) {
                    date = parsedDate
                } else {
                    throw DecodingError.dataCorruptedError(forKey: .date, in: container, debugDescription: "Unable to parse date: \(dateString)")
                }
            }
        } else {
            throw DecodingError.dataCorruptedError(forKey: .date, in: container, debugDescription: "Date field missing or invalid")
        }
    }
}

// MARK: - Database Daily Prompt Model
struct DBDailyPrompt: Codable, Identifiable {
    let id: UUID?
    let text: String
    let date: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case date
    }
}

// MARK: - Simple ID-only models for counting queries

struct DBIdOnly: Codable {
    let id: UUID
}

struct DBDateOnly: Codable {
    let date: Date
}

struct DBCreatedAtOnly: Codable {
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
    }
}

// MARK: - In-App Notification Model

struct InAppNotification: Codable, Identifiable {
    let id: UUID
    let recipientId: UUID
    let senderId: UUID
    let senderName: String
    let type: String
    let message: String?
    let data: [String: String]?  // Extra data like conversation_id
    var isRead: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case recipientId = "recipient_id"
        case senderId = "sender_id"
        case senderName = "sender_name"
        case type
        case message
        case data
        case isRead = "is_read"
        case createdAt = "created_at"
    }
    
    var isCheckInAlert: Bool {
        type == "check_in_alert"
    }
    
    var conversationId: String? {
        data?["conversation_id"]
    }
}
