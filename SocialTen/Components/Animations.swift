//
//  Animations.swift
//  SocialTen
//

import SwiftUI

// MARK: - Appear Animation Modifier

struct AppearAnimation: ViewModifier {
    @State private var isVisible = false
    let delay: Double
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func appearAnimation(delay: Double = 0) -> some View {
        modifier(AppearAnimation(delay: delay))
    }
}

// MARK: - Staggered List Animation

struct StaggeredListModifier: ViewModifier {
    let index: Int
    let baseDelay: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 15)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(baseDelay + Double(index) * 0.05)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func staggeredAnimation(index: Int, baseDelay: Double = 0.1) -> some View {
        modifier(StaggeredListModifier(index: index, baseDelay: baseDelay))
    }
}

// MARK: - Pulse Animation Modifier

struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false
    let duration: Double
    let minOpacity: Double
    let maxOpacity: Double
    
    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? maxOpacity : minOpacity)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func pulseAnimation(duration: Double = 1.5, minOpacity: Double = 0.5, maxOpacity: Double = 1.0) -> some View {
        modifier(PulseAnimation(duration: duration, minOpacity: minOpacity, maxOpacity: maxOpacity))
    }
}

// MARK: - Breathe Animation (subtle scale)

struct BreatheAnimation: ViewModifier {
    @State private var isBreathing = false
    let duration: Double
    let scale: CGFloat
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isBreathing ? scale : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
            }
    }
}

extension View {
    func breatheAnimation(duration: Double = 3.0, scale: CGFloat = 1.02) -> some View {
        modifier(BreatheAnimation(duration: duration, scale: scale))
    }
}

// MARK: - Shimmer Effect (for loading states)

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.1),
                        Color.white.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Glow Animation

struct GlowAnimation: ViewModifier {
    @State private var isGlowing = false
    let color: Color
    let radius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(isGlowing ? 0.6 : 0.2), radius: isGlowing ? radius : radius / 2)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    isGlowing = true
                }
            }
    }
}

extension View {
    func glowAnimation(color: Color = .white, radius: CGFloat = 10) -> some View {
        modifier(GlowAnimation(color: color, radius: radius))
    }
}

// MARK: - Slide Transition

extension AnyTransition {
    static var slideUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }
    
    static var slideFromTrailing: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    static var scaleAndFade: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        )
    }
}

// MARK: - Enhanced Button Style with Haptics

struct PremiumButtonStyle: ButtonStyle {
    let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle
    
    init(hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        self.hapticStyle = hapticStyle
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    UIImpactFeedbackGenerator(style: hapticStyle).impactOccurred()
                }
            }
    }
}

// MARK: - Card Hover Effect

struct CardHoverModifier: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(
                color: Color.black.opacity(isHovered ? 0.3 : 0.2),
                radius: isHovered ? 20 : 10,
                y: isHovered ? 10 : 5
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
                isHovered = pressing
            }, perform: {})
    }
}

extension View {
    func cardHoverEffect() -> some View {
        modifier(CardHoverModifier())
    }
}

// MARK: - Number Counter Animation

struct AnimatedCounter: View {
    let value: Int
    let font: Font
    let color: Color
    
    @State private var displayValue: Int = 0
    
    var body: some View {
        Text("\(displayValue)")
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText())
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    displayValue = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    displayValue = newValue
                }
            }
    }
}

// MARK: - Floating Animation

struct FloatingModifier: ViewModifier {
    @State private var isFloating = false
    let offset: CGFloat
    let duration: Double
    
    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? -offset : offset)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    isFloating = true
                }
            }
    }
}

extension View {
    func floatingAnimation(offset: CGFloat = 5, duration: Double = 2.0) -> some View {
        modifier(FloatingModifier(offset: offset, duration: duration))
    }
}
