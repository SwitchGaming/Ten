//
//  FriendBubble.swift
//  SocialTen
//

import SwiftUI

struct FriendBubble: View {
    let friend: User
    
    var body: some View {
        VStack(spacing: ThemeManager.shared.spacing.sm) {
            ZStack {
                Circle()
                    .fill(ThemeManager.shared.colors.cardBackground)
                    .frame(width: 56, height: 56)
                
                if let rating = friend.todayRating {
                    Text("\(rating)")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                } else {
                    Text(String(friend.displayName.prefix(1)).lowercased())
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                }
            }
            
            Text(friend.displayName.lowercased())
                .font(ThemeManager.shared.fonts.small)
                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                .lineLimit(1)
                .frame(width: 56)
        }
    }
}

#Preview {
    FriendBubble(friend: User(
        id: "1",
        username: "test",
        displayName: "Test User",
        bio: "",
        todayRating: 8
    ))
    .padding()
    .background(Color.black)
}
