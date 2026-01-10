//
//  ChatView.swift
//  SocialTen
//

import SwiftUI

struct ChatView: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @ObservedObject private var conversationManager = ConversationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    let conversation: Conversation
    let friend: User
    
    @State private var messageText = ""
    @State private var isLoading = true
    @State private var scrollProxy: ScrollViewProxy?
    @State private var loadedMessages: [Message] = []
    @State private var replyingTo: Message? = nil
    @State private var showFriendProfile = false
    @State private var showDeleteConfirmation = false
    @State private var showMoreOptions = false
    @FocusState private var isInputFocused: Bool
    
    private var messages: [Message] {
        // Use local state for messages, updated after loading
        loadedMessages
    }
    
    private var currentUserId: String {
        viewModel.currentUserProfile?.id ?? ""
    }
    
    // Check if friend is still in friends list
    private var isFriend: Bool {
        viewModel.friends.contains { $0.id == friend.id }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Header
            chatHeader
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        if isLoading {
                            ProgressView()
                                .padding(.vertical, ThemeManager.shared.spacing.xl)
                        } else if messages.isEmpty {
                            emptyStateView
                        } else {
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                SwipeableMessageBubble(
                                    message: message,
                                    isFromCurrentUser: message.senderId == currentUserId,
                                    showReadReceipt: shouldShowReadReceipt(for: message),
                                    showTimestamp: shouldShowTimestamp(at: index),
                                    isFirstInGroup: isFirstInGroup(at: index),
                                    replyToMessage: getReplyMessage(for: message),
                                    friendName: friend.displayName,
                                    reactions: conversationManager.reactions(for: message.id),
                                    currentUserId: currentUserId,
                                    onReply: { replyingTo = message },
                                    onReact: { emoji in
                                        Task {
                                            await conversationManager.toggleReaction(messageId: message.id, emoji: emoji)
                                        }
                                    }
                                )
                                .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
                    .padding(.vertical, ThemeManager.shared.spacing.sm)
                }
                .onAppear {
                    scrollProxy = proxy
                }
                .onChange(of: messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }
            
            // Reply Preview
            if let replyMessage = replyingTo {
                replyPreviewBar(for: replyMessage)
            }
            
            // Input Bar
            messageInputBar
        }
        .background(ThemeManager.shared.colors.background.ignoresSafeArea())
        .task {
            // Load messages and subscribe to updates
            await loadMessagesAndSubscribe()
        }
        .onReceive(conversationManager.$messagesCache) { cache in
            // Sync local state when cache updates (from realtime)
            if let cachedMessages = cache[conversation.id] {
                // Always sync - handles new messages AND status updates
                loadedMessages = cachedMessages
            }
        }
        .onReceive(conversationManager.$reactionsCache) { _ in
            // Force view refresh when reactions change
            // The view will re-read reactions via conversationManager.reactions(for:)
        }
        .onDisappear {
            // Unsubscribe when leaving
            Task {
                await conversationManager.unsubscribeFromMessages()
            }
        }
    }
    
    // MARK: - Header
    
    private var chatHeader: some View {
        HStack(spacing: ThemeManager.shared.spacing.md) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(ThemeManager.shared.colors.textSecondary)
            }
            
            // Tappable avatar and name to view profile
            Button(action: { showFriendProfile = true }) {
                HStack(spacing: ThemeManager.shared.spacing.sm) {
                    FriendAvatar(user: friend, size: 36)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(friend.displayName.lowercased())
                            .font(.system(size: 15, weight: .light))
                            .tracking(ThemeManager.shared.letterSpacing.wide)
                            .foregroundColor(ThemeManager.shared.colors.textPrimary)
                        
                        if isFriend, let rating = friend.todayRating {
                            Text("feeling \(ratingText(rating))")
                                .font(.system(size: 11, weight: .light))
                                .tracking(ThemeManager.shared.letterSpacing.wide)
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        } else if !isFriend {
                            Text("not friends")
                                .font(.system(size: 11, weight: .light))
                                .tracking(ThemeManager.shared.letterSpacing.wide)
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // More options button
            Menu {
                Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                    Label("Delete Chat", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(ThemeManager.shared.colors.textSecondary)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
        .padding(.vertical, ThemeManager.shared.spacing.sm)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ThemeManager.shared.colors.accent3.opacity(0.15))
                .frame(height: 0.5)
        }
        .fullScreenCover(isPresented: $showFriendProfile) {
            UserProfileView(
                user: friend,
                isFriend: isFriend,
                showAddButton: !isFriend,
                onAddFriend: {
                    Task {
                        await viewModel.sendFriendRequest(toUserId: friend.id)
                    }
                },
                onRemoveFriend: nil
            )
            .environmentObject(viewModel)
        }
        .alert("Delete Chat", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    let success = await conversationManager.deleteConversation(conversation.id)
                    if success {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("This will permanently delete this conversation for you. The other person will still be able to see it.")
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: ThemeManager.shared.spacing.md) {
            Spacer()
            
            FriendAvatar(user: friend, size: 72)
            
            Text("start a conversation")
                .font(.system(size: 14))
                .foregroundColor(ThemeManager.shared.colors.textTertiary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, ThemeManager.shared.spacing.xxl * 2)
    }
    
    // MARK: - Reply Preview Bar
    
    private func replyPreviewBar(for message: Message) -> some View {
        HStack(spacing: ThemeManager.shared.spacing.sm) {
            // Accent bar
            RoundedRectangle(cornerRadius: 1)
                .fill(ThemeManager.shared.colors.accent1)
                .frame(width: 2, height: 28)
            
            VStack(alignment: .leading, spacing: 1) {
                Text((message.senderId == currentUserId ? "you" : friend.displayName.lowercased()))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(ThemeManager.shared.colors.textSecondary)
                
                Text(message.content)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Close button
            Button(action: { replyingTo = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
            }
        }
        .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
        .padding(.vertical, ThemeManager.shared.spacing.sm)
        .background(ThemeManager.shared.colors.cardBackground)
    }
    
    // MARK: - Input Bar
    
    private var messageInputBar: some View {
        VStack(spacing: 0) {
            // Top border
            Rectangle()
                .fill(ThemeManager.shared.colors.accent3.opacity(0.15))
                .frame(height: 0.5)
            
            if isFriend {
                // Normal message input
                HStack(spacing: ThemeManager.shared.spacing.sm) {
                    // Text field
                    TextField("message...", text: $messageText, axis: .vertical)
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                        .padding(.horizontal, ThemeManager.shared.spacing.md)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(ThemeManager.shared.colors.cardBackground)
                        )
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                    
                    // Send button
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? ThemeManager.shared.colors.textTertiary
                                : ThemeManager.shared.colors.background)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? ThemeManager.shared.colors.cardBackground
                                        : ThemeManager.shared.colors.accent1)
                            )
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
                .padding(.top, ThemeManager.shared.spacing.sm)
                .padding(.bottom, ThemeManager.shared.spacing.sm)
            } else {
                // Not friends - show add friend prompt
                VStack(spacing: ThemeManager.shared.spacing.sm) {
                    Text("you're no longer friends with \(friend.displayName.lowercased())")
                        .font(.system(size: 13, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    
                    Button(action: {
                        Task {
                            await viewModel.sendFriendRequest(toUserId: friend.id)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 12))
                            Text("add friend to message")
                                .font(.system(size: 13, weight: .regular))
                        }
                        .foregroundColor(ThemeManager.shared.colors.accent1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(ThemeManager.shared.colors.cardBackground)
                        )
                    }
                    .disabled(viewModel.sentFriendRequests.contains(friend.id))
                    .opacity(viewModel.sentFriendRequests.contains(friend.id) ? 0.5 : 1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ThemeManager.shared.spacing.md)
            }
        }
        .background(ThemeManager.shared.colors.background)
    }
    
    // MARK: - Actions
    
    private func loadMessagesAndSubscribe() async {
        isLoading = true
        
        // Load messages and update local state
        let fetchedMessages = await conversationManager.loadMessages(for: conversation.id)
        loadedMessages = fetchedMessages
        
        print("ChatView: Loaded \(fetchedMessages.count) messages for conversation \(conversation.id)")
        
        // Mark as read
        await conversationManager.markAsRead(conversationId: conversation.id)
        
        // Load reactions for these messages
        await conversationManager.loadReactions(for: conversation.id)
        
        // Subscribe to realtime updates
        await conversationManager.subscribeToMessages(conversationId: conversation.id)
        
        isLoading = false
        
        // Scroll to bottom after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let proxy = scrollProxy, let lastMessage = messages.last {
                withAnimation {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }
    
    private func sendMessage() {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        let replyId = replyingTo?.id
        messageText = ""
        replyingTo = nil
        isInputFocused = false
        
        Task {
            if let newMessage = await conversationManager.sendMessage(to: friend.id, content: content, replyToId: replyId) {
                // Only add if not already present (cache sync might have added it)
                if !loadedMessages.contains(where: { $0.id == newMessage.id }) {
                    loadedMessages.append(newMessage)
                }
                
                // Scroll to bottom
                if let proxy = scrollProxy {
                    withAnimation {
                        proxy.scrollTo(newMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private func getReplyMessage(for message: Message) -> Message? {
        guard let replyId = message.replyToId else { return nil }
        return messages.first { $0.id == replyId }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastMessage = messages.last else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
    
    private func shouldShowReadReceipt(for message: Message) -> Bool {
        // Only show read receipt for the last message sent by current user
        guard message.senderId == currentUserId else { return false }
        guard let lastSentIndex = messages.lastIndex(where: { $0.senderId == currentUserId }) else { return false }
        guard let messageIndex = messages.firstIndex(where: { $0.id == message.id }) else { return false }
        return messageIndex == lastSentIndex
    }
    
    // MARK: - Message Grouping
    
    private func shouldShowTimestamp(at index: Int) -> Bool {
        // Show timestamp if this is the last message in a group
        guard index < messages.count else { return true }
        
        let message = messages[index]
        
        // If it's the last message, always show timestamp
        if index == messages.count - 1 {
            return true
        }
        
        let nextMessage = messages[index + 1]
        
        // Show timestamp if next message is from different sender
        if nextMessage.senderId != message.senderId {
            return true
        }
        
        // Show timestamp if next message is more than 2 minutes apart
        let timeDiff = nextMessage.createdAt.timeIntervalSince(message.createdAt)
        if timeDiff > 120 { // 2 minutes
            return true
        }
        
        return false
    }
    
    private func isFirstInGroup(at index: Int) -> Bool {
        // Check if this is the first message in a group (for extra top spacing)
        guard index > 0 else { return true }
        
        let message = messages[index]
        let prevMessage = messages[index - 1]
        
        // First in group if previous message is from different sender
        if prevMessage.senderId != message.senderId {
            return true
        }
        
        // First in group if previous message is more than 2 minutes apart
        let timeDiff = message.createdAt.timeIntervalSince(prevMessage.createdAt)
        if timeDiff > 120 { // 2 minutes
            return true
        }
        
        return false
    }
    
    private func ratingText(_ rating: Int) -> String {
        switch rating {
        case 1...2: return "rough"
        case 3...4: return "low"
        case 5...6: return "okay"
        case 7...8: return "good"
        case 9...10: return "amazing"
        default: return ""
        }
    }
}

// MARK: - Swipeable Message Bubble

struct SwipeableMessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    let showReadReceipt: Bool
    let showTimestamp: Bool
    let isFirstInGroup: Bool
    let replyToMessage: Message?
    let friendName: String
    let reactions: [Reaction]
    let currentUserId: String
    let onReply: () -> Void
    let onReact: (String) -> Void
    
    @State private var offset: CGFloat = 0
    @State private var showReplyIcon = false
    @State private var showEmojiPicker = false
    
    private let swipeThreshold: CGFloat = 60
    private let quickReactionEmojis = ["❤️", "😂", "😮", "😢", "😡", "👍"]
    
    var body: some View {
        HStack(spacing: 8) {
            // Reply icon (appears on swipe)
            if !isFromCurrentUser {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ThemeManager.shared.colors.accent1)
                    .opacity(showReplyIcon ? 1 : 0)
                    .scaleEffect(showReplyIcon ? 1 : 0.5)
            }
            
            // Message content
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Reply quote (if replying to a message)
                if let replyMsg = replyToMessage {
                    replyQuote(for: replyMsg)
                }
                
                // Message bubble
                VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: -6) {
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundColor(isFromCurrentUser ? ThemeManager.shared.colors.background : ThemeManager.shared.colors.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(isFromCurrentUser
                                    ? ThemeManager.shared.colors.accent1
                                    : ThemeManager.shared.colors.cardBackground)
                        )
                        .onTapGesture(count: 2) {
                            // Double tap for heart
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            onReact("❤️")
                        }
                        .onLongPressGesture(minimumDuration: 0.4) {
                            // Long press for emoji picker
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            showEmojiPicker = true
                        }
                        .sheet(isPresented: $showEmojiPicker) {
                            emojiPickerSheet
                                .presentationDetents([.height(80)])
                                .presentationDragIndicator(.visible)
                                .presentationBackground(ThemeManager.shared.colors.cardBackground)
                        }
                    
                    // Reaction bubble floats below message
                    if !reactions.isEmpty {
                        HStack {
                            if isFromCurrentUser { Spacer() }
                            ReactionStackBubble(
                                groupedReactions: groupedReactions,
                                chipTextColor: ThemeManager.shared.colors.textTertiary,
                                tint: ThemeManager.shared.colors.cardBackground
                            ) { emoji in
                                onReact(emoji)
                            }
                            .padding(.leading, isFromCurrentUser ? 0 : 12)
                            .padding(.trailing, isFromCurrentUser ? 12 : 0)
                            if !isFromCurrentUser { Spacer() }
                        }
                    }
                }
                
                // Timestamp and status (only show for last message in group)
                if showTimestamp {
                    HStack(spacing: 4) {
                        Text(formatTime(message.createdAt))
                            .font(.system(size: 10))
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)

                        if isFromCurrentUser && showReadReceipt {
                            MessageStatusIcon(status: message.status)
                        }
                    }
                    .padding(.top, 0)
                }
            }
            .offset(x: offset)
            
            // Reply icon for current user messages
            if isFromCurrentUser {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 16))
                    .foregroundColor(ThemeManager.shared.colors.accent1)
                    .opacity(showReplyIcon ? 1 : 0)
                    .scaleEffect(showReplyIcon ? 1 : 0.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: isFromCurrentUser ? .trailing : .leading)
        .padding(.top, isFirstInGroup ? 8 : 1)
        .padding(.bottom, showTimestamp ? 2 : 1)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    let translation = value.translation.width
                    
                    // Allow swipe right for received, left for sent
                    if isFromCurrentUser {
                        // Swipe left to reply
                        if translation < 0 {
                            offset = max(translation, -swipeThreshold - 20)
                            withAnimation(.easeOut(duration: 0.1)) {
                                showReplyIcon = abs(translation) > swipeThreshold
                            }
                        }
                    } else {
                        // Swipe right to reply
                        if translation > 0 {
                            offset = min(translation, swipeThreshold + 20)
                            withAnimation(.easeOut(duration: 0.1)) {
                                showReplyIcon = translation > swipeThreshold
                            }
                        }
                    }
                }
                .onEnded { value in
                    let translation = value.translation.width
                    
                    // Trigger reply if threshold met
                    if (isFromCurrentUser && translation < -swipeThreshold) ||
                       (!isFromCurrentUser && translation > swipeThreshold) {
                        // Haptic feedback
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        
                        onReply()
                    }
                    
                    // Reset position
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = 0
                        showReplyIcon = false
                    }
                }
        )
    }
    
    // MARK: - Reactions View

    private var reactionsView: some View {
        ReactionStackBubble(
            groupedReactions: groupedReactions,
            chipTextColor: ThemeManager.shared.colors.textTertiary,
            tint: ThemeManager.shared.colors.cardBackground
        ) { emoji in
            onReact(emoji)
        }
    }

    private var groupedReactions: [(emoji: String, count: Int, hasCurrentUser: Bool)] {
        var grouped: [String: (count: Int, hasCurrentUser: Bool)] = [:]
        for reaction in reactions {
            let hasUser = reaction.userId == currentUserId
            if let existing = grouped[reaction.emoji] {
                grouped[reaction.emoji] = (existing.count + 1, existing.hasCurrentUser || hasUser)
            } else {
                grouped[reaction.emoji] = (1, hasUser)
            }
        }
        return grouped
            .map { (emoji: $0.key, count: $0.value.count, hasCurrentUser: $0.value.hasCurrentUser) }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Emoji Picker
    
    private var emojiPickerSheet: some View {
        HStack(spacing: 24) {
            ForEach(quickReactionEmojis, id: \.self) { emoji in
                Button(action: {
                    onReact(emoji)
                    showEmojiPicker = false
                }) {
                    Text(emoji)
                        .font(.system(size: 32))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }
    
    private func replyQuote(for replyMsg: Message) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1)
                .fill(isFromCurrentUser ? ThemeManager.shared.colors.background.opacity(0.5) : ThemeManager.shared.colors.accent1)
                .frame(width: 2)
            
            VStack(alignment: .leading, spacing: 1) {
                Text((replyMsg.senderId == (isFromCurrentUser ? message.senderId : "") ? "you" : friendName.lowercased()))
                    .font(.system(size: 10))
                    .foregroundColor(isFromCurrentUser ? ThemeManager.shared.colors.background.opacity(0.8) : ThemeManager.shared.colors.textSecondary)
                
                Text(replyMsg.content)
                    .font(.system(size: 11))
                    .foregroundColor(isFromCurrentUser ? ThemeManager.shared.colors.background.opacity(0.7) : ThemeManager.shared.colors.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isFromCurrentUser
                    ? ThemeManager.shared.colors.background.opacity(0.2)
                    : ThemeManager.shared.colors.surfaceLight)
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Reactions Bubble Subviews

private struct ReactionStackBubble: View {
    let groupedReactions: [(emoji: String, count: Int, hasCurrentUser: Bool)]
    let chipTextColor: Color
    let tint: Color
    let onTapEmoji: (String) -> Void

    init(
        groupedReactions: [(emoji: String, count: Int, hasCurrentUser: Bool)],
        chipTextColor: Color,
        tint: Color,
        onTapEmoji: @escaping (String) -> Void
    ) {
        self.groupedReactions = groupedReactions
        self.chipTextColor = chipTextColor
        self.tint = tint
        self.onTapEmoji = onTapEmoji
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(groupedReactions, id: \.emoji) { reaction in
                ReactionChip(
                    emoji: reaction.emoji,
                    count: reaction.count,
                    countColor: chipTextColor
                ) {
                    onTapEmoji(reaction.emoji)
                }
            }
        }
    }
}

private struct ReactionChip: View {
    let emoji: String
    let count: Int
    let countColor: Color
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Text(emoji)
                .font(.system(size: 14))
            if count > 1 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(countColor)
            }
        }
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Message Status Icon

struct MessageStatusIcon: View {
    let status: MessageStatus
    
    var body: some View {
        Group {
            switch status {
            case .sent:
                Image(systemName: "paperplane")
                    .font(.system(size: 9))
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
            case .delivered:
                Image(systemName: "eye.slash")
                    .font(.system(size: 10))
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
            case .read:
                Image(systemName: "eye")
                    .font(.system(size: 10))
                    .foregroundColor(ThemeManager.shared.colors.accent1)
            }
        }
    }
}

// MARK: - Conversation Extension for Identifiable

extension Conversation: Hashable {
    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
