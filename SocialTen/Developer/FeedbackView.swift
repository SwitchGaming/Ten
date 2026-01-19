//
//  FeedbackView.swift
//  SocialTen
//
//  User feedback submission view
//

import SwiftUI

// MARK: - Feedback Tag

enum FeedbackTag: String, CaseIterable {
    case bug = "bug"
    case enhancement = "enhancement"
    case general = "general"
    
    var icon: String {
        switch self {
        case .bug: return "ladybug.fill"
        case .enhancement: return "lightbulb.fill"
        case .general: return "bubble.left.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .bug: return Color(hex: "F87171")
        case .enhancement: return Color(hex: "FBBF24")
        case .general: return Color(hex: "60A5FA")
        }
    }
    
    var title: String {
        rawValue
    }
}

// MARK: - Feedback View

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var message: String = ""
    @State private var selectedTag: FeedbackTag? = nil
    @State private var isAnonymous: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var showSuccess: Bool = false
    @State private var errorMessage: String? = nil
    
    @FocusState private var isMessageFocused: Bool
    
    private var canSubmit: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedTag != nil
    }
    
    var body: some View {
        ZStack {
            themeManager.colors.background.ignoresSafeArea()
            
            if showSuccess {
                successView
            } else {
                feedbackForm
            }
        }
        .onTapGesture {
            isMessageFocused = false
        }
    }
    
    // MARK: - Feedback Form
    
    private var feedbackForm: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: themeManager.spacing.xl) {
                    // Tag Selection
                    tagSelection
                    
                    // Message Input
                    messageInput
                    
                    // Anonymous Toggle
                    anonymousToggle
                    
                    // Submit Button
                    submitButton
                }
                .padding(.horizontal, themeManager.spacing.screenHorizontal)
                .padding(.top, themeManager.spacing.lg)
                .padding(.bottom, 100)
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(themeManager.colors.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(themeManager.colors.cardBackground)
                    )
            }
            
            Spacer()
            
            Text("feedback")
                .font(themeManager.fonts.headline)
                .foregroundColor(themeManager.colors.textPrimary)
            
            Spacer()
            
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, themeManager.spacing.screenHorizontal)
        .padding(.top, themeManager.spacing.lg)
        .padding(.bottom, themeManager.spacing.md)
    }
    
    // MARK: - Tag Selection
    
    private var tagSelection: some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.sm) {
            Text("what's this about?")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(themeManager.colors.textSecondary)
            
            HStack(spacing: themeManager.spacing.sm) {
                ForEach(FeedbackTag.allCases, id: \.self) { tag in
                    TagButton(
                        tag: tag,
                        isSelected: selectedTag == tag,
                        action: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedTag = tag
                            }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Message Input
    
    private var messageInput: some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.sm) {
            HStack {
                Text("your message")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeManager.colors.textSecondary)
                
                Spacer()
                
                Text("\(message.count)/500")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(message.count > 500 ? .red : themeManager.colors.textTertiary)
            }
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $message)
                    .focused($isMessageFocused)
                    .font(.system(size: 16))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 150, maxHeight: 200)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: themeManager.radius.md)
                            .fill(themeManager.colors.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: themeManager.radius.md)
                            .stroke(isMessageFocused ? themeManager.colors.accent1.opacity(0.5) : Color.clear, lineWidth: 2)
                    )
                    .onChange(of: message) { _, newValue in
                        // Only check if last character is newline (more efficient)
                        if newValue.last == "\n" {
                            message = String(newValue.dropLast())
                            isMessageFocused = false
                            return
                        }
                        // Limit to 500 chars
                        if newValue.count > 500 {
                            message = String(newValue.prefix(500))
                        }
                    }
                
                if message.isEmpty {
                    Text("share your thoughts, report a bug, or suggest an improvement...")
                        .font(.system(size: 16))
                        .foregroundColor(themeManager.colors.textTertiary)
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    // MARK: - Anonymous Toggle
    
    private var anonymousToggle: some View {
        VStack(spacing: themeManager.spacing.md) {
            // Toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("send anonymously")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(themeManager.colors.textPrimary)
                    
                    Text(isAnonymous ? "your identity will be hidden" : "linked to your account")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isAnonymous)
                    .labelsHidden()
                    .tint(themeManager.colors.accent1)
            }
            .padding(themeManager.spacing.md)
            .background(
                RoundedRectangle(cornerRadius: themeManager.radius.md)
                    .fill(themeManager.colors.cardBackground)
            )
            
            // Info notice
            if !isAnonymous {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "FBBF24"))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("rewards for linked feedback!")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(themeManager.colors.textPrimary)
                        
                        Text("non-anonymous feedback may be rewarded with exclusive badges or themes.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: themeManager.radius.md)
                        .fill(Color(hex: "FBBF24").opacity(0.1))
                )
                
                // User info notice
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    
                    Text("your username (@\(viewModel.currentUser?.username ?? "you")) will be linked to this feedback.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Submit Button
    
    private var submitButton: some View {
        VStack(spacing: themeManager.spacing.sm) {
            Button(action: submitFeedback) {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14))
                        Text("submit feedback")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: themeManager.radius.md)
                        .fill(canSubmit ? themeManager.colors.accent1 : themeManager.colors.accent1.opacity(0.3))
                )
            }
            .disabled(!canSubmit || isSubmitting)
            
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red)
            }
            
            if selectedTag == nil {
                Text("please select a tag to continue")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Success View
    
    private var successView: some View {
        VStack(spacing: themeManager.spacing.xl) {
            Spacer()
            
            // Animated checkmark
            ZStack {
                Circle()
                    .fill(themeManager.colors.accent1.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .fill(themeManager.colors.accent1.opacity(0.3))
                    .frame(width: 90, height: 90)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(themeManager.colors.accent1)
            }
            .scaleEffect(showSuccess ? 1 : 0.5)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showSuccess)
            
            VStack(spacing: 8) {
                Text("thank you!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.colors.textPrimary)
                
                Text("your feedback helps us make ten better for everyone.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .opacity(showSuccess ? 1 : 0)
            .offset(y: showSuccess ? 0 : 20)
            .animation(.easeOut(duration: 0.4).delay(0.2), value: showSuccess)
            
            if !isAnonymous {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "FBBF24"))
                    Text("you may receive a reward!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "FBBF24"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(hex: "FBBF24").opacity(0.15))
                )
                .opacity(showSuccess ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.4), value: showSuccess)
            }
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Text("done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: themeManager.radius.md)
                            .fill(themeManager.colors.accent1)
                    )
            }
            .padding(.horizontal, themeManager.spacing.screenHorizontal)
            .padding(.bottom, 32)
            .opacity(showSuccess ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.5), value: showSuccess)
        }
    }
    
    // MARK: - Submit
    
    private func submitFeedback() {
        guard canSubmit, let tag = selectedTag else { return }
        
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                try await SupabaseManager.shared.client
                    .rpc("submit_feedback", params: [
                        "p_message": message.trimmingCharacters(in: .whitespacesAndNewlines),
                        "p_tag": tag.rawValue,
                        "p_is_anonymous": isAnonymous ? "true" : "false"
                    ])
                    .execute()
                
                await MainActor.run {
                    isSubmitting = false
                    withAnimation {
                        showSuccess = true
                    }
                }
            } catch {
                print("❌ Error submitting feedback: \(error)")
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Failed to submit. Please try again."
                }
            }
        }
    }
}

// MARK: - Tag Button

struct TagButton: View {
    let tag: FeedbackTag
    let isSelected: Bool
    let action: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tag.icon)
                    .font(.system(size: 12))
                Text(tag.title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : themeManager.colors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? tag.color : themeManager.colors.cardBackground)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : tag.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    FeedbackView()
}
