//
//  FriendBubble.swift
//  SocialTen
//

import SwiftUI

struct FriendBubble: View {
    let friend: User
    @State private var glowAnimation = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Get the friend's theme glow color if they're premium, otherwise use current user's theme
    var bubbleColor: Color {
        friend.isPremium ? friend.selectedTheme.glowColor : themeManager.colors.accent2
    }
    
    var bubbleBackground: Color {
        friend.isPremium ? friend.selectedTheme.colors.cardBackground : themeManager.colors.cardBackground
    }
    
    var body: some View {
        VStack(spacing: themeManager.spacing.sm) {
            ZStack {
                // Premium glow ring (only for premium friends)
                if friend.isPremium {
                    Circle()
                        .fill(bubbleColor)
                        .frame(width: 64, height: 64)
                        .blur(radius: glowAnimation ? 10 : 6)
                        .opacity(glowAnimation ? 0.5 : 0.3)
                    
                    Circle()
                        .stroke(bubbleColor.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 60, height: 60)
                }
                
                Circle()
                    .fill(bubbleBackground)
                    .frame(width: 56, height: 56)
                
                if let rating = friend.todayRating {
                    Text("\(rating)")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(bubbleColor)
                } else {
                    Text(String(friend.displayName.prefix(1)).lowercased())
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(bubbleColor.opacity(0.7))
                }
            }
            
            HStack(spacing: 2) {
                Text(friend.displayName.lowercased())
                    .font(themeManager.fonts.small)
                    .foregroundColor(themeManager.colors.textTertiary)
                    .lineLimit(1)
                
                if friend.isPremium {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(bubbleColor)
                }
            }
            .frame(width: 64)
        }
        .onAppear {
            if friend.isPremium {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowAnimation = true
                }
            }
        }
    }
}

#Preview {
    HStack {
        FriendBubble(friend: User(
            id: "1",
            username: "test",
            displayName: "Test",
            bio: "",
            todayRating: 8
        ))
        
        FriendBubble(friend: User(
            id: "2",
            username: "premium",
            displayName: "Premium",
            bio: "",
            todayRating: 9,
            premiumExpiresAt: Date().addingTimeInterval(86400 * 30),
            selectedThemeId: "ocean"
        ))
    }
    .padding()
    .background(Color.black)
}
