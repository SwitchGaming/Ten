//
//  OnboardingView.swift
//  SocialTen
//
//  Premium onboarding experience - Apple-inspired minimal design
//

import SwiftUI

// MARK: - Tutorial Manager

class TutorialManager: ObservableObject {
    static let shared = TutorialManager()
    
    @Published var hasSeenDoubleTapTutorial: Bool {
        didSet { UserDefaults.standard.set(hasSeenDoubleTapTutorial, forKey: "hasSeenDoubleTapTutorial") }
    }
    @Published var hasSeenVibeSwipeTutorial: Bool {
        didSet { UserDefaults.standard.set(hasSeenVibeSwipeTutorial, forKey: "hasSeenVibeSwipeTutorial") }
    }
    @Published var hasSeenRatingSwipeTutorial: Bool {
        didSet { UserDefaults.standard.set(hasSeenRatingSwipeTutorial, forKey: "hasSeenRatingSwipeTutorial") }
    }
    
    private init() {
        self.hasSeenDoubleTapTutorial = UserDefaults.standard.bool(forKey: "hasSeenDoubleTapTutorial")
        self.hasSeenVibeSwipeTutorial = UserDefaults.standard.bool(forKey: "hasSeenVibeSwipeTutorial")
        self.hasSeenRatingSwipeTutorial = UserDefaults.standard.bool(forKey: "hasSeenRatingSwipeTutorial")
    }
    
    func resetAllTutorials() {
        hasSeenDoubleTapTutorial = false
        hasSeenVibeSwipeTutorial = false
        hasSeenRatingSwipeTutorial = false
    }
}

// MARK: - Tutorial Overlay View

struct TutorialOverlay: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let icon: String
    let title: String
    let subtitle: String
    let onDismiss: () -> Void
    
    @State private var showContent = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            themeManager.colors.background.opacity(0.9)
                .ignoresSafeArea()
                .onTapGesture { dismissWithAnimation() }
            
            VStack(spacing: 32) {
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(themeManager.colors.accent2.opacity(0.3), lineWidth: 1)
                            .frame(width: 80 + CGFloat(index) * 30, height: 80 + CGFloat(index) * 30)
                            .scaleEffect(pulseScale)
                            .opacity(2.0 - pulseScale)
                            .animation(
                                .easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.3),
                                value: pulseScale
                            )
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(themeManager.colors.textPrimary)
                }
                .frame(height: 160)
                
                VStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(themeManager.colors.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(themeManager.colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                Button(action: dismissWithAnimation) {
                    Text("got it")
                        .font(.system(size: 14, weight: .medium))
                        .tracking(2)
                        .foregroundColor(themeManager.colors.background)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(themeManager.colors.textPrimary))
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)
            .padding(.horizontal, 40)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
            pulseScale = 1.5
        }
    }
    
    private func dismissWithAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            showContent = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Main Onboarding View

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var currentPage = 0
    @State private var pageDirection: Int = 1 // 1 = forward, -1 = back
    
    private let totalPages = 6
    
    var displayName: String {
        let name = authViewModel.pendingUsername.isEmpty ? "friend" : authViewModel.pendingUsername
        return name.lowercased()
    }
    
    var body: some View {
        ZStack {
            themeManager.colors.background.ignoresSafeArea()
            
            // Page content with custom transition
            Group {
                switch currentPage {
                case 0: WelcomePage(displayName: displayName)
                case 1: RatingPage()
                case 2: VibePage()
                case 3: TenFriendsPage()
                case 4: ConnectionPage()
                case 5: ReadyPage(onComplete: completeOnboarding)
                default: EmptyView()
                }
            }
            .id(currentPage)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(x: pageDirection > 0 ? 50 : -50)),
                removal: .opacity.combined(with: .offset(x: pageDirection > 0 ? -50 : 50))
            ))
            .animation(.easeInOut(duration: 0.4), value: currentPage)
            
            // Navigation overlay
            VStack {
                // Progress dots at top
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? themeManager.colors.textPrimary : themeManager.colors.accent3)
                            .frame(width: index == currentPage ? 8 : 6, height: index == currentPage ? 8 : 6)
                            .animation(.easeOut(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Bottom navigation (except on last page)
                if currentPage < totalPages - 1 {
                    HStack {
                        if currentPage > 0 {
                            Button(action: goBack) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundColor(themeManager.colors.textTertiary)
                                    .frame(width: 48, height: 48)
                            }
                        } else {
                            Spacer().frame(width: 48)
                        }
                        
                        Spacer()
                        
                        Button(action: goForward) {
                            HStack(spacing: 8) {
                                Text("continue")
                                    .font(.system(size: 14, weight: .medium))
                                    .tracking(1)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(themeManager.colors.background)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(themeManager.colors.textPrimary))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 50)
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 && currentPage < totalPages - 1 {
                        goForward()
                    } else if value.translation.width > 50 && currentPage > 0 {
                        goBack()
                    }
                }
        )
    }
    
    private func goForward() {
        pageDirection = 1
        withAnimation {
            currentPage += 1
        }
    }
    
    private func goBack() {
        pageDirection = -1
        withAnimation {
            currentPage -= 1
        }
    }
    
    func completeOnboarding() {
        TutorialManager.shared.resetAllTutorials()
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.easeInOut(duration: 0.5)) {
            isOnboardingComplete = true
        }
    }
}

// MARK: - Page 1: Welcome

struct WelcomePage: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let displayName: String
    
    @State private var showLogo = false
    @State private var showGreeting = false
    @State private var showTagline = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Logo
            Text("ten")
                .font(.system(size: 56, weight: .ultraLight))
                .tracking(12)
                .foregroundColor(themeManager.colors.textPrimary)
                .opacity(showLogo ? 1 : 0)
                .scaleEffect(showLogo ? 1 : 0.9)
            
            Spacer().frame(height: 80)
            
            // Greeting
            VStack(spacing: 16) {
                Text("hey, \(displayName)")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(themeManager.colors.textPrimary)
                    .opacity(showGreeting ? 1 : 0)
                    .offset(y: showGreeting ? 0 : 10)
                
                Text("welcome to real connection")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(themeManager.colors.textTertiary)
                    .opacity(showTagline ? 1 : 0)
                    .offset(y: showTagline ? 0 : 10)
            }
            
            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                showLogo = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
                showGreeting = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(1.0)) {
                showTagline = true
            }
        }
    }
}

// MARK: - Page 2: Rating

struct RatingPage: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var showCard = false
    @State private var showText = false
    @State private var displayRating: Int = 7
    @State private var ratingBounce: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Rating card (matches real SwipeableRatingCard styling)
            VStack(spacing: 16) {
                // Rating number
                Text("\(displayRating)")
                    .font(.system(size: 120, weight: .ultraLight))
                    .foregroundColor(themeManager.colors.textPrimary)
                    .offset(y: ratingBounce)
                    .contentTransition(.numericText())
                
                // Rating dots
                HStack(spacing: 8) {
                    ForEach(1...10, id: \.self) { i in
                        Circle()
                            .fill(i == displayRating ? themeManager.colors.accent1 : themeManager.colors.accent3.opacity(0.5))
                            .frame(width: i == displayRating ? 10 : 6, height: i == displayRating ? 10 : 6)
                            .animation(.spring(response: 0.3), value: displayRating)
                    }
                }
                
                Text("swipe to rate")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(themeManager.colors.textTertiary)
                    .padding(.top, 8)
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 32)
            .background(
                RoundedRectangle(cornerRadius: themeManager.radius.lg)
                    .fill(themeManager.colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: themeManager.radius.lg)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .opacity(showCard ? 1 : 0)
            .scaleEffect(showCard ? 1 : 0.95)
            .padding(.horizontal, 24)
            
            Spacer().frame(height: 48)
            
            // Text
            VStack(spacing: 12) {
                Text("rate your day")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(themeManager.colors.textPrimary)
                
                Text("see how your friends are doing\nat a glance. check in when\nthey need you most.")
                    .font(.system(size: 15, weight: .light))
                    .foregroundColor(themeManager.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .opacity(showText ? 1 : 0)
            .offset(y: showText ? 0 : 15)
            
            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                showCard = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                showText = true
            }
            startRatingAnimation()
        }
    }
    
    private func startRatingAnimation() {
        let sequence = [7, 8, 6, 9, 7]
        for (index, rating) in sequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.8 + 0.8) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    displayRating = rating
                    ratingBounce = -4
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                        ratingBounce = 0
                    }
                }
            }
        }
    }
}

// MARK: - Page 3: Vibe

struct VibePage: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var showCard = false
    @State private var showText = false
    @State private var showResponses = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Vibe card (matches real VibeCard styling)
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    // Sparkle icon
                    ZStack {
                        Circle()
                            .fill(themeManager.colors.accent2.opacity(0.15))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(themeManager.colors.accent2)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("coffee run ☕️")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(themeManager.colors.textPrimary)
                        
                        Text("in 15 min · downtown")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(themeManager.colors.textTertiary)
                    }
                    
                    Spacer()
                }
                
                // Response avatars
                HStack(spacing: -8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(themeManager.colors.surfaceLight)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(hex: "22C55E"))
                                    .opacity(showResponses ? 1 : 0)
                            )
                            .overlay(Circle().stroke(themeManager.colors.cardBackground, lineWidth: 2))
                            .scaleEffect(showResponses ? 1 : 0.8)
                            .opacity(showResponses ? 1 : 0.5)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.12), value: showResponses)
                    }
                    
                    Spacer()
                    
                    Text("3 in")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "22C55E"))
                        .opacity(showResponses ? 1 : 0)
                }
                .padding(.top, 8)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: themeManager.radius.lg)
                    .fill(themeManager.colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: themeManager.radius.lg)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .opacity(showCard ? 1 : 0)
            .scaleEffect(showCard ? 1 : 0.95)
            .padding(.horizontal, 24)
            
            Spacer().frame(height: 48)
            
            // Text
            VStack(spacing: 12) {
                Text("start a vibe")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(themeManager.colors.textPrimary)
                
                Text("create a hangout in seconds.\nfriends say \"i'm in\" or \"i can't\".\nno more group chat chaos.")
                    .font(.system(size: 15, weight: .light))
                    .foregroundColor(themeManager.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .opacity(showText ? 1 : 0)
            .offset(y: showText ? 0 : 15)
            
            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                showCard = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                showText = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                showResponses = true
            }
        }
    }
}

// MARK: - Page 4: Ten Friends

struct TenFriendsPage: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var showVisualization = false
    @State private var showText = false
    @State private var visibleFriends: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Friend circle visualization
            ZStack {
                ForEach(0..<10, id: \.self) { index in
                    let angle = Double(index) * (360.0 / 10.0) - 90
                    let radian = angle * .pi / 180
                    
                    Circle()
                        .fill(index < visibleFriends ? themeManager.colors.accent2 : themeManager.colors.accent3.opacity(0.3))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(index < visibleFriends ? themeManager.colors.background : themeManager.colors.textTertiary)
                        )
                        .offset(
                            x: CGFloat(cos(radian)) * 90,
                            y: CGFloat(sin(radian)) * 90
                        )
                        .scaleEffect(index < visibleFriends ? 1 : 0.7)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(index) * 0.08), value: visibleFriends)
                }
                
                // Center "you"
                Circle()
                    .fill(themeManager.colors.cardBackground)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Text("you")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(themeManager.colors.textPrimary)
                    )
                    .overlay(Circle().stroke(themeManager.colors.accent2.opacity(0.5), lineWidth: 2))
            }
            .frame(width: 240, height: 240)
            .opacity(showVisualization ? 1 : 0)
            
            Spacer().frame(height: 48)
            
            // Text
            VStack(spacing: 12) {
                Text("only ten friends")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(themeManager.colors.textPrimary)
                
                Text("this isn't about followers.\nit's about the people who matter.\nno noise. just connection.")
                    .font(.system(size: 15, weight: .light))
                    .foregroundColor(themeManager.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .opacity(showText ? 1 : 0)
            .offset(y: showText ? 0 : 15)
            
            Spacer().frame(height: 24)
            
            // Premium hint
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 11))
                Text("25 with ten+")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(themeManager.colors.accent2)
            .opacity(showText ? 0.7 : 0)
            
            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                showVisualization = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                showText = true
            }
            // Animate friends appearing
            for i in 1...10 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08 + 0.3) {
                    visibleFriends = i
                }
            }
        }
    }
}

// MARK: - Page 5: Connection of the Week

struct ConnectionPage: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var showAvatars = false
    @State private var showConnection = false
    @State private var showText = false
    @State private var leftOffset: CGFloat = -80
    @State private var rightOffset: CGFloat = 80
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Connection visualization
            ZStack {
                // Connection line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [themeManager.colors.accent2, Color(hex: "EC4899")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: showConnection ? 80 : 0, height: 2)
                    .opacity(showConnection ? 1 : 0)
                
                // You
                Circle()
                    .fill(themeManager.colors.cardBackground)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Text("you")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(themeManager.colors.textPrimary)
                    )
                    .overlay(Circle().stroke(themeManager.colors.accent2, lineWidth: 2))
                    .offset(x: leftOffset)
                
                // New connection
                Circle()
                    .fill(themeManager.colors.cardBackground)
                    .frame(width: 72, height: 72)
                    .overlay(
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(themeManager.colors.textSecondary)
                    )
                    .overlay(Circle().stroke(Color(hex: "EC4899"), lineWidth: 2))
                    .offset(x: rightOffset)
            }
            .frame(height: 100)
            .opacity(showAvatars ? 1 : 0)
            
            Spacer().frame(height: 24)
            
            // Weekly badge
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                Text("every week")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(themeManager.colors.textTertiary)
            .opacity(showConnection ? 1 : 0)
            
            Spacer().frame(height: 40)
            
            // Text
            VStack(spacing: 12) {
                Text("connection of the week")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(themeManager.colors.textPrimary)
                
                Text("each week, we pair you with\nsomeone new. take a chance\non a new friend.")
                    .font(.system(size: 15, weight: .light))
                    .foregroundColor(themeManager.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .opacity(showText ? 1 : 0)
            .offset(y: showText ? 0 : 15)
            
            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                showAvatars = true
            }
            
            // Slide avatars together
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    leftOffset = -55
                    rightOffset = 55
                }
            }
            
            // Show connection
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showConnection = true
                }
            }
            
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                showText = true
            }
        }
    }
}

// MARK: - Page 6: Ready

struct ReadyPage: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let onComplete: () -> Void
    
    @State private var showContent = false
    @State private var showButton = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 40) {
                // Feature recap
                VStack(spacing: 20) {
                    FeatureRow(icon: "hand.thumbsup", text: "rate your day")
                    FeatureRow(icon: "sparkles", text: "start vibes")
                    FeatureRow(icon: "person.2", text: "ten real friends")
                    FeatureRow(icon: "heart", text: "weekly connections")
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                
                Spacer().frame(height: 20)
                
                VStack(spacing: 12) {
                    Text("you're ready")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(themeManager.colors.textPrimary)
                    
                    Text("no algorithms. no clutter.\njust you and your people.")
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(themeManager.colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .opacity(showContent ? 1 : 0)
            }
            
            Spacer()
            
            // Get started button
            Button(action: onComplete) {
                Text("let's go")
                    .font(.system(size: 16, weight: .medium))
                    .tracking(2)
                    .foregroundColor(themeManager.colors.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(themeManager.colors.textPrimary)
                    )
            }
            .opacity(showButton ? 1 : 0)
            .scaleEffect(showButton ? 1 : 0.95)
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                showContent = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                showButton = true
            }
        }
    }
}

struct FeatureRow: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(themeManager.colors.accent2)
                .frame(width: 32)
            
            Text(text)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(themeManager.colors.textPrimary)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
        .environmentObject(AuthViewModel())
}
