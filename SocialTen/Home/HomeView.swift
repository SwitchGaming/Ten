//
//  HomeView.swift
//  SocialTen
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showCreatePost = false
    @State private var navigateToVibeTab = false
    @State private var expandedVibeId: String? = nil
    
    var body: some View {
        SmartScrollView {
            VStack(spacing: themeManager.spacing.xl) {
                // Header
                Text("ten")
                    .font(themeManager.fonts.title)
                    .foregroundColor(themeManager.colors.textPrimary)
                    .tracking(themeManager.letterSpacing.widest)
                    .padding(.top, themeManager.spacing.lg)
                    .appearAnimation(delay: 0)
                
                // Rating Card
                SwipeableRatingCard(
                    rating: viewModel.currentUserProfile?.todayRating,
                    lastRating: viewModel.currentUserProfile?.lastRating,
                    onRatingChanged: { newRating in
                        Task {
                            await viewModel.updateRating(newRating)
                        }
                    }
                )
                .appearAnimation(delay: 0.1)
                
                // Daily Prompt (optional)
                DailyPromptCard()
                    .appearAnimation(delay: 0.2)
                
                // Friends Section
                FriendsSection()
                    .appearAnimation(delay: 0.3)
                
                // Active Vibe Banner (if any)
                if !viewModel.getActiveVibes().isEmpty {
                    ActiveVibeBanner(
                        navigateToVibeTab: $navigateToVibeTab,
                        expandedVibeId: $expandedVibeId
                    )
                    .appearAnimation(delay: 0.4)
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, themeManager.spacing.screenHorizontal)
        }
        .background(themeManager.colors.background.ignoresSafeArea())
        .refreshable {
            await viewModel.loadCurrentUser()
        }
        .onChange(of: navigateToVibeTab) { _, shouldNavigate in
            if shouldNavigate {
                // Post notification to switch to vibe tab
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToVibeTab"),
                    object: expandedVibeId
                )
                navigateToVibeTab = false
            }
        }
    }
}

// MARK: - Daily Prompt Card

struct DailyPromptCard: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showCreatePost = false
    
    var body: some View {
        Button(action: { showCreatePost = true }) {
            DepthCard(depth: .low) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("today's prompt")
                            .font(themeManager.fonts.caption)
                            .foregroundColor(themeManager.colors.textTertiary)
                            .tracking(themeManager.letterSpacing.wide)
                            .textCase(.uppercase)
                        
                        Text(viewModel.todaysPrompt.text)
                            .font(themeManager.fonts.body)
                            .foregroundColor(themeManager.colors.textSecondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(themeManager.colors.textTertiary)
                }
                .padding(themeManager.spacing.md)
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .fullScreenCover(isPresented: $showCreatePost) {
            CreatePostView(startOnPromptTab: true)
        }
    }
}

// MARK: - Friends Section

struct FriendsSection: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            Text("friends")
                .font(themeManager.fonts.caption)
                .foregroundColor(themeManager.colors.textTertiary)
                .tracking(themeManager.letterSpacing.wide)
                .textCase(.uppercase)
            
            if viewModel.friends.isEmpty {
                Text("no friends yet")
                    .font(themeManager.fonts.body)
                    .foregroundColor(themeManager.colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, themeManager.spacing.lg)
            } else {
                // Sort friends: those who rated today first (by rating desc), then stale ratings last (by rating desc)
                let sortedFriends = viewModel.friends.sorted { friend1, friend2 in
                    let today1 = friend1.hasRatedToday
                    let today2 = friend2.hasRatedToday
                    
                    // Friends who rated today come first
                    if today1 != today2 {
                        return today1
                    }
                    // Within same group, sort by rating descending
                    return (friend1.todayRating ?? 0) > (friend2.todayRating ?? 0)
                }
                
                FriendsScrollView(sortedFriends: sortedFriends)
            }
        }
    }
}

// MARK: - Friends Scroll View with swipe indicator

struct FriendsScrollView: View {
    let sortedFriends: [User]
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showArrow = true
    @State private var selectedFriend: User?
    
    var body: some View {
        ZStack(alignment: .trailing) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: themeManager.spacing.md) {
                    ForEach(sortedFriends) { friend in
                        Button(action: {
                            selectedFriend = friend
                        }) {
                            FriendBubble(friend: friend, isStale: !friend.hasRatedToday)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.vertical, 12)
                .padding(.bottom, 8)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onChange(of: geo.frame(in: .named("friendsScroll")).minX) { _, minX in
                                withAnimation(.easeOut(duration: 0.2)) {
                                    showArrow = minX >= -10
                                }
                            }
                    }
                )
            }
            .coordinateSpace(name: "friendsScroll")
            .scrollClipDisabled()
            
            // Swipe indicator arrow
            if sortedFriends.count > 3 && showArrow {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.colors.textSecondary.opacity(0.7))
                    .padding(.trailing, 4)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .fullScreenCover(item: $selectedFriend) { friend in
            UserProfileView(
                user: friend,
                isFriend: true,
                showAddButton: false,
                onAddFriend: nil,
                onRemoveFriend: {
                    Task {
                        await viewModel.removeFriend(friend.id)
                    }
                }
            )
            .environmentObject(viewModel)
            .environmentObject(BadgeManager.shared)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(SupabaseAppViewModel())
}
