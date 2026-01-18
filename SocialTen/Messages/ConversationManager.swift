//
//  ConversationManager.swift
//  SocialTen
//

import SwiftUI
import Combine
import Supabase

// MARK: - Conversation Manager

@MainActor
class ConversationManager: ObservableObject {
    static let shared = ConversationManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var totalUnreadCount: Int = 0
    @Published private(set) var isLoading: Bool = false
    
    // Messages cache per conversation
    @Published private(set) var messagesCache: [String: [Message]] = [:]
    
    // Reactions cache per message
    @Published private(set) var reactionsCache: [String: [Reaction]] = [:]
    
    // MARK: - Private Properties
    
    private var messagesChannel: RealtimeChannelV2?
    private var reactionsChannel: RealtimeChannelV2?
    private var activeConversationId: String?
    private var currentUserId: String?
    
    /// Public read-only access to the currently active conversation
    var currentActiveConversationId: String? {
        return activeConversationId
    }
    
    // Cache keys
    private let conversationsCacheKey = "cachedConversations"
    private let unreadCountCacheKey = "cachedUnreadCount"
    
    // MARK: - Initialization
    
    private init() {
        loadFromCache()
    }
    
    // MARK: - Public API
    
    func setCurrentUser(_ userId: String) {
        currentUserId = userId
    }
    
    /// Load all conversations with unread counts (single efficient query)
    func loadConversations() async {
        guard currentUserId != nil else { return }
        
        isLoading = true
        
        do {
            let response: [DBConversation] = try await SupabaseManager.shared.client
                .rpc("get_conversations_with_unread")
                .execute()
                .value
            
            conversations = response.map { Conversation(from: $0) }
            
            // Calculate total unread
            totalUnreadCount = conversations.reduce(0) { $0 + $1.unreadCount }
            
            saveToCache()
            
            print("ConversationManager: Loaded \(conversations.count) conversations, \(totalUnreadCount) unread")
        } catch {
            print("ConversationManager: Error loading conversations - \(error)")
        }
        
        isLoading = false
    }
    
    /// Load messages for a conversation (paginated)
    func loadMessages(for conversationId: String, limit: Int = 50, before: Date? = nil) async -> [Message] {
        print("ConversationManager: loadMessages called for conversation: \(conversationId)")
        
        guard let convUUID = UUID(uuidString: conversationId) else {
            print("ConversationManager: Invalid conversation ID format: \(conversationId)")
            return []
        }
        
        do {
            let response: [DBMessage]
            
            if let beforeDate = before {
                // Paginated query - filter by date first
                response = try await SupabaseManager.shared.client
                    .from("messages")
                    .select()
                    .eq("conversation_id", value: convUUID)
                    .lt("created_at", value: ISO8601DateFormatter().string(from: beforeDate))
                    .order("created_at", ascending: false)
                    .limit(limit)
                    .execute()
                    .value
            } else {
                // Initial query - no date filter
                response = try await SupabaseManager.shared.client
                    .from("messages")
                    .select()
                    .eq("conversation_id", value: convUUID)
                    .order("created_at", ascending: false)
                    .limit(limit)
                    .execute()
                    .value
            }
            
            print("ConversationManager: Fetched \(response.count) messages from DB")
            
            let messages = response.map { Message(from: $0) }.reversed()
            
            // Update cache
            if before == nil {
                // Fresh load - replace cache
                messagesCache[conversationId] = Array(messages)
                print("ConversationManager: Cached \(messages.count) messages for \(conversationId)")
            } else {
                // Pagination - prepend older messages
                var existing = messagesCache[conversationId] ?? []
                existing.insert(contentsOf: messages, at: 0)
                messagesCache[conversationId] = existing
            }
            
            return Array(messages)
        } catch {
            print("ConversationManager: Error loading messages - \(error)")
            return []
        }
    }
    
    /// Send a message (optimistic update)
    func sendMessage(to recipientId: String, content: String, replyToId: String? = nil) async -> Message? {
        guard let senderId = currentUserId else {
            print("ConversationManager: No current user ID set")
            return nil
        }
        guard let recipientUUID = UUID(uuidString: recipientId) else {
            print("ConversationManager: Invalid recipient ID: \(recipientId)")
            return nil
        }
        
        print("ConversationManager: Sending message from \(senderId) to \(recipientId)")
        
        do {
            // Always include p_reply_to_id to avoid function overload ambiguity
            let params: [String: String?] = [
                "p_recipient_id": recipientUUID.uuidString,
                "p_content": content,
                "p_reply_to_id": replyToId.flatMap { UUID(uuidString: $0)?.uuidString }
            ]
            
            let response: [SendMessageResponse] = try await SupabaseManager.shared.client
                .rpc("send_message", params: params)
                .execute()
                .value
            
            print("ConversationManager: RPC response count: \(response.count)")
            
            guard let result = response.first else {
                print("ConversationManager: No result returned from send_message RPC")
                return nil
            }
            
            let message = Message(from: result)
            print("ConversationManager: Message sent successfully, ID: \(message.id)")
            
            // Update messages cache
            let convId = message.conversationId
            var messages = messagesCache[convId] ?? []
            messages.append(message)
            messagesCache[convId] = messages
            
            // Update conversation in list
            await updateConversationPreview(
                conversationId: convId,
                preview: content.prefix(50) + (content.count > 50 ? "..." : ""),
                senderId: senderId,
                timestamp: message.createdAt
            )
            
            // Send push notification for DM
            await sendDMNotification(to: recipientId, conversationId: convId, messagePreview: String(content.prefix(50)))
            
            return message
        } catch {
            print("ConversationManager: Error sending message - \(error)")
            return nil
        }
    }
    
    /// Mark all messages in conversation as read
    func markAsRead(conversationId: String) async {
        guard let convUUID = UUID(uuidString: conversationId) else { return }
        
        do {
            let _: Int = try await SupabaseManager.shared.client
                .rpc("mark_messages_read", params: ["p_conversation_id": convUUID.uuidString])
                .execute()
                .value
            
            // Update local state
            if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
                let previousUnread = conversations[index].unreadCount
                conversations[index].unreadCount = 0
                totalUnreadCount = max(0, totalUnreadCount - previousUnread)
            }
            
            // Update message statuses in cache
            if var messages = messagesCache[conversationId] {
                for i in messages.indices {
                    if messages[i].senderId != currentUserId && messages[i].status != .read {
                        messages[i].status = .read
                        messages[i].readAt = Date()
                    }
                }
                messagesCache[conversationId] = messages
            }
            
            saveToCache()
        } catch {
            print("ConversationManager: Error marking as read - \(error)")
        }
    }
    
    /// Get or create conversation with a user
    func getOrCreateConversation(with userId: String) async -> String? {
        guard let currentId = currentUserId,
              let currentUUID = UUID(uuidString: currentId),
              let otherUUID = UUID(uuidString: userId) else { return nil }
        
        do {
            let conversationId: UUID = try await SupabaseManager.shared.client
                .rpc("get_or_create_conversation", params: [
                    "user1_id": currentUUID.uuidString,
                    "user2_id": otherUUID.uuidString
                ])
                .execute()
                .value
            
            // Reload conversations to get the new/existing one
            await loadConversations()
            
            return conversationId.uuidString
        } catch {
            print("ConversationManager: Error getting/creating conversation - \(error)")
            return nil
        }
    }
    
    /// Refresh unread count (lightweight call for badge updates)
    func refreshUnreadCount() async {
        do {
            let count: Int = try await SupabaseManager.shared.client
                .rpc("get_total_unread_count")
                .execute()
                .value
            
            totalUnreadCount = count
            saveToCache()
        } catch {
            print("ConversationManager: Error refreshing unread count - \(error)")
        }
    }
    
    /// Delete a conversation for the current user (soft delete - only hides for this user)
    func deleteConversation(_ conversationId: String) async -> Bool {
        guard let convUUID = UUID(uuidString: conversationId) else { return false }
        
        do {
            let _: Bool = try await SupabaseManager.shared.client
                .rpc("delete_conversation_for_user", params: ["p_conversation_id": convUUID.uuidString])
                .execute()
                .value
            
            // Remove from local state
            conversations.removeAll { $0.id == conversationId }
            messagesCache.removeValue(forKey: conversationId)
            
            // Recalculate unread count
            totalUnreadCount = conversations.reduce(0) { $0 + $1.unreadCount }
            
            saveToCache()
            print("ConversationManager: Deleted conversation \(conversationId)")
            return true
        } catch {
            print("ConversationManager: Error deleting conversation - \(error)")
            return false
        }
    }
    
    // MARK: - Reactions
    
    /// Toggle reaction on a message (add/remove)
    func toggleReaction(messageId: String, emoji: String) async {
        guard let msgUUID = UUID(uuidString: messageId) else { return }
        
        do {
            let _: [ToggleReactionResponse] = try await SupabaseManager.shared.client
                .rpc("toggle_reaction", params: [
                    "p_message_id": msgUUID.uuidString,
                    "p_emoji": emoji
                ])
                .execute()
                .value
            
            print("ConversationManager: Toggled reaction \(emoji) on message \(messageId)")
        } catch {
            print("ConversationManager: Error toggling reaction - \(error)")
        }
    }
    
    /// Load reactions for messages in a conversation
    func loadReactions(for conversationId: String) async {
        guard let messages = messagesCache[conversationId] else { return }
        let messageIds = messages.map { $0.id }
        
        do {
            let response: [DBReaction] = try await SupabaseManager.shared.client
                .from("message_reactions")
                .select()
                .in("message_id", values: messageIds)
                .execute()
                .value
            
            // Group reactions by message
            var newReactionsCache = reactionsCache
            for msgId in messageIds {
                let msgReactions = response
                    .filter { $0.messageId.uuidString == msgId }
                    .map { Reaction(from: $0) }
                newReactionsCache[msgId] = msgReactions
            }
            reactionsCache = newReactionsCache
        } catch {
            print("ConversationManager: Error loading reactions - \(error)")
        }
    }
    
    /// Get reactions for a specific message
    func reactions(for messageId: String) -> [Reaction] {
        reactionsCache[messageId] ?? []
    }
    
    // MARK: - Realtime Subscriptions
    
    /// Subscribe to messages for active conversation
    func subscribeToMessages(conversationId: String) async {
        // Unsubscribe from previous if different
        if activeConversationId != conversationId {
            await unsubscribeFromMessages()
        }
        
        activeConversationId = conversationId
        
        guard let convUUID = UUID(uuidString: conversationId) else { return }
        
        messagesChannel = SupabaseManager.shared.client.realtimeV2.channel("messages-\(conversationId)")
        
        let insertions = messagesChannel!.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "conversation_id=eq.\(convUUID.uuidString)"
        )
        
        let updates = messagesChannel!.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "messages",
            filter: "conversation_id=eq.\(convUUID.uuidString)"
        )
        
        await messagesChannel!.subscribe()
        
        // Listen for new messages
        Task {
            for await insertion in insertions {
                await handleNewMessage(insertion, conversationId: conversationId)
            }
        }
        
        // Listen for status updates (delivered/read)
        Task {
            for await update in updates {
                await handleMessageUpdate(update, conversationId: conversationId)
            }
        }
        
        // Subscribe to reactions for this conversation's messages
        await subscribeToReactions(conversationId: conversationId)
        
        print("ConversationManager: Subscribed to messages for \(conversationId)")
    }
    
    /// Subscribe to reactions for messages in a conversation
    private func subscribeToReactions(conversationId: String) async {
        // Get message IDs in this conversation
        guard let messages = messagesCache[conversationId], !messages.isEmpty else { return }
        
        reactionsChannel = SupabaseManager.shared.client.realtimeV2.channel("reactions-\(conversationId)")
        
        // Listen for all reaction changes (we'll filter client-side)
        let insertions = reactionsChannel!.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "message_reactions"
        )
        
        let updates = reactionsChannel!.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "message_reactions"
        )
        
        let deletions = reactionsChannel!.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "message_reactions"
        )
        
        await reactionsChannel!.subscribe()
        
        // Handle new reactions
        Task {
            for await insertion in insertions {
                await handleNewReaction(insertion, conversationId: conversationId)
            }
        }
        
        // Handle updated reactions (user changed emoji)
        Task {
            for await update in updates {
                await handleUpdatedReaction(update, conversationId: conversationId)
            }
        }
        
        // Handle deleted reactions
        Task {
            for await deletion in deletions {
                await handleDeletedReaction(deletion, conversationId: conversationId)
            }
        }
    }
    
    /// Unsubscribe from message updates
    func unsubscribeFromMessages() async {
        if let channel = messagesChannel {
            await SupabaseManager.shared.client.realtimeV2.removeChannel(channel)
            messagesChannel = nil
        }
        if let channel = reactionsChannel {
            await SupabaseManager.shared.client.realtimeV2.removeChannel(channel)
            reactionsChannel = nil
        }
        activeConversationId = nil
        print("ConversationManager: Unsubscribed from messages and reactions")
    }
    
    // MARK: - Private Helpers
    
    private func handleNewMessage(_ insertion: InsertAction, conversationId: String) async {
        do {
            let dbMessage = try insertion.decodeRecord(as: DBMessage.self, decoder: JSONDecoder.supabaseDecoder)
            let message = Message(from: dbMessage)
            
            // Only add if not from current user (we already added it optimistically)
            if message.senderId != currentUserId {
                var messages = messagesCache[conversationId] ?? []
                
                // Avoid duplicates
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                    messagesCache[conversationId] = messages
                }
                
                // Auto-mark as read since user is actively viewing this conversation
                await markAsRead(conversationId: conversationId)
            }
        } catch {
            print("ConversationManager: Error decoding new message - \(error)")
        }
    }
    
    private func handleMessageUpdate(_ update: UpdateAction, conversationId: String) async {
        do {
            let dbMessage = try update.decodeRecord(as: DBMessage.self, decoder: JSONDecoder.supabaseDecoder)
            let updatedMessage = Message(from: dbMessage)
            
            print("ConversationManager: Received message update - ID: \(updatedMessage.id), Status: \(updatedMessage.status)")
            
            // Update message in cache
            if var messages = messagesCache[conversationId],
               let index = messages.firstIndex(where: { $0.id == updatedMessage.id }) {
                
                print("ConversationManager: Before update - message[\(index)] status: \(messages[index].status)")
                
                messages[index].status = updatedMessage.status
                messages[index].readAt = updatedMessage.readAt
                
                print("ConversationManager: After update - message[\(index)] status: \(messages[index].status)")
                
                // Force @Published to emit by reassigning the entire dictionary
                messagesCache[conversationId] = messages
                
                print("ConversationManager: Cache reassigned with updated status")
            }
        } catch {
            print("ConversationManager: Error decoding message update - \(error)")
        }
    }
    
    private func handleNewReaction(_ insertion: InsertAction, conversationId: String) async {
        do {
            let dbReaction = try insertion.decodeRecord(as: DBReaction.self, decoder: JSONDecoder.supabaseDecoder)
            let reaction = Reaction(from: dbReaction)
            
            // Only add if this message is in our conversation
            guard let messages = messagesCache[conversationId],
                  messages.contains(where: { $0.id == reaction.messageId }) else { return }
            
            var msgReactions = reactionsCache[reaction.messageId] ?? []
            
            // Remove any existing reaction from same user (one reaction per user)
            msgReactions.removeAll { $0.userId == reaction.userId }
            
            // Add new reaction
            msgReactions.append(reaction)
            reactionsCache[reaction.messageId] = msgReactions
            print("ConversationManager: Added reaction \(reaction.emoji) to message \(reaction.messageId)")
        } catch {
            print("ConversationManager: Error decoding new reaction - \(error)")
        }
    }
    
    private func handleUpdatedReaction(_ update: UpdateAction, conversationId: String) async {
        do {
            let dbReaction = try update.decodeRecord(as: DBReaction.self, decoder: JSONDecoder.supabaseDecoder)
            let reaction = Reaction(from: dbReaction)
            
            // Only handle if this message is in our conversation
            guard let messages = messagesCache[conversationId],
                  messages.contains(where: { $0.id == reaction.messageId }) else { return }
            
            var msgReactions = reactionsCache[reaction.messageId] ?? []
            
            // Update existing reaction
            if let index = msgReactions.firstIndex(where: { $0.userId == reaction.userId }) {
                msgReactions[index] = reaction
            } else {
                msgReactions.append(reaction)
            }
            
            reactionsCache[reaction.messageId] = msgReactions
            print("ConversationManager: Updated reaction to \(reaction.emoji) on message \(reaction.messageId)")
        } catch {
            print("ConversationManager: Error decoding updated reaction - \(error)")
        }
    }
    
    private func handleDeletedReaction(_ deletion: DeleteAction, conversationId: String) async {
        // Reload all reactions for this conversation since delete may not have full data
        await loadReactions(for: conversationId)
        print("ConversationManager: Reloaded reactions after deletion")
    }
    
    private func updateConversationPreview(conversationId: String, preview: String, senderId: String, timestamp: Date) async {
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[index].lastMessagePreview = String(preview)
            conversations[index].lastMessageSenderId = senderId
            conversations[index].lastMessageAt = timestamp
            conversations[index].updatedAt = timestamp
            
            // Re-sort conversations by updated_at
            conversations.sort { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
        } else {
            // New conversation - reload all
            await loadConversations()
        }
        
        saveToCache()
    }
    
    // MARK: - Cache Persistence
    
    private func saveToCache() {
        UserDefaults.standard.set(totalUnreadCount, forKey: unreadCountCacheKey)
        // Note: Full conversation cache could be added for offline support
    }
    
    private func loadFromCache() {
        totalUnreadCount = UserDefaults.standard.integer(forKey: unreadCountCacheKey)
    }
    
    /// Clear all data (for logout)
    func clearData() async {
        await unsubscribeFromMessages()
        conversations = []
        messagesCache = [:]
        totalUnreadCount = 0
        currentUserId = nil
        UserDefaults.standard.removeObject(forKey: conversationsCacheKey)
        UserDefaults.standard.removeObject(forKey: unreadCountCacheKey)
    }
    
    // MARK: - Push Notifications
    
    /// Sends a DM push notification to the recipient
    private func sendDMNotification(to recipientId: String, conversationId: String, messagePreview: String) async {
        guard let senderId = currentUserId else {
            print("❌ DM notification skipped: no currentUserId")
            return
        }
        
        print("📤 Attempting to send DM notification to \(recipientId)")
        
        // Get sender's display name - use raw query to avoid DBUser decoding issues
        do {
            struct DisplayNameResult: Codable {
                let displayName: String
                enum CodingKeys: String, CodingKey {
                    case displayName = "display_name"
                }
            }
            
            let response: [DisplayNameResult] = try await SupabaseManager.shared.client
                .from("users")
                .select("display_name")
                .eq("id", value: UUID(uuidString: senderId)!)
                .limit(1)
                .execute()
                .value
            
            guard let senderName = response.first?.displayName else {
                print("❌ DM notification skipped: could not get sender display name")
                return
            }
            
            print("📤 Sending DM notification from \(senderName) to \(recipientId)")
            
            // Call the edge function
            var body: [String: Any] = [
                "type": "direct_message",
                "userId": recipientId,
                "senderName": senderName,
                "data": [
                    "conversationId": conversationId,
                    "preview": messagePreview
                ]
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            
            try await SupabaseManager.shared.client.functions.invoke(
                "send-push-notification",
                options: FunctionInvokeOptions(body: jsonData)
            )
            
            print("✅ DM notification sent to \(recipientId)")
        } catch {
            print("❌ Error sending DM notification: \(error)")
        }
    }
}

// MARK: - JSON Decoder Extension

extension JSONDecoder {
    static var supabaseDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
        }
        return decoder
    }
}
