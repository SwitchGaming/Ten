//
//  TenPlusView.swift
//  SocialTen
//

import SwiftUI

struct TenPlusView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedThemeIndex = 0
    @State private var isAnimating = false
    @State private var showContent = false
    @State private var gradientRotation: Double = 0
    @State private var email = ""
    @State private var isEmailSubmitted = false
    @State private var particleSystem = ParticleSystem()
    
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
            
            ScrollView(showsIndicators: false) {
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
    
    // MARK: - Coming Soon Banner
    
    var comingSoonBanner: some View {
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
                
                Image(systemName: "sparkles")
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
                Text("coming soon")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.white)
                
                Text("be the first to know when ten+ launches")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            // Email signup
            if isEmailSubmitted {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("you're on the list!")
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
                    // Email input
                    HStack {
                        Image(systemName: "envelope")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                        
                        TextField("", text: $email)
                            .placeholder(when: email.isEmpty) {
                                Text("enter your email")
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    
                    // Submit button
                    Button(action: submitEmail) {
                        HStack(spacing: 8) {
                            Text("notify me")
                                .font(.system(size: 15, weight: .semibold))
                                .tracking(1)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
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
                }
                .padding(.horizontal, 20)
            }
            
            // Fine print
            Text("no spam, just a single notification when we launch")
                .font(.system(size: 11, weight: .light))
                .foregroundColor(.white.opacity(0.4))
                .padding(.top, 8)
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
    
    func submitEmail() {
        guard !email.isEmpty else { return }
        hapticMedium.impactOccurred()
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            isEmailSubmitted = true
        }
        
        // TODO: Actually submit email to backend
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



#Preview {
    TenPlusView()
}
