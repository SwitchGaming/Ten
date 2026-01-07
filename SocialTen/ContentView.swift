//
//  ContentView.swift
//  SocialTen
//
//  Created by Joe Alapat on 12/3/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var appViewModel = SupabaseAppViewModel()
    @StateObject private var badgeManager = BadgeManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @State private var isOnboardingComplete = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Ensure premium theme is loaded on app launch
        _ = PremiumManager.shared
    }
    
    var body: some View {
        ZStack {
            Group {
                if authViewModel.isLoading {
                    // Enhanced loading screen
                    LoadingScreen()
                } else if authViewModel.isAuthenticated {
                    if authViewModel.isNewUser && !isOnboardingComplete {
                        // Show onboarding for new users
                        OnboardingView(isOnboardingComplete: $isOnboardingComplete)
                            .environmentObject(authViewModel)
                            .transition(.opacity)
                    } else {
                        // Main app
                        MainTabView()
                            .environmentObject(appViewModel)
                            .environmentObject(authViewModel)
                            .environmentObject(badgeManager)
                            .task {
                                await appViewModel.loadCurrentUser()
                                // Explicitly load posts and vibes after user loads
                                await appViewModel.loadPosts()
                                await appViewModel.loadVibes()
                                await appViewModel.loadFriendRequests()
                                await appViewModel.loadFriends()
                                await appViewModel.loadConnectionOfTheWeek()
                                // Load badges from Supabase and check for new ones
                                if let userId = appViewModel.currentUserProfile?.id {
                                    await badgeManager.loadFromSupabase(userId: userId)
                                    await badgeManager.checkForNewBadges(
                                        userId: userId,
                                        friendCount: appViewModel.friends.count
                                    )
                                }
                            }                            .transition(.opacity)
                    }
                } else {
                    // Auth screen
                    AuthView()
                        .environmentObject(authViewModel)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authViewModel.isLoading)
            .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
            
            // Badge celebration overlay
            if badgeManager.showBadgeCelebration, let badge = badgeManager.newlyEarnedBadge {
                BadgeCelebrationView(badge: badge) {
                    badgeManager.dismissCelebration()
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated && authViewModel.isNewUser {
                isOnboardingComplete = false
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            Task {
                switch newPhase {
                case .active:
                    // App came to foreground - refresh data and reconnect realtime
                    if authViewModel.isAuthenticated {
                        await appViewModel.loadPosts()
                        await appViewModel.loadVibes()
                        await appViewModel.loadFriendRequests()
                        await appViewModel.loadFriends()
                        await appViewModel.loadConnectionOfTheWeek()
                    }
                case .background:
                    // App went to background - unsubscribe from realtime
                    await appViewModel.unsubscribeFromRealtime()
                case .inactive:
                    break
                @unknown default:
                    break
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HandlePushNotification"))) { notification in
            guard let userInfo = notification.userInfo,
                  let type = userInfo["type"] as? String else { return }
            
            // Handle navigation based on notification type
            switch type {
            case "vibe":
                // Navigate to vibe tab
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToVibeTab"), object: nil)
            case "friend_request":
                // Navigate to friends tab
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToFriendsTab"), object: nil)
            case "reply":
                // Navigate to feed tab
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToFeedTab"), object: nil)
            default:
                break
            }
        }
    }
}

// ...existing LoadingScreen and LoadingDots code...

// MARK: - Enhanced Loading Screen

struct LoadingScreen: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.8
    @State private var showLoader = false
    @State private var glowOpacity: Double = 0
    
    var body: some View {
        ZStack {
            themeManager.colors.background.ignoresSafeArea()
            
            VStack(spacing: 32) {
                ZStack {
                    // Glow effect
                    Text("ten")
                        .font(.system(size: 56, weight: .ultraLight))
                        .tracking(12)
                        .foregroundColor(themeManager.colors.accent2)
                        .blur(radius: 20)
                        .opacity(glowOpacity)
                    
                    // Main logo
                    Text("ten")
                        .font(.system(size: 56, weight: .ultraLight))
                        .tracking(12)
                        .foregroundColor(themeManager.colors.textPrimary)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                
                if showLoader {
                    LoadingDots()
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            // Animate logo in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                logoOpacity = 1
                logoScale = 1
            }
            
            // Start glow animation
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(0.5)) {
                glowOpacity = 0.5
            }
            
            // Show loader after delay
            withAnimation(.easeIn(duration: 0.3).delay(0.6)) {
                showLoader = true
            }
        }
    }
}

// MARK: - Loading Dots Animation

struct LoadingDots: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var activeIndex = 0
    let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(themeManager.colors.textTertiary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(activeIndex == index ? 1.3 : 1)
                    .opacity(activeIndex == index ? 1 : 0.4)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: activeIndex)
            }
        }
        .onReceive(timer) { _ in
            activeIndex = (activeIndex + 1) % 3
        }
    }
}

#Preview {
    ContentView()
}
