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
    @StateObject private var checkInManager = CheckInManager.shared
    @StateObject private var premiumManager = PremiumManager.shared
    @StateObject private var ambassadorInvitationManager = AmbassadorInvitationManager.shared
    @State private var isOnboardingComplete = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var showCheckInWalkthrough = false
    @State private var showCheckInAlert = false
    @State private var showSupportReceived = false
    @State private var navigateToConversationId: String? = nil
    @State private var showDowngradeFlow = false
    @State private var showAmbassadorInvitation = false
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Ensure premium theme is loaded on app launch
        _ = PremiumManager.shared
    }
    
    // TESTING: Set to true to force show onboarding (ignores UserDefaults)
    private let forceShowOnboarding = false
    
    var body: some View {
        ZStack {
            Group {
                if authViewModel.isLoading {
                    // Enhanced loading screen
                    LoadingScreen()
                } else if authViewModel.isAuthenticated {
                    // Force onboarding for testing (bypasses the saved state)
                    if forceShowOnboarding && !isOnboardingComplete {
                        OnboardingView(isOnboardingComplete: $isOnboardingComplete)
                            .environmentObject(authViewModel)
                            .transition(.opacity)
                            .onAppear {
                                // Reset the flag when force showing
                                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                            }
                    } else if authViewModel.isNewUser && !isOnboardingComplete {
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
                                // Check if daily rating should be reset (new day in user's timezone)
                                appViewModel.checkAndResetDailyRating()
                                // Explicitly load posts and vibes after user loads
                                await appViewModel.loadPosts()
                                await appViewModel.loadVibes()
                                await appViewModel.loadFriendRequests()
                                await appViewModel.loadFriends()
                                await appViewModel.loadConnectionOfTheWeek()
                                
                                // Re-register device token after login (in case it was deleted)
                                if let savedToken = UserDefaults.standard.string(forKey: "deviceToken") {
                                    await NotificationManager.shared.registerDeviceToken(savedToken)
                                }
                                
                                // Validate premium status from server
                                await premiumManager.validatePremiumStatus()
                                await premiumManager.validatePremiumStatus()
                                
                                // Load blocked users
                                await BlockManager.shared.loadBlockedUsers()
                                
                                // Check if user needs to go through downgrade flow
                                if !premiumManager.isPremium {
                                    let friendCount = appViewModel.friends.count
                                    let groupCount = 0 // TODO: Get actual group count
                                    
                                    if friendCount > PremiumManager.standardFriendLimit || groupCount > PremiumManager.standardGroupLimit {
                                        await MainActor.run {
                                            premiumManager.initializeDowngradeFlow(friendCount: friendCount, groupCount: groupCount)
                                            showDowngradeFlow = true
                                        }
                                    }
                                }
                                
                                // Load badges from Supabase and check for new ones
                                if let userId = appViewModel.currentUserProfile?.id {
                                    await badgeManager.loadFromSupabase(userId: userId)
                                    await badgeManager.checkForNewBadges(
                                        userId: userId,
                                        friendCount: appViewModel.friends.count
                                    )
                                }
                                
                                // Check for ambassador invitation
                                await ambassadorInvitationManager.checkForInvitation()
                                if ambassadorInvitationManager.pendingInvitation != nil {
                                    await MainActor.run {
                                        showAmbassadorInvitation = true
                                    }
                                }
                                
                                // Update widgets with latest data
                                appViewModel.updateWidgetData()
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
                        // Refresh unread message count immediately
                        await ConversationManager.shared.refreshUnreadCount()
                        
                        // Check if daily rating should be reset (new day in user's timezone)
                        appViewModel.checkAndResetDailyRating()
                        
                        await appViewModel.loadPosts()
                        await appViewModel.loadVibes()
                        await appViewModel.loadFriendRequests()
                        await appViewModel.loadFriends()
                        await appViewModel.loadConnectionOfTheWeek()
                        await appViewModel.loadRatingHistory()
                        
                        // Load any pending support messages (responses to your check-in)
                        await appViewModel.loadPendingSupportMessages()
                        if appViewModel.pendingSupportMessage != nil {
                            await MainActor.run {
                                showSupportReceived = true
                            }
                            return // Show support first, don't check for other alerts
                        }
                        
                        // Load any pending check-in alerts from friends
                        await appViewModel.loadPendingCheckInAlerts()
                        if appViewModel.pendingCheckInAlert != nil {
                            await MainActor.run {
                                showCheckInAlert = true
                            }
                        }
                        
                        // Check if we should trigger a check-in
                        await checkForCheckIn()
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
            case "direct_message":
                // Refresh unread count and navigate to feed/messages tab
                Task {
                    await ConversationManager.shared.refreshUnreadCount()
                }
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToConversation"), object: nil)
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EvaluateCheckIn"))) { _ in
            print("🔍 CheckIn: Received EvaluateCheckIn notification")
            Task {
                await checkForCheckIn()
            }
        }
        .fullScreenCover(isPresented: $showCheckInWalkthrough) {
            CheckInWalkthroughView()
                .environmentObject(appViewModel)
        }
        .fullScreenCover(isPresented: $showCheckInAlert) {
            if let alert = appViewModel.pendingCheckInAlert {
                CheckInAlertView(
                    friendName: alert.senderName,
                    friendId: alert.senderId.uuidString,
                    onSendSupport: { message in
                        Task {
                            await appViewModel.sendCheckInResponse(to: alert.senderId.uuidString, message: message)
                            await appViewModel.markCheckInAlertAsRead(alert)
                            showCheckInAlert = false
                        }
                    },
                    onDismiss: {
                        Task {
                            await appViewModel.markCheckInAlertAsRead(alert)
                            showCheckInAlert = false
                        }
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showSupportReceived) {
            if let support = appViewModel.pendingSupportMessage {
                SupportReceivedView(
                    senderName: support.senderName,
                    message: support.message ?? "Thinking of you! 💙",
                    conversationId: support.conversationId,
                    onGoToChat: {
                        Task {
                            // Mark as read
                            await appViewModel.markSupportMessageAsRead(support)
                            
                            // Also mark chat messages as read
                            if let convId = support.conversationId {
                                await ConversationManager.shared.markAsRead(conversationId: convId)
                                navigateToConversationId = convId
                            }
                            
                            showSupportReceived = false
                            
                            // Navigate to messages tab and open conversation
                            NotificationCenter.default.post(
                                name: NSNotification.Name("NavigateToConversation"),
                                object: nil,
                                userInfo: ["conversationId": support.conversationId ?? ""]
                            )
                        }
                    },
                    onDismiss: {
                        Task {
                            await appViewModel.markSupportMessageAsRead(support)
                            
                            // Also mark chat messages as read when viewing support message
                            if let convId = support.conversationId {
                                await ConversationManager.shared.markAsRead(conversationId: convId)
                            }
                            
                            showSupportReceived = false
                        }
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $showDowngradeFlow) {
            DowngradeFlowView()
                .environmentObject(appViewModel)
                .interactiveDismissDisabled()
        }
        .fullScreenCover(isPresented: $showAmbassadorInvitation) {
            if let invitation = ambassadorInvitationManager.pendingInvitation {
                AmbassadorInvitationView(invitation: invitation) {
                    // On complete - refresh ambassador status
                    Task {
                        await premiumManager.checkAmbassadorStatus()
                    }
                }
            }
        }
    }
    
    // MARK: - Check-In Logic
    
    /// Checks if the user might need emotional support based on their recent ratings
    private func checkForCheckIn() async {
        print("🔍 CheckIn: Starting evaluation...")
        print("🔍 CheckIn: Rating history count: \(appViewModel.ratingHistory.count)")
        
        // Check if we should show a check-in
        if checkInManager.shouldTriggerCheckIn(ratings: appViewModel.ratingHistory) {
            print("✅ CheckIn: Showing walkthrough!")
            let bestFriendInfo = appViewModel.getBestFriendForCheckIn()
            
            await MainActor.run {
                checkInManager.startCheckIn(
                    hasBestFriend: bestFriendInfo.hasBestFriend,
                    bestFriendName: bestFriendInfo.bestFriendName
                )
                showCheckInWalkthrough = true
            }
        } else {
            print("🔍 CheckIn: No check-in needed")
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
