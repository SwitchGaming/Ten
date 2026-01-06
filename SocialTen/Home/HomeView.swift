//
//  HomeView.swift
//  SocialTen
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @State private var showCreatePost = false
    @State private var navigateToVibeTab = false
    @State private var expandedVibeId: String? = nil
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: ThemeManager.shared.spacing.xl) {
                // Header
                Text("ten")
                    .font(ThemeManager.shared.fonts.title)
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    .tracking(ThemeManager.shared.letterSpacing.widest)
                    .padding(.top, ThemeManager.shared.spacing.lg)
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
            .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
        }
        .background(ThemeManager.shared.colors.background.ignoresSafeArea())
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
    @State private var showCreatePost = false
    
    var body: some View {
        Button(action: { showCreatePost = true }) {
            DepthCard(depth: .low) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("today's prompt")
                            .font(ThemeManager.shared.fonts.caption)
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            .tracking(ThemeManager.shared.letterSpacing.wide)
                            .textCase(.uppercase)
                        
                        Text(viewModel.todaysPrompt.text)
                            .font(ThemeManager.shared.fonts.body)
                            .foregroundColor(ThemeManager.shared.colors.textSecondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                }
                .padding(ThemeManager.shared.spacing.md)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.md) {
            Text("friends")
                .font(ThemeManager.shared.fonts.caption)
                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                .tracking(ThemeManager.shared.letterSpacing.wide)
                .textCase(.uppercase)
            
            if viewModel.friends.isEmpty {
                Text("no friends yet")
                    .font(ThemeManager.shared.fonts.body)
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ThemeManager.shared.spacing.lg)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ThemeManager.shared.spacing.md) {
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
