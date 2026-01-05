//
//  User.swift
//  SocialTen
//

import SwiftUI

struct User: Identifiable, Codable {
    let id: String
    let username: String
    var displayName: String
    var bio: String
    var todayRating: Int?
    var ratingTimestamp: Date?
    var friendIds: [String]
    var ratingHistory: [RatingEntry]
    
    // Dynamic friend limit based on premium status
    static var maxFriends: Int {
        PremiumManager.shared.friendLimit
    }
    
    init(
        id: String = UUID().uuidString,
        username: String,
        displayName: String,
        bio: String = "",
        todayRating: Int? = nil,
        ratingTimestamp: Date? = nil,
        friendIds: [String] = [],
        ratingHistory: [RatingEntry] = []
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.bio = bio
        self.todayRating = todayRating
        self.ratingTimestamp = ratingTimestamp
        self.friendIds = friendIds
        self.ratingHistory = ratingHistory
    }
    
    var canAddMoreFriends: Bool {
        friendIds.count < User.maxFriends
    }
}

struct RatingEntry: Identifiable, Codable {
    let id: String
    let rating: Int
    let date: Date
    
    init(id: String = UUID().uuidString, rating: Int, date: Date) {
        self.id = id
        self.rating = rating
        self.date = date
    }
}
