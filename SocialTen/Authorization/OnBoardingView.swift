//
//  OnboardingView.swift
//  SocialTen
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var currentPage = 0
    @State private var showContent = false
    
    private let totalPages = 5
    
    var displayName: String {
        authViewModel.pendingUsername.isEmpty ? "friend" : authViewModel.pendingUsername
    }
    
    var body: some View {
        ZStack {
            ThemeManager.shared.colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with progress
                headerView
                
                // Content pages
                TabView(selection: $currentPage) {
                    WelcomePage(displayName: displayName, showContent: $showContent)
                        .tag(0)
                    
                    RatingPage(showContent: $showContent)
                        .tag(1)
                    
                    PostsPage(showContent: $showContent)
                        .tag(2)
                    
                    VibesPage(showContent: $showContent)
                        .tag(3)
                    
                    ConnectionPage(showContent: $showContent, onComplete: completeOnboarding)
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentPage)
                
                // Bottom navigation
                bottomNavigation
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                showContent = true
            }
        }
        .onChange(of: currentPage) { _, _ in
            showContent = false
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                showContent = true
            }
        }
    }
    
    // MARK: - Header
    
    var headerView: some View {
        HStack {
            // Progress indicator
            HStack(spacing: 4) {
                ForEach(0..<totalPages, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index <= currentPage ? Color.white : Color.white.opacity(0.2))
                        .frame(width: index == currentPage ? 24 : 8, height: 4)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)
                }
            }
            
            Spacer()
            
            // Skip button
            if currentPage < totalPages - 1 {
                Button(action: completeOnboarding) {
                    Text("skip")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
    
    // MARK: - Bottom Navigation
    
    var bottomNavigation: some View {
        HStack {
            // Back button
            if currentPage > 0 {
                Button(action: { currentPage -= 1 }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ThemeManager.shared.colors.textSecondary)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(ThemeManager.shared.colors.cardBackground))
                }
            } else {
                Spacer().frame(width: 50)
            }
            
            Spacer()
            
            Text("\(currentPage + 1) of \(totalPages)")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(ThemeManager.shared.colors.textTertiary)
            
            Spacer()
            
            // Next button
            if currentPage < totalPages - 1 {
                Button(action: { currentPage += 1 }) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.white))
                }
            } else {
                Spacer().frame(width: 50)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
    
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.easeInOut(duration: 0.4)) {
            isOnboardingComplete = true
        }
    }
}

// MARK: - Page 1: Welcome

struct WelcomePage: View {
    let displayName: String
    @Binding var showContent: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 32) {
                Text("ten")
                    .font(.system(size: 64, weight: .ultraLight))
                    .tracking(12)
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                
                VStack(spacing: 12) {
                    Text("welcome, \(displayName)")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    
                    Text("let's show you around")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 15)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Text("swipe or tap to continue")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
            }
            .opacity(showContent ? 1 : 0)
            .padding(.bottom, 80)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Page 2: Day Rating

struct RatingPage: View {
    @Binding var showContent: Bool
    @State private var animatedRating: Int = 7
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 40) {
                // Animated rating display
                Text("\(animatedRating)")
                    .font(.system(size: 120, weight: .ultraLight))
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.8)
                
                // Rating dots
                RatingDotsView(rating: animatedRating)
                    .opacity(showContent ? 1 : 0)
                
                // Description
                VStack(spacing: 12) {
                    Text("rate your day")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    
                    Text("every day, swipe to rate how\nyou're feeling from 1 to 10.\nyour friends see your rating\nand know how you're doing.")
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
            }
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .onAppear { startRatingAnimation() }
    }
    
    func startRatingAnimation() {
        let ratings = [7, 8, 6, 9, 7]
        for (index, rating) in ratings.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.8 + 0.5) {
                withAnimation(.spring(response: 0.4)) {
                    animatedRating = rating
                }
            }
        }
    }
}

struct RatingDotsView: View {
    let rating: Int
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...10, id: \.self) { i in
                Circle()
                    .fill(i <= rating ? ThemeManager.shared.colors.accent2 : ThemeManager.shared.colors.cardBackground)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Page 3: Posts

struct PostsPage: View {
    @Binding var showContent: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 40) {
                // Post preview card
                PostPreviewCard()
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)
                
                // Description
                VStack(spacing: 12) {
                    Text("share moments")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    
                    Text("post updates, thoughts, or respond\nto daily prompts. your rating is\ntagged to each post so friends\nknow how you were feeling.")
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
            }
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

struct PostPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(ThemeManager.shared.colors.cardBackground)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text("j")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(ThemeManager.shared.colors.textSecondary)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("jamie")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    
                    Text("2h ago")
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                }
                
                Spacer()
                
                Text("8")
                    .font(.system(size: 18, weight: .ultraLight))
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
            }
            
            Text("finally finished that project 🎉")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(ThemeManager.shared.colors.textPrimary)
            
            HStack(spacing: 16) {
                Label("3", systemImage: "heart.fill")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(.red)
                
                Label("1", systemImage: "bubble.left")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(ThemeManager.shared.colors.textSecondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ThemeManager.shared.colors.cardBackground)
        )
    }
}

// MARK: - Page 4: Vibes

struct VibesPage: View {
    @Binding var showContent: Bool
    @State private var showCheckmarks = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 40) {
                // Vibe card preview
                VibePreviewCard(showCheckmarks: showCheckmarks)
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.9)
                
                // Description
                VStack(spacing: 12) {
                    Text("start a vibe")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    
                    Text("want to hang out? create a vibe\nin under 6 seconds. friends can\ninstantly say yes or no.\nno more group chat chaos.")
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
            }
            
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation { showCheckmarks = true }
            }
        }
    }
}

struct VibePreviewCard: View {
    let showCheckmarks: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(ThemeManager.shared.colors.accent2)
                
                Text("basketball?")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
            }
            
            Text("in 30 min · the court")
                .font(.system(size: 13, weight: .light))
                .foregroundColor(ThemeManager.shared.colors.textTertiary)
            
            // Response indicators
            HStack(spacing: -8) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(ThemeManager.shared.colors.background)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.green)
                                .opacity(showCheckmarks ? 1 : 0)
                        )
                        .overlay(Circle().stroke(Color.green.opacity(0.4), lineWidth: 2))
                }
            }
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ThemeManager.shared.colors.cardBackground)
        )
    }
}

// MARK: - Page 5: Connection & Friends Limit

struct ConnectionPage: View {
    @Binding var showContent: Bool
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 40) {
                // Network visualization
                ConnectionNetworkVisualization(showContent: showContent)
                
                // Description
                VStack(spacing: 12) {
                    Text("your ten")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    
                    Text("ten is for real connection.\nadd up to 10 close friends.\neach week, we match you with\na new person to connect with.")
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
            }
            
            Spacer()
            
            // Get started button
            Button(action: onComplete) {
                Text("let's go")
                    .font(.system(size: 15, weight: .medium))
                    .tracking(2)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
            }
            .opacity(showContent ? 1 : 0)
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
    }
}

struct ConnectionNetworkVisualization: View {
    let showContent: Bool
    
    var body: some View {
        ZStack {
            // Friend circles in a circle
            ForEach(0..<10, id: \.self) { index in
                let angle = Double(index) * (360.0 / 10.0) * .pi / 180
                let radius: CGFloat = 70
                
                Circle()
                    .fill(ThemeManager.shared.colors.cardBackground)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(ThemeManager.shared.colors.textSecondary)
                    )
                    .offset(
                        x: CGFloat(cos(angle)) * radius,
                        y: CGFloat(sin(angle)) * radius
                    )
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.5)
            }
            
            // Center "you" circle
            Circle()
                .fill(ThemeManager.shared.colors.accent2.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay(
                    Text("you")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                )
                .overlay(Circle().stroke(ThemeManager.shared.colors.accent2.opacity(0.5), lineWidth: 2))
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.8)
        }
        .frame(width: 200, height: 180)
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
        .environmentObject(AuthViewModel())
}
