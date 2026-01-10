//
//  BadgeViews.swift
//  SocialTen
//

import SwiftUI

// MARK: - Premium Badge Icon View

struct BadgeIconView: View {
    let badge: BadgeDefinition
    let isEarned: Bool
    let size: CGFloat
    
    @State private var isAnimating = false
    @State private var shimmerPhase: CGFloat = -1
    
    var body: some View {
        ZStack {
            // Ambient glow (earned only)
            if isEarned {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                badge.rarity.color.opacity(0.6),
                                badge.rarity.color.opacity(0.2),
                                .clear
                            ],
                            center: .center,
                            startRadius: size * 0.15,
                            endRadius: size * 0.85
                        )
                    )
                    .frame(width: size * 1.7, height: size * 1.7)
                    .blur(radius: 10)
                    .opacity(isAnimating ? 0.9 : 0.5)
            }
            
            // Outer ring shadow
            Circle()
                .fill(Color.black.opacity(0.5))
                .frame(width: size, height: size)
                .blur(radius: 5)
                .offset(y: 3)
            
            // Main badge circle with rich gradient
            Circle()
                .fill(
                    isEarned ?
                    LinearGradient(
                        stops: [
                            .init(color: badge.gradientColors[0], location: 0),
                            .init(color: badge.gradientColors[1], location: 0.5),
                            .init(color: badge.gradientColors[2], location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [Color(hex: "18181B"), Color(hex: "09090B")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Inner radial highlight for depth
            if isEarned {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.05),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.35, y: 0.35),
                            startRadius: 0,
                            endRadius: size * 0.6
                        )
                    )
                    .frame(width: size * 0.95, height: size * 0.95)
            }
            
            // Inner shadow ring for depth
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.4),
                            Color.clear,
                            Color.white.opacity(isEarned ? 0.15 : 0.03)
                        ],
                        startPoint: .bottomTrailing,
                        endPoint: .topLeading
                    ),
                    lineWidth: size * 0.06
                )
                .frame(width: size * 0.9, height: size * 0.9)
            
            // Top highlight arc
            if isEarned {
                Circle()
                    .trim(from: 0, to: 0.35)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.15),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: size * 0.025, lineCap: .round)
                    )
                    .frame(width: size * 0.82, height: size * 0.82)
                    .rotationEffect(.degrees(-130))
            }
            
            // Shimmer effect for legendary badges
            if isEarned && badge.rarity == .legendary {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * 0.9, height: size * 0.9)
                    .mask(
                        Rectangle()
                            .frame(width: size * 0.3, height: size * 1.5)
                            .offset(x: shimmerPhase * size)
                    )
            }
            
            // Icon with shadow
            ZStack {
                // Icon shadow
                Image(systemName: badge.icon)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundColor(.black.opacity(0.35))
                    .offset(y: 1.5)
                
                // Main icon
                Image(systemName: badge.icon)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(
                        isEarned ?
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        ) :
                        LinearGradient(
                            colors: [Color(hex: "27272A"), Color(hex: "27272A")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(isEarned ? 0.2 : 0), radius: 2, y: 1)
            }
        }
        .onAppear {
            if isEarned {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
                
                // Shimmer for legendary
                if badge.rarity == .legendary {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                        shimmerPhase = 1
                    }
                }
            }
        }
    }
}

// MARK: - Badge Tooltip View

struct BadgeTooltipView: View {
    let badge: BadgeDefinition
    let isEarned: Bool
    let earnedDate: Date?
    let onDismiss: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 28) {
            // Badge icon (large)
            BadgeIconView(badge: badge, isEarned: isEarned, size: 110)
                .scaleEffect(isAnimating ? 1.02 : 1.0)
            
            // Badge name
            Text(badge.name)
                .font(.system(size: 24, weight: .light))
                .tracking(3)
                .foregroundColor(.white)
            
            // Description
            Text(badge.description)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.white.opacity(0.5))
            
            // Rarity pill
            HStack(spacing: 8) {
                Circle()
                    .fill(badge.rarity.color)
                    .frame(width: 6, height: 6)
                    .shadow(color: badge.rarity.color.opacity(0.5), radius: 4)
                
                Text(badge.rarity.displayName.lowercased())
                    .font(.system(size: 11, weight: .medium))
                    .tracking(2)
                    .foregroundColor(badge.rarity.color)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(badge.rarity.color.opacity(0.08))
            )
            
            if isEarned, let date = earnedDate {
                VStack(spacing: 8) {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                        .padding(.vertical, 4)
                    
                    Text("earned \(formatDate(date))")
                        .font(.system(size: 11, weight: .light))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.35))
                    
                    Text(badge.rarity.percentile)
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1)
                        .foregroundColor(badge.rarity.color.opacity(0.6))
                }
            } else if !isEarned {
                VStack(spacing: 8) {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                        .padding(.vertical, 4)
                    
                    HStack(spacing: 5) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                        Text("locked")
                            .tracking(2)
                    }
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(.white.opacity(0.25))
                }
            }
        }
        .padding(32)
        .background(
            ZStack {
                // Frosted glass background
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                
                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.05),
                                Color.clear,
                                badge.rarity.color.opacity(isEarned ? 0.03 : 0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Border
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
        .onTapGesture {
            onDismiss()
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date).lowercased()
    }
}

// MARK: - Premium Badge Toast (bottom notification)

struct BadgeToastNotification: View {
    let badge: BadgeDefinition
    @Binding var isVisible: Bool
    
    @State private var opacity: Double = 0
    @State private var offset: CGFloat = 30
    
    var body: some View {
        HStack(spacing: 14) {
            // Mini badge icon
            BadgeIconView(badge: badge, isEarned: true, size: 36)
            
            // Info
            VStack(alignment: .leading, spacing: 3) {
                // Badge label
                Text("badge")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.5)
                    .foregroundColor(badge.rarity.color.opacity(0.8))
                    .textCase(.uppercase)
                
                // Badge name
                Text(badge.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                // Rarity + percentile
                Text("\(badge.rarity.displayName.lowercased()) · \(badge.rarity.percentile)")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.white.opacity(0.45))
            }
            
            Spacer()
        }
        .padding(.leading, 14)
        .padding(.trailing, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "1A1A1A").opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [badge.rarity.color.opacity(0.3), badge.rarity.color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.4), radius: 20, y: 8)
        )
        .padding(.horizontal, 24)
        .opacity(opacity)
        .offset(y: offset)
        .onAppear {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                opacity = 1
                offset = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeOut(duration: 0.25)) {
                    opacity = 0
                    offset = 15
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    isVisible = false
                }
            }
        }
    }
}

// MARK: - Mystery Badge Icon (for non-friends)

struct MysteryBadgeIcon: View {
    let size: CGFloat
    
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Pulsing glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05),
                            .clear
                        ],
                        center: .center,
                        startRadius: size * 0.1,
                        endRadius: size * 0.8
                    )
                )
                .frame(width: size * 1.5, height: size * 1.5)
                .blur(radius: 8)
                .opacity(isPulsing ? 0.8 : 0.3)
            
            // Outer ring shadow
            Circle()
                .fill(Color.black.opacity(0.4))
                .frame(width: size, height: size)
                .blur(radius: 4)
                .offset(y: 2)
            
            // Main circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "1F1F1F"), Color(hex: "0F0F0F")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Inner border
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                .frame(width: size * 0.9, height: size * 0.9)
            
            // Question mark
            Text("?")
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundColor(Color.white.opacity(0.25))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Mystery Stat Row

struct MysteryStatRow: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let icon: String
    let label: String
    let iconColor: Color
    
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(iconColor.opacity(0.6))
                .frame(width: 20)
            
            Text("?")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(themeManager.colors.textPrimary.opacity(isPulsing ? 0.4 : 0.2))
            
            Text(label)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(themeManager.colors.textPrimary.opacity(0.4))
            
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let icon: String
    let value: String
    let label: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            Text(value)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(themeManager.colors.textPrimary)
            
            Text(label)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(themeManager.colors.textSecondary)
            
            Spacer()
        }
    }
}

// MARK: - Mystery Rating View

struct MysteryRatingView: View {
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 8) {
            Text("?")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundColor(ThemeManager.shared.colors.textTertiary.opacity(isPulsing ? 0.5 : 0.25))
            
            Text("friends only")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(ThemeManager.shared.colors.textTertiary.opacity(0.5))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

struct UserProfileView: View {
    let user: User
    let isFriend: Bool
    let showAddButton: Bool
    let onAddFriend: (() async -> Void)?
    let onRemoveFriend: (() -> Void)?
    
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @EnvironmentObject var badgeManager: BadgeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var hasSentRequest = false
    @State private var isSending = false
    @State private var showRemoveConfirmation = false
    @State private var showChat = false
    @State private var chatConversation: Conversation?
    
    // Stats loaded from Supabase for friends
    @State private var loadedStreak: Int = 0
    @State private var loadedBadgeCount: Int = 0
    @State private var loadedDaysActive: Int = 0
    @State private var loadedVibesCreated: Int = 0
    @State private var loadedBadges: [BadgeDefinition] = []
    @State private var isLoadingStats = true
    
    // Friendship score
    @State private var friendshipScore: FriendshipScore?
    @State private var isLoadingFriendshipScore = false
    
    var isCurrentUser: Bool {
        user.id == viewModel.currentUserProfile?.id
    }
    
    // Get user's top badges
    var topBadges: [BadgeDefinition] {
        if isCurrentUser {
            let earned = badgeManager.earnedBadgeDefinitions
            let sorted = earned.sorted { $0.rarity.glowIntensity > $1.rarity.glowIntensity }
            return Array(sorted.prefix(3))
        } else {
            return loadedBadges
        }
    }
    
    // Stats
    var userBadgeCount: Int {
        isCurrentUser ? badgeManager.earnedBadges.count : loadedBadgeCount
    }
    
    var userStreak: Int {
        isCurrentUser ? badgeManager.currentStreak : loadedStreak
    }
    
    var userDaysActive: Int {
        isCurrentUser ? badgeManager.daysActive : loadedDaysActive
    }
    
    var userVibesCreated: Int {
        isCurrentUser ? badgeManager.vibesCreated : loadedVibesCreated
    }
    
    var body: some View {
        ZStack {
            ThemeManager.shared.colors.background.ignoresSafeArea()
            
            SmartScrollView {
                VStack(spacing: ThemeManager.shared.spacing.xl) {
                    // Header with close button
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ThemeManager.shared.colors.textSecondary)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(ThemeManager.shared.colors.cardBackground)
                                )
                        }
                    }
                    .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
                    .padding(.top, ThemeManager.shared.spacing.lg)
                    
                    // Avatar with premium glow
                    ZStack {
                        // Premium glow ring
                        if user.isPremium {
                            Circle()
                                .fill(user.selectedTheme.glowColor)
                                .frame(width: 120, height: 120)
                                .blur(radius: 20)
                                .opacity(0.4)
                            
                            Circle()
                                .stroke(user.selectedTheme.glowColor, lineWidth: 2)
                                .frame(width: 108, height: 108)
                                .opacity(0.6)
                        }
                        
                        Circle()
                            .fill(user.isPremium ? user.selectedTheme.colors.cardBackground : ThemeManager.shared.colors.cardBackground)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Text(String(user.displayName.prefix(1)).lowercased())
                                    .font(.system(size: 40, weight: .ultraLight))
                                    .foregroundColor(user.isPremium ? user.selectedTheme.glowColor : ThemeManager.shared.colors.textSecondary)
                            )
                    }
                    
                    // Name & Username
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Text(user.displayName.lowercased())
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(ThemeManager.shared.colors.textPrimary)
                            
                            // Premium badge
                            if user.isPremium {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 14))
                                    Text("ten+")
                                        .font(.system(size: 12, weight: .medium))
                                        .tracking(1)
                                }
                                .foregroundColor(user.selectedTheme.glowColor)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Text("@\(user.username)")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            
                            // Show their theme name if premium
                            if user.isPremium {
                                Text("·")
                                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                Text(user.selectedTheme.name.lowercased())
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundColor(user.selectedTheme.glowColor.opacity(0.8))
                            }
                        }
                    }
                    
                    // Badges Row
                    VStack(spacing: 12) {
                        Text("badges")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2)
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            .textCase(.uppercase)
                        
                        if isFriend {
                            if isLoadingStats && !isCurrentUser {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: ThemeManager.shared.colors.textTertiary))
                                    .scaleEffect(0.8)
                            } else if topBadges.isEmpty {
                                Text("no badges yet")
                                    .font(.system(size: 12, weight: .light))
                                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            } else {
                                HStack(spacing: -8) {
                                    ForEach(topBadges) { badge in
                                        BadgeIconView(
                                            badge: badge,
                                            isEarned: true,
                                            size: 36
                                        )
                                    }
                                }
                            }
                        } else {
                            // Show mystery badges for non-friends
                            HStack(spacing: -6) {
                                ForEach(0..<3, id: \.self) { _ in
                                    MysteryBadgeIcon(size: 36)
                                }
                            }
                        }
                    }
                    
                    // Today's Rating Card
                    VStack(spacing: 12) {
                        Text("today")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2)
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            .textCase(.uppercase)
                        
                        ratingCard
                    }
                    .padding(.top, 8)
                    
                    // Message Button (for friends only, shown right under rating)
                    if isFriend && !isCurrentUser {
                        messageButtonSection
                    }
                    
                    // Friendship Score Card (only for friends, not current user)
                    if isFriend && !isCurrentUser {
                        FriendshipScoreCard(
                            friendshipScore: friendshipScore,
                            isLoading: isLoadingFriendshipScore,
                            friendName: user.displayName
                        )
                        .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
                    }
                    
                    // Stats Section
                    VStack(spacing: 16) {
                        Text("stats")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2)
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        VStack(spacing: 14) {
                            if isFriend {
                                if isLoadingStats && !isCurrentUser {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: ThemeManager.shared.colors.textTertiary))
                                            .scaleEffect(0.8)
                                        Spacer()
                                    }
                                    .padding(.vertical, 20)
                                } else {
                                    StatRow(icon: "flame.fill", value: "\(userStreak)", label: "day streak", iconColor: .orange)
                                    StatRow(icon: "trophy.fill", value: "\(userBadgeCount)", label: "badges earned", iconColor: .yellow)
                                    StatRow(icon: "calendar", value: "\(userDaysActive)", label: "days active", iconColor: .blue)
                                    StatRow(icon: "sparkles", value: "\(userVibesCreated)", label: "vibes created", iconColor: .purple)
                                }
                            } else {
                                MysteryStatRow(icon: "flame.fill", label: "day streak", iconColor: .orange)
                                MysteryStatRow(icon: "trophy.fill", label: "badges earned", iconColor: .yellow)
                                MysteryStatRow(icon: "calendar", label: "days active", iconColor: .blue)
                                MysteryStatRow(icon: "sparkles", label: "vibes created", iconColor: .purple)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(ThemeManager.shared.colors.cardBackground.opacity(0.5))
                        )
                    }
                    .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
                    .padding(.top, 8)
                    
                    // Non-friend hint
                    if !isFriend {
                        Text("become friends to see more")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(ThemeManager.shared.colors.textTertiary.opacity(0.6))
                            .padding(.top, 4)
                    }
                    
                    // Member since
                    VStack(spacing: 4) {
                        Text("member since")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2)
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            .textCase(.uppercase)
                        
                        Text("december 2025")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(ThemeManager.shared.colors.textSecondary)
                    }
                    .padding(.top, 16)
                    
                    Spacer(minLength: 40)
                    
                    // Action Buttons
                    if showAddButton && !isFriend {
                        addFriendButton
                            .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
                    } else if isFriend && !isCurrentUser {
                        // Remove friend button only
                        removeFriendButton
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .task {
            if isFriend && !isCurrentUser {
                // Load stats and friendship score in parallel
                async let statsTask: () = loadUserStats()
                async let scoreTask: () = loadFriendshipScore()
                _ = await (statsTask, scoreTask)
            } else {
                isLoadingStats = false
            }
        }
        .alert("Remove Friend", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                onRemoveFriend?()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to remove \(user.displayName) from your friends?")
        }
    }
    
    // MARK: - Load User Stats from Supabase
    
    func loadUserStats() async {
        guard let userUUID = UUID(uuidString: user.id) else {
            isLoadingStats = false
            return
        }
        
        do {
            // Fetch user stats
            let stats: [DBUserStats] = try await SupabaseManager.shared.client
                .from("user_stats")
                .select()
                .eq("user_id", value: userUUID)
                .execute()
                .value
            
            if let userStats = stats.first {
                loadedStreak = userStats.currentStreak
                loadedDaysActive = userStats.daysActive
                loadedVibesCreated = userStats.vibesCreated
            }
            
            // Fetch user badges
            let badges: [DBUserBadge] = try await SupabaseManager.shared.client
                .from("user_badges")
                .select()
                .eq("user_id", value: userUUID)
                .execute()
                .value
            
            loadedBadgeCount = badges.count
            
            // Convert badge IDs to BadgeDefinitions (top 3 by rarity)
            let badgeDefinitions = badges.compactMap { dbBadge in
                BadgeLibrary.badge(withId: dbBadge.badgeId)
            }
            let sorted = badgeDefinitions.sorted { $0.rarity.glowIntensity > $1.rarity.glowIntensity }
            loadedBadges = Array(sorted.prefix(3))
            
        } catch {
            print("Error loading user stats: \(error)")
        }
        
        isLoadingStats = false
    }
    
    // MARK: - Load Friendship Score
    
    func loadFriendshipScore() async {
        isLoadingFriendshipScore = true
        friendshipScore = await viewModel.calculateFriendshipScore(for: user.id)
        isLoadingFriendshipScore = false
    }
    
    // MARK: - Rating Card
    
    var ratingCard: some View {
        VStack(spacing: 8) {
            if isFriend {
                if let rating = user.todayRating {
                    Text("\(rating)")
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    
                    Text(ratingMoodText(for: rating))
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                } else {
                    Text("-")
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    
                    Text("not rated yet")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                }
            } else {
                // Mystery rating for non-friends
                MysteryRatingView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ThemeManager.shared.colors.cardBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
        .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
    }
    
    // MARK: - Add Friend Button
    
    var hasMaxFriends: Bool {
        viewModel.friends.count >= PremiumManager.shared.friendLimit
    }
    
    var addFriendButton: some View {
        Group {
            if hasMaxFriends {
                // Max friends reached - show upgrade or circle complete
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 14, weight: .medium))
                        Text("circle complete")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .tracking(1)
                    .foregroundColor(ThemeManager.shared.colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(ThemeManager.shared.colors.cardBackground)
                    )
                    
                    Text(PremiumManager.shared.isPremium ? "you've reached \(PremiumManager.shared.friendLimit) friends." : "you've reached 10 friends. upgrade to ten+ for more.")
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        .multilineTextAlignment(.center)
                }
            } else {
                Button(action: {
                    Task {
                        isSending = true
                        await onAddFriend?()
                        hasSentRequest = true
                        isSending = false
                    }
                }) {
                    HStack(spacing: 8) {
                        if isSending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: ThemeManager.shared.colors.textPrimary))
                                .scaleEffect(0.8)
                        } else if hasSentRequest || viewModel.sentFriendRequests.contains(user.id) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .medium))
                            Text("request sent")
                        } else {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 14, weight: .medium))
                            Text("add friend")
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .tracking(1)
                    .foregroundColor(hasSentRequest || viewModel.sentFriendRequests.contains(user.id) ? .green : ThemeManager.shared.colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(hasSentRequest || viewModel.sentFriendRequests.contains(user.id) ? Color.green.opacity(0.15) : ThemeManager.shared.colors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(hasSentRequest || viewModel.sentFriendRequests.contains(user.id) ? Color.green.opacity(0.3) : ThemeManager.shared.colors.textPrimary.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .disabled(hasSentRequest || isSending || viewModel.sentFriendRequests.contains(user.id))
            }
        }
    }
    
    // MARK: - Message Button Section (with low rating prompt)
    
    var messageButtonSection: some View {
        VStack(spacing: 8) {
            // Show prompt if friend's rating is low (less than 5)
            if let rating = user.todayRating, rating < 5 {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                    Text("\(user.displayName.components(separatedBy: " ").first ?? user.displayName) might need some support today")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.orange)
                .padding(.bottom, 4)
            }
            
            messageButton
        }
    }
    
    // MARK: - Message Button
    
    var messageButton: some View {
        Button(action: {
            Task {
                if let conversationId = await ConversationManager.shared.getOrCreateConversation(with: user.id) {
                    let conversation = Conversation(
                        id: conversationId,
                        participantIds: [viewModel.currentUserProfile?.id ?? "", user.id]
                    )
                    chatConversation = conversation
                    showChat = true
                }
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 14))
                Text("message")
                    .font(.system(size: 14, weight: .medium))
                    .tracking(1)
            }
            .foregroundColor(ThemeManager.shared.colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, ThemeManager.shared.spacing.md)
            .background(
                RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                    .fill(ThemeManager.shared.colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                    .stroke(ThemeManager.shared.colors.accent1.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PremiumButtonStyle())
        .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
        .fullScreenCover(isPresented: $showChat) {
            if let conversation = chatConversation {
                ChatView(conversation: conversation, friend: user)
                    .environmentObject(viewModel)
            }
        }
    }
    
    // MARK: - Remove Friend Button
    
    var removeFriendButton: some View {
        Button(action: { showRemoveConfirmation = true }) {
            Text("remove friend")
                .font(.system(size: 13, weight: .medium))
                .tracking(1)
                .foregroundColor(.red.opacity(0.7))
        }
    }
    
    // MARK: - Helper
    
    func ratingMoodText(for rating: Int) -> String {
        switch rating {
        case 1...2: return "having a rough day"
        case 3...4: return "feeling low"
        case 5...6: return "doing okay"
        case 7...8: return "having a good day"
        case 9...10: return "feeling amazing"
        default: return ""
        }
    }
}

// MARK: - Tappable Badge Icon

struct TappableBadgeIcon: View {
    let badge: BadgeDefinition
    let size: CGFloat
    @Binding var selectedBadge: BadgeDefinition?
    
    var body: some View {
        Button(action: {
            selectedBadge = badge
        }) {
            BadgeIconView(badge: badge, isEarned: true, size: size)
        }
    }
}


// MARK: - Badge Row (for profile display)

struct BadgeRowView: View {
    let badges: [BadgeDefinition]
    let earnedBadgeIds: Set<String>
    let onBadgeTap: (BadgeDefinition) -> Void
    let maxDisplay: Int
    
    init(
        badges: [BadgeDefinition],
        earnedBadgeIds: Set<String>,
        maxDisplay: Int = 5,
        onBadgeTap: @escaping (BadgeDefinition) -> Void
    ) {
        self.badges = badges
        self.earnedBadgeIds = earnedBadgeIds
        self.maxDisplay = maxDisplay
        self.onBadgeTap = onBadgeTap
    }
    
    var earnedBadges: [BadgeDefinition] {
        badges.filter { earnedBadgeIds.contains($0.id) }
    }
    
    var displayBadges: [BadgeDefinition] {
        Array(earnedBadges.prefix(maxDisplay))
    }
    
    var remainingCount: Int {
        max(0, earnedBadges.count - maxDisplay)
    }
    
    var body: some View {
        HStack(spacing: -6) {
            ForEach(displayBadges) { badge in
                Button(action: { onBadgeTap(badge) }) {
                    BadgeIconView(badge: badge, isEarned: true, size: 34)
                }
            }
            
            if remainingCount > 0 {
                ZStack {
                    Circle()
                        .fill(ThemeManager.shared.colors.cardBackground)
                        .frame(width: 34, height: 34)
                    
                    Text("+\(remainingCount)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ThemeManager.shared.colors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Badge Collection View (Full Screen)

struct BadgeCollectionView: View {
    @ObservedObject var badgeManager = BadgeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBadge: BadgeDefinition? = nil
    @State private var showTooltip = false
    
    var earnedCount: Int {
        badgeManager.earnedBadges.count
    }
    
    var totalCount: Int {
        BadgeLibrary.all.count
    }
    
    var body: some View {
        ZStack {
            ThemeManager.shared.colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ThemeManager.shared.colors.textSecondary)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(ThemeManager.shared.colors.cardBackground)
                            )
                    }
                    
                    Spacer()
                    
                    Text("badges")
                        .font(.system(size: 16, weight: .light))
                        .tracking(4)
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    
                    Spacer()
                    
                    Text("\(earnedCount)/\(totalCount)")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        .frame(width: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
                
                SmartScrollView {
                    VStack(spacing: 28) {
                        ForEach(BadgeCategory.allCases, id: \.self) { category in
                            BadgeCategorySection(
                                category: category,
                                badges: BadgeLibrary.badges(in: category),
                                earnedBadgeIds: Set(badgeManager.earnedBadges.map { $0.badgeId }),
                                onBadgeTap: { badge in
                                    selectedBadge = badge
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        showTooltip = true
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            
            // Tooltip overlay
            if showTooltip, let badge = selectedBadge {
                Color.black.opacity(0.75)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showTooltip = false
                        }
                    }
                
                BadgeTooltipView(
                    badge: badge,
                    isEarned: badgeManager.hasBadge(badge.id),
                    earnedDate: badgeManager.earnedDate(for: badge.id),
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showTooltip = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(1)
            }
        }
    }
}

// MARK: - Badge Category Section

struct BadgeCategorySection: View {
    let category: BadgeCategory
    let badges: [BadgeDefinition]
    let earnedBadgeIds: Set<String>
    let onBadgeTap: (BadgeDefinition) -> Void
    
    var earnedInCategory: Int {
        badges.filter { earnedBadgeIds.contains($0.id) }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category header
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 11))
                    .foregroundColor(category.color.opacity(0.7))
                
                Text(category.displayName.lowercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    .textCase(.uppercase)
                
                Spacer()
                
                Text("\(earnedInCategory)/\(badges.count)")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(ThemeManager.shared.colors.textTertiary.opacity(0.6))
            }
            
            // Badge grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ForEach(badges) { badge in
                    Button(action: { onBadgeTap(badge) }) {
                        VStack(spacing: 10) {
                            BadgeIconView(
                                badge: badge,
                                isEarned: earnedBadgeIds.contains(badge.id),
                                size: 54
                            )
                            
                            Text(badge.name)
                                .font(.system(size: 9, weight: .medium))
                                .tracking(0.5)
                                .foregroundColor(
                                    earnedBadgeIds.contains(badge.id) ?
                                    ThemeManager.shared.colors.textSecondary :
                                    ThemeManager.shared.colors.textTertiary.opacity(0.35)
                                )
                                .lineLimit(1)
                                .frame(maxWidth: 70)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ThemeManager.shared.colors.cardBackground.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }
}

// MARK: - Ultra Premium Badge Celebration View

struct BadgeCelebrationView: View {
    let badge: BadgeDefinition
    let onDismiss: () -> Void
    
    @State private var showBadge = false
    @State private var showText = false
    @State private var showButton = false
    @State private var badgeScale: CGFloat = 0.3
    @State private var badgeOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.5
    @State private var particles: [FloatingParticle] = []
    
    var body: some View {
        ZStack {
            // Deep dark background with vignette
            RadialGradient(
                colors: [
                    Color.black.opacity(0.88),
                    Color.black.opacity(0.95),
                    Color.black
                ],
                center: .center,
                startRadius: 50,
                endRadius: 500
            )
            .ignoresSafeArea()
            
            // Floating ambient particles
            ForEach(particles) { particle in
                Circle()
                    .fill(badge.rarity.color.opacity(particle.opacity))
                    .frame(width: particle.size, height: particle.size)
                    .blur(radius: particle.size / 3)
                    .position(particle.position)
            }
            
            // Central glow
            if showBadge {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                badge.rarity.color.opacity(0.25),
                                badge.rarity.color.opacity(0.08),
                                .clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 180
                        )
                    )
                    .frame(width: 360, height: 360)
                    .scaleEffect(glowScale)
                    .blur(radius: 30)
            }
            
            VStack(spacing: 44) {
                Spacer()
                
                // Badge
                BadgeIconView(badge: badge, isEarned: true, size: 150)
                    .scaleEffect(badgeScale)
                    .opacity(badgeOpacity)
                    .shadow(color: badge.rarity.color.opacity(0.3), radius: 40, y: 10)
                
                // Text content
                VStack(spacing: 18) {
                    Text("new badge")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(5)
                        .foregroundColor(badge.rarity.color.opacity(0.7))
                        .textCase(.uppercase)
                        .opacity(showText ? 1 : 0)
                        .offset(y: showText ? 0 : 8)
                    
                    Text(badge.name)
                        .font(.system(size: 30, weight: .light))
                        .tracking(3)
                        .foregroundColor(.white)
                        .opacity(showText ? 1 : 0)
                        .offset(y: showText ? 0 : 8)
                    
                    Text(badge.description)
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(.white.opacity(0.45))
                        .opacity(showText ? 1 : 0)
                        .offset(y: showText ? 0 : 8)
                    
                    // Rarity indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(badge.rarity.color)
                            .frame(width: 5, height: 5)
                            .shadow(color: badge.rarity.color.opacity(0.6), radius: 6)
                        
                        Text(badge.rarity.displayName.lowercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(3)
                            .foregroundColor(badge.rarity.color.opacity(0.85))
                    }
                    .padding(.top, 8)
                    .opacity(showText ? 1 : 0)
                    .offset(y: showText ? 0 : 8)
                }
                
                Spacer()
                
                // Continue button
                Button(action: {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    onDismiss()
                }) {
                    Text("continue")
                        .font(.system(size: 13, weight: .medium))
                        .tracking(4)
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                }
                .padding(.horizontal, 44)
                .padding(.bottom, 50)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 15)
            }
        }
        .onAppear {
            // Create floating particles
            createParticles()
            
            // Haptic
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
            // Badge fade and scale in
            withAnimation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.15)) {
                showBadge = true
                badgeScale = 1
                badgeOpacity = 1
            }
            
            // Glow expand
            withAnimation(.easeOut(duration: 1.2).delay(0.2)) {
                glowScale = 1
            }
            
            // Text fade in
            withAnimation(.easeOut(duration: 0.6).delay(0.55)) {
                showText = true
            }
            
            // Button fade in
            withAnimation(.easeOut(duration: 0.5).delay(1.1)) {
                showButton = true
            }
        }
    }
    
    func createParticles() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        for i in 0..<15 {
            let particle = FloatingParticle(
                id: i,
                position: CGPoint(
                    x: CGFloat.random(in: 40...(screenWidth - 40)),
                    y: CGFloat.random(in: 100...(screenHeight - 200))
                ),
                size: CGFloat.random(in: 3...8),
                opacity: Double.random(in: 0.1...0.25)
            )
            particles.append(particle)
        }
        
        // Animate particles floating
        for i in 0..<particles.count {
            let randomDuration = Double.random(in: 3...6)
            let randomDelay = Double.random(in: 0...2)
            let randomYOffset = CGFloat.random(in: 20...50)
            
            withAnimation(.easeInOut(duration: randomDuration).repeatForever(autoreverses: true).delay(randomDelay)) {
                particles[i].position.y -= randomYOffset
                particles[i].opacity = Double.random(in: 0.15...0.35)
            }
        }
    }
}

struct FloatingParticle: Identifiable {
    let id: Int
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}

#Preview {
    BadgeCollectionView()
}
