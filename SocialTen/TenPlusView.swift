//
//  TenPlusView.swift
//  SocialTen
//

import SwiftUI

struct TenPlusView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var premiumManager = PremiumManager.shared
    @State private var selectedThemeIndex = 0
    @State private var isAnimating = false
    @State private var showContent = false
    @State private var gradientRotation: Double = 0
    @State private var promoCode = ""
    @State private var promoCodeResult: PromoCodeResultState = .none
    @State private var particleSystem = ParticleSystem()
    @State private var showThemeSelector = false
    
    enum PromoCodeResultState: Equatable {
        case none
        case success(expiryDate: Date)
        case expired
        case alreadyRedeemed
        case invalid
    }
    
    private let hapticLight = UIImpactFeedbackGenerator(style: .light)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    
    let themes: [PremiumTheme] = [
        PremiumTheme(
            name: "midnight",
            description: "classic elegance",
            background: Color(hex: "050508"),
            accent: Color.white,
            secondary: Color(hex: "6366F1"),
            gradientColors: [Color(hex: "0f0f23"), Color(hex: "050508"), Color(hex: "1a1a2e")]
        ),
        PremiumTheme(
            name: "aurora",
            description: "northern lights",
            background: Color(hex: "0a0a1a"),
            accent: Color(hex: "22D3EE"),
            secondary: Color(hex: "A855F7"),
            gradientColors: [Color(hex: "0f172a"), Color(hex: "1e1b4b"), Color(hex: "0c4a6e")]
        ),
        PremiumTheme(
            name: "rose",
            description: "midnight bloom",
            background: Color(hex: "0f0a0a"),
            accent: Color(hex: "FB7185"),
            secondary: Color(hex: "E879F9"),
            gradientColors: [Color(hex: "1f0a1a"), Color(hex: "0f0a0a"), Color(hex: "2a0a1a")]
        ),
        PremiumTheme(
            name: "golden",
            description: "sunset warmth",
            background: Color(hex: "0a0806"),
            accent: Color(hex: "FBBF24"),
            secondary: Color(hex: "F97316"),
            gradientColors: [Color(hex: "1a1006"), Color(hex: "0a0806"), Color(hex: "1f1508")]
        ),
        PremiumTheme(
            name: "forest",
            description: "nature's calm",
            background: Color(hex: "050a08"),
            accent: Color(hex: "4ADE80"),
            secondary: Color(hex: "2DD4BF"),
            gradientColors: [Color(hex: "0a1a10"), Color(hex: "050a08"), Color(hex: "0f1f15")]
        ),
        PremiumTheme(
            name: "ocean",
            description: "deep blue",
            background: Color(hex: "040810"),
            accent: Color(hex: "38BDF8"),
            secondary: Color(hex: "818CF8"),
            gradientColors: [Color(hex: "0c1929"), Color(hex: "040810"), Color(hex: "0a1628")]
        )
    ]
    
    var currentTheme: PremiumTheme {
        themes[selectedThemeIndex]
    }
    
    var body: some View {
        Group {
            if premiumManager.isPremium {
                PremiumManagementView()
            } else {
                upsellView
            }
        }
    }
    
    var upsellView: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground(
                colors: currentTheme.gradientColors,
                rotation: gradientRotation
            )
            .ignoresSafeArea()
            
            // Floating particles
            ParticleView(particleSystem: particleSystem, color: currentTheme.accent)
                .ignoresSafeArea()
            
            SmartScrollView {
                VStack(spacing: 0) {
                    // Header
                    header
                    
                    // Hero Section with animated logo
                    heroSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 30)
                    
                    // Interactive Theme Preview
                    themePreviewSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 30)
                    
                    // Phone Mockup
                    phoneMockupSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 30)
                    
                    // Features
                    featuresSection
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 30)
                    
                    // Coming Soon Banner with email signup
                    comingSoonBanner
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 30)
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                showContent = true
            }
            
            // Start gradient animation
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                gradientRotation = 360
            }
            
            isAnimating = true
            hapticLight.prepare()
            hapticMedium.prepare()
        }
    }
    
    // MARK: - Header
    
    var header: some View {
        HStack {
            Button(action: {
                hapticLight.impactOccurred()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Hero Section
    
    var heroSection: some View {
        VStack(spacing: 24) {
            // Animated logo with glow
            ZStack {
                // Outer glow
                Text("ten")
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundColor(currentTheme.accent)
                    .blur(radius: 30)
                    .opacity(0.4)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                
                // Inner glow
                Text("ten")
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundColor(currentTheme.secondary)
                    .blur(radius: 15)
                    .opacity(0.5)
                
                // Main text
                Text("ten")
                    .font(.system(size: 72, weight: .ultraLight))
                    .foregroundColor(.white)
                
                // Plus sign with gradient
                Text("+")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [currentTheme.accent, currentTheme.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .offset(x: 55, y: -24)
                    .scaleEffect(isAnimating ? 1.05 : 0.95)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
            }
            .padding(.top, 40)
            
            // Tagline with gradient
            VStack(spacing: 8) {
                Text("unlock the full experience")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.white)
                
                Text("personalize · expand · connect")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [currentTheme.accent.opacity(0.8), currentTheme.secondary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
        .padding(.bottom, 48)
    }
    
    // MARK: - Theme Preview Section
        
    var themePreviewSection: some View {
        VStack(spacing: 24) {
            Text("choose your vibe")
                .font(.system(size: 12, weight: .semibold))
                .tracking(3)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
            
            // Theme selector - horizontal scroll with extra padding for glow
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<themes.count, id: \.self) { index in
                        PremiumThemeButton(
                            theme: themes[index],
                            isSelected: selectedThemeIndex == index
                        ) {
                            hapticMedium.impactOccurred()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                selectedThemeIndex = index
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20) // Add vertical padding for glow
            }
            
            // Theme name with animation
            VStack(spacing: 6) {
                Text(currentTheme.name)
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white)
                    .id(currentTheme.name)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                
                Text(currentTheme.description)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(currentTheme.accent.opacity(0.8))
            }
            .animation(.easeInOut(duration: 0.3), value: selectedThemeIndex)
        }
        .padding(.bottom, 32)
    }
    
    // MARK: - App Preview Section
        
    var phoneMockupSection: some View {
        VStack(spacing: 20) {
            Text("preview")
                .font(.system(size: 12, weight: .semibold))
                .tracking(3)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
            
            // Clean window preview
            AppPreviewWindow(theme: currentTheme)
                .padding(.horizontal, 24)
        }
        .padding(.bottom, 48)
    }
    
    // MARK: - Features Section
    
    var featuresSection: some View {
        VStack(spacing: 24) {
            Text("what you'll get")
                .font(.system(size: 12, weight: .semibold))
                .tracking(3)
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
            
            VStack(spacing: 12) {
                PremiumFeatureCard(
                    icon: "paintpalette.fill",
                    title: "6 Premium Themes",
                    description: "Beautiful color schemes that transform your entire app",
                    theme: currentTheme,
                    delay: 0
                )
                
                PremiumFeatureCard(
                    icon: "person.3.fill",
                    title: "Extended Circle",
                    description: "Connect with up to 25 friends instead of 10",
                    theme: currentTheme,
                    delay: 0.1
                )
                
                PremiumFeatureCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Mood Analytics",
                    description: "Track patterns and insights over time",
                    theme: currentTheme,
                    delay: 0.2
                )
                
                PremiumFeatureCard(
                    icon: "sparkles",
                    title: "Priority Vibes",
                    description: "Your vibes appear first for all your friends",
                    theme: currentTheme,
                    delay: 0.3
                )
                
                PremiumFeatureCard(
                    icon: "heart.circle.fill",
                    title: "Support Development",
                    description: "Help us build the future of meaningful connection",
                    theme: currentTheme,
                    delay: 0.4
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 48)
    }
    
    // MARK: - Promo Code / Premium Status Banner
    
    var comingSoonBanner: some View {
        VStack(spacing: 24) {
            if premiumManager.isPremium {
                // Premium active state
                premiumActiveView
            } else {
                // Promo code entry
                promoCodeEntryView
            }
        }
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                colors: [currentTheme.accent.opacity(0.3), currentTheme.secondary.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 20)
    }
    
    var premiumActiveView: some View {
        VStack(spacing: 20) {
            // Success icon with glow
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .opacity(isAnimating ? 0.5 : 0.8)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 8) {
                Text("ten+ active")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.white)
                
                if let daysRemaining = premiumManager.daysRemaining {
                    Text("\(daysRemaining) days remaining")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                if let expiryDate = premiumManager.expiryDateString {
                    Text("expires \(expiryDate)")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            // Theme selector button
            Button(action: {
                hapticMedium.impactOccurred()
                showThemeSelector = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 14))
                    Text("change theme")
                        .font(.system(size: 15, weight: .semibold))
                        .tracking(1)
                }
                .foregroundColor(currentTheme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [currentTheme.accent, currentTheme.secondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: currentTheme.accent.opacity(0.4), radius: 20, y: 10)
            }
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $showThemeSelector) {
            ThemeSelectorSheet()
        }
    }
    
    var promoCodeEntryView: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(currentTheme.accent.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .opacity(isAnimating ? 0.5 : 0.8)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                
                Circle()
                    .fill(currentTheme.accent.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "ticket.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [currentTheme.accent, currentTheme.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("have a promo code?")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.white)
                
                Text("enter your 6-character code to unlock ten+")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            // Result message
            if case .success(let expiryDate) = promoCodeResult {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("premium activated until \(formatDate(expiryDate))!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.2))
                        .overlay(
                            Capsule()
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
                .transition(.scale.combined(with: .opacity))
            } else {
                VStack(spacing: 12) {
                    // Promo code input
                    HStack {
                        Image(systemName: "ticket")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                        
                        TextField("", text: $promoCode)
                            .placeholder(when: promoCode.isEmpty) {
                                Text("enter code")
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .autocapitalization(.allCharacters)
                            .autocorrectionDisabled()
                            .onChange(of: promoCode) { _, newValue in
                                // Limit to 6 characters and uppercase
                                let filtered = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                                if filtered.count <= 6 {
                                    promoCode = filtered
                                } else {
                                    promoCode = String(filtered.prefix(6))
                                }
                                // Reset error state when typing
                                if promoCodeResult != .none && promoCodeResult != .success(expiryDate: Date()) {
                                    promoCodeResult = .none
                                }
                            }
                        
                        Text("\(promoCode.count)/6")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(promoCodeErrorBorderColor, lineWidth: 1)
                            )
                    )
                    
                    // Error message
                    if promoCodeResult == .invalid {
                        Text("invalid promo code")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                    } else if promoCodeResult == .expired {
                        Text("this code has expired")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    } else if promoCodeResult == .alreadyRedeemed {
                        Text("this code has already been redeemed")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    
                    // Submit button
                    Button(action: redeemCode) {
                        HStack(spacing: 8) {
                            Text("redeem")
                                .font(.system(size: 15, weight: .semibold))
                                .tracking(1)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(promoCode.count == 6 ? currentTheme.background : .white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Group {
                                if promoCode.count == 6 {
                                    LinearGradient(
                                        colors: [currentTheme.accent, currentTheme.secondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                } else {
                                    Color.white.opacity(0.1)
                                }
                            }
                        )
                        .clipShape(Capsule())
                        .shadow(color: promoCode.count == 6 ? currentTheme.accent.opacity(0.4) : .clear, radius: 20, y: 10)
                    }
                    .disabled(promoCode.count != 6)
                }
                .padding(.horizontal, 20)
            }
            
            // Fine print
            Text("codes are case-insensitive and expire on a set date")
                .font(.system(size: 11, weight: .light))
                .foregroundColor(.white.opacity(0.4))
                .padding(.top, 8)
        }
    }
    
    var promoCodeErrorBorderColor: Color {
        switch promoCodeResult {
        case .invalid, .expired, .alreadyRedeemed:
            return Color.red.opacity(0.5)
        default:
            return Color.white.opacity(0.1)
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    func redeemCode() {
        guard promoCode.count == 6 else { return }
        hapticMedium.impactOccurred()
        
        let result = premiumManager.redeemPromoCode(promoCode)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            switch result {
            case .success(let expiryDate):
                promoCodeResult = .success(expiryDate: expiryDate)
                haptic(.success)
            case .expired:
                promoCodeResult = .expired
                haptic(.error)
            case .alreadyRedeemed:
                promoCodeResult = .alreadyRedeemed
                haptic(.error)
            case .invalid:
                promoCodeResult = .invalid
                haptic(.error)
            }
        }
    }
}

// MARK: - Premium Theme Model

struct PremiumTheme {
    let name: String
    let description: String
    let background: Color
    let accent: Color
    let secondary: Color
    let gradientColors: [Color]
}

// MARK: - Premium Theme Button

struct PremiumThemeButton: View {
    let theme: PremiumTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    // Gradient circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [theme.accent, theme.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: isSelected ? 64 : 52, height: isSelected ? 64 : 52)
                    
                    // Selection ring
                    if isSelected {
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 72, height: 72)
                    }
                }
                .shadow(color: isSelected ? theme.accent.opacity(0.5) : .clear, radius: 16)
                
                // Theme name
                Text(theme.name)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))
            }
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - App Preview Window

struct AppPreviewWindow: View {
    let theme: PremiumTheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Window content
            VStack(spacing: 24) {
                // Rating section
                VStack(spacing: 12) {
                    Text("8")
                        .font(.system(size: 80, weight: .ultraLight))
                        .foregroundColor(.white)
                    
                    Text("friday")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(2)
                    
                    // Rating dots
                    HStack(spacing: 6) {
                        ForEach(1...10, id: \.self) { i in
                            Circle()
                                .fill(i == 8 ? theme.accent : Color.white.opacity(0.2))
                                .frame(width: i == 8 ? 10 : 6, height: i == 8 ? 10 : 6)
                                .shadow(color: i == 8 ? theme.accent.opacity(0.5) : .clear, radius: 4)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.top, 32)
                
                Spacer()
                
                // Vibe card
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [theme.accent.opacity(0.3), theme.secondary.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 18))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [theme.accent, theme.secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("dinner?")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        Text("tonight · 7pm")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    // Response indicators
                    HStack(spacing: -8) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(theme.background)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [theme.accent.opacity(0.3), theme.secondary.opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .overlay(
                                    Text("\(7 + i)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.8))
                                )
                        }
                        
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text("+2")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.green)
                            )
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [theme.accent.opacity(0.3), theme.secondary.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 340)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(theme.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.05),
                                theme.accent.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: theme.accent.opacity(0.15), radius: 40, y: 20)
            .shadow(color: Color.black.opacity(0.3), radius: 20, y: 10)
        }
    }
}
// MARK: - Premium Feature Card

struct PremiumFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let theme: PremiumTheme
    let delay: Double
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.accent.opacity(0.2), theme.secondary.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.accent, theme.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(theme.accent)
                .opacity(0.8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .scaleEffect(isVisible ? 1 : 0.95)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Animated Gradient Background

struct AnimatedGradientBackground: View {
    let colors: [Color]
    let rotation: Double
    
    var body: some View {
        ZStack {
            // Base color
            colors[1]
            
            // Animated blobs
            GeometryReader { geometry in
                ZStack {
                    // Blob 1
                    Circle()
                        .fill(colors[0])
                        .frame(width: geometry.size.width * 0.8)
                        .blur(radius: 80)
                        .offset(
                            x: cos(rotation * .pi / 180) * 100,
                            y: sin(rotation * .pi / 180) * 100 - geometry.size.height * 0.3
                        )
                        .opacity(0.6)
                    
                    // Blob 2
                    Circle()
                        .fill(colors[2])
                        .frame(width: geometry.size.width * 0.6)
                        .blur(radius: 60)
                        .offset(
                            x: sin(rotation * .pi / 180) * 80 + geometry.size.width * 0.2,
                            y: cos(rotation * .pi / 180) * 80 + geometry.size.height * 0.2
                        )
                        .opacity(0.5)
                }
            }
        }
    }
}

// MARK: - Particle System

struct ParticleSystem {
    var particles: [Particle] = (0..<20).map { _ in Particle() }
}

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat = CGFloat.random(in: 0...1)
    var y: CGFloat = CGFloat.random(in: 0...1)
    var scale: CGFloat = CGFloat.random(in: 0.5...1.5)
    var opacity: Double = Double.random(in: 0.1...0.4)
}

struct ParticleView: View {
    let particleSystem: ParticleSystem
    let color: Color
    
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(particleSystem.particles) { particle in
                Circle()
                    .fill(color)
                    .frame(width: 4 * particle.scale, height: 4 * particle.scale)
                    .position(
                        x: particle.x * geometry.size.width,
                        y: particle.y * geometry.size.height
                    )
                    .opacity(animate ? particle.opacity : particle.opacity * 0.5)
                    .animation(
                        .easeInOut(duration: Double.random(in: 2...4))
                        .repeatForever(autoreverses: true)
                        .delay(Double.random(in: 0...2)),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}

// MARK: - Theme Selector Sheet

struct ThemeSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var premiumManager = PremiumManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var selectedThemeId: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.colors.background.ignoresSafeArea()
                
                SmartScrollView {
                    VStack(spacing: 24) {
                        // Current theme indicator
                        VStack(spacing: 8) {
                            Text("current theme")
                                .font(.system(size: 12, weight: .medium))
                                .tracking(2)
                                .foregroundColor(themeManager.colors.textTertiary)
                                .textCase(.uppercase)
                            
                            Text(themeManager.currentTheme.name)
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(themeManager.colors.textPrimary)
                            
                            Text(themeManager.currentTheme.description)
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(themeManager.colors.accent2)
                        }
                        .padding(.top, 20)
                        
                        // Theme grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(AppTheme.allThemes) { theme in
                                ThemeCard(
                                    theme: theme,
                                    isSelected: themeManager.currentTheme.id == theme.id,
                                    isPremiumUser: premiumManager.isPremium
                                ) {
                                    if !theme.isPremium || premiumManager.isPremium {
                                        haptic(.medium)
                                        premiumManager.setTheme(theme.id)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationTitle("themes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.colors.accent2)
                }
            }
        }
    }
}

// MARK: - Theme Card

struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let isPremiumUser: Bool
    let action: () -> Void
    
    var isLocked: Bool {
        theme.isPremium && !isPremiumUser
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Color preview
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.colors.background)
                        .frame(height: 100)
                        .overlay(
                            VStack(spacing: 8) {
                                // Mini rating preview
                                Text("8")
                                    .font(.system(size: 32, weight: .ultraLight))
                                    .foregroundColor(theme.colors.textPrimary)
                                
                                // Accent dots
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(theme.colors.accent1)
                                        .frame(width: 8, height: 8)
                                    Circle()
                                        .fill(theme.colors.accent2)
                                        .frame(width: 8, height: 8)
                                    Circle()
                                        .fill(theme.colors.textSecondary)
                                        .frame(width: 8, height: 8)
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isSelected ? theme.colors.accent2 : Color.clear, lineWidth: 2)
                        )
                    
                    // Lock overlay for non-premium
                    if isLocked {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.6))
                            .overlay(
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.7))
                            )
                    }
                    
                    // Selection checkmark
                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(theme.colors.accent2)
                                    .background(Circle().fill(theme.colors.background).padding(-2))
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                }
                
                // Theme name
                VStack(spacing: 2) {
                    Text(theme.name.lowercased())
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    
                    if theme.isPremium {
                        Text("premium")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(ThemeManager.shared.colors.accent2)
                            .textCase(.uppercase)
                    }
                }
            }
        }
        .disabled(isLocked)
        .opacity(isLocked ? 0.6 : 1)
    }
}

// MARK: - Premium Management View

struct PremiumManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var premiumManager = PremiumManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var glowAnimation = false
    
    var body: some View {
        ZStack {
            themeManager.colors.background.ignoresSafeArea()
            
            SmartScrollView {
                VStack(spacing: 32) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(themeManager.colors.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(themeManager.colors.cardBackground)
                                )
                        }
                        
                        Spacer()
                        
                        Text("ten+")
                            .font(.system(size: 18, weight: .light))
                            .tracking(4)
                            .foregroundColor(themeManager.colors.textPrimary)
                        
                        Spacer()
                        
                        Color.clear.frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Premium Status Card
                    premiumStatusCard
                    
                    // Theme Selection
                    themeSelectionSection
                    
                    // Premium Features List
                    premiumFeaturesSection
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowAnimation = true
            }
        }
    }
    
    var premiumStatusCard: some View {
        VStack(spacing: 20) {
            // Animated premium badge
            ZStack {
                // Outer glow
                Circle()
                    .fill(themeManager.colors.accent2)
                    .frame(width: 80, height: 80)
                    .blur(radius: glowAnimation ? 25 : 15)
                    .opacity(glowAnimation ? 0.6 : 0.3)
                    .scaleEffect(glowAnimation ? 1.2 : 1.0)
                
                Circle()
                    .fill(themeManager.colors.accent2.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [themeManager.colors.accent1, themeManager.colors.accent2],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("premium active")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(themeManager.colors.textPrimary)
                
                if let daysRemaining = premiumManager.daysRemaining {
                    HStack(spacing: 4) {
                        Text("\(daysRemaining)")
                            .font(.system(size: 32, weight: .ultraLight))
                            .foregroundColor(themeManager.colors.accent2)
                        Text("days remaining")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(themeManager.colors.textSecondary)
                    }
                }
                
                if let expiryDate = premiumManager.expiryDateString {
                    Text("expires \(expiryDate)")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(themeManager.colors.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(themeManager.colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [themeManager.colors.accent2.opacity(0.3), themeManager.colors.accent2.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 20)
    }
    
    var themeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("theme")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(2)
                    .foregroundColor(themeManager.colors.textTertiary)
                    .textCase(.uppercase)
                
                Spacer()
                
                Text(themeManager.currentTheme.name.lowercased())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeManager.colors.accent2)
            }
            .padding(.horizontal, 20)
            
            // Horizontal theme scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AppTheme.allThemes) { theme in
                        PremiumThemeChip(
                            theme: theme,
                            isSelected: themeManager.currentTheme.id == theme.id
                        ) {
                            haptic(.medium)
                            premiumManager.setTheme(theme.id)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    var premiumFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("your benefits")
                .font(.system(size: 12, weight: .medium))
                .tracking(2)
                .foregroundColor(themeManager.colors.textTertiary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
            
            VStack(spacing: 1) {
                PremiumFeatureRow(icon: "paintpalette.fill", title: "Premium Themes", description: "6 beautiful color schemes", isActive: true)
                PremiumFeatureRow(icon: "person.3.fill", title: "Extended Circle", description: "Up to 25 friends", isActive: true)
                PremiumFeatureRow(icon: "sparkles", title: "Glowing Vibes", description: "Your vibes stand out", isActive: true)
                PremiumFeatureRow(icon: "wand.and.stars", title: "Premium Animations", description: "Enhanced visual effects", isActive: true)
            }
            .background(themeManager.colors.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Premium Theme Chip

struct PremiumThemeChip: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [theme.colors.accent1, theme.colors.accent2],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: isSelected ? 56 : 48, height: isSelected ? 56 : 48)
                    
                    if isSelected {
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 64, height: 64)
                    }
                }
                .shadow(color: isSelected ? theme.colors.accent2.opacity(0.5) : .clear, radius: 12)
                
                Text(theme.name.lowercased())
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? themeManager.colors.textPrimary : themeManager.colors.textTertiary)
            }
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: - Premium Feature Row

struct PremiumFeatureRow: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let icon: String
    let title: String
    let description: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(themeManager.colors.accent2)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(themeManager.colors.textPrimary)
                
                Text(description)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(themeManager.colors.textTertiary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    TenPlusView()
}
