//
//  PremiumActivatedView.swift
//  SocialTen
//
//  Celebratory view shown when premium is activated
//

import SwiftUI

struct PremiumActivatedView: View {
    let username: String
    let referredByName: String?
    let onDismiss: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var premiumUserCount: Int = 100
    @State private var showContent = false
    @State private var showConfetti = false
    @State private var confettiParticles: [ConfettiParticle] = []
    
    var body: some View {
        ZStack {
            // Solid background with subtle gradient
            themeManager.colors.background
                .ignoresSafeArea()
            
            // Subtle accent gradient at top
            VStack {
                LinearGradient(
                    colors: [
                        themeManager.colors.accent1.opacity(0.15),
                        themeManager.colors.background.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 300)
                Spacer()
            }
            .ignoresSafeArea()
            
            // Confetti layer
            if showConfetti {
                ConfettiOverlay(particles: confettiParticles)
            }
            
            // Main content
            VStack(spacing: 32) {
                Spacer()
                
                // Animated crown/star icon
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(themeManager.colors.accent1.opacity(0.3))
                        .frame(width: 140, height: 140)
                        .blur(radius: 20)
                        .scaleEffect(showContent ? 1.2 : 0.8)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: showContent)
                    
                    // Icon background
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [themeManager.colors.accent1, themeManager.colors.accent2],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .shadow(color: themeManager.colors.accent1.opacity(0.5), radius: 20)
                    
                    // Plus icon
                    Text("✦")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                .scaleEffect(showContent ? 1 : 0.5)
                .opacity(showContent ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showContent)
                
                // Welcome message
                VStack(spacing: 16) {
                    Text("Welcome, \(username)!")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(themeManager.colors.textPrimary)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.3), value: showContent)
                    
                    // User count message
                    HStack(spacing: 4) {
                        Text("You've joined")
                            .foregroundColor(themeManager.colors.textSecondary)
                        Text("\(premiumUserCount)+")
                            .foregroundColor(themeManager.colors.accent1)
                            .fontWeight(.semibold)
                        Text("users on")
                            .foregroundColor(themeManager.colors.textSecondary)
                        Text("ten+")
                            .foregroundColor(themeManager.colors.accent1)
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 16, weight: .regular))
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.4), value: showContent)
                    
                    // Referred by message
                    if let referrer = referredByName {
                        HStack(spacing: 4) {
                            Text("Invited by")
                                .foregroundColor(themeManager.colors.textTertiary)
                            Text(referrer)
                                .foregroundColor(themeManager.colors.textSecondary)
                                .fontWeight(.medium)
                        }
                        .font(.system(size: 14, weight: .regular))
                        .padding(.top, 4)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.5), value: showContent)
                    }
                }
                
                Spacer()
                
                // Features unlocked
                VStack(spacing: 12) {
                    Text("unlocked".uppercased())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(themeManager.colors.textTertiary)
                        .tracking(2)
                    
                    HStack(spacing: 20) {
                        FeatureUnlockedBadge(icon: "paintpalette.fill", label: "Themes")
                        FeatureUnlockedBadge(icon: "person.3.fill", label: "25 Friends")
                        FeatureUnlockedBadge(icon: "chart.line.uptrend.xyaxis", label: "Insights")
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 30)
                .animation(.easeOut(duration: 0.5).delay(0.6), value: showContent)
                
                Spacer()
                
                // Continue button
                Button(action: onDismiss) {
                    Text("Let's go!")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [themeManager.colors.accent1, themeManager.colors.accent2],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                        .shadow(color: themeManager.colors.accent1.opacity(0.4), radius: 12, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 40)
                .animation(.easeOut(duration: 0.5).delay(0.8), value: showContent)
            }
        }
        .task {
            // Load premium user count
            premiumUserCount = await PremiumManager.shared.getPremiumUserCount()
            
            // Trigger animations
            withAnimation {
                showContent = true
            }
            
            // Generate confetti particles
            generateConfetti()
            
            // Show confetti after brief delay
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation {
                showConfetti = true
            }
        }
    }
    
    private func generateConfetti() {
        for i in 0..<60 {
            let particle = ConfettiParticle(
                id: i,
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: -20,
                color: [
                    themeManager.colors.accent1,
                    themeManager.colors.accent2,
                    Color.yellow,
                    Color.pink,
                    Color.purple,
                    Color.cyan
                ].randomElement()!,
                size: CGFloat.random(in: 6...12),
                rotation: Double.random(in: 0...360),
                delay: Double.random(in: 0...1)
            )
            confettiParticles.append(particle)
        }
    }
}

// MARK: - Feature Badge

struct FeatureUnlockedBadge: View {
    let icon: String
    let label: String
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(themeManager.colors.cardBackground)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(themeManager.colors.accent1.opacity(0.3), lineWidth: 1)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(themeManager.colors.accent1)
            }
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeManager.colors.textPrimary)
        }
    }
}

// MARK: - Confetti

struct ConfettiParticle: Identifiable {
    let id: Int
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let size: CGFloat
    var rotation: Double
    let delay: Double
}

struct ConfettiOverlay: View {
    let particles: [ConfettiParticle]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    ConfettiPiece(particle: particle, screenHeight: geo.size.height)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct ConfettiPiece: View {
    let particle: ConfettiParticle
    let screenHeight: CGFloat
    
    @State private var yOffset: CGFloat = 0
    @State private var xOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(particle.color)
            .frame(width: particle.size * 0.6, height: particle.size)
            .rotationEffect(.degrees(particle.rotation + rotation))
            .offset(x: particle.x + xOffset, y: particle.y + yOffset)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 3)
                    .delay(particle.delay)
                ) {
                    yOffset = screenHeight + 100
                    xOffset = CGFloat.random(in: -100...100)
                    rotation = Double.random(in: 360...720)
                }
                
                withAnimation(
                    .easeIn(duration: 1)
                    .delay(particle.delay + 2)
                ) {
                    opacity = 0
                }
            }
    }
}

// MARK: - Preview

#Preview {
    PremiumActivatedView(
        username: "joe",
        referredByName: "Sarah",
        onDismiss: {}
    )
}
