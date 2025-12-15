//
//  User.swift
//  SocialTen
//
//  Created on 12/3/25.
//

import SwiftUI

struct User: Identifiable, Codable {
    let id: String
    var username: String
    var displayName: String
    var bio: String
    var profileImageURL: String?
    var todayRating: Int?
    var ratingTimestamp: Date?
    var profileCustomization: ProfileCustomization
    var friendIds: [String]
    
    init(
        id: String = UUID().uuidString,
        username: String,
        displayName: String,
        bio: String = "",
        profileImageURL: String? = nil,
        todayRating: Int? = nil,
        ratingTimestamp: Date? = nil,
        profileCustomization: ProfileCustomization = ProfileCustomization(),
        friendIds: [String] = []
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.bio = bio
        self.profileImageURL = profileImageURL
        self.todayRating = todayRating
        self.ratingTimestamp = ratingTimestamp
        self.profileCustomization = profileCustomization
        self.friendIds = friendIds
    }
}

struct ProfileCustomization: Codable {
    var glowColor: CodableColor
    var glowIntensity: Double
    var glassOpacity: Double
    var shadowIntensity: Double
    var showGlow: Bool
    var profileLayout: ProfileLayout
    
    init(
        glowColor: CodableColor = CodableColor(color: .white),
        glowIntensity: Double = 0.3,
        glassOpacity: Double = 0.08,
        shadowIntensity: Double = 0.5,
        showGlow: Bool = true,
        profileLayout: ProfileLayout = .minimal
    ) {
        self.glowColor = glowColor
        self.glowIntensity = glowIntensity
        self.glassOpacity = glassOpacity
        self.shadowIntensity = shadowIntensity
        self.showGlow = showGlow
        self.profileLayout = profileLayout
    }
}

enum ProfileLayout: String, Codable, CaseIterable {
    case minimal = "Minimal"
    case glass = "Glass"
    case shadow = "Shadow"
}

// Codable Color wrapper
struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double
    
    init(color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.opacity = Double(a)
    }
    
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

// Preset glow colors for customization
enum GlowPreset: String, CaseIterable {
    case white = "White"
    case cyan = "Cyan"
    case purple = "Purple"
    case blue = "Blue"
    case green = "Green"
    case orange = "Orange"
    case pink = "Pink"
    
    var color: Color {
        switch self {
        case .white: return .white
        case .cyan: return Color(red: 0.4, green: 0.9, blue: 1.0)
        case .purple: return Color(red: 0.6, green: 0.4, blue: 1.0)
        case .blue: return Color(red: 0.3, green: 0.5, blue: 1.0)
        case .green: return Color(red: 0.4, green: 1.0, blue: 0.6)
        case .orange: return Color(red: 1.0, green: 0.6, blue: 0.3)
        case .pink: return Color(red: 1.0, green: 0.4, blue: 0.6)
        }
    }
}
