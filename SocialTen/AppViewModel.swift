//
//  AppViewModel.swift
//  SocialTen
//
//  Created on 12/3/25.
//

import SwiftUI

@Observable
class AppViewModel: ObservableObject {
    // Current user and social graph
    var currentUser: User?
    var friends: [User] = []
    var isLoggedIn: Bool = false
    
    // Friend request system
    var friendRequests: [FriendRequest] = []
    
    // Posts, vibes, rating history, prompt
    var posts: [Post] = []
    var ratingHistory: [RatingEntry] = []
    var todaysPrompt: DailyPrompt = DailyPrompt(text: "what made you smile today?")
    var vibes: [Vibe] = []
    
    // Sample users pool (search etc.)
    private var allUsers: [User] = []
    
    // Prompts pool
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
        loadSampleData()
        generateTodaysPrompt()
    }
    
    // MARK: - Prompt
    
    func generateTodaysPrompt() {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let promptIndex = dayOfYear % prompts.count
        todaysPrompt = DailyPrompt(text: prompts[promptIndex])
    }
    
    // MARK: - Sample Data
    
    func loadSampleData() {
        let calendar = Calendar.current
        
        func generateRatingHistory() -> [RatingEntry] {
            (1...6).compactMap { daysAgo in
                guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { return nil }
                return RatingEntry(rating: Int.random(in: 4...10), date: date)
            }
        }
        
        // Create sample friends
        let friend1 = User(
            id: "friend1",
            username: "alex_smith",
            displayName: "Alex",
            bio: "living in the moment",
            todayRating: 8,
            ratingTimestamp: Date(),
            profileCustomization: ProfileCustomization(
                glowColor: CodableColor(color: GlowPreset.cyan.color),
                glowIntensity: 0.4
            ),
            ratingHistory: generateRatingHistory()
        )
        let friend2 = User(
            id: "friend2",
            username: "jordan_lee",
            displayName: "Jordan",
            bio: "coffee. code. repeat.",
            todayRating: 6,
            ratingTimestamp: Date(),
            profileCustomization: ProfileCustomization(
                glowColor: CodableColor(color: GlowPreset.green.color),
                glowIntensity: 0.3
            ),
            ratingHistory: generateRatingHistory()
        )
        let friend3 = User(
            id: "friend3",
            username: "sam_taylor",
            displayName: "Sam",
            bio: "chasing horizons",
            todayRating: 9,
            ratingTimestamp: Date(),
            profileCustomization: ProfileCustomization(
                glowColor: CodableColor(color: GlowPreset.orange.color),
                glowIntensity: 0.5
            ),
            ratingHistory: generateRatingHistory()
        )
        let friend4 = User(
            id: "friend4",
            username: "riley_chen",
            displayName: "Riley",
            bio: "music is the answer",
            todayRating: 4,
            ratingTimestamp: Date(),
            profileCustomization: ProfileCustomization(
                glowColor: CodableColor(color: GlowPreset.purple.color),
                glowIntensity: 0.35
            ),
            ratingHistory: generateRatingHistory()
        )
        let friend5 = User(
            id: "friend5",
            username: "casey_jones",
            displayName: "Casey",
            bio: "simplicity",
            todayRating: 7,
            ratingTimestamp: Date(),
            profileCustomization: ProfileCustomization(
                glowColor: CodableColor(color: GlowPreset.blue.color),
                glowIntensity: 0.4
            ),
            ratingHistory: generateRatingHistory()
        )
        
        let user6 = User(
            id: "user6",
            username: "taylor_swift",
            displayName: "Taylor",
            bio: "music lover",
            profileCustomization: ProfileCustomization(
                glowColor: CodableColor(color: GlowPreset.pink.color),
                glowIntensity: 0.4
            ),
            ratingHistory: generateRatingHistory()
        )
        let user7 = User(
            id: "user7",
            username: "jamie_doe",
            displayName: "Jamie",
            bio: "photographer",
            profileCustomization: ProfileCustomization(
                glowColor: CodableColor(color: GlowPreset.white.color),
                glowIntensity: 0.3
            ),
            ratingHistory: generateRatingHistory()
        )
        
        allUsers = [friend1, friend2, friend3, friend4, friend5, user6, user7]
        friends = [friend1, friend2, friend3, friend4, friend5]
        
        // Current user
        currentUser = User(
            id: "currentUser",
            username: "you",
            displayName: "You",
            bio: "be real",
            todayRating: nil,
            friendIds: friends.map { $0.id },
            ratingHistory: generateRatingHistory()
        )
        
        // Friend requests
        friendRequests = [FriendRequest(fromUserId: "user6", toUserId: "currentUser")]
        
        // Sample posts (uses new Post model)
        posts = [
            Post(
                userId: "friend1",
                caption: "great day at the beach",
                plusOnes: [PlusOne(userId: "friend2"), PlusOne(userId: "friend3")],
                replies: []
            ),
            Post(
                userId: "friend3",
                plusOnes: [],
                replies: [],
                promptResponse: "my morning coffee",
                promptId: todaysPrompt.id
            )
        ]
        
        // Sample vibes
        let sampleVibe1 = Vibe(
            userId: "friend2",
            title: "Study session?",
            timeDescription: "in 30 min",
            location: "Library"
        )
        let sampleVibe2 = Vibe(
            userId: "friend1",
            title: "Football tonight",
            timeDescription: "later",
            location: "Main field"
        )
        vibes = [sampleVibe1, sampleVibe2]
        
        // Rating history (last 7)
        ratingHistory = (1...5).compactMap { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { return nil }
            return RatingEntry(rating: Int.random(in: 5...9), date: date)
        }
        
        isLoggedIn = true
    }
    
    // MARK: - Rating methods
    
    func updateRating(_ value: Int) {
        currentUser?.todayRating = value
        currentUser?.ratingTimestamp = Date()
        
        // Add to history
        let today = Date()
        if let existingIndex = ratingHistory.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            ratingHistory[existingIndex] = RatingEntry(rating: value, date: today)
        } else {
            ratingHistory.append(RatingEntry(rating: value, date: today))
        }
    }
    
    func getLast7DaysRatings() -> [RatingEntry] {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return ratingHistory.filter { $0.date >= sevenDaysAgo }.sorted { $0.date < $1.date }
    }
    
    // MARK: - Profile
    
    func updateProfile(displayName: String, bio: String, customization: ProfileCustomization) {
        currentUser?.displayName = displayName
        currentUser?.bio = bio
        currentUser?.profileCustomization = customization
    }
    
    // MARK: - User helpers
    
    func getUser(by id: String) -> User? {
        if id == currentUser?.id { return currentUser }
        return allUsers.first { $0.id == id }
    }
    
    func getUserById(_ id: String) -> User? { getUser(by: id) }
    
    // MARK: - Posts
    
    func createPost(imageData: Data?, caption: String?, promptResponse: String? = nil) {
        guard let userId = currentUser?.id else { return }
        let post = Post(
            userId: userId,
            imageData: imageData,
            caption: caption,
            plusOnes: [],
            replies: [],
            promptResponse: promptResponse,
            promptId: promptResponse != nil ? todaysPrompt.id : nil
        )
        posts.insert(post, at: 0)
    }
    
    func getFeedPosts() -> [Post] {
        let friendIds = Set(friends.map { $0.id })
        let currentUserId = currentUser?.id ?? ""
        return posts.filter { friendIds.contains($0.userId) || $0.userId == currentUserId }.sorted { $0.timestamp > $1.timestamp }
    }
    
    func togglePlusOne(for postId: String) {
        guard let userId = currentUser?.id else { return }
        guard let postIndex = posts.firstIndex(where: { $0.id == postId }) else { return }
        if let existingIndex = posts[postIndex].plusOnes.firstIndex(where: { $0.userId == userId }) {
            posts[postIndex].plusOnes.remove(at: existingIndex)
        } else {
            let plusOne = PlusOne(userId: userId)
            posts[postIndex].plusOnes.append(plusOne)
        }
    }
    
    func addReply(to postId: String, text: String) {
        guard let userId = currentUser?.id else { return }
        guard let postIndex = posts.firstIndex(where: { $0.id == postId }) else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let reply = Reply(userId: userId, text: text)
        posts[postIndex].replies.append(reply)
    }
    
    // MARK: - Friend system
    
    func searchUsers(query: String) -> [User] {
        guard !query.isEmpty else { return [] }
        let lowercasedQuery = query.lowercased()
        return allUsers.filter { user in
            guard user.id != currentUser?.id else { return false }
            guard !friends.contains(where: { $0.id == user.id }) else { return false }
            return user.username.lowercased().contains(lowercasedQuery) || user.displayName.lowercased().contains(lowercasedQuery)
        }
    }
    
    func getFriendRequestStatus(for userId: String) -> FriendRequestStatus {
        if friends.contains(where: { $0.id == userId }) { return .friends }
        if friendRequests.contains(where: {
            ($0.fromUserId == currentUser?.id && $0.toUserId == userId && $0.status == .pending) ||
            ($0.fromUserId == userId && $0.toUserId == currentUser?.id && $0.status == .pending)
        }) { return .pending }
        return .none
    }
    
    func getIncomingRequests() -> [FriendRequest] {
        friendRequests.filter { $0.toUserId == currentUser?.id && $0.status == .pending }
    }
    
    func getOutgoingRequests() -> [FriendRequest] {
        friendRequests.filter { $0.fromUserId == currentUser?.id && $0.status == .pending }
    }
    
    func sendFriendRequest(to userId: String) {
        guard let currentUserId = currentUser?.id else { return }
        guard currentUser?.canAddMoreFriends == true else { return }
        guard !friendRequests.contains(where: {
            ($0.fromUserId == currentUserId && $0.toUserId == userId) ||
            ($0.fromUserId == userId && $0.toUserId == currentUserId)
        }) else { return }
        let request = FriendRequest(fromUserId: currentUserId, toUserId: userId)
        friendRequests.append(request)
    }
    
    func acceptFriendRequest(_ requestId: String) {
        guard let index = friendRequests.firstIndex(where: { $0.id == requestId }) else { return }
        guard currentUser?.canAddMoreFriends == true else { return }
        let request = friendRequests[index]
        friendRequests[index].status = .accepted
        if let newFriend = allUsers.first(where: { $0.id == request.fromUserId }) {
            friends.append(newFriend)
            currentUser?.friendIds.append(newFriend.id)
        }
    }
    
    func declineFriendRequest(_ requestId: String) {
        guard let index = friendRequests.firstIndex(where: { $0.id == requestId }) else { return }
        friendRequests[index].status = .declined
    }
    
    func cancelFriendRequest(_ requestId: String) {
        friendRequests.removeAll { $0.id == requestId }
    }
    
    func removeFriend(_ friendId: String) {
        friends.removeAll { $0.id == friendId }
        currentUser?.friendIds.removeAll { $0 == friendId }
    }
    
    // MARK: - Vibes
    
    func createVibe(title: String, timeDescription: String, location: String) {
        guard let userId = currentUser?.id else { return }
        let vibe = Vibe(userId: userId, title: title, timeDescription: timeDescription, location: location)
        vibes.insert(vibe, at: 0)
    }
    
    func getActiveVibes() -> [Vibe] {
        // Filter out expired and inactive vibes
        vibes.filter { $0.isActive && !$0.isExpired }.sorted { $0.timestamp > $1.timestamp }
    }
    
    func respondToVibe(_ vibeId: String, response: VibeResponseType) {
        guard let userId = currentUser?.id else { return }
        guard let index = vibes.firstIndex(where: { $0.id == vibeId }) else { return }
        // Remove any existing response by this user
        vibes[index].responses.removeAll { $0.userId == userId }
        // Add new response
        let vr = VibeResponse(userId: userId, response: response)
        vibes[index].responses.append(vr)
    }
    
    func getUserVibeResponse(for vibeId: String) -> VibeResponseType? {
        guard let userId = currentUser?.id else { return nil }
        guard let vibe = vibes.first(where: { $0.id == vibeId }) else { return nil }
        return vibe.responses.first(where: { $0.userId == userId })?.response
    }
    
    func cancelVibe(_ vibeId: String) {
        if let index = vibes.firstIndex(where: { $0.id == vibeId }) {
            vibes[index].isActive = false
        }
    }
    
    func deleteVibe(_ vibeId: String) {
        vibes.removeAll { $0.id == vibeId }
    }
}
