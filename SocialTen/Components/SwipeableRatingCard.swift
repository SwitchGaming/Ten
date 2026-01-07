//
//  SwipeableRatingCard.swift
//  SocialTen
//

import SwiftUI

struct SwipeableRatingCard: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let rating: Int?
    var onRatingChanged: ((Int) -> Void)?
    
    @State private var displayRating: Int = 5
    @State private var dragOffset: CGFloat = 0
    @State private var isPressed = false
    @State private var showHint = true
    @State private var hasChangedRating = false
    @State private var showConfirmAnimation = false
    @State private var confirmRippleScale: CGFloat = 0.3
    @State private var confirmRippleOpacity: Double = 0
    @State private var particles: [ConfirmationParticle] = []
    @GestureState private var isDragging = false
    
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    private let confirmFeedbackGenerator = UINotificationFeedbackGenerator()
    private let dragThreshold: CGFloat = 50  // Points to drag for 1 rating change
    
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date()).lowercased()
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: Date()).lowercased()
    }
    
    var body: some View {
        DepthCard(depth: .medium) {
            ZStack {
                // Confirmation ripple animation (contained within card)
                Circle()
                    .fill(themeManager.colors.accent1.opacity(0.2))
                    .scaleEffect(confirmRippleScale)
                    .opacity(confirmRippleOpacity)
                
                // Particle effects
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .offset(x: particle.x, y: particle.y)
                        .opacity(particle.opacity)
                }
                
                VStack(spacing: 16) {
                    Spacer()
                        .frame(height: 20)
                    
                    // Rating number
                    Text("\(displayRating)")
                        .font(.system(size: 140, weight: .ultraLight))
                        .foregroundColor(showConfirmAnimation ? themeManager.colors.accent1 : themeManager.colors.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: displayRating)
                        .scaleEffect(showConfirmAnimation ? 1.15 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: showConfirmAnimation)
                    
                    // Date info
                    VStack(spacing: 4) {
                        Text(dayOfWeek)
                            .font(.system(size: 18, weight: .light))
                            .tracking(4)
                            .foregroundColor(themeManager.colors.textPrimary)
                        
                        Text(formattedDate)
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(themeManager.colors.textTertiary)
                    }
                    
                    // Rating dots indicator
                    HStack(spacing: 8) {
                        ForEach(1...10, id: \.self) { i in
                            Circle()
                                .fill(i == displayRating ? themeManager.colors.accent1 : themeManager.colors.accent3.opacity(0.5))
                                .frame(width: i == displayRating ? 10 : 6, height: i == displayRating ? 10 : 6)
                                .animation(.spring(response: 0.3), value: displayRating)
                        }
                    }
                    .padding(.top, 16)
                    
                    // Hint text
                    VStack(spacing: 4) {
                        if rating == nil && !hasChangedRating {
                            Text("how's your day going?")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(themeManager.colors.textSecondary)
                            
                            if showHint {
                                Text("swipe left or right to rate")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(themeManager.colors.textTertiary)
                            }
                        } else if hasChangedRating && displayRating != rating {
                            // Show double-tap to confirm hint
                            Text("double tap to confirm")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(themeManager.colors.accent2)
                                .transition(.opacity.combined(with: .scale))
                        } else if showHint && rating != nil {
                            Text("swipe to update your rating")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(themeManager.colors.textTertiary)
                        }
                    }
                    .padding(.top, 8)
                    .animation(.easeInOut(duration: 0.2), value: hasChangedRating)
                    .animation(.easeInOut(duration: 0.2), value: displayRating)
                    
                    Spacer()
                        .frame(height: 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
            }
            .clipped() // Contain animations within card bounds
        }
        .scaleEffect(isPressed || isDragging ? 0.98 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed || isDragging)
        .gesture(
            DragGesture()
                .updating($isDragging) { _, state, _ in
                    state = true
                }
                .onChanged { value in
                    let translation = value.translation.width
                    dragOffset = translation
                    
                    let ratingChange = Int(translation / dragThreshold)
                    let baseRating = rating ?? 5
                    let newRating = max(1, min(10, baseRating + ratingChange))
                    
                    if newRating != displayRating {
                        feedbackGenerator.impactOccurred()
                        displayRating = newRating
                        hasChangedRating = true
                    }
                }
                .onEnded { _ in
                    dragOffset = 0
                    if showHint {
                        withAnimation {
                            showHint = false
                        }
                    }
                }
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    if hasChangedRating && displayRating != rating {
                        confirmRating()
                    }
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.1)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .onAppear {
            if let rating = rating {
                displayRating = rating
            }
        }
        .onChange(of: rating) { _, newValue in
            if let newValue = newValue {
                displayRating = newValue
                hasChangedRating = false
            }
        }
    }
    
    private func confirmRating() {
        confirmFeedbackGenerator.notificationOccurred(.success)
        
        // Generate particles
        generateParticles()
        
        // Show confirmation animation
        withAnimation(.easeOut(duration: 0.15)) {
            showConfirmAnimation = true
        }
        
        // Ripple animation
        withAnimation(.easeOut(duration: 0.4)) {
            confirmRippleScale = 1.2
            confirmRippleOpacity = 0.5
        }
        
        // Fade out ripple
        withAnimation(.easeOut(duration: 0.3).delay(0.15)) {
            confirmRippleOpacity = 0
        }
        
        // Animate particles outward
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            animateParticles()
        }
        
        // Reset and save
        DispatchQueue.main.async {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showConfirmAnimation = false
                }
                confirmRippleScale = 0.3
                hasChangedRating = false
                
                // Save the rating
                onRatingChanged?(displayRating)
            }
            
            // Clear particles
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                particles.removeAll()
            }
        }
    }
    
    private func generateParticles() {
        particles.removeAll()
        let colors = [
            themeManager.colors.accent1,
            themeManager.colors.accent2,
            themeManager.colors.accent3,
            themeManager.colors.textPrimary.opacity(0.6)
        ]
        
        for i in 0..<12 {
            let angle = (Double(i) / 12.0) * 2 * .pi
            let particle = ConfirmationParticle(
                id: UUID(),
                x: 0,
                y: 0,
                targetX: CGFloat(cos(angle)) * CGFloat.random(in: 60...100),
                targetY: CGFloat(sin(angle)) * CGFloat.random(in: 60...100),
                size: CGFloat.random(in: 4...8),
                color: colors.randomElement() ?? themeManager.colors.accent1,
                opacity: 1.0
            )
            particles.append(particle)
        }
    }
    
    private func animateParticles() {
        for i in particles.indices {
            withAnimation(.easeOut(duration: 0.5)) {
                particles[i].x = particles[i].targetX
                particles[i].y = particles[i].targetY
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                particles[i].opacity = 0
            }
        }
    }
}

struct ConfirmationParticle: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    let targetX: CGFloat
    let targetY: CGFloat
    let size: CGFloat
    let color: Color
    var opacity: Double
}

#Preview {
    ZStack {
        ThemeManager.shared.colors.background.ignoresSafeArea()
        SwipeableRatingCard(rating: 7) { _ in }
    }
}
