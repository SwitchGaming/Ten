//
//  FriendGroup.swift
//  SocialTen
//
//  Model for friend groups
//

import Foundation

// MARK: - Friend Group Model

struct FriendGroup: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let emoji: String
    let created_at: String?
    let members: [GroupMember]
    
    var memberCount: Int { members.count }
    
    var displayName: String {
        "\(emoji) \(name)"
    }
    
    static func == (lhs: FriendGroup, rhs: FriendGroup) -> Bool {
        lhs.id == rhs.id
    }
}

struct GroupMember: Codable, Identifiable, Equatable {
    let id: UUID
    let username: String
    let display_name: String
    
    static func == (lhs: GroupMember, rhs: GroupMember) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Group Limit Info

struct GroupLimitInfo: Codable {
    let current_count: Int
    let max_groups: Int
    let is_premium: Bool
    let can_create: Bool
}

// MARK: - Group for Picker (simplified)

struct GroupPickerItem: Identifiable, Equatable {
    let id: UUID?
    let name: String
    let emoji: String
    let memberCount: Int
    
    var isAllFriends: Bool { id == nil }
    
    var displayName: String {
        isAllFriends ? "all friends" : "\(emoji) \(name)"
    }
    
    static let allFriends = GroupPickerItem(id: nil, name: "all friends", emoji: "👥", memberCount: 0)
    
    init(id: UUID?, name: String, emoji: String, memberCount: Int) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.memberCount = memberCount
    }
    
    init(from group: FriendGroup) {
        self.id = group.id
        self.name = group.name
        self.emoji = group.emoji
        self.memberCount = group.memberCount
    }
}
