//
//  DepthCard.swift
//  SocialTen
//

import SwiftUI

struct DepthCard<Content: View>: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let depth: DepthLevel
    let content: Content
    
    enum DepthLevel {
        case low
        case medium
        case high
        
        var shadowRadius: CGFloat {
            switch self {
            case .low: return 8
            case .medium: return 16
            case .high: return 24
            }
        }
        
        var shadowOpacity: Double {
            switch self {
            case .low: return 0.15
            case .medium: return 0.25
            case .high: return 0.35
            }
        }
        
        var shadowY: CGFloat {
            switch self {
            case .low: return 4
            case .medium: return 8
            case .high: return 12
            }
        }
    }
    
    init(depth: DepthLevel = .medium, @ViewBuilder content: () -> Content) {
        self.depth = depth
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: themeManager.radius.lg)
                    .fill(themeManager.colors.cardBackground)
                    .shadow(
                        color: Color.black.opacity(depth.shadowOpacity),
                        radius: depth.shadowRadius,
                        x: 0,
                        y: depth.shadowY
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: themeManager.radius.lg)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    DepthCard {
        Text("Hello")
            .padding()
    }
    .padding()
    .background(Color.black)
}
