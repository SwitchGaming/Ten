//
//  Theme.swift
//  SocialTen
//
//  Created on 12/3/25.
//

import SwiftUI

// MARK: - Shadow Theme

enum ShadowTheme {
    // Backgrounds
    static let background = Color(red: 0.04, green: 0.04, blue: 0.06)
    static let cardBackground = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let surfaceLight = Color(red: 0.12, green: 0.12, blue: 0.14)
    
    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.4)
}

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    var glowColor: Color
    var glowIntensity: Double
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(ShadowTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(glowColor.opacity(glowIntensity * 0.3), lineWidth: 1)
                    )
                    .shadow(color: glowColor.opacity(glowIntensity * 0.2), radius: 20, x: 0, y: 0)
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            )
    }
}

extension View {
    func glassCard(glowColor: Color = .white, glowIntensity: Double = 0.3) -> some View {
        self.modifier(GlassCardModifier(glowColor: glowColor, glowIntensity: glowIntensity))
    }
}
