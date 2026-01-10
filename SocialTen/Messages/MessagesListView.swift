//
//  MessagesListView.swift
//  SocialTen
//

import SwiftUI

struct MessagesListView: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @StateObject private var conversationManager = ConversationManager.shared
    @State private var selectedConversation: Conversation?
    @State private var showNewMessageSheet = false
    
    var body: some View {
        SmartScrollView {
            VStack(spacing: ThemeManager.shared.spacing.lg) {
                // Header with new message button
                HStack {
                    Text("messages")
                        .font(ThemeManager.shared.fonts.headline)
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                        .tracking(ThemeManager.shared.letterSpacing.wide)
                    
                    Spacer()
                    
                    Button(action: { showNewMessageSheet = true }) {
                        Image(systemName: "square.and.pencil")
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
                .padding(.top, ThemeManager.shared.spacing.sm)
                
                // Conversations list
                if conversationManager.isLoading && conversationManager.conversations.isEmpty {
                    MessagesLoadingView()
                } else if conversationManager.conversations.isEmpty {
                    EmptyMessagesView(showNewMessageSheet: $showNewMessageSheet)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(conversationManager.conversations) { conversation in
                            ConversationRow(
                                conversation: conversation,
                                friend: getFriend(for: conversation)
                            )
                            .onTapGesture {
                                selectedConversation = conversation
                            }
                            
                            if conversation.id != conversationManager.conversations.last?.id {
                                Divider()
                                    .background(ThemeManager.shared.colors.textTertiary.opacity(0.1))
                                    .padding(.leading, 68)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: ThemeManager.shared.radius.lg)
                            .fill(ThemeManager.shared.colors.cardBackground)
                    )
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
        }
        .refreshable {
            await conversationManager.loadConversations()
        }
        .fullScreenCover(item: $selectedConversation) { conversation in
            if let friend = getFriend(for: conversation) {
                ChatView(conversation: conversation, friend: friend)
                    .environmentObject(viewModel)
            }
        }
        .sheet(isPresented: $showNewMessageSheet) {
            NewMessageSheet(onSelectFriend: { friend in
                showNewMessageSheet = false
                Task {
                    if let conversationId = await conversationManager.getOrCreateConversation(with: friend.id) {
                        if let conversation = conversationManager.conversations.first(where: { $0.id == conversationId }) {
                            selectedConversation = conversation
                        } else {
                            // Create a temporary conversation object to open chat
                            let newConversation = Conversation(
                                id: conversationId,
                                participantIds: [viewModel.currentUserProfile?.id ?? "", friend.id]
                            )
                            selectedConversation = newConversation
                        }
                    }
                }
            })
            .environmentObject(viewModel)
            .presentationDetents([.medium, .large])
        }
    }
    
    private func getFriend(for conversation: Conversation) -> User? {
        guard let currentUserId = viewModel.currentUserProfile?.id,
              let friendId = conversation.otherParticipantId(currentUserId: currentUserId) else {
            return nil
        }
        return viewModel.friends.first { $0.id == friendId }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    let friend: User?
    
    @StateObject private var conversationManager = ConversationManager.shared
    
    private var isUnread: Bool {
        conversation.unreadCount > 0
    }
    
    private var timeAgo: String {
        guard let date = conversation.lastMessageAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var body: some View {
        HStack(spacing: ThemeManager.shared.spacing.md) {
            // Avatar with unread indicator
            ZStack(alignment: .topTrailing) {
                // Friend avatar
                if let friend = friend {
                    FriendAvatar(user: friend, size: 52)
                } else {
                    Circle()
                        .fill(ThemeManager.shared.colors.surfaceLight)
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        )
                }
                
                // Unread dot
                if isUnread {
                    Circle()
                        .fill(ThemeManager.shared.colors.accent1)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(ThemeManager.shared.colors.cardBackground, lineWidth: 2)
                        )
                        .offset(x: 2, y: -2)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(friend?.displayName ?? "Unknown")
                        .font(.system(size: 16, weight: isUnread ? .semibold : .medium))
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    
                    Spacer()
                    
                    Text(timeAgo)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                }
                
                HStack(spacing: 4) {
                    // Preview text
                    Text(conversation.lastMessagePreview ?? "Start a conversation")
                        .font(.system(size: 14, weight: isUnread ? .medium : .regular))
                        .foregroundColor(isUnread ? ThemeManager.shared.colors.textSecondary : ThemeManager.shared.colors.textTertiary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, ThemeManager.shared.spacing.md)
        .padding(.vertical, ThemeManager.shared.spacing.md)
        .contentShape(Rectangle())
    }
}

// MARK: - Friend Avatar

struct FriendAvatar: View {
    let user: User
    let size: CGFloat
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Get the user's theme color if they're premium, otherwise use current theme
    private var avatarColor: Color {
        user.isPremium ? user.selectedTheme.glowColor : themeManager.colors.accent2
    }
    
    private var backgroundColor: Color {
        user.isPremium ? user.selectedTheme.colors.cardBackground : themeManager.colors.cardBackground
    }
    
    var body: some View {
        ZStack {
            // Premium glow ring (only for premium users)
            if user.isPremium {
                Circle()
                    .fill(avatarColor)
                    .frame(width: size + 8, height: size + 8)
                    .blur(radius: 6)
                    .opacity(0.3)
                
                Circle()
                    .stroke(avatarColor.opacity(0.6), lineWidth: 1)
                    .frame(width: size + 4, height: size + 4)
            }
            
            Circle()
                .fill(backgroundColor)
                .frame(width: size, height: size)
            
            Text(user.displayName.prefix(1).lowercased())
                .font(.system(size: size * 0.4, weight: .light))
                .foregroundColor(avatarColor)
        }
        .frame(width: size + (user.isPremium ? 8 : 0), height: size + (user.isPremium ? 8 : 0))
    }
}

// MARK: - Empty Messages View

struct EmptyMessagesView: View {
    @Binding var showNewMessageSheet: Bool
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: ThemeManager.shared.spacing.lg) {
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
                Text("no messages yet")
                    .font(ThemeManager.shared.fonts.body)
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                
                Text("start a conversation with a friend")
                    .font(ThemeManager.shared.fonts.caption)
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
            }
            
            Button(action: { showNewMessageSheet = true }) {
                Text("new message")
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

// MARK: - Messages Loading View

struct MessagesLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                HStack(spacing: ThemeManager.shared.spacing.md) {
                    Circle()
                        .fill(ThemeManager.shared.colors.surfaceLight)
                        .frame(width: 52, height: 52)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ThemeManager.shared.colors.surfaceLight)
                            .frame(width: 120, height: 14)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(ThemeManager.shared.colors.surfaceLight)
                            .frame(width: 180, height: 12)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, ThemeManager.shared.spacing.md)
                .padding(.vertical, ThemeManager.shared.spacing.md)
                .opacity(isAnimating ? 0.6 : 0.3)
                .animation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.1),
                    value: isAnimating
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: ThemeManager.shared.radius.lg)
                .fill(ThemeManager.shared.colors.cardBackground)
        )
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - New Message Sheet

struct NewMessageSheet: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @Environment(\.dismiss) private var dismiss
    let onSelectFriend: (User) -> Void
    
    @State private var searchText = ""
    
    var filteredFriends: [User] {
        if searchText.isEmpty {
            return viewModel.friends
        }
        return viewModel.friends.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: ThemeManager.shared.spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    
                    TextField("Search friends", text: $searchText)
                        .font(ThemeManager.shared.fonts.body)
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                }
                .padding(ThemeManager.shared.spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                        .fill(ThemeManager.shared.colors.surfaceLight)
                )
                .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
                .padding(.vertical, ThemeManager.shared.spacing.md)
                
                // Friends list
                if filteredFriends.isEmpty {
                    VStack(spacing: ThemeManager.shared.spacing.md) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 40, weight: .ultraLight))
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        
                        Text(searchText.isEmpty ? "No friends yet" : "No matches found")
                            .font(ThemeManager.shared.fonts.body)
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredFriends) { friend in
                            Button(action: { onSelectFriend(friend) }) {
                                HStack(spacing: ThemeManager.shared.spacing.md) {
                                    FriendAvatar(user: friend, size: 44)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(friend.displayName)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(ThemeManager.shared.colors.textPrimary)
                                        
                                        Text("@\(friend.username)")
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(ThemeManager.shared.colors.background)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(ThemeManager.shared.colors.background)
            //.navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("new message")
                        .font(.system(size: 17, weight: .light))
                        .tracking(4)
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(ThemeManager.shared.colors.textSecondary)
                }
            }
        }
    }
}
