//
//  ThemeManager.swift
//  SocialTen
//

import SwiftUI

// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: AppTheme = .default
    
    var colors: ThemeColors {
        currentTheme.colors
    }
    
    var fonts: ThemeFonts {
        ThemeFonts()
    }
    
    var spacing: ThemeSpacing {
        ThemeSpacing()
    }
    
    var radius: ThemeRadius {
        ThemeRadius()
    }
    
    var letterSpacing: ThemeLetterSpacing {
        ThemeLetterSpacing()
    }
    
    var animation: ThemeAnimation {
        ThemeAnimation()
    }
    
    private init() {}
    
    func setTheme(_ theme: AppTheme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTheme = theme
        }
    }
}

// MARK: - App Theme

struct AppTheme: Identifiable {
    let id: String
    let name: String
    let description: String
    let colors: ThemeColors
    let isPremium: Bool
    let glowColor: Color
    
    static func == (lhs: AppTheme, rhs: AppTheme) -> Bool {
        lhs.id == rhs.id
    }
    
    static let `default` = AppTheme(
        id: "default",
        name: "Midnight",
        description: "Classic elegance",
        colors: ThemeColors(
            background: Color(hex: "0A0A0A"),
            cardBackground: Color(hex: "141414"),
            surfaceLight: Color(hex: "1C1C1E"),
            accent1: Color.white,
            accent2: Color(hex: "8B5CF6"),
            accent3: Color(hex: "3F3F46"),
            textPrimary: Color.white,
            textSecondary: Color(hex: "A1A1AA"),
            textTertiary: Color(hex: "52525B")
        ),
        isPremium: false,
        glowColor: Color(hex: "8B5CF6")
    )
    
    // Premium themes for ten+
    static let ocean = AppTheme(
        id: "ocean",
        name: "Ocean",
        description: "Deep blue serenity",
        colors: ThemeColors(
            background: Color(hex: "0A1628"),
            cardBackground: Color(hex: "132035"),
            surfaceLight: Color(hex: "1E3A5F"),
            accent1: Color(hex: "38BDF8"),
            accent2: Color(hex: "0EA5E9"),
            accent3: Color(hex: "1E3A5F"),
            textPrimary: Color.white,
            textSecondary: Color(hex: "94A3B8"),
            textTertiary: Color(hex: "64748B")
        ),
        isPremium: true,
        glowColor: Color(hex: "38BDF8")
    )
    
    static let forest = AppTheme(
        id: "forest",
        name: "Forest",
        description: "Nature's calm",
        colors: ThemeColors(
            background: Color(hex: "0A1410"),
            cardBackground: Color(hex: "132016"),
            surfaceLight: Color(hex: "1A3020"),
            accent1: Color(hex: "4ADE80"),
            accent2: Color(hex: "22C55E"),
            accent3: Color(hex: "1A3020"),
            textPrimary: Color.white,
            textSecondary: Color(hex: "A1CAAB"),
            textTertiary: Color(hex: "6B8B73")
        ),
        isPremium: true,
        glowColor: Color(hex: "4ADE80")
    )
    
    static let sunset = AppTheme(
        id: "sunset",
        name: "Sunset",
        description: "Golden warmth",
        colors: ThemeColors(
            background: Color(hex: "1A0A0A"),
            cardBackground: Color(hex: "251414"),
            surfaceLight: Color(hex: "351E1E"),
            accent1: Color(hex: "FB923C"),
            accent2: Color(hex: "F97316"),
            accent3: Color(hex: "351E1E"),
            textPrimary: Color.white,
            textSecondary: Color(hex: "CAAB9A"),
            textTertiary: Color(hex: "8B7165")
        ),
        isPremium: true,
        glowColor: Color(hex: "FB923C")
    )
    
    static let aurora = AppTheme(
        id: "aurora",
        name: "Aurora",
        description: "Northern lights",
        colors: ThemeColors(
            background: Color(hex: "050814"),
            cardBackground: Color(hex: "0c1220"),
            surfaceLight: Color(hex: "12192d"),
            accent1: Color(hex: "5EEAD4"),
            accent2: Color(hex: "34D399"),
            accent3: Color(hex: "12192d"),
            textPrimary: Color.white,
            textSecondary: Color(hex: "99F6E4"),
            textTertiary: Color(hex: "5EEAD4").opacity(0.5)
        ),
        isPremium: true,
        glowColor: Color(hex: "5EEAD4")
    )
    
    static let rose = AppTheme(
        id: "rose",
        name: "Blossom",
        description: "Cherry bloom",
        colors: ThemeColors(
            background: Color(hex: "0d0a0c"),
            cardBackground: Color(hex: "1a1318"),
            surfaceLight: Color(hex: "261c22"),
            accent1: Color(hex: "F9A8D4"),
            accent2: Color(hex: "EC4899"),
            accent3: Color(hex: "261c22"),
            textPrimary: Color.white,
            textSecondary: Color(hex: "FBCFE8"),
            textTertiary: Color(hex: "F472B6").opacity(0.5)
        ),
        isPremium: true,
        glowColor: Color(hex: "F472B6")
    )
    
    static let allThemes: [AppTheme] = [.default, .ocean, .forest, .sunset, .aurora, .rose]
    static let premiumThemes: [AppTheme] = [.ocean, .forest, .sunset, .aurora, .rose]
}

// MARK: - Theme Colors

struct ThemeColors {
    let background: Color
    let cardBackground: Color
    let surfaceLight: Color
    let accent1: Color
    let accent2: Color
    let accent3: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
}

// MARK: - Theme Fonts

struct ThemeFonts {
    let largeTitle: Font = .system(size: 28, weight: .light)
    let title: Font = .system(size: 20, weight: .light)
    let headline: Font = .system(size: 17, weight: .medium)
    let body: Font = .system(size: 15, weight: .regular)
    let caption: Font = .system(size: 13, weight: .regular)
    let small: Font = .system(size: 11, weight: .regular)
    
    // Number display fonts
    let ratingLarge: Font = .system(size: 120, weight: .ultraLight)
    let ratingMedium: Font = .system(size: 72, weight: .ultraLight)
    let ratingSmall: Font = .system(size: 32, weight: .light)
}

// MARK: - Theme Spacing

struct ThemeSpacing {
    let xxs: CGFloat = 2
    let xs: CGFloat = 4
    let sm: CGFloat = 8
    let md: CGFloat = 16
    let lg: CGFloat = 24
    let xl: CGFloat = 32
    let xxl: CGFloat = 48
    
    let screenHorizontal: CGFloat = 20
    let cardPadding: CGFloat = 20
}

// MARK: - Theme Radius

struct ThemeRadius {
    let sm: CGFloat = 8
    let md: CGFloat = 12
    let lg: CGFloat = 16
    let xl: CGFloat = 24
    let full: CGFloat = 9999
}

// MARK: - Theme Letter Spacing

struct ThemeLetterSpacing {
    let tight: CGFloat = -0.5
    let normal: CGFloat = 0
    let wide: CGFloat = 2
    let wider: CGFloat = 4
    let widest: CGFloat = 8
}

// MARK: - Theme Animation

struct ThemeAnimation {
    let fast: Animation = .easeOut(duration: 0.15)
    let normal: Animation = .easeInOut(duration: 0.25)
    let slow: Animation = .easeInOut(duration: 0.4)
    let spring: Animation = .spring(response: 0.35, dampingFraction: 0.8)
    let springBouncy: Animation = .spring(response: 0.4, dampingFraction: 0.6)
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Haptic Feedback

enum HapticType {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
    case selection
}

func haptic(_ type: HapticType) {
    switch type {
    case .light:
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    case .medium:
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    case .heavy:
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    case .success:
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    case .warning:
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    case .error:
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    case .selection:
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
