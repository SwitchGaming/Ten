//
//  FeedTab.swift
//  SocialTen
//

import SwiftUI

struct FeedTab: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @State private var showCreatePost = false
    
    var feedPosts: [Post] {
        viewModel.getFeedPosts()
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: ThemeManager.shared.spacing.xl) {
                // Header
                HStack {
                    Text("feed")
                        .font(ThemeManager.shared.fonts.title)
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                        .tracking(ThemeManager.shared.letterSpacing.wide)
                    
                    Spacer()
                    
                    Button(action: { showCreatePost = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(ThemeManager.shared.colors.textSecondary)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(ThemeManager.shared.colors.cardBackground)
                            )
                    }
                    .buttonStyle(PremiumButtonStyle())
                }
                .padding(.top, ThemeManager.shared.spacing.lg)
                .appearAnimation(delay: 0)
                
                // Posts
                if viewModel.isLoadingPosts && feedPosts.isEmpty {
                    // Loading state - only show when initially loading
                    FeedLoadingView()
                        .appearAnimation(delay: 0.1)
                } else if feedPosts.isEmpty {
                    EmptyFeedView(showCreatePost: $showCreatePost)
                        .appearAnimation(delay: 0.2)
                } else {
                    LazyVStack(spacing: ThemeManager.shared.spacing.lg) {
                        ForEach(Array(feedPosts.enumerated()), id: \.element.id) { index, post in
                            FeedPostCard(post: post)
                                .staggeredAnimation(index: index, baseDelay: 0.1)
                                .onAppear {
                                    // Load more when nearing the end
                                    if index == feedPosts.count - 3 {
                                        Task {
                                            await viewModel.loadMorePosts()
                                        }
                                    }
                                }
                        }
                        
                        // Loading indicator at bottom
                        if viewModel.hasMorePosts && !feedPosts.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: ThemeManager.shared.colors.textTertiary))
                                    .scaleEffect(0.8)
                                Spacer()
                            }
                            .padding(.vertical, ThemeManager.shared.spacing.md)
                        }
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
        }
        .background(ThemeManager.shared.colors.background.ignoresSafeArea())
        .refreshable {
            await viewModel.loadPosts()
        }
        .fullScreenCover(isPresented: $showCreatePost) {
            CreatePostView()
        }
        .onAppear {
            viewModel.markPostsAsSeen()
        }
    }
}

// MARK: - Enhanced Empty Feed View

struct EmptyFeedView: View {
    @Binding var showCreatePost: Bool
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: ThemeManager.shared.spacing.lg) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(ThemeManager.shared.colors.cardBackground)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 32, weight: .ultraLight))
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
            }
            
            VStack(spacing: 8) {
                Text("nothing here yet")
                    .font(ThemeManager.shared.fonts.body)
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                
                Text("share what's on your mind")
                    .font(ThemeManager.shared.fonts.caption)
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
            }
            
            Button(action: { showCreatePost = true }) {
                Text("create post")
                    .font(ThemeManager.shared.fonts.caption)
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    .padding(.horizontal, ThemeManager.shared.spacing.lg)
                    .padding(.vertical, ThemeManager.shared.spacing.sm)
                    .background(
                        Capsule()
                            .stroke(ThemeManager.shared.colors.textTertiary.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(PremiumButtonStyle())
            .padding(.top, ThemeManager.shared.spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ThemeManager.shared.spacing.xxl * 2)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Feed Loading View

struct FeedLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: ThemeManager.shared.spacing.xl) {
            // Skeleton post cards
            ForEach(0..<3, id: \.self) { index in
                SkeletonPostCard()
                    .opacity(isAnimating ? 0.6 : 0.3)
                    .animation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Skeleton Post Card

struct SkeletonPostCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.md) {
            // Header skeleton
            HStack(spacing: ThemeManager.shared.spacing.sm) {
                Circle()
                    .fill(ThemeManager.shared.colors.cardBackground)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ThemeManager.shared.colors.cardBackground)
                        .frame(width: 100, height: 12)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ThemeManager.shared.colors.cardBackground)
                        .frame(width: 60, height: 10)
                }
                
                Spacer()
            }
            
            // Content skeleton
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(ThemeManager.shared.colors.cardBackground)
                    .frame(height: 14)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(ThemeManager.shared.colors.cardBackground)
                    .frame(width: 200, height: 14)
            }
            
            // Actions skeleton
            HStack(spacing: ThemeManager.shared.spacing.lg) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(ThemeManager.shared.colors.cardBackground)
                    .frame(width: 50, height: 12)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(ThemeManager.shared.colors.cardBackground)
                    .frame(width: 50, height: 12)
            }
        }
        .padding(ThemeManager.shared.spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ThemeManager.shared.radius.lg)
                .fill(ThemeManager.shared.colors.cardBackground.opacity(0.3))
        )
    }
}

// MARK: - Feed Post Card

struct FeedPostCard: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    let post: Post
    
    @State private var showReplies = false
    @State private var replyText = ""
    
    var user: User? {
        viewModel.getUser(by: post.userId)
    }
    
    var isOwnPost: Bool {
        post.userId == viewModel.currentUserProfile?.id
    }
    
    var hasLiked: Bool {
        guard let userId = viewModel.currentUserProfile?.id else { return false }
        return post.plusOnes.contains { $0.userId == userId }
    }
    
    var body: some View {
        DepthCard(depth: .low) {
            VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.md) {
                // Header
                HStack(spacing: ThemeManager.shared.spacing.sm) {
                    Circle()
                        .fill(ThemeManager.shared.colors.background)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(user?.displayName.prefix(1) ?? "?").lowercased())
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(ThemeManager.shared.colors.textSecondary)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(user?.displayName.lowercased() ?? "unknown")
                                .font(ThemeManager.shared.fonts.body)
                                .foregroundColor(ThemeManager.shared.colors.textPrimary)
                            
                            if isOwnPost {
                                Text("· you")
                                    .font(ThemeManager.shared.fonts.caption)
                                    .foregroundColor(ThemeManager.shared.colors.accent2)
                            }
                        }
                        
                        Text(timeAgo(post.timestamp))
                            .font(ThemeManager.shared.fonts.caption)
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    }
                    
                    Spacer()
                    
                    // Show post's rating (rating at time of post creation)
                    if let rating = post.rating {
                        Text("\(rating)")
                            .font(.system(size: 20, weight: .ultraLight))
                            .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    }
                    
                    // Delete button for own posts
                    if isOwnPost {
                        Button(action: {
                            Task {
                                await viewModel.deletePost(post.id)
                            }
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(PremiumButtonStyle(hapticStyle: .medium))
                    }
                }
                
                // Prompt Response
                if let promptResponse = post.promptResponse {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(post.promptText ?? viewModel.todaysPrompt.text)
                            .font(ThemeManager.shared.fonts.caption)
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            .tracking(ThemeManager.shared.letterSpacing.wide)
                            .textCase(.uppercase)
                        
                        Text(promptResponse)
                            .font(ThemeManager.shared.fonts.body)
                            .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    }
                } else if let caption = post.caption {
                    Text(caption)
                        .font(ThemeManager.shared.fonts.body)
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                }
                
                // Actions
                HStack(spacing: ThemeManager.shared.spacing.lg) {
                    // Like
                    Button(action: {
                        Task {
                            await viewModel.toggleLike(for: post.id)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: hasLiked ? "heart.fill" : "heart")
                                .font(.system(size: 16))
                                .foregroundColor(hasLiked ? .red : ThemeManager.shared.colors.textSecondary)
                                .scaleEffect(hasLiked ? 1.1 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hasLiked)
                            
                            if post.plusOneCount > 0 {
                                Text("\(post.plusOneCount)")
                                    .font(ThemeManager.shared.fonts.caption)
                                    .foregroundColor(hasLiked ? .red : ThemeManager.shared.colors.textSecondary)
                            }
                        }
                    }
                    .buttonStyle(PremiumButtonStyle())
                    
                    // Reply
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showReplies.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 16))
                                .foregroundColor(ThemeManager.shared.colors.textSecondary)
                            
                            if post.replyCount > 0 {
                                Text("\(post.replyCount)")
                                    .font(ThemeManager.shared.fonts.caption)
                                    .foregroundColor(ThemeManager.shared.colors.textSecondary)
                            }
                        }
                    }
                    .buttonStyle(PremiumButtonStyle())
                    
                    Spacer()
                }
                
                // Replies Section
                if showReplies {
                    VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.sm) {
                        ForEach(Array(post.replies.enumerated()), id: \.element.id) { index, reply in
                            FeedReplyRow(reply: reply)
                                .staggeredAnimation(index: index, baseDelay: 0)
                        }
                        
                        // Reply input
                        HStack(spacing: ThemeManager.shared.spacing.sm) {
                            TextField("", text: $replyText)
                                .placeholder(when: replyText.isEmpty) {
                                    Text("reply...")
                                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                }
                                .font(ThemeManager.shared.fonts.caption)
                                .foregroundColor(ThemeManager.shared.colors.textPrimary)
                                .onChange(of: replyText) { _, newValue in
                                    if newValue.count > 200 {
                                        replyText = String(newValue.prefix(200))
                                    }
                                }
                                .padding(.horizontal, ThemeManager.shared.spacing.sm)
                                .padding(.vertical, ThemeManager.shared.spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: ThemeManager.shared.radius.full)
                                        .fill(ThemeManager.shared.colors.background)
                                )
                            
                            if !replyText.isEmpty {
                                HStack(spacing: 4) {
                                    Text("\(replyText.count)/200")
                                        .font(.system(size: 9))
                                        .foregroundColor(replyText.count > 200 ? .red : ThemeManager.shared.colors.textTertiary)
                                    
                                    Button(action: sendReply) {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(replyText.count <= 200 ? ThemeManager.shared.colors.accent1 : ThemeManager.shared.colors.textTertiary)
                                    }
                                    .disabled(replyText.count > 200)
                                }
                                .buttonStyle(PremiumButtonStyle())
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.spring(response: 0.3), value: replyText.isEmpty)
                        .animation(.spring(response: 0.3), value: replyText.isEmpty)
                    }
                    .padding(.top, ThemeManager.shared.spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(ThemeManager.shared.spacing.md)
        }
    }
    
    func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86400)d"
    }
    
    func sendReply() {
        Task {
            await viewModel.addReply(to: post.id, text: replyText)
            replyText = ""
        }
    }
}

// MARK: - Feed Reply Row

struct FeedReplyRow: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    let reply: Reply
    
    var user: User? {
        viewModel.getUser(by: reply.userId)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: ThemeManager.shared.spacing.sm) {
            Circle()
                .fill(ThemeManager.shared.colors.background)
                .frame(width: 28, height: 28)
                .overlay(
                    Text(String(user?.displayName.prefix(1) ?? "?").lowercased())
                        .font(.system(size: 10, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textSecondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user?.displayName.lowercased() ?? "unknown")
                    .font(ThemeManager.shared.fonts.caption)
                    .foregroundColor(ThemeManager.shared.colors.textSecondary)
                
                Text(reply.text)
                    .font(ThemeManager.shared.fonts.caption)
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    FeedTab()
        .environmentObject(SupabaseAppViewModel())
}
