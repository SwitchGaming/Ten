//
//  HomeView.swift
//  SocialTen
//
//  Created on 12/3/25.
//

import SwiftUI

struct HomeView: View {
    var viewModel: AppViewModel
    @State private var showRatingPicker = false
    @State private var showCreatePost = false
    @State private var startOnPromptTab = false
// goat
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // Your rating card
                    YourRatingCard(viewModel: viewModel, showRatingPicker: $showRatingPicker)
                    
                    // Horizontal friends bar (like Instagram stories)
                    FriendsRatingBar(viewModel: viewModel)
                    
                    // Daily prompt
                    DailyPromptCard(viewModel: viewModel, showCreatePost: $showCreatePost, startOnPromptTab: $startOnPromptTab)
                    
                    // Feed
                    FeedSection(viewModel: viewModel)
                }
                .padding(.vertical, 24)
            }
            .background(ShadowTheme.background)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ten")
                        .font(.system(size: 20, weight: .light))
                        .tracking(4)
                        .foregroundColor(ShadowTheme.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        startOnPromptTab = false
                        showCreatePost = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(ShadowTheme.textSecondary)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCreatePost) {
                CreatePostView(viewModel: viewModel, startOnPromptTab: startOnPromptTab)
                    .onDisappear {
                        startOnPromptTab = false
                    }
            }
            .fullScreenCover(isPresented: $showRatingPicker) {
                RatingPickerSheet(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Your Rating Card

struct YourRatingCard: View {
    var viewModel: AppViewModel
    @Binding var showRatingPicker: Bool
    
    var glowColor: Color {
        viewModel.currentUser?.profileCustomization.glowColor.color ?? .white
    }
    
    var glowIntensity: Double {
        viewModel.currentUser?.profileCustomization.showGlow == true
            ? (viewModel.currentUser?.profileCustomization.glowIntensity ?? 0.3)
            : 0
    }
    
    var body: some View {
        VStack(spacing: 24) {
            if let rating = viewModel.currentUser?.todayRating {
                VStack(spacing: 16) {
                    Text("\(rating)")
                        .font(.system(size: 120, weight: .ultraLight))
                        .foregroundColor(ShadowTheme.textPrimary)
                        .shadow(color: glowColor.opacity(glowIntensity), radius: 20)
                    
                    Text("today")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(3)
                        .foregroundColor(ShadowTheme.textTertiary)
                        .textCase(.uppercase)
                }
            } else {
                VStack(spacing: 16) {
                    Text("—")
                        .font(.system(size: 100, weight: .ultraLight))
                        .foregroundColor(ShadowTheme.textTertiary)
                    
                    Text("tap to rate")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(2)
                        .foregroundColor(ShadowTheme.textTertiary)
                        .textCase(.uppercase)
                }
            }
            
            Button(action: { showRatingPicker = true }) {
                Text(viewModel.currentUser?.todayRating == nil ? "rate" : "update")
                    .font(.system(size: 14, weight: .medium))
                    .tracking(2)
                    .foregroundColor(ShadowTheme.textPrimary)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
            }
            .padding(.horizontal, 8)
        }
        .padding(32)
        .glassCard(glowColor: glowColor, glowIntensity: glowIntensity)
        .padding(.horizontal, 20)
    }
}

// MARK: - Horizontal Friends Rating Bar (Instagram Stories Style)

struct FriendsRatingBar: View {
    var viewModel: AppViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("friends")
                .font(.system(size: 12, weight: .medium))
                .tracking(2)
                .foregroundColor(ShadowTheme.textTertiary)
                .textCase(.uppercase)
                .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.friends.sorted { ($0.todayRating ?? 0) > ($1.todayRating ?? 0) }) { friend in
                        FriendRatingBubble(friend: friend)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
        }
    }
}

struct FriendRatingBubble: View {
    let friend: User
    
    var glowColor: Color {
        friend.profileCustomization.glowColor.color
    }
    
    var glowIntensity: Double {
        friend.profileCustomization.showGlow ? friend.profileCustomization.glowIntensity : 0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Avatar with rating inside
            Circle()
                .fill(ShadowTheme.surfaceLight)
                .frame(width: 56, height: 56)
                .overlay(
                    Group {
                        if let rating = friend.todayRating {
                            Text("\(rating)")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(ShadowTheme.textPrimary)
                        } else {
                            Text(String(friend.displayName.prefix(1)).lowercased())
                                .font(.system(size: 20, weight: .light))
                                .foregroundColor(ShadowTheme.textTertiary)
                        }
                    }
                )
                .overlay(
                    Circle()
                        .stroke(glowColor.opacity(glowIntensity * 0.6), lineWidth: 2)
                )
                .shadow(color: glowColor.opacity(glowIntensity * 0.3), radius: 8)
            
            // Name
            Text(friend.displayName.lowercased())
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(ShadowTheme.textTertiary)
                .lineLimit(1)
                .frame(width: 60)
        }
    }
}

// MARK: - Create Vibe Button

struct CreateVibeButton: View {
    @Binding var showCreateVibe: Bool
    
    var body: some View {
        Button(action: { showCreateVibe = true }) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(.purple.opacity(0.8))
                
                Text("start a vibe")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ShadowTheme.textSecondary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(ShadowTheme.textTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ShadowTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [.purple.opacity(0.3), .purple.opacity(0.1)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Vibes Section

struct VibesSection: View {
    var viewModel: AppViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.purple.opacity(0.8))
                
                Text("vibes")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(2)
                    .foregroundColor(ShadowTheme.textTertiary)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.getActiveVibes()) { vibe in
                        VibeCard(vibe: vibe, viewModel: viewModel)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Vibe Card

struct VibeCard: View {
    let vibe: Vibe
    var viewModel: AppViewModel
    
    var creator: User? {
        viewModel.getUser(by: vibe.userId)
    }
    
    var glowColor: Color {
        creator?.profileCustomization.glowColor.color ?? .purple
    }
    
    var isOwnVibe: Bool {
        vibe.userId == viewModel.currentUser?.id
    }
    
    var userResponse: VibeResponseType? {
        viewModel.getUserVibeResponse(for: vibe.id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(ShadowTheme.surfaceLight)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(creator?.displayName.prefix(1) ?? "?").lowercased())
                            .font(.system(size: 10, weight: .light))
                            .foregroundColor(ShadowTheme.textSecondary)
                    )
                    .overlay(
                        Circle()
                            .stroke(glowColor.opacity(0.4), lineWidth: 1)
                    )
                
                Text(creator?.displayName.lowercased() ?? "someone")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ShadowTheme.textSecondary)
                
                Spacer()
            }
            
            // Vibe Title
            Text(vibe.title)
                .font(.system(size: 20, weight: .light))
                .foregroundColor(ShadowTheme.textPrimary)
            
            // Time & Location
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10, weight: .light))
                    Text(vibe.timeDescription)
                        .font(.system(size: 11, weight: .regular))
                }
                .foregroundColor(ShadowTheme.textTertiary)
                
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .font(.system(size: 10, weight: .light))
                    Text(vibe.location)
                        .font(.system(size: 11, weight: .regular))
                }
                .foregroundColor(ShadowTheme.textTertiary)
            }
            
            // Response counts
            if vibe.yesCount > 0 || vibe.maybeCount > 0 {
                HStack(spacing: 12) {
                    if vibe.yesCount > 0 {
                        Text("\(vibe.yesCount) in")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.green.opacity(0.8))
                    }
                    if vibe.maybeCount > 0 {
                        Text("\(vibe.maybeCount) maybe")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange.opacity(0.8))
                    }
                }
            }
            
            // Response buttons (only if not your own vibe)
            if !isOwnVibe {
                HStack(spacing: 8) {
                    VibeResponseButton(
                        text: "yes",
                        isSelected: userResponse == .yes,
                        selectedColor: .green
                    ) {
                        viewModel.respondToVibe(vibe.id, response: .yes)
                    }
                    
                    VibeResponseButton(
                        text: "maybe",
                        isSelected: userResponse == .maybe,
                        selectedColor: .orange
                    ) {
                        viewModel.respondToVibe(vibe.id, response: .maybe)
                    }
                    
                    VibeResponseButton(
                        text: "no",
                        isSelected: userResponse == .no,
                        selectedColor: .red
                    ) {
                        viewModel.respondToVibe(vibe.id, response: .no)
                    }
                }
            } else {
                // Cancel button for own vibe
                Button(action: { viewModel.cancelVibe(vibe.id) }) {
                    Text("cancel vibe")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ShadowTheme.textTertiary)
                }
            }
        }
        .padding(16)
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ShadowTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [glowColor.opacity(0.3), glowColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: glowColor.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Vibe Response Button

struct VibeResponseButton: View {
    let text: String
    let isSelected: Bool
    let selectedColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? selectedColor : ShadowTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? selectedColor.opacity(0.15) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isSelected ? selectedColor.opacity(0.4) : Color.white.opacity(0.1),
                                    lineWidth: 1
                                )
                        )
                )
        }
    }
}

// MARK: - Daily Prompt Card

struct DailyPromptCard: View {
    var viewModel: AppViewModel
    @Binding var showCreatePost: Bool
    @Binding var startOnPromptTab: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("prompt")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(2)
                    .foregroundColor(ShadowTheme.textTertiary)
                    .textCase(.uppercase)
                
                Spacer()
                
                Text("today")
                    .font(.system(size: 10, weight: .light))
                    .foregroundColor(ShadowTheme.textTertiary)
            }
            .padding(.horizontal, 24)
            
            Button(action: {
                startOnPromptTab = true
                showCreatePost = true
            }) {
                HStack {
                    Text(viewModel.todaysPrompt.text)
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(ShadowTheme.textSecondary)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(ShadowTheme.textTertiary)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ShadowTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Feed Section

struct FeedSection: View {
    var viewModel: AppViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("feed")
                .font(.system(size: 12, weight: .medium))
                .tracking(2)
                .foregroundColor(ShadowTheme.textTertiary)
                .textCase(.uppercase)
                .padding(.horizontal, 24)
            
            if viewModel.getFeedPosts().isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundColor(ShadowTheme.textTertiary)
                    
                    Text("no posts yet")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(ShadowTheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.getFeedPosts()) { post in
                        PostCard(post: post, viewModel: viewModel)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Post Card

struct PostCard: View {
    let post: Post
    var viewModel: AppViewModel
    @State private var showReplies = false
    @State private var replyText = ""
    
    var user: User? {
        viewModel.getUser(by: post.userId)
    }
    
    var glowColor: Color {
        user?.profileCustomization.glowColor.color ?? .white
    }
    
    var glowIntensity: Double {
        user?.profileCustomization.showGlow == true ? (user?.profileCustomization.glowIntensity ?? 0.3) : 0
    }
    
    var hasPlusOned: Bool {
        guard let userId = viewModel.currentUser?.id else { return false }
        return post.plusOnes.contains { $0.userId == userId }
    }
    
    var plusOneNames: String {
        let names = post.plusOnes.compactMap { plusOne in
            viewModel.getUser(by: plusOne.userId)?.displayName
        }
        if names.isEmpty { return "" }
        if names.count == 1 { return names[0] }
        if names.count == 2 { return "\(names[0]) and \(names[1])" }
        return "\(names[0]), \(names[1]) +\(names.count - 2)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Circle()
                    .fill(ShadowTheme.surfaceLight)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(user?.displayName.prefix(1) ?? "?").lowercased())
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(ShadowTheme.textSecondary)
                    )
                    .overlay(
                        Circle()
                            .stroke(glowColor.opacity(glowIntensity * 0.5), lineWidth: 1)
                    )
                    .shadow(color: glowColor.opacity(glowIntensity * 0.3), radius: 6)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(user?.displayName.lowercased() ?? "unknown")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(ShadowTheme.textPrimary)
                    
                    Text(timeAgo(post.timestamp))
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(ShadowTheme.textTertiary)
                }
                
                Spacer()
                
                if let rating = user?.todayRating {
                    Text("\(rating)")
                        .font(.system(size: 22, weight: .ultraLight))
                        .foregroundColor(ShadowTheme.textPrimary)
                        .shadow(color: glowColor.opacity(glowIntensity * 0.4), radius: 6)
                }
            }
            
            // Content
            if let imageData = post.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            if let promptResponse = post.promptResponse {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.todaysPrompt.text)
                        .font(.system(size: 11, weight: .medium))
                        .tracking(1)
                        .foregroundColor(ShadowTheme.textTertiary)
                        .textCase(.uppercase)
                    
                    Text(promptResponse)
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(ShadowTheme.textPrimary)
                }
            } else if let caption = post.caption {
                Text(caption)
                    .font(.system(size: 15, weight: .light))
                    .foregroundColor(ShadowTheme.textPrimary)
            }
            
            // Reactions: +1 and Reply
            HStack(spacing: 24) {
                // +1 Button
                Button(action: { viewModel.togglePlusOne(for: post.id) }) {
                    HStack(spacing: 4) {
                        Text("+1")
                            .font(.system(size: 14, weight: hasPlusOned ? .semibold : .medium))
                            .foregroundColor(hasPlusOned ? .white : ShadowTheme.textSecondary)
                        
                        if post.plusOneCount > 0 {
                            Text("·")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(hasPlusOned ? .white.opacity(0.6) : ShadowTheme.textTertiary)
                            
                            Text("\(post.plusOneCount)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(hasPlusOned ? .white : ShadowTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(hasPlusOned ? Color.white.opacity(0.15) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(hasPlusOned ? 0.2 : 0.1), lineWidth: 1)
                            )
                    )
                }
                
                // Reply Button
                Button(action: { showReplies.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(ShadowTheme.textSecondary)
                        
                        if post.replyCount > 0 {
                            Text("\(post.replyCount)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(ShadowTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                
                Spacer()
            }
            
            // +1 names (if any)
            if post.plusOneCount > 0 {
                Text(plusOneNames)
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(ShadowTheme.textTertiary)
            }
            
            // Replies section
            if showReplies {
                VStack(alignment: .leading, spacing: 12) {
                    // Existing replies
                    ForEach(post.replies) { reply in
                        ReplyRow(reply: reply, viewModel: viewModel)
                    }
                    
                    // Reply input
                    HStack(spacing: 12) {
                        TextField("reply...", text: $replyText)
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(ShadowTheme.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(ShadowTheme.surfaceLight)
                            )
                        
                        if !replyText.isEmpty {
                            Button(action: {
                                viewModel.addReply(to: post.id, text: replyText)
                                replyText = ""
                            }) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 28, weight: .regular))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ShadowTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86400)d"
    }
}

// MARK: - Reply Row

struct ReplyRow: View {
    let reply: Reply
    var viewModel: AppViewModel
    
    var user: User? {
        viewModel.getUser(by: reply.userId)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(ShadowTheme.surfaceLight)
                .frame(width: 28, height: 28)
                .overlay(
                    Text(String(user?.displayName.prefix(1) ?? "?").lowercased())
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(ShadowTheme.textSecondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user?.displayName.lowercased() ?? "unknown")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(ShadowTheme.textSecondary)
                
                Text(reply.text)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(ShadowTheme.textPrimary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Rating Picker Sheet

struct RatingPickerSheet: View {
    var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRating: Double = 5
    @State private var lastHapticRating: Int = 5
    
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    var glowColor: Color {
        viewModel.currentUser?.profileCustomization.glowColor.color ?? .white
    }
    
    var body: some View {
        ZStack {
            ShadowTheme.background.ignoresSafeArea()
            
            VStack(spacing: 48) {
                // Close button
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(ShadowTheme.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                Spacer()
                
                VStack(spacing: 24) {
                    Text("\(Int(selectedRating))")
                        .font(.system(size: 160, weight: .ultraLight))
                        .foregroundColor(ShadowTheme.textPrimary)
                        .shadow(color: glowColor.opacity(0.4), radius: 30)
                        .animation(.spring(response: 0.3), value: selectedRating)
                    
                    Text("how was your day?")
                        .font(.system(size: 14, weight: .light))
                        .tracking(2)
                        .foregroundColor(ShadowTheme.textSecondary)
                }
                
                VStack(spacing: 16) {
                    // Custom minimal slider
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 2)
                            
                            // Progress
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.3))
                                .frame(width: geo.size.width * CGFloat((selectedRating - 1) / 9), height: 2)
                            
                            // Thumb
                            Circle()
                                .fill(ShadowTheme.cardBackground)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: glowColor.opacity(0.3), radius: 8)
                                .offset(x: geo.size.width * CGFloat((selectedRating - 1) / 9) - 12)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let percent = max(0, min(1, value.location.x / geo.size.width))
                                            let newRating = Double(round(percent * 9 + 1))
                                            
                                            // Trigger haptic when crossing to a new number
                                            if Int(newRating) != lastHapticRating {
                                                hapticFeedback.impactOccurred()
                                                lastHapticRating = Int(newRating)
                                            }
                                            
                                            selectedRating = newRating
                                        }
                                )
                        }
                        .frame(height: 24)
                    }
                    .frame(height: 24)
                    .padding(.horizontal, 40)
                    
                    HStack {
                        Text("1")
                        Spacer()
                        Text("10")
                    }
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(ShadowTheme.textTertiary)
                    .padding(.horizontal, 40)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: {
                        viewModel.updateRating(Int(selectedRating))
                        dismiss()
                    }) {
                        Text("save")
                            .font(.system(size: 14, weight: .medium))
                            .tracking(2)
                            .foregroundColor(ShadowTheme.textPrimary)
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                    
                    Button(action: { dismiss() }) {
                        Text("cancel")
                            .font(.system(size: 14, weight: .medium))
                            .tracking(2)
                            .foregroundColor(ShadowTheme.textSecondary)
                            .textCase(.uppercase)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            if let currentRating = viewModel.currentUser?.todayRating {
                selectedRating = Double(currentRating)
            }
        }
    }
}

#Preview {
    HomeView(viewModel: AppViewModel())
}
