//
//  CreatePostView.swift
//  SocialTen
//

import SwiftUI

struct CreatePostView: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    var startOnPromptTab: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    @State private var caption: String = ""
    @State private var promptResponse: String = ""
    @State private var postType: PostType = .post
    
    // Character limits
    private let captionLimit = 280
    private let promptResponseLimit = 280
    
    enum PostType: String, CaseIterable {
        case post = "post"
        case prompt = "prompt"
    }
    
    var canPost: Bool {
        switch postType {
        case .post:
            return !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && caption.count <= captionLimit
        case .prompt:
            return !promptResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && promptResponse.count <= promptResponseLimit
        }
    }
    
    var headerTitle: String {
        switch postType {
        case .post: return "new post"
        case .prompt: return "today's prompt"
        }
    }
    
    var body: some View {
        ZStack {
            ThemeManager.shared.colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Text("cancel")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(ThemeManager.shared.colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Text(headerTitle)
                        .font(.system(size: 16, weight: .light))
                        .tracking(2)
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    
                    Spacer()
                    
                    Button(action: createPost) {
                        Text("post")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(canPost ? .white : ThemeManager.shared.colors.textTertiary)
                    }
                    .disabled(!canPost)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // Type selector (Post, Prompt)
                HStack(spacing: 0) {
                    ForEach(PostType.allCases, id: \.self) { type in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                postType = type
                            }
                        }) {
                            Text(type.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .tracking(1)
                                .foregroundColor(postType == type ? ThemeManager.shared.colors.textPrimary : ThemeManager.shared.colors.textTertiary)
                                .textCase(.uppercase)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    postType == type ?
                                    Color.white.opacity(0.05) : Color.clear
                                )
                        }
                    }
                }
                .background(ThemeManager.shared.colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                
                ScrollView {
                    VStack(spacing: 24) {
                        switch postType {
                        case .post:
                            PostInput(caption: $caption, limit: captionLimit)
                            
                        case .prompt:
                            PromptInput(prompt: viewModel.todaysPrompt, response: $promptResponse, limit: promptResponseLimit)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            if startOnPromptTab {
                postType = .prompt
            }
        }
    }
    
    func createPost() {
        Task { @MainActor in
            switch postType {
            case .post:
                let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
                await viewModel.createPost(
                    imageData: nil,
                    caption: trimmedCaption.isEmpty ? nil : trimmedCaption
                )
            case .prompt:
                await viewModel.createPost(imageData: nil, caption: nil, promptResponse: promptResponse)
            }
            dismiss()
        }
    }
}

// MARK: - Post Input (Caption only)

struct PostInput: View {
    @Binding var caption: String
    let limit: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("what's on your mind?")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(1)
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    .textCase(.uppercase)
                
                Spacer()
                
                Text("\(caption.count)/\(limit)")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(caption.count > limit ? .red : ThemeManager.shared.colors.textTertiary)
            }
            
            TextField("share a thought...", text: $caption, axis: .vertical)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(ThemeManager.shared.colors.textPrimary)
                .lineLimit(6...12)
                .onChange(of: caption) { _, newValue in
                    if newValue.count > limit {
                        caption = String(newValue.prefix(limit))
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ThemeManager.shared.colors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(caption.count > limit ? Color.red.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Prompt Input

struct PromptInput: View {
    let prompt: DailyPrompt
    @Binding var response: String
    let limit: Int
    
    var body: some View {
        VStack(spacing: 24) {
            // Prompt card
            VStack(spacing: 12) {
                Text("today's prompt")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(2)
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    .textCase(.uppercase)
                
                Text(prompt.text)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ThemeManager.shared.colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            
            // Response input
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("your response")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(1)
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        .textCase(.uppercase)
                    
                    Spacer()
                    
                    Text("\(response.count)/\(limit)")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(response.count > limit ? .red : ThemeManager.shared.colors.textTertiary)
                }
                
                TextField("type here...", text: $response, axis: .vertical)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    .lineLimit(3...6)
                    .onChange(of: response) { _, newValue in
                        if newValue.count > limit {
                            response = String(newValue.prefix(limit))
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ThemeManager.shared.colors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(response.count > limit ? Color.red.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
            }
        }
    }
}

#Preview {
    CreatePostView()
        .environmentObject(SupabaseAppViewModel())
}
