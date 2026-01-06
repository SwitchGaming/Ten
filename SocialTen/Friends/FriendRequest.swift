//
//  FriendRequest.swift
//  SocialTen
//

import Foundation

struct FriendRequest: Identifiable, Codable {
    let id: String
    let fromUserId: String
    let toUserId: String
    let timestamp: Date
    var status: RequestStatus
    
    init(
        id: String = UUID().uuidString,
        fromUserId: String,
        toUserId: String,
        timestamp: Date = Date(),
        status: RequestStatus = .pending
    ) {
        self.id = id
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.timestamp = timestamp
        self.status = status
    }
}

enum RequestStatus: String, Codable {
    case pending
    case accepted
    case declined
}
