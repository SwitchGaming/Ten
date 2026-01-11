import SwiftUI

/// View shown when a user receives a supportive message from a friend
struct SupportReceivedView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let senderName: String
    let message: String
    let conversationId: String?
    let onGoToChat: (() -> Void)?
    let onDismiss: () -> Void
    
    @State private var showContent = false
    @State private var heartScale: CGFloat = 0.5
    @State private var heartOpacity: Double = 0
    
    private var colors: ThemeColors {
        themeManager.colors
    }
    
    private var firstName: String {
        senderName.components(separatedBy: " ").first ?? senderName
    }
    
    var body: some View {
        ZStack {
            // Background
            colors.background.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Animated heart
                ZStack {
                    // Glow
                    Circle()
                        .fill(colors.accent1.opacity(0.2))
                        .frame(width: 140, height: 140)
                        .blur(radius: 30)
                        .scaleEffect(heartScale * 1.2)
                    
                    // Heart icon
                    Image(systemName: "heart.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [colors.accent1, colors.accent2],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(heartScale)
                        .opacity(heartOpacity)
                }
                
                if showContent {
                    VStack(spacing: 16) {
                        Text("\(senderName) sent you support")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(colors.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        // Message bubble
                        VStack(spacing: 12) {
                            Text("\"")
                                .font(.system(size: 48, weight: .ultraLight))
                                .foregroundColor(colors.accent1.opacity(0.5))
                                .offset(y: 10)
                            
                            Text(message)
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(colors.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 24)
                        }
                        .padding(.vertical, 24)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(colors.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(colors.accent1.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 24)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                Spacer()
                
                if showContent {
                    VStack(spacing: 12) {
                        // Primary action - Go to chat (if conversation exists)
                        if conversationId != nil, let onGoToChat = onGoToChat {
                            Button(action: onGoToChat) {
                                HStack(spacing: 8) {
                                    Image(systemName: "bubble.left.fill")
                                    Text("Go to chat")
                                }
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(colors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [colors.accent1, colors.accent2],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(28)
                            }
                        }
                        
                        // Secondary action - Dismiss
                        Button(action: onDismiss) {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                Text(conversationId != nil ? "Maybe later" : "Thanks, \(firstName)!")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(conversationId != nil ? colors.textSecondary : colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                conversationId != nil 
                                    ? AnyShapeStyle(colors.cardBackground)
                                    : AnyShapeStyle(LinearGradient(
                                        colors: [colors.accent1, colors.accent2],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            )
                            .cornerRadius(28)
                            .overlay(
                                RoundedRectangle(cornerRadius: 28)
                                    .stroke(conversationId != nil ? colors.textTertiary.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Animate heart
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2)) {
                heartScale = 1.0
                heartOpacity = 1.0
            }
            
            // Show content
            withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
                showContent = true
            }
        }
    }
}

#Preview {
    SupportReceivedView(
        senderName: "Sarah",
        message: "Hey! Just wanted you to know I'm thinking of you. You've got this! 💪",
        conversationId: "test-123",
        onGoToChat: {},
        onDismiss: {}
    )
}
