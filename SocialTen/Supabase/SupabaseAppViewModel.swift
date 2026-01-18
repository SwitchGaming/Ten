//
//  SupabaseAppViewModel.swift
//  SocialTen
//

import Foundation
import Supabase
import WidgetKit

@MainActor
class SupabaseAppViewModel: ObservableObject {
    // Current user and social graph
    @Published var currentUser: DBUser?
    @Published var currentUserProfile: User?
    @Published var friends: [User] = []
    @Published var isLoading = false
    @Published var isLoadingPosts = true
    @Published var hasMorePosts = true
    private var postsPage = 0
    private let postsPerPage = 10
    
    // Friend request system
    @Published var friendRequests: [FriendRequest] = []
    @Published var sentFriendRequests: Set<String> = []  // User IDs we've sent requests to
    
    // Posts, vibes, rating history, prompt
    @Published var posts: [Post] = []
    @Published var vibes: [Vibe] = []
    @Published var ratingHistory: [RatingEntry] = []
    @Published var todaysPrompt: DailyPrompt = DailyPrompt(text: "what made you smile today?")
    
    // Activity tracking
    @Published var hasUnreadPosts: Bool = false
    @Published var hasUnreadVibes: Bool = false
    @Published var pendingRequestCount: Int = 0
    
    // Check-in alerts (received from friends)
    @Published var pendingCheckInAlert: InAppNotification?
    
    // Support messages received (responses to check-in alerts you sent)
    @Published var pendingSupportMessage: InAppNotification?
    
    // Connection of the week
    @Published var connectionOfTheWeek: ConnectionPairing?
    @Published var isLoadingConnection = false
    

    // Last seen timestamps (persisted in UserDefaults)
    private var lastSeenPostTimestamp: Date {
        get { UserDefaults.standard.object(forKey: "lastSeenPostTimestamp") as? Date ?? Date.distantPast }
        set { UserDefaults.standard.set(newValue, forKey: "lastSeenPostTimestamp") }
    }

    private var lastSeenVibeTimestamp: Date {
        get { UserDefaults.standard.object(forKey: "lastSeenVibeTimestamp") as? Date ?? Date.distantPast }
        set { UserDefaults.standard.set(newValue, forKey: "lastSeenVibeTimestamp") }
    }
    
    // Realtime channels
    private var postsChannel: RealtimeChannelV2?
    private var vibesChannel: RealtimeChannelV2?
    private var friendRequestsChannel: RealtimeChannelV2?
    private var friendshipsChannel: RealtimeChannelV2?
    private var usersChannel: RealtimeChannelV2?
    private var postRepliesChannel: RealtimeChannelV2?
    private var vibeResponsesChannel: RealtimeChannelV2?
    
    private let supabase = SupabaseManager.shared.client
    
    // Prompts pool (fallback)
    private let prompts = [
        "what made you smile today?",
        "one word for today?",
        "what are you grateful for?",
        "what's on your mind?",
        "how are you really feeling?",
        "what's your highlight?",
        "what challenged you today?"
    ]
    
    init() {
        generateTodaysPrompt()
    }
    
    // MARK: - Load User Data
    
    func loadCurrentUser() async {
        isLoading = true
        
        do {
            guard let authUser = try? await supabase.auth.session.user else {
                isLoading = false
                return
            }
            
            // Fetch user profile
            let users: [DBUser] = try await supabase
                .from("users")
                .select()
                .eq("auth_id", value: authUser.id)
                .execute()
                .value
            
            if let dbUser = users.first {
                self.currentUser = dbUser
                self.currentUserProfile = dbUser.toUser()
                
                // Load friends
                await loadFriends()

                // Load friend requests
                await loadFriendRequests()

                // Load vibes
                await loadVibes()
                
                // Load posts
                await loadPosts()
                
                // Load rating history
                await loadRatingHistory()

                // Setup realtime subscriptions
                await setupRealtimeSubscriptions()
                
                // Initialize ConversationManager with user ID
                if let userId = dbUser.id?.uuidString {
                    await MainActor.run {
                        ConversationManager.shared.setCurrentUser(userId)
                    }
                    await ConversationManager.shared.loadConversations()
                }
            }
        } catch {
            print("Error loading user: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Realtime Subscriptions

    func setupRealtimeSubscriptions() async {
        guard currentUser?.id != nil else { return }
        
        // Subscribe to posts changes
        await subscribeToPostsChanges()
        
        // Subscribe to vibes changes
        await subscribeToVibesChanges()
        
        // Subscribe to friend requests changes
        await subscribToFriendRequestsChanges()
        
        // Subscribe to friendships changes
        await subscribeToFriendshipsChanges()
        
        // Subscribe to user rating changes (for friends)
        await subscribeToUserRatingChanges()
        
        // Subscribe to post replies
        await subscribeToPostRepliesChanges()
        
        await subscribeToVibeResponsesChanges()
    }

    private func subscribeToPostsChanges() async {
        postsChannel = supabase.realtimeV2.channel("posts-changes")
        
        let insertions = postsChannel!.postgresChange(InsertAction.self, table: "posts")
        let deletions = postsChannel!.postgresChange(DeleteAction.self, table: "posts")
        
        await postsChannel!.subscribe()
        
        Task {
            for await insertion in insertions {
                print("New post inserted")
                await loadPosts()
            }
        }
        
        Task {
            for await deletion in deletions {
                print("Post deleted")
                await loadPosts()
            }
        }
    }

    private func subscribeToVibesChanges() async {
        vibesChannel = supabase.realtimeV2.channel("vibes-changes")
        
        let insertions = vibesChannel!.postgresChange(InsertAction.self, table: "vibes")
        let deletions = vibesChannel!.postgresChange(DeleteAction.self, table: "vibes")
        let updates = vibesChannel!.postgresChange(UpdateAction.self, table: "vibes")
        
        await vibesChannel!.subscribe()
        
        Task {
            for await _ in insertions {
                print("New vibe created")
                await loadVibes()
            }
        }
        
        Task {
            for await _ in deletions {
                print("Vibe deleted")
                await loadVibes()
            }
        }
        
        Task {
            for await _ in updates {
                print("Vibe updated")
                await loadVibes()
            }
        }
    }

    private func subscribToFriendRequestsChanges() async {
        friendRequestsChannel = supabase.realtimeV2.channel("friend-requests-changes")
        
        let insertions = friendRequestsChannel!.postgresChange(InsertAction.self, table: "friend_requests")
        let updates = friendRequestsChannel!.postgresChange(UpdateAction.self, table: "friend_requests")
        let deletions = friendRequestsChannel!.postgresChange(DeleteAction.self, table: "friend_requests")
        
        await friendRequestsChannel!.subscribe()
        
        Task {
            for await _ in insertions {
                print("New friend request")
                await loadFriendRequests()
            }
        }
        
        Task {
            for await _ in updates {
                print("Friend request updated")
                await loadFriendRequests()
                await loadFriends()
            }
        }
        
        Task {
            for await _ in deletions {
                print("Friend request deleted")
                await loadFriendRequests()
            }
        }
    }

    private func subscribeToFriendshipsChanges() async {
        friendshipsChannel = supabase.realtimeV2.channel("friendships-changes")
        
        let insertions = friendshipsChannel!.postgresChange(InsertAction.self, table: "friendships")
        let deletions = friendshipsChannel!.postgresChange(DeleteAction.self, table: "friendships")
        
        await friendshipsChannel!.subscribe()
        
        Task {
            for await _ in insertions {
                print("New friendship added")
                await loadFriends()
            }
        }
        
        Task {
            for await _ in deletions {
                print("Friendship removed")
                await loadFriends()
            }
        }
    }

    private func subscribeToUserRatingChanges() async {
        usersChannel = supabase.realtimeV2.channel("users-rating-changes")
        
        let updates = usersChannel!.postgresChange(UpdateAction.self, table: "users")
        
        await usersChannel!.subscribe()
        
        Task {
            for await _ in updates {
                print("User rating updated")
                await loadFriends() // Reload friends to get updated ratings
            }
        }
    }

    private func subscribeToPostRepliesChanges() async {
        postRepliesChannel = supabase.realtimeV2.channel("post-replies-changes")
        
        let insertions = postRepliesChannel!.postgresChange(InsertAction.self, table: "post_replies")
        
        await postRepliesChannel!.subscribe()
        
        Task {
            for await _ in insertions {
                print("New reply added")
                await loadPosts()
            }
        }
    }
    
    private func subscribeToVibeResponsesChanges() async {
        vibeResponsesChannel = supabase.realtimeV2.channel("vibe-responses-changes")
        
        let insertions = vibeResponsesChannel!.postgresChange(InsertAction.self, table: "vibe_responses")
        let updates = vibeResponsesChannel!.postgresChange(UpdateAction.self, table: "vibe_responses")
        let deletions = vibeResponsesChannel!.postgresChange(DeleteAction.self, table: "vibe_responses")
        
        await vibeResponsesChannel!.subscribe()
        
        Task {
            for await _ in insertions {
                print("Someone joined a vibe")
                await loadVibes()
            }
        }
        
        Task {
            for await _ in updates {
                print("Vibe response updated")
                await loadVibes()
            }
        }
        
        Task {
            for await _ in deletions {
                print("Someone left a vibe")
                await loadVibes()
            }
        }
    }
    
    func unsubscribeFromRealtime() async {
        if let channel = postsChannel {
            await supabase.realtimeV2.removeChannel(channel)
        }
        if let channel = vibesChannel {
            await supabase.realtimeV2.removeChannel(channel)
        }
        if let channel = friendRequestsChannel {
            await supabase.realtimeV2.removeChannel(channel)
        }
        if let channel = friendshipsChannel {
            await supabase.realtimeV2.removeChannel(channel)
        }
        if let channel = usersChannel {
            await supabase.realtimeV2.removeChannel(channel)
        }
        if let channel = postRepliesChannel {
            await supabase.realtimeV2.removeChannel(channel)
        }
        if let channel = vibeResponsesChannel {
            await supabase.realtimeV2.removeChannel(channel)
        }
    }
    
    // MARK: - Friends
    
    func loadFriends() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            // Get friendships where user is either user_id or friend_id
            let friendships: [DBFriendship] = try await supabase
                .from("friendships")
                .select()
                .or("user_id.eq.\(userId),friend_id.eq.\(userId)")
                .execute()
                .value
            
            // Get friend IDs
            let friendIds = friendships.map { friendship in
                friendship.userId == userId ? friendship.friendId : friendship.userId
            }
            
            // Fetch friend profiles OR clear if no friends
            if friendIds.isEmpty {
                // No friendships - clear the friends array
                self.friends = []
                print("No friendships found - cleared friends list")
            } else {
                let friendUsers: [DBUser] = try await supabase
                    .from("users")
                    .select()
                    .in("id", values: friendIds.map { $0.uuidString })
                    .execute()
                    .value
                
                self.friends = friendUsers.map { $0.toUser() }
                print("Loaded \(self.friends.count) friends")
            }
            
            // Update widgets with latest friend data
            updateWidgetData()
        } catch {
            print("Error loading friends: \(error)")
        }
    }
    
    func loadFriendRequests() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            // Load requests sent TO the current user (pending only)
            let incomingRequests: [DBFriendRequest] = try await supabase
                .from("friend_requests")
                .select()
                .eq("to_user_id", value: userId)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .execute()
                .value
            
            // Load requests sent BY the current user (pending only)
            let outgoingRequests: [DBFriendRequest] = try await supabase
                .from("friend_requests")
                .select()
                .eq("from_user_id", value: userId)
                .eq("status", value: "pending")
                .execute()
                .value
            
            // Track sent requests by user ID
            sentFriendRequests = Set(outgoingRequests.map { $0.toUserId.uuidString })
            
            // Convert incoming to local model with user info
            var friendRequestsWithUsers: [FriendRequest] = []
            for request in incomingRequests {
                guard let requestId = request.id else { continue }
                
                let friendRequest = FriendRequest(
                    id: requestId.uuidString,
                    fromUserId: request.fromUserId.uuidString,
                    toUserId: request.toUserId.uuidString,
                    timestamp: request.createdAt ?? Date(),
                    status: RequestStatus(rawValue: request.status) ?? .pending
                )
                friendRequestsWithUsers.append(friendRequest)
            }
            
            self.friendRequests = friendRequestsWithUsers
        } catch {
            print("Error loading friend requests: \(error)")
        }
        updateUnreadCounts()
    }
    
    func cancelFriendRequest(toUserId: String) async -> Bool {
        guard let fromUserId = currentUser?.id,
              let toUserUUID = UUID(uuidString: toUserId) else { return false }
        
        // Optimistic update
        sentFriendRequests.remove(toUserId)
        
        do {
            try await supabase
                .from("friend_requests")
                .delete()
                .eq("from_user_id", value: fromUserId)
                .eq("to_user_id", value: toUserUUID)
                .execute()
            
            print("Friend request cancelled")
            return true
        } catch {
            print("Error cancelling friend request: \(error)")
            // Restore on failure
            sentFriendRequests.insert(toUserId)
            return false
        }
    }

    func searchUsers(query: String) async -> [User] {
        guard !query.isEmpty else { return [] }
        guard let currentUserId = currentUser?.id else { return [] }
        
        do {
            // Search by username (case insensitive)
            let users: [DBUser] = try await supabase
                .from("users")
                .select()
                .ilike("username", pattern: "%\(query)%")
                .neq("id", value: currentUserId) // Exclude current user
                .limit(20)
                .execute()
                .value
            
            // Filter out existing friends
            let friendIds = Set(friends.map { $0.id })
            return users
                .map { $0.toUser() }
                .filter { !friendIds.contains($0.id) }
        } catch {
            print("Error searching users: \(error)")
            return []
        }
    }
    
    // Check if we have an incoming friend request from a specific user
    func hasIncomingRequestFrom(userId: String) -> Bool {
        return friendRequests.contains { $0.fromUserId == userId && $0.status == .pending }
    }
    
    // Get the request ID for an incoming request from a specific user
    func getIncomingRequestId(fromUserId: String) -> String? {
        return friendRequests.first { $0.fromUserId == fromUserId && $0.status == .pending }?.id
    }

    func sendFriendRequest(toUserId: String) async -> Bool {
        guard let fromUserId = currentUser?.id,
              let toUserUUID = UUID(uuidString: toUserId) else { return false }
        
        // Check if request already exists
        do {
            let existingRequests: [DBFriendRequest] = try await supabase
                .from("friend_requests")
                .select()
                .eq("from_user_id", value: fromUserId)
                .eq("to_user_id", value: toUserUUID)
                .execute()
                .value
            
            if !existingRequests.isEmpty {
                print("Friend request already sent")
                sentFriendRequests.insert(toUserId)
                return false
            }
            
            // Also check reverse direction
            let reverseRequests: [DBFriendRequest] = try await supabase
                .from("friend_requests")
                .select()
                .eq("from_user_id", value: toUserUUID)
                .eq("to_user_id", value: fromUserId)
                .execute()
                .value
            
            if !reverseRequests.isEmpty {
                print("This user already sent you a request")
                return false
            }
        } catch {
            print("Error checking existing requests: \(error)")
            return false
        }
        
        // Optimistic update
        sentFriendRequests.insert(toUserId)
        
        // Send the request
        let newRequest = DBFriendRequest(
            id: nil,
            fromUserId: fromUserId,
            toUserId: toUserUUID,
            status: "pending",
            createdAt: nil
        )
        
        do {
            try await supabase
                .from("friend_requests")
                .insert(newRequest)
                .execute()
            
            print("Friend request sent successfully")
            
            // Send push notification to recipient
            if let senderName = currentUserProfile?.displayName {
                await sendPushNotification(type: "friend_request", to: toUserId, senderName: senderName)
            }
            
            return true
        } catch {
            print("Error sending friend request: \(error)")
            sentFriendRequests.remove(toUserId)
            return false
        }
    }

    func acceptFriendRequest(_ requestId: String) async {
        guard let requestUUID = UUID(uuidString: requestId),
              let currentUserId = currentUser?.id else { return }
        
        // Find the request to get the from_user_id
        guard let request = friendRequests.first(where: { $0.id == requestId }) else { return }
        guard let fromUserUUID = UUID(uuidString: request.fromUserId) else { return }
        
        // Optimistic update
        friendRequests.removeAll { $0.id == requestId }
        
        do {
            // Create friendship (current user -> from user)
            let friendship = DBFriendship(
                id: nil,
                userId: currentUserId,
                friendId: fromUserUUID,
                createdAt: nil
            )
            
            try await supabase
                .from("friendships")
                .insert(friendship)
                .execute()
            
            // Create reverse friendship (from user -> current user)
            let reverseFriendship = DBFriendship(
                id: nil,
                userId: fromUserUUID,
                friendId: currentUserId,
                createdAt: nil
            )
            
            try await supabase
                .from("friendships")
                .insert(reverseFriendship)
                .execute()
            
            // Delete the friend request from the database
            try await supabase
                .from("friend_requests")
                .delete()
                .eq("id", value: requestUUID)
                .execute()
            
            print("Friend request accepted, friendships created, and request deleted")
            
            // Reload friends list and requests
            await loadFriends()
            await loadFriendRequests()
            updateUnreadCounts()
        } catch {
            print("Error accepting friend request: \(error)")
            // Reload requests if failed
            await loadFriendRequests()
        }
    }
    func rejectFriendRequest(_ requestId: String) async {
        guard let requestUUID = UUID(uuidString: requestId) else { return }
        
        // Optimistic update
        friendRequests.removeAll { $0.id == requestId }
        
        do {
            // Delete the friend request from the database
            try await supabase
                .from("friend_requests")
                .delete()
                .eq("id", value: requestUUID)
                .execute()
            
            print("Friend request rejected and deleted")
            updateUnreadCounts()
        } catch {
            print("Error rejecting friend request: \(error)")
            // Reload requests if failed
            await loadFriendRequests()
        }
    }

    func removeFriend(_ friendId: String) async {
        guard let currentUserUUID = currentUser?.id,
              let friendUUID = UUID(uuidString: friendId) else {
            print("Invalid IDs for remove friend")
            return
        }
        
        // Optimistic update
        friends.removeAll { $0.id == friendId }
        
        do {
            // Delete ALL friendships between these two users (both directions)
            // Direction 1: current user -> friend
            try await supabase
                .from("friendships")
                .delete()
                .eq("user_id", value: currentUserUUID)
                .eq("friend_id", value: friendUUID)
                .execute()
            
            print("Deleted friendship direction 1")
            
            // Direction 2: friend -> current user
            try await supabase
                .from("friendships")
                .delete()
                .eq("user_id", value: friendUUID)
                .eq("friend_id", value: currentUserUUID)
                .execute()
            
            print("Deleted friendship direction 2")
            
            print("Friend removed successfully (both directions)")
            
            // Force reload to ensure sync
            await loadFriends()
        } catch {
            print("Error removing friend: \(error)")
            // Reload friends if failed
            await loadFriends()
        }
    }

    func getUser(byId userId: String) async -> User? {
        guard let userUUID = UUID(uuidString: userId) else { return nil }
        
        // First check if it's in our local cache
        if let localUser = getUser(by: userId) {
            return localUser
        }
        
        // Otherwise fetch from database
        do {
            let users: [DBUser] = try await supabase
                .from("users")
                .select()
                .eq("id", value: userUUID)
                .limit(1)
                .execute()
                .value
            
            return users.first?.toUser()
        } catch {
            print("Error fetching user: \(error)")
            return nil
        }
    }
    
    // MARK: - Vibes
    
    func loadVibes() async {
        do {
            let dbVibes: [DBVibe] = try await supabase
                .from("vibes")
                .select()
                .eq("is_active", value: true)
                .gt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
                .order("timestamp", ascending: false)
                .execute()
                .value
            
            // Load responses for each vibe
            var vibesWithResponses: [Vibe] = []
            for dbVibe in dbVibes {
                guard let vibeId = dbVibe.id else { continue }
                
                let responses: [DBVibeResponse] = try await supabase
                    .from("vibe_responses")
                    .select()
                    .eq("vibe_id", value: vibeId)
                    .execute()
                    .value
                
                let vibe = dbVibe.toVibe(responses: responses)
                vibesWithResponses.append(vibe)
            }
            
            self.vibes = vibesWithResponses
            updateUnreadCounts()
        } catch {
            print("Error loading vibes: \(error)")
        }
    }
    
    func createVibe(title: String, timeDescription: String, location: String, expiresAt: Date) async {
        guard let userId = currentUser?.id,
              let userIdString = currentUserProfile?.id else { return }
        
        // Optimistic update - add to local state immediately
        let tempId = UUID().uuidString
        let localVibe = Vibe(
            id: tempId,
            userId: userIdString,
            title: title,
            timeDescription: timeDescription,
            location: location,
            timestamp: Date(),
            responses: [],
            isActive: true
        )
        vibes.insert(localVibe, at: 0)
        
        let newVibe = DBVibe(
            id: nil,
            userId: userId,
            title: title,
            timeDescription: timeDescription,
            location: location,
            timestamp: nil,
            expiresAt: expiresAt,
            isActive: true
        )
        
        do {
            // Insert and get the actual ID from server
            let insertedVibes: [DBVibe] = try await supabase
                .from("vibes")
                .insert(newVibe)
                .select()
                .execute()
                .value
            
            // Update local vibe with actual database ID
            if let insertedVibe = insertedVibes.first,
               let actualId = insertedVibe.id,
               let index = vibes.firstIndex(where: { $0.id == tempId }) {
                vibes[index] = Vibe(
                    id: actualId.uuidString,
                    userId: userIdString,
                    title: title,
                    timeDescription: timeDescription,
                    location: location,
                    timestamp: insertedVibe.timestamp ?? Date(),
                    responses: [],
                    isActive: true
                )
                print("Vibe created with ID: \(actualId.uuidString)")
            }
            
            // Track for badges
            await BadgeManager.shared.trackVibeCreated(userId: userIdString)
            await BadgeManager.shared.checkForNewBadges(userId: userIdString, friendCount: friends.count)
            
            // Send push notifications to all friends
            if let senderName = currentUserProfile?.displayName {
                await sendPushNotificationToAllFriends(
                    type: "vibe",
                    senderName: senderName,
                    data: ["vibeId": insertedVibes.first?.id?.uuidString ?? tempId]
                )
            }
            
        } catch {
            print("Error creating vibe: \(error)")
            // Remove optimistic update if failed
            vibes.removeAll { $0.id == tempId }
        }
    }
    
    func respondToVibe(_ vibeId: String, response: VibeResponseType) async {
        guard let userId = currentUser?.id,
              let userIdString = currentUserProfile?.id,
              let vibeUUID = UUID(uuidString: vibeId) else { return }
        
        // Optimistic update - update local state immediately
        if let index = vibes.firstIndex(where: { $0.id == vibeId }) {
            var updatedVibe = vibes[index]
            // Remove existing response from this user
            updatedVibe.responses.removeAll { $0.userId == userIdString }
            // Add new response
            let newResponse = VibeResponse(
                id: UUID().uuidString,
                userId: userIdString,
                response: response,
                timestamp: Date()
            )
            updatedVibe.responses.append(newResponse)
            vibes[index] = updatedVibe
        }
        
        
        
        let vibeResponse = DBVibeResponse(
            id: nil,
            vibeId: vibeUUID,
            userId: userId,
            response: response.rawValue,
            timestamp: nil
        )
        
        do {
            // Upsert (insert or update)
            try await supabase
                .from("vibe_responses")
                .upsert(vibeResponse, onConflict: "vibe_id,user_id")
                .execute()
            
            // Send push notification to vibe creator (only for "yes" responses)
            if response == .yes,
               let vibe = vibes.first(where: { $0.id == vibeId }),
               vibe.userId != userIdString, // Don't notify yourself
               let senderName = currentUserProfile?.displayName {
                await sendPushNotification(
                    type: "vibe_response",
                    to: vibe.userId,
                    senderName: senderName,
                    data: ["vibeId": vibeId]
                )
            }
        } catch {
            print("Error responding to vibe: \(error)")
            // Reload vibes if failed
            await loadVibes()
        }
    }
    
    func deleteVibe(_ vibeId: String) async {
        guard let vibeUUID = UUID(uuidString: vibeId) else { return }
        
        // Optimistic update - remove from local state immediately
        vibes.removeAll { $0.id == vibeId }
        
        do {
            try await supabase
                .from("vibes")
                .delete()
                .eq("id", value: vibeUUID)
                .execute()
        } catch {
            print("Error deleting vibe: \(error)")
            // Reload vibes if delete failed
            await loadVibes()
        }
    }
    
    func loadPosts() async {
        isLoadingPosts = true
        postsPage = 0
        hasMorePosts = true
        
        do {
            // Load first batch of posts quickly
            let dbPosts: [DBPost] = try await supabase
                .from("posts")
                .select()
                .order("timestamp", ascending: false)
                .limit(postsPerPage)
                .execute()
                .value
            
            // Load all likes and replies in parallel batch queries
            let postIds = dbPosts.compactMap { $0.id }
            
            if postIds.isEmpty {
                self.posts = []
                isLoadingPosts = false
                return
            }
            
            // Batch load all likes for these posts at once
            async let likesTask: [DBPostLike] = supabase
                .from("post_likes")
                .select()
                .in("post_id", values: postIds.map { $0.uuidString })
                .execute()
                .value
            
            // Batch load all replies for these posts at once
            async let repliesTask: [DBPostReply] = supabase
                .from("post_replies")
                .select()
                .in("post_id", values: postIds.map { $0.uuidString })
                .execute()
                .value
            
            // Wait for both to complete in parallel
            let (allLikes, allReplies) = try await (likesTask, repliesTask)
            
            // Group likes and replies by post ID
            let likesByPost = Dictionary(grouping: allLikes) { $0.postId }
            let repliesByPost = Dictionary(grouping: allReplies) { $0.postId }
            
            // Build posts with their likes and replies
            var postsWithDetails: [Post] = []
            for dbPost in dbPosts {
                guard let postId = dbPost.id else { continue }
                let postLikes = likesByPost[postId] ?? []
                let postReplies = repliesByPost[postId] ?? []
                let post = dbPost.toPost(likes: postLikes, replies: postReplies)
                postsWithDetails.append(post)
            }
            
            self.posts = postsWithDetails
            hasMorePosts = dbPosts.count == postsPerPage
            updateUnreadCounts()
        } catch {
            print("Error loading posts: \(error)")
        }
        
        isLoadingPosts = false
    }
    
    func loadMorePosts() async {
        guard hasMorePosts, !isLoadingPosts else { return }
        
        postsPage += 1
        let offset = postsPage * postsPerPage
        
        do {
            let dbPosts: [DBPost] = try await supabase
                .from("posts")
                .select()
                .order("timestamp", ascending: false)
                .range(from: offset, to: offset + postsPerPage - 1)
                .execute()
                .value
            
            if dbPosts.isEmpty {
                hasMorePosts = false
                return
            }
            
            let postIds = dbPosts.compactMap { $0.id }
            
            // Batch load likes and replies in parallel
            async let likesTask: [DBPostLike] = supabase
                .from("post_likes")
                .select()
                .in("post_id", values: postIds.map { $0.uuidString })
                .execute()
                .value
            
            async let repliesTask: [DBPostReply] = supabase
                .from("post_replies")
                .select()
                .in("post_id", values: postIds.map { $0.uuidString })
                .execute()
                .value
            
            let (allLikes, allReplies) = try await (likesTask, repliesTask)
            
            let likesByPost = Dictionary(grouping: allLikes) { $0.postId }
            let repliesByPost = Dictionary(grouping: allReplies) { $0.postId }
            
            var newPosts: [Post] = []
            for dbPost in dbPosts {
                guard let postId = dbPost.id else { continue }
                let postLikes = likesByPost[postId] ?? []
                let postReplies = repliesByPost[postId] ?? []
                let post = dbPost.toPost(likes: postLikes, replies: postReplies)
                newPosts.append(post)
            }
            
            // Append to existing posts
            self.posts.append(contentsOf: newPosts)
            hasMorePosts = dbPosts.count == postsPerPage
        } catch {
            print("Error loading more posts: \(error)")
        }
    }
    func createPost(imageData: Data?, caption: String?, promptResponse: String? = nil) async {
        guard let userId = currentUser?.id,
              let userIdString = currentUserProfile?.id else { return }
        
        var imageUrl: String? = nil
        
        // Get the current rating at time of post creation
        let postRating = currentUserProfile?.todayRating
        
        // Upload image if provided (this still needs to wait)
        if let imageData = imageData {
            imageUrl = await uploadImage(imageData)
        }
        
        // Optimistic update - add to local state immediately
        let tempId = UUID().uuidString
        let localPost = Post(
            id: tempId,
            userId: userIdString,
            imageData: imageData,
            imageUrl: imageUrl,
            caption: caption,
            plusOnes: [],
            replies: [],
            timestamp: Date(),
            promptResponse: promptResponse,
            promptId: promptResponse != nil ? todaysPrompt.id : nil,
            promptText: promptResponse != nil ? todaysPrompt.text : nil,
            rating: postRating
        )
        posts.insert(localPost, at: 0)
        
        let newPost = DBPost(
            id: nil,
            userId: userId,
            imageUrl: imageUrl,
            caption: caption,
            promptResponse: promptResponse,
            promptId: promptResponse != nil ? todaysPrompt.id : nil,
            promptText: promptResponse != nil ? todaysPrompt.text : nil,
            timestamp: nil,
            rating: postRating
        )
        
        do {
            // Insert and get the returned post with actual ID
            let insertedPosts: [DBPost] = try await supabase
                .from("posts")
                .insert(newPost)
                .select()
                .execute()
                .value
            
            // Update local post with actual database ID
            if let insertedPost = insertedPosts.first,
               let actualId = insertedPost.id,
               let index = posts.firstIndex(where: { $0.id == tempId }) {
                posts[index] = Post(
                    id: actualId.uuidString,
                    userId: userIdString,
                    imageData: imageData,
                    imageUrl: insertedPost.imageUrl,
                    caption: insertedPost.caption,
                    plusOnes: [],
                    replies: [],
                    timestamp: insertedPost.timestamp ?? Date(),
                    promptResponse: insertedPost.promptResponse,
                    promptId: insertedPost.promptId,
                    promptText: insertedPost.promptText,
                    rating: insertedPost.rating
                )
                print("Post created with ID: \(actualId.uuidString)")
            }
        } catch {
            print("Error creating post: \(error)")
            // Remove optimistic update if failed
            posts.removeAll { $0.id == tempId }
        }
    }
    
    func toggleLike(for postId: String) async {
        guard let userId = currentUser?.id,
              let userIdString = currentUserProfile?.id,
              let postUUID = UUID(uuidString: postId) else { return }
        
        // Optimistic update - update local state immediately
        var isCurrentlyLiked = false
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            var updatedPost = posts[index]
            if let likeIndex = updatedPost.plusOnes.firstIndex(where: { $0.userId == userIdString }) {
                // Already liked - remove it
                updatedPost.plusOnes.remove(at: likeIndex)
                isCurrentlyLiked = true
            } else {
                // Not liked - add it
                let newLike = PlusOne(id: UUID().uuidString, userId: userIdString, timestamp: Date())
                updatedPost.plusOnes.append(newLike)
                isCurrentlyLiked = false
            }
            posts[index] = updatedPost
        }
        // After the like is inserted successfully
        // Add:
        if let userId = currentUserProfile?.id {
            await BadgeManager.shared.trackLike(userId: userId)
            await BadgeManager.shared.checkForNewBadges(userId: userId, friendCount: friends.count)
        }
        
        do {
            if isCurrentlyLiked {
                // Remove like from server
                try await supabase
                    .from("post_likes")
                    .delete()
                    .eq("post_id", value: postUUID)
                    .eq("user_id", value: userId)
                    .execute()
            } else {
                // Add like to server
                let like = DBPostLike(
                    id: nil,
                    postId: postUUID,
                    userId: userId,
                    timestamp: nil
                )
                try await supabase
                    .from("post_likes")
                    .insert(like)
                    .execute()
            }
        } catch {
            print("Error toggling like: \(error)")
            // Reload posts if failed
            await loadPosts()
        }
    }

    func deletePost(_ postId: String) async {
        guard let postUUID = UUID(uuidString: postId) else {
            print("Invalid post ID format: \(postId)")
            return
        }
        
        // Store the post in case we need to restore it
        let postToDelete = posts.first { $0.id == postId }
        
        // Optimistic update - remove from local state immediately
        posts.removeAll { $0.id == postId }
        
        do {
            // Delete the post - mirrors deleteVibe which works
            try await supabase
                .from("posts")
                .delete()
                .eq("id", value: postUUID)
                .execute()
            
            print("Successfully deleted post: \(postId)")
        } catch {
            print("Error deleting post: \(error)")
            // Restore the post if delete failed
            if let post = postToDelete {
                posts.insert(post, at: 0)
            }
            // Reload posts to sync with server
            await loadPosts()
        }
    }

    // MARK: - Profile Update

    enum ProfileUpdateResult {
        case success
        case usernameTaken
        case error(String)
    }

    func updateProfile(username: String, displayName: String) async -> ProfileUpdateResult {
        guard let userId = currentUser?.id else { return .error("Not logged in") }
        
        let currentUsername = currentUserProfile?.username ?? ""
        
        // Check if username changed and if new username is taken
        if username.lowercased() != currentUsername.lowercased() {
            do {
                let existingUsers: [DBUser] = try await supabase
                    .from("users")
                    .select("id")
                    .eq("username", value: username.lowercased())
                    .execute()
                    .value
                
                if !existingUsers.isEmpty {
                    return .usernameTaken
                }
            } catch {
                return .error("Failed to check username")
            }
        }
        
        // Update profile
        do {
            let updateData: [String: AnyJSON] = [
                "username": .string(username.lowercased()),
                "display_name": .string(displayName)
            ]
            
            try await supabase
                .from("users")
                .update(updateData)
                .eq("id", value: userId)
                .execute()
            
            // Update local state
            currentUserProfile?.displayName = displayName
            if var user = currentUserProfile {
                user = User(
                    id: user.id,
                    username: username.lowercased(),
                    displayName: displayName,
                    bio: user.bio,
                    todayRating: user.todayRating,
                    ratingTimestamp: user.ratingTimestamp,
                    friendIds: user.friendIds,
                    ratingHistory: user.ratingHistory
                )
                currentUserProfile = user
            }
            
            return .success
        } catch {
            print("Error updating profile: \(error)")
            return .error("Failed to update profile")
        }
    }
    
    func addReply(to postId: String, text: String) async {
        guard let userId = currentUser?.id,
              let userIdString = currentUserProfile?.id,
              let postUUID = UUID(uuidString: postId) else { return }
        
        // Create local reply for optimistic update
        let tempId = UUID().uuidString
        let localReply = Reply(
            id: tempId,
            userId: userIdString,
            text: text,
            timestamp: Date()
        )
        
        // Optimistic update - add reply to local state immediately
        if let postIndex = posts.firstIndex(where: { $0.id == postId }) {
            posts[postIndex].replies.append(localReply)
        }
        
        let reply = DBPostReply(
            id: nil,
            postId: postUUID,
            userId: userId,
            text: text,
            timestamp: nil
        )
        
        do {
            try await supabase
                .from("post_replies")
                .insert(reply)
                .execute()
            
            print("Reply added successfully")
            
            // Track for badges after successful insert
            await BadgeManager.shared.trackReply(userId: userIdString)
            await BadgeManager.shared.checkForNewBadges(userId: userIdString, friendCount: friends.count)
            
            // Send push notification to post author
            if let post = posts.first(where: { $0.id == postId }),
               post.userId != userIdString, // Don't notify yourself
               let senderName = currentUserProfile?.displayName {
                await sendPushNotification(
                    type: "reply",
                    to: post.userId,
                    senderName: senderName,
                    data: ["postId": postId]
                )
            }
        } catch {
            print("Error adding reply: \(error)")
            // Revert optimistic update on failure
            if let postIndex = posts.firstIndex(where: { $0.id == postId }) {
                posts[postIndex].replies.removeAll { $0.id == tempId }
            }
            // Reload posts to sync with server
            await loadPosts()
        }
    }
    
    func deleteReply(replyId: String, from postId: String) async {
        guard let replyUUID = UUID(uuidString: replyId) else {
            print("Invalid reply ID format: \(replyId)")
            return
        }
        
        // Store the reply in case we need to restore it
        var replyToDelete: Reply?
        var postIndex: Int?
        
        if let idx = posts.firstIndex(where: { $0.id == postId }) {
            postIndex = idx
            replyToDelete = posts[idx].replies.first { $0.id == replyId }
            // Optimistic update - remove from local state immediately
            posts[idx].replies.removeAll { $0.id == replyId }
        }
        
        do {
            // Delete the reply from the database
            try await supabase
                .from("post_replies")
                .delete()
                .eq("id", value: replyUUID)
                .execute()
            
            print("Successfully deleted reply: \(replyId)")
        } catch {
            print("Error deleting reply: \(error)")
            // Restore the reply if delete failed
            if let reply = replyToDelete, let idx = postIndex {
                posts[idx].replies.append(reply)
            }
            // Reload posts to sync with server
            await loadPosts()
        }
    }
    
    // MARK: - Widgets
    
    func updateWidgetData() {
        guard let user = currentUserProfile else {
            print("⚠️ updateWidgetData: No user profile")
            return
        }
        
        // Get streak from UserDefaults
        let currentStreak = UserDefaults.standard.integer(forKey: "currentStreak")
        
        // Get current theme
        let theme = ThemeManager.shared.currentTheme
        let widgetTheme = WidgetThemeColors(
            background: theme.colors.background.hexString,
            cardBackground: theme.colors.cardBackground.hexString,
            surfaceLight: theme.colors.surfaceLight.hexString,
            accent1: theme.colors.accent1.hexString,
            accent2: theme.colors.accent2.hexString,
            textPrimary: theme.colors.textPrimary.hexString,
            textSecondary: theme.colors.textSecondary.hexString,
            textTertiary: theme.colors.textTertiary.hexString,
            glowColor: theme.glowColor.hexString
        )
        
        // Sort friends by most recent rating first
        let sortedFriends = friends.sorted { friend1, friend2 in
            guard let time1 = friend1.ratingTimestamp else { return false }
            guard let time2 = friend2.ratingTimestamp else { return true }
            return time1 > time2
        }
        
        // Build user data for widget
        let widgetUser = WidgetUserData(
            displayName: user.displayName,
            todayRating: user.todayRating,
            ratingTimestamp: user.ratingTimestamp,
            currentStreak: currentStreak,
            isPremium: user.isPremium,
            themeId: PremiumManager.shared.selectedThemeId
        )
        
        // Build friends data for widget with full theme info
        let widgetFriends = sortedFriends.map { friend in
            WidgetFriendData(
                id: friend.id,
                username: friend.username,
                displayName: friend.displayName,
                todayRating: friend.todayRating,
                ratingTimestamp: friend.ratingTimestamp,
                profileImageUrl: nil,
                isPremium: friend.isPremium,
                themeId: friend.isPremium ? friend.selectedTheme.id : nil,
                themeAccent: friend.isPremium ? friend.selectedTheme.glowColor.hexString : nil,
                themeCardBackground: friend.isPremium ? friend.selectedTheme.colors.cardBackground.hexString : nil
            )
        }
        
        // Get latest post for premium widget
        let latestPost: WidgetPostData? = posts.first.map { post in
            let author = getUser(by: post.userId)
            return WidgetPostData(
                id: post.id,
                authorName: author?.displayName ?? "unknown",
                authorIsPremium: author?.isPremium ?? false,
                authorThemeAccent: author?.isPremium == true ? author?.selectedTheme.glowColor.hexString : nil,
                content: post.caption ?? post.promptResponse ?? "",
                rating: post.rating,
                promptText: post.promptText,
                createdAt: post.timestamp,
                replyCount: post.replies.count
            )
        }
        
        // Update widget
        WidgetDataManager.shared.updateWidgetData(
            user: widgetUser,
            friends: widgetFriends,
            todaysPrompt: todaysPrompt.text,
            latestPost: latestPost,
            theme: widgetTheme
        )
    }
    
    // MARK: - Rating
    
    func loadRatingHistory() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            let history: [DBRatingHistory] = try await supabase
                .from("rating_history")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)  // Use created_at for proper ordering
                .limit(7)
                .execute()
                .value
            
            self.ratingHistory = history.map { dbEntry in
                RatingEntry(id: dbEntry.id?.uuidString ?? UUID().uuidString, rating: dbEntry.rating, date: dbEntry.createdAt ?? dbEntry.date)
            }
            
            // Debug: Print what we got
            for (index, entry) in ratingHistory.enumerated() {
                print("🔍 CheckIn: Rating[\(index)]: \(entry.rating) on \(entry.date)")
            }
        } catch {
            print("Error loading rating history: \(error)")
        }
    }
    
    // MARK: - Daily Rating Reset
    
    /// Checks if the user's rating is from a previous day and resets it locally.
    /// This ensures users are prompted to rate each new day fresh.
    func checkAndResetDailyRating() {
        guard let profile = currentUserProfile else {
            print("⏰ checkAndResetDailyRating: No profile loaded yet")
            return
        }
        
        print("⏰ checkAndResetDailyRating: todayRating=\(profile.todayRating ?? -1), hasRatedToday=\(profile.hasRatedToday), timestamp=\(profile.ratingTimestamp?.description ?? "nil")")
        
        // If the rating timestamp is not from today, clear the local rating
        if !profile.hasRatedToday && profile.todayRating != nil {
            var updatedProfile = profile
            // Store the previous rating before clearing
            updatedProfile.lastRating = profile.todayRating
            updatedProfile.todayRating = nil
            // Keep ratingTimestamp so we know when they last rated
            currentUserProfile = updatedProfile
            print("⏰ Daily rating reset - previous rating was \(profile.todayRating ?? 0), now lastRating=\(updatedProfile.lastRating ?? -1)")
        } else if profile.hasRatedToday {
            print("⏰ User has already rated today, no reset needed")
        } else {
            print("⏰ No previous rating to reset")
        }
    }
    
    func updateRating(_ rating: Int) async {
        guard let userId = currentUser?.id else { return }
        
        // Update local state FIRST (create new User with updated rating)
        if var updatedProfile = currentUserProfile {
            updatedProfile.todayRating = rating
            updatedProfile.ratingTimestamp = Date()
            updatedProfile.lastRating = nil  // Clear stale rating since they've rated today
            currentUserProfile = updatedProfile
        }
        
        do {
            // Update users table
            let updateData: [String: AnyJSON] = [
                "today_rating": .integer(rating),
                "rating_timestamp": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            
            try await supabase
                .from("users")
                .update(updateData)
                .eq("id", value: userId)
                .execute()
            
            // Also insert into rating_history
            let now = Date()
            let isoFormatter = ISO8601DateFormatter()
            let dateOnlyFormatter = DateFormatter()
            dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
            
            let historyEntry: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "rating": .integer(rating),
                "date": .string(dateOnlyFormatter.string(from: now)),  // Date only for the date column
                "created_at": .string(isoFormatter.string(from: now))   // Full timestamp for ordering
            ]
            
            try await supabase
                .from("rating_history")
                .insert(historyEntry)
                .execute()
            
            print("Rating updated successfully to \(rating)")
            // After: print("Rating updated successfully to \(rating)")
            // Add these lines:

            // Track for badges
            if let userId = currentUserProfile?.id {
                await BadgeManager.shared.trackRating(rating, userId: userId)
                await BadgeManager.shared.checkForNewBadges(
                    userId: userId,
                    friendCount: friends.count,
                    rating: rating
                )
            }
            
            // Update widgets
            updateWidgetData()
            
            // Reload rating history for check-in evaluation
            await loadRatingHistory()
            print("🔍 Rating history reloaded, count: \(ratingHistory.count)")
            
            // Notify ContentView to evaluate check-in
            NotificationCenter.default.post(name: NSNotification.Name("EvaluateCheckIn"), object: nil)
        } catch {
            print("Error updating rating: \(error)")
            // Reload user profile if update failed
            await loadCurrentUser()
        }
    }
    
    // MARK: - Push Notifications
    
    /// Sends a push notification to a specific user via the edge function
    /// - Parameters:
    ///   - type: Notification type (vibe, vibe_response, friend_request, reply, connection_match)
    ///   - userId: The recipient user's UUID string
    ///   - senderName: The display name of the person triggering the notification
    ///   - data: Optional additional data to include in the notification payload
    func sendPushNotification(type: String, to userId: String, senderName: String, data: [String: String]? = nil) async {
        do {
            var body: [String: Any] = [
                "type": type,
                "userId": userId,
                "senderName": senderName
            ]
            
            if let data = data {
                body["data"] = data
            }
            
            let jsonData = try JSONSerialization.data(withJSONObject: body)
            
            try await supabase.functions.invoke(
                "send-push-notification",
                options: FunctionInvokeOptions(body: jsonData)
            )
            
            print("✅ Push notification sent: \(type) to \(userId)")
        } catch {
            print("❌ Error sending push notification: \(error)")
        }
    }
    
    /// Sends push notifications to all friends of the current user
    func sendPushNotificationToAllFriends(type: String, senderName: String, data: [String: String]? = nil) async {
        for friend in friends {
            await sendPushNotification(type: type, to: friend.id, senderName: senderName, data: data)
        }
    }
    
    // MARK: - Check-In Alerts
    
    /// Sends a gentle check-in alert to the user's best friend
    /// Only sends if the user has a best friend with score >= 10
    func sendCheckInAlert() async {
        guard let userName = currentUserProfile?.displayName ?? currentUser?.displayName,
              let senderId = currentUser?.id?.uuidString else { return }
        
        // Find best friend (highest score, must be >= 10)
        let sortedFriends = friends.sorted { friend1, friend2 in
            let score1 = FriendshipScoreCache.shared.getScore(for: friend1.id)?.score ?? 0
            let score2 = FriendshipScoreCache.shared.getScore(for: friend2.id)?.score ?? 0
            return score1 > score2
        }
        
        guard let bestFriend = sortedFriends.first,
              let bestFriendScore = FriendshipScoreCache.shared.getScore(for: bestFriend.id)?.score,
              bestFriendScore >= 10 else {
            print("⚠️ No best friend found to send check-in alert")
            return
        }
        
        // Send push notification
        await sendPushNotification(
            type: "check_in_alert",
            to: bestFriend.id,
            senderName: userName,
            data: ["message": "might need some support today"]
        )
        
        // Also create an in-app notification record
        do {
            let notificationData: [String: AnyJSON] = [
                "recipient_id": .string(bestFriend.id),
                "sender_id": .string(senderId),
                "sender_name": .string(userName),
                "type": .string("check_in_alert"),
                "message": .string("\(userName) might need some support"),
                "is_read": .bool(false),
                "created_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            
            try await supabase
                .from("in_app_notifications")
                .insert(notificationData)
                .execute()
            
            print("✅ In-app notification created for \(bestFriend.displayName)")
        } catch {
            print("⚠️ Could not create in-app notification: \(error)")
        }
        
        print("✅ Check-in alert sent to \(bestFriend.displayName)")
    }
    
    /// Get the best friend for check-in purposes
    func getBestFriendForCheckIn() -> (hasBestFriend: Bool, bestFriendName: String?) {
        let sortedFriends = friends.sorted { friend1, friend2 in
            let score1 = FriendshipScoreCache.shared.getScore(for: friend1.id)?.score ?? 0
            let score2 = FriendshipScoreCache.shared.getScore(for: friend2.id)?.score ?? 0
            return score1 > score2
        }
        
        guard let bestFriend = sortedFriends.first,
              let bestFriendScore = FriendshipScoreCache.shared.getScore(for: bestFriend.id)?.score,
              bestFriendScore >= 10 else {
            return (false, nil)
        }
        
        return (true, bestFriend.displayName)
    }
    
    /// Sends a supportive response to a friend who triggered a check-in alert
    func sendCheckInResponse(to friendId: String, message: String) async {
        guard let userName = currentUserProfile?.displayName ?? currentUser?.displayName,
              let senderId = currentUser?.id?.uuidString else { return }
        
        // First, send the message as a DM
        var conversationId: String? = nil
        
        // Get or create conversation with this friend
        if let convId = await ConversationManager.shared.getOrCreateConversation(with: friendId) {
            conversationId = convId
            
            // Send the support message as a regular DM
            let dmMessage = await ConversationManager.shared.sendMessage(to: friendId, content: message)
            if dmMessage != nil {
                print("✅ Support message sent as DM")
            }
        }
        
        // Send push notification
        await sendPushNotification(
            type: "check_in_response",
            to: friendId,
            senderName: userName,
            data: ["message": message]
        )
        
        // Create an in-app notification record for the SupportReceivedView
        do {
            var notificationData: [String: AnyJSON] = [
                "recipient_id": .string(friendId),
                "sender_id": .string(senderId),
                "sender_name": .string(userName),
                "type": .string("check_in_response"),
                "message": .string(message),
                "is_read": .bool(false),
                "created_at": .string(ISO8601DateFormatter().string(from: Date()))
            ]
            
            // Include conversation ID so we can navigate to chat
            if let convId = conversationId {
                notificationData["data"] = .object(["conversation_id": .string(convId)])
            }
            
            try await supabase
                .from("in_app_notifications")
                .insert(notificationData)
                .execute()
            
            print("✅ Support notification saved with conversation_id: \(conversationId ?? "none")")
        } catch {
            print("⚠️ Could not save support message: \(error)")
        }
        
        print("✅ Check-in response sent to \(friendId)")
    }
    
    /// Load any unread check-in alerts for the current user
    func loadPendingCheckInAlerts() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            let notifications: [InAppNotification] = try await supabase
                .from("in_app_notifications")
                .select()
                .eq("recipient_id", value: userId)
                .eq("type", value: "check_in_alert")
                .eq("is_read", value: false)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            if let alert = notifications.first {
                self.pendingCheckInAlert = alert
                print("📬 Found pending check-in alert from \(alert.senderName)")
            }
        } catch {
            print("⚠️ Error loading check-in alerts: \(error)")
        }
    }
    
    /// Load any unread support messages (responses to check-in alerts you sent)
    func loadPendingSupportMessages() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            let notifications: [InAppNotification] = try await supabase
                .from("in_app_notifications")
                .select()
                .eq("recipient_id", value: userId)
                .eq("type", value: "check_in_response")
                .eq("is_read", value: false)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            if let support = notifications.first {
                self.pendingSupportMessage = support
                print("💝 Found support message from \(support.senderName)")
            }
        } catch {
            print("⚠️ Error loading support messages: \(error)")
        }
    }
    
    /// Mark a support message as read
    func markSupportMessageAsRead(_ notification: InAppNotification) async {
        struct UpdatePayload: Encodable {
            let is_read: Bool
            let read_at: String
        }
        
        do {
            try await supabase
                .from("in_app_notifications")
                .update(UpdatePayload(is_read: true, read_at: ISO8601DateFormatter().string(from: Date())))
                .eq("id", value: notification.id)
                .execute()
            
            self.pendingSupportMessage = nil
            print("✅ Support message marked as read")
        } catch {
            print("⚠️ Error marking support as read: \(error)")
        }
    }
    
    /// Mark a check-in alert as read
    func markCheckInAlertAsRead(_ notification: InAppNotification) async {
        struct UpdatePayload: Encodable {
            let is_read: Bool
            let read_at: String
        }
        
        do {
            try await supabase
                .from("in_app_notifications")
                .update(UpdatePayload(is_read: true, read_at: ISO8601DateFormatter().string(from: Date())))
                .eq("id", value: notification.id)
                .execute()
            
            self.pendingCheckInAlert = nil
            print("✅ Check-in alert marked as read")
        } catch {
            print("⚠️ Error marking alert as read: \(error)")
        }
    }
    
    // MARK: - Image Upload
    
    func uploadImage(_ imageData: Data) async -> String? {
        guard let userId = currentUser?.id else { return nil }
        
        let fileName = "\(userId.uuidString)/\(UUID().uuidString).jpg"
        
        do {
            try await supabase.storage
                .from("post-images")
                .upload(
                    path: fileName,
                    file: imageData,
                    options: FileOptions(contentType: "image/jpeg")
                )
            
            let publicUrl = try supabase.storage
                .from("post-images")
                .getPublicURL(path: fileName)
            
            return publicUrl.absoluteString
        } catch {
            print("Error uploading image: \(error)")
            return nil
        }
    }
    
    // MARK: - Helper Functions
    
    func generateTodaysPrompt() {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let promptIndex = dayOfYear % prompts.count
        todaysPrompt = DailyPrompt(text: prompts[promptIndex])
    }
    
    func getUser(by id: String) -> User? {
        if id == currentUserProfile?.id { return currentUserProfile }
        return friends.first { $0.id == id }
    }
    
    func getUserVibeResponse(for vibeId: String) -> VibeResponseType? {
        guard let userId = currentUserProfile?.id else { return nil }
        guard let vibe = vibes.first(where: { $0.id == vibeId }) else { return nil }
        return vibe.responses.first(where: { $0.userId == userId })?.response
    }
    
    func getActiveVibes() -> [Vibe] {
        vibes.filter { $0.isActive && !$0.isExpired }
    }
    
    func getFeedPosts() -> [Post] {
        let friendIds = Set(friends.map { $0.id })
        let currentUserId = currentUserProfile?.id ?? ""
        return posts.filter { friendIds.contains($0.userId) || $0.userId == currentUserId }
    }
    
    private func calculateExpiresAt(timeDescription: String) -> Date {
        let now = Date()
        switch timeDescription.lowercased() {
        case "now":
            return now.addingTimeInterval(30 * 60)
        case "in 5 min":
            return now.addingTimeInterval(35 * 60)
        case "in 15 min":
            return now.addingTimeInterval(45 * 60)
        case "in 30 min":
            return now.addingTimeInterval(60 * 60)
        case "in 1 hr":
            return now.addingTimeInterval(90 * 60)
        case "later":
            return now.addingTimeInterval(4 * 60 * 60)
        default:
            return now.addingTimeInterval(2 * 60 * 60)
        }
    }
    
    // MARK: - Activity Tracking

    func markPostsAsSeen() {
        if let latestPost = posts.first {
            lastSeenPostTimestamp = latestPost.timestamp
        }
        hasUnreadPosts = false
    }

    func markVibesAsSeen() {
        if let latestVibe = vibes.first {
            lastSeenVibeTimestamp = latestVibe.timestamp
        }
        hasUnreadVibes = false
    }

    func updateUnreadCounts() {
        // Check for unread posts (excluding current user's own posts)
        let currentUserId = currentUserProfile?.id
        let unreadPosts = posts.filter { post in
            post.timestamp > lastSeenPostTimestamp && post.userId != currentUserId
        }
        hasUnreadPosts = !unreadPosts.isEmpty
        
        // Check for unread vibes (excluding current user's own vibes)
        let unreadVibes = vibes.filter { vibe in
            vibe.timestamp > lastSeenVibeTimestamp && vibe.userId != currentUserId
        }
        hasUnreadVibes = !unreadVibes.isEmpty
        
        // Update pending request count
        pendingRequestCount = friendRequests.filter { $0.status == .pending }.count
    }
    
    struct ConnectionPairing {
        let id: String
        let matchedUser: User
        let mutualCount: Int
        let similarityReason: String
        let expiresAt: Date
        var isMatched: Bool = false
        
        var reasonText: String {
            switch similarityReason {
            case "mutuals":
                return mutualCount == 1 ? "you have 1 mutual friend" : "you have \(mutualCount) mutual friends"
            case "same_rating":
                return "you're both having a similar day"
            case "similar_streak":
                return "you both have great streaks going"
            default:
                return "someone new to meet"
            }
        }
    }

    struct DBConnectionPairing: Codable {
        let id: UUID?
        let userA: UUID
        let userB: UUID
        let mutualCount: Int
        let similarityReason: String
        let createdAt: Date?
        let expiresAt: Date?
        let isMatched: Bool?
        
        enum CodingKeys: String, CodingKey {
            case id
            case userA = "user_a"
            case userB = "user_b"
            case mutualCount = "mutual_count"
            case similarityReason = "similarity_reason"
            case createdAt = "created_at"
            case expiresAt = "expires_at"
            case isMatched = "is_matched"
        }
    }
    
    struct DBConnectionPairingInsert: Codable {
        let userA: UUID
        let userB: UUID
        let mutualCount: Int
        let similarityReason: String
        let expiresAt: Date
        
        enum CodingKeys: String, CodingKey {
            case userA = "user_a"
            case userB = "user_b"
            case mutualCount = "mutual_count"
            case similarityReason = "similarity_reason"
            case expiresAt = "expires_at"
        }
    }
    func loadConnectionOfTheWeek() async {
        guard let userId = currentUser?.id else { return }
        
        isLoadingConnection = true
        
        do {
            // Check for existing valid pairing
            let pairings: [DBConnectionPairing] = try await supabase
                .from("connection_pairings")
                .select()
                .or("user_a.eq.\(userId),user_b.eq.\(userId)")
                .gt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
                .execute()
                .value
            
            if let pairing = pairings.first {
                // Get the matched user (the one that isn't current user)
                let matchedUserId = pairing.userA == userId ? pairing.userB : pairing.userA
                
                // Check if they are now friends
                let isFriend = friends.contains { $0.id == matchedUserId.uuidString }
                
                // If they became friends, mark as matched in DB
                if isFriend && pairing.isMatched != true {
                    try? await supabase
                        .from("connection_pairings")
                        .update(["is_matched": true])
                        .eq("id", value: pairing.id!)
                        .execute()
                }
                
                // Fetch matched user details
                let users: [DBUser] = try await supabase
                    .from("users")
                    .select()
                    .eq("id", value: matchedUserId)
                    .execute()
                    .value
                
                if let matchedDBUser = users.first {
                    connectionOfTheWeek = ConnectionPairing(
                        id: pairing.id?.uuidString ?? "",
                        matchedUser: matchedDBUser.toUser(),
                        mutualCount: pairing.mutualCount,
                        similarityReason: pairing.similarityReason,
                        expiresAt: pairing.expiresAt ?? getNextMonday(),
                        isMatched: isFriend || pairing.isMatched == true
                    )
                }
            } else {
                connectionOfTheWeek = nil
            }
        } catch {
            print("Error loading connection of the week: \(error)")
            connectionOfTheWeek = nil
        }
        
        isLoadingConnection = false
    }
    
    // Helper to get next Monday at midnight
    private func getNextMonday() -> Date {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysUntilMonday = (9 - weekday) % 7
        let nextMonday = calendar.date(byAdding: .day, value: daysUntilMonday == 0 ? 7 : daysUntilMonday, to: today)!
        return calendar.startOfDay(for: nextMonday)
    }

    func refreshConnectionOfTheWeek() async {
        guard let userId = currentUser?.id else { return }
        
        // Check if user has max friends (using dynamic limit)
        if friends.count >= PremiumManager.shared.friendLimit {
            connectionOfTheWeek = nil
            return
        }
        
        // If current connection is matched, don't allow refresh - just reload
        if connectionOfTheWeek?.isMatched == true {
            await loadConnectionOfTheWeek()
            return
        }
        
        isLoadingConnection = true
        
        do {
            // Check if there's an existing matched pairing - don't delete it
            let existingPairings: [DBConnectionPairing] = try await supabase
                .from("connection_pairings")
                .select()
                .or("user_a.eq.\(userId),user_b.eq.\(userId)")
                .execute()
                .value
            
            // If there's a matched pairing, just reload and return
            if let existingPairing = existingPairings.first, existingPairing.isMatched == true {
                await loadConnectionOfTheWeek()
                isLoadingConnection = false
                return
            }
            
            // Delete any existing non-matched pairing for this user
            try await supabase
                .from("connection_pairings")
                .delete()
                .or("user_a.eq.\(userId),user_b.eq.\(userId)")
                .eq("is_matched", value: false)
                .execute()
            
            // Call the database function to find a match
            let result: [MatchResult] = try await supabase
                .rpc("find_connection_match", params: ["p_user_id": userId])
                .execute()
                .value
            
            if let match = result.first, let matchedUserId = match.matchedUserId {
                // Create the pairing with global expiry time (next Monday)
                let newPairing = DBConnectionPairingInsert(
                    userA: userId,
                    userB: matchedUserId,
                    mutualCount: match.mutualCount,
                    similarityReason: match.similarityReason ?? "random",
                    expiresAt: getNextMonday()
                )

                try await supabase
                    .from("connection_pairings")
                    .insert(newPairing)
                    .execute()
                
                // Send push notification to the matched user
                if let senderName = currentUserProfile?.displayName {
                    await sendPushNotification(
                        type: "connection_match",
                        to: matchedUserId.uuidString,
                        senderName: senderName
                    )
                }
                
                // Reload to get the full pairing with user details
                await loadConnectionOfTheWeek()
            } else {
                connectionOfTheWeek = nil
            }
        } catch {
            print("Error refreshing connection: \(error)")
            connectionOfTheWeek = nil
        }
        
        isLoadingConnection = false
    }

    struct MatchResult: Codable {
        let matchedUserId: UUID?
        let mutualCount: Int
        let similarityReason: String?
        
        enum CodingKeys: String, CodingKey {
            case matchedUserId = "matched_user_id"
            case mutualCount = "mutual_count"
            case similarityReason = "similarity_reason"
        }
    }
    
    // MARK: - Friendship Score
    
    /// Preload all friendship scores in background (batch RPC)
    func preloadAllFriendshipScores() async {
        guard let currentUserId = currentUser?.id else { return }
        
        // Don't reload if we have recent scores for all friends
        let allCached = friends.allSatisfy { friend in
            FriendshipScoreCache.shared.getScore(for: friend.id) != nil
        }
        if allCached && !friends.isEmpty { return }
        
        print("📊 Preloading all friendship scores...")
        
        do {
            // Try batch RPC first
            let response: BatchFriendshipScoreResponse = try await supabase
                .rpc("calculate_batch_friendship_scores", params: [
                    "current_user_id": currentUserId.uuidString
                ])
                .execute()
                .value
            
            // Cache all scores
            for scoreData in response.scores {
                let breakdown = FriendshipScore.ScoreBreakdown(
                    likesGiven: scoreData.likesGiven,
                    likesReceived: scoreData.likesReceived,
                    repliesGiven: scoreData.repliesGiven,
                    repliesReceived: scoreData.repliesReceived,
                    vibeResponsesGiven: scoreData.vibeResponsesGiven,
                    vibeResponsesReceived: scoreData.vibeResponsesReceived,
                    matchingRatingDays: scoreData.matchingRatingDays,
                    friendshipWeeks: scoreData.friendshipWeeks
                )
                let friendshipScore = FriendshipScore(
                    id: scoreData.friendId,
                    score: scoreData.score,
                    breakdown: breakdown
                )
                FriendshipScoreCache.shared.cacheScore(friendshipScore)
            }
            print("📊 Cached \(response.scores.count) friendship scores")
        } catch {
            print("📊 Batch RPC failed, falling back to individual loading: \(error.localizedDescription)")
            // Fallback: Load individually in parallel (limited concurrency)
            await withTaskGroup(of: Void.self) { group in
                for friend in friends.prefix(10) {
                    group.addTask {
                        _ = await self.calculateFriendshipScore(for: friend.id)
                    }
                }
            }
        }
    }
    
    /// Calculate friendship score for a specific friend
    /// Optimized: Uses RPC if available, falls back to client-side batched queries
    func calculateFriendshipScore(for friendId: String) async -> FriendshipScore? {
        guard let currentUserId = currentUser?.id,
              let friendUUID = UUID(uuidString: friendId) else {
            return nil
        }
        
        // Check cache first
        if let cached = FriendshipScoreCache.shared.getScore(for: friendId) {
            return cached
        }
        
        // Mark as loading
        FriendshipScoreCache.shared.setLoading(friendId, loading: true)
        defer { FriendshipScoreCache.shared.setLoading(friendId, loading: false) }
        
        // Try RPC first (most efficient - single database round trip)
        if let score = await calculateScoreViaRPC(currentUserId: currentUserId, friendId: friendUUID) {
            let friendshipScore = score.toFriendshipScore(friendId: friendId)
            FriendshipScoreCache.shared.cacheScore(friendshipScore)
            return friendshipScore
        }
        
        // Fallback: Client-side calculation with batched parallel queries
        return await calculateScoreClientSide(currentUserId: currentUserId, friendId: friendUUID)
    }
    
    /// Try to calculate score via Supabase RPC (PostgreSQL function)
    private func calculateScoreViaRPC(currentUserId: UUID, friendId: UUID) async -> FriendshipScoreResponse? {
        do {
            let response: FriendshipScoreResponse = try await supabase
                .rpc("calculate_friendship_score", params: [
                    "current_user_id": currentUserId.uuidString,
                    "friend_user_id": friendId.uuidString
                ])
                .execute()
                .value
            
            return response
        } catch {
            // RPC doesn't exist yet - fall back to client-side
            print("RPC not available, using client-side calculation: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Client-side calculation with optimized batched queries
    private func calculateScoreClientSide(currentUserId: UUID, friendId: UUID) async -> FriendshipScore? {
        print("📊 Calculating friendship score client-side for friend: \(friendId)")
        
        // Run queries individually to handle errors gracefully
        let friendshipDate = await getFriendshipCreatedAt(userId: currentUserId, friendId: friendId)
        let likesGiven = await countLikesGivenSafe(from: currentUserId, to: friendId)
        let likesReceived = await countLikesGivenSafe(from: friendId, to: currentUserId)
        let repliesGiven = await countRepliesGivenSafe(from: currentUserId, to: friendId)
        let repliesReceived = await countRepliesGivenSafe(from: friendId, to: currentUserId)
        let vibeResponsesGiven = await countVibeResponsesSafe(responder: friendId, vibeCreator: currentUserId)
        let vibeResponsesReceived = await countVibeResponsesSafe(responder: currentUserId, vibeCreator: friendId)
        let matchingDays = await countMatchingRatingDaysSafe(user1: currentUserId, user2: friendId)
        
        print("📊 Score breakdown - Likes: \(likesGiven)/\(likesReceived), Replies: \(repliesGiven)/\(repliesReceived), Vibes: \(vibeResponsesGiven)/\(vibeResponsesReceived), Matching days: \(matchingDays)")
        
        // Calculate friendship weeks
        let friendshipWeeks: Int
        if let date = friendshipDate {
            let weeks = Calendar.current.dateComponents([.weekOfYear], from: date, to: Date()).weekOfYear ?? 0
            friendshipWeeks = max(1, weeks) // At least 1 if they're friends
            print("📊 Friendship created: \(date), weeks: \(friendshipWeeks)")
        } else {
            friendshipWeeks = 1 // Default to 1 week if friendship exists but no date
            print("📊 No friendship date found, defaulting to 1 week")
        }
        
        // Calculate total score with weights:
        // - Likes: 1 point each
        // - Replies: 2 points each
        // - Vibe responses: 3 points each
        // - Matching rating days: 1 point each
        // - Friendship duration: 1 point per week
        let score = likesGiven + likesReceived +
                    (repliesGiven + repliesReceived) * 2 +
                    (vibeResponsesGiven + vibeResponsesReceived) * 3 +
                    matchingDays +
                    friendshipWeeks
        
        print("📊 Total friendship score: \(score)")
        
        let breakdown = FriendshipScore.ScoreBreakdown(
            likesGiven: likesGiven,
            likesReceived: likesReceived,
            repliesGiven: repliesGiven,
            repliesReceived: repliesReceived,
            vibeResponsesGiven: vibeResponsesGiven,
            vibeResponsesReceived: vibeResponsesReceived,
            matchingRatingDays: matchingDays,
            friendshipWeeks: friendshipWeeks
        )
        
        let friendshipScore = FriendshipScore(
            id: friendId.uuidString,
            score: score,
            breakdown: breakdown
        )
        
        // Cache the result
        FriendshipScoreCache.shared.cacheScore(friendshipScore)
        
        return friendshipScore
    }
    
    // MARK: - Friendship Score Helper Queries (Safe versions that don't throw)
    
    /// Get when the friendship was created
    private func getFriendshipCreatedAt(userId: UUID, friendId: UUID) async -> Date? {
        do {
            let friendships: [DBCreatedAtOnly] = try await supabase
                .from("friendships")
                .select("created_at")
                .eq("user_id", value: userId)
                .eq("friend_id", value: friendId)
                .limit(1)
                .execute()
                .value
            
            return friendships.first?.createdAt
        } catch {
            print("📊 Error getting friendship date: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Count likes given from one user to another's posts (safe - returns 0 on error)
    private func countLikesGivenSafe(from likerId: UUID, to postOwnerId: UUID) async -> Int {
        do {
            // Get posts by postOwnerId
            let posts: [DBIdOnly] = try await supabase
                .from("posts")
                .select("id")
                .eq("user_id", value: postOwnerId)
                .execute()
                .value
            
            guard !posts.isEmpty else { return 0 }
            let postIds = posts.map { $0.id }
            
            // Count likes by likerId on those posts
            let likes: [DBIdOnly] = try await supabase
                .from("post_likes")
                .select("id")
                .eq("user_id", value: likerId)
                .in("post_id", values: postIds)
                .execute()
                .value
            
            return likes.count
        } catch {
            print("📊 Error counting likes: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// Count replies given from one user to another's posts (safe - returns 0 on error)
    private func countRepliesGivenSafe(from replierId: UUID, to postOwnerId: UUID) async -> Int {
        do {
            // Get posts by postOwnerId
            let posts: [DBIdOnly] = try await supabase
                .from("posts")
                .select("id")
                .eq("user_id", value: postOwnerId)
                .execute()
                .value
            
            guard !posts.isEmpty else { return 0 }
            let postIds = posts.map { $0.id }
            
            // Count replies by replierId on those posts
            let replies: [DBIdOnly] = try await supabase
                .from("post_replies")
                .select("id")
                .eq("user_id", value: replierId)
                .in("post_id", values: postIds)
                .execute()
                .value
            
            return replies.count
        } catch {
            print("📊 Error counting replies: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// Count vibe responses where responder joined vibes created by vibeCreator (safe)
    private func countVibeResponsesSafe(responder: UUID, vibeCreator: UUID) async -> Int {
        do {
            // Get vibes by vibeCreator
            let vibes: [DBIdOnly] = try await supabase
                .from("vibes")
                .select("id")
                .eq("user_id", value: vibeCreator)
                .execute()
                .value
            
            guard !vibes.isEmpty else { return 0 }
            let vibeIds = vibes.map { $0.id }
            
            // Count "yes" responses by responder
            let responses: [DBIdOnly] = try await supabase
                .from("vibe_responses")
                .select("id")
                .eq("user_id", value: responder)
                .eq("response", value: "yes")
                .in("vibe_id", values: vibeIds)
                .execute()
                .value
            
            return responses.count
        } catch {
            print("📊 Error counting vibe responses: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// Count days where both users rated the same day (safe - returns 0 on error)
    private func countMatchingRatingDaysSafe(user1: UUID, user2: UUID) async -> Int {
        do {
            // Get rating dates for user1
            let user1Ratings: [DBDateOnly] = try await supabase
                .from("rating_history")
                .select("date")
                .eq("user_id", value: user1)
                .execute()
                .value
            
            guard !user1Ratings.isEmpty else { return 0 }
            
            // Get rating dates for user2
            let user2Ratings: [DBDateOnly] = try await supabase
                .from("rating_history")
                .select("date")
                .eq("user_id", value: user2)
                .execute()
                .value
            
            guard !user2Ratings.isEmpty else { return 0 }
            
            // Count matching dates
            let user1Dates = Set(user1Ratings.map { Calendar.current.startOfDay(for: $0.date) })
            let user2Dates = Set(user2Ratings.map { Calendar.current.startOfDay(for: $0.date) })
            
            return user1Dates.intersection(user2Dates).count
        } catch {
            print("📊 Error counting matching rating days: \(error.localizedDescription)")
            return 0
        }
    }
}

// MARK: - Database Model Extensions

extension DBUser {
    func toUser() -> User {
        User(
            id: id?.uuidString ?? UUID().uuidString,
            username: username,
            displayName: displayName,
            bio: bio,
            todayRating: todayRating,
            ratingTimestamp: ratingTimestamp,
            friendIds: [],
            ratingHistory: [],
            premiumExpiresAt: premiumExpiresAt,
            selectedThemeId: selectedThemeId
        )
    }
}

extension DBVibe {
    func toVibe(responses: [DBVibeResponse]) -> Vibe {
        Vibe(
            id: id?.uuidString ?? UUID().uuidString,
            userId: userId.uuidString,
            title: title,
            timeDescription: timeDescription,
            location: location,
            timestamp: timestamp ?? Date(),
            responses: responses.map { $0.toVibeResponse() },
            isActive: isActive
        )
    }
}

extension DBVibeResponse {
    func toVibeResponse() -> VibeResponse {
        VibeResponse(
            id: id?.uuidString ?? UUID().uuidString,
            userId: userId.uuidString,
            response: VibeResponseType(rawValue: response) ?? .no,
            timestamp: timestamp ?? Date()
        )
    }
}

extension DBPost {
    func toPost(likes: [DBPostLike], replies: [DBPostReply]) -> Post {
        Post(
            id: id?.uuidString ?? UUID().uuidString,
            userId: userId.uuidString,
            imageData: nil, // We'll load from URL separately
            imageUrl: imageUrl,
            caption: caption,
            plusOnes: likes.map { PlusOne(id: $0.id?.uuidString ?? UUID().uuidString, userId: $0.userId.uuidString, timestamp: $0.timestamp ?? Date()) },
            replies: replies.map { Reply(id: $0.id?.uuidString ?? UUID().uuidString, userId: $0.userId.uuidString, text: $0.text, timestamp: $0.timestamp ?? Date()) },
            timestamp: timestamp ?? Date(),
            promptResponse: promptResponse,
            promptId: promptId,
            promptText: promptText,
            rating: rating
        )
    }
}
