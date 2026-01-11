import SwiftUI

/// View shown to a friend when they receive a check-in alert
/// Allows them to send quick supportive responses
struct CheckInAlertView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    let friendName: String
    let friendId: String
    var onSendSupport: ((String) -> Void)?
    var onDismiss: (() -> Void)?
    
    @State private var selectedResponse: QuickResponse?
    @State private var customMessage = ""
    @State private var isSending = false
    @State private var showSuccess = false
    
    private var colors: ThemeColors {
        themeManager.colors
    }
    
    var body: some View {
        ZStack {
            // Background - use theme colors
            colors.background.ignoresSafeArea()
            
            if showSuccess {
                successView
            } else {
                mainContent
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerView
                
                // Quick Response Cards
                quickResponsesSection
                
                // Custom Message Option
                customMessageSection
                
                // Send Button
                sendButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(colors.accent1.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "heart.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [colors.accent1, colors.accent2],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("\(friendName) might need some support")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(colors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Sometimes a small gesture makes a big difference.\nWould you like to reach out?")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Quick Responses
    
    private var quickResponsesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick responses")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colors.textTertiary)
                .padding(.leading, 4)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(CheckInManager.quickResponses) { response in
                    quickResponseCard(response)
                }
            }
        }
    }
    
    private func quickResponseCard(_ response: QuickResponse) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                if selectedResponse?.id == response.id {
                    selectedResponse = nil
                } else {
                    selectedResponse = response
                    customMessage = ""
                }
            }
        }) {
            VStack(spacing: 8) {
                Text(response.emoji)
                    .font(.system(size: 28))
                
                Text(response.shortText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(colors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedResponse?.id == response.id 
                          ? colors.accent1.opacity(0.2) 
                          : colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                selectedResponse?.id == response.id 
                                    ? colors.accent1.opacity(0.6) 
                                    : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
        }
    }
    
    // MARK: - Custom Message
    
    private var customMessageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Or write your own")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(colors.textTertiary)
                .padding(.leading, 4)
            
            TextEditor(text: $customMessage)
                .scrollContentBackground(.hidden)
                .foregroundColor(colors.textPrimary)
                .frame(minHeight: 80)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(colors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    !customMessage.isEmpty 
                                        ? colors.accent1.opacity(0.4) 
                                        : Color.clear,
                                    lineWidth: 1
                                )
                        )
                )
                .onChange(of: customMessage) { _, newValue in
                    if !newValue.isEmpty {
                        selectedResponse = nil
                    }
                }
        }
    }
    
    // MARK: - Send Button
    
    private var sendButton: some View {
        VStack(spacing: 12) {
            Button(action: sendMessage) {
                HStack(spacing: 8) {
                    if isSending {
                        ProgressView()
                            .tint(colors.textPrimary)
                    } else {
                        Image(systemName: "paperplane.fill")
                        Text("Send Message")
                    }
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        colors: canSend 
                            ? [colors.accent1, colors.accent2] 
                            : [colors.textTertiary.opacity(0.4), colors.textTertiary.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(28)
            }
            .disabled(!canSend || isSending)
            
            Button(action: { 
                onDismiss?()
                dismiss() 
            }) {
                Text("Maybe later")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(colors.textTertiary)
            }
        }
    }
    
    private var canSend: Bool {
        selectedResponse != nil || !customMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Success View
    
    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 12) {
                Text("Message sent!")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(colors.textPrimary)
                
                Text("Your support means a lot to \(friendName).")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Button(action: { 
                onDismiss?()
                dismiss() 
            }) {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(colors.accent1)
                    .cornerRadius(28)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        guard canSend else { return }
        
        isSending = true
        
        let messageToSend: String
        if let response = selectedResponse {
            messageToSend = response.fullMessage
        } else {
            messageToSend = customMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Call the closure if provided
        if let onSendSupport = onSendSupport {
            onSendSupport(messageToSend)
            withAnimation(.easeInOut(duration: 0.3)) {
                isSending = false
                showSuccess = true
            }
        } else {
            // Fallback - just show success
            withAnimation(.easeInOut(duration: 0.3)) {
                isSending = false
                showSuccess = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CheckInAlertView(friendName: "Sarah", friendId: "123")
}
