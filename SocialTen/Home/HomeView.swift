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
        ScrollView(showsIndicators: false) {
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: themeManager.spacing.md) {
                        ForEach(viewModel.friends.sorted { ($0.todayRating ?? 0) > ($1.todayRating ?? 0) }) { friend in
                            FriendBubble(friend: friend)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(SupabaseAppViewModel())
}
