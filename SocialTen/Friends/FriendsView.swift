//
//  FriendsView.swift
//  SocialTen
//

import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @EnvironmentObject var badgeManager: BadgeManager
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var scoreCache = FriendshipScoreCache.shared
    @ObservedObject private var groupsManager = GroupsManager.shared
    @State private var searchText = ""
    @State private var selectedFriend: User?
    @State private var showAddFriend = false
    @State private var showRequests = false
    @State private var showSettings = false
    @State private var selectedBadgeForToast: BadgeDefinition? = nil
    @State private var showConnectionProfile = false
    @State private var connectionRequestSent = false
    
    // Check if any scores are loaded
    private var hasLoadedScores: Bool {
        viewModel.friends.contains { scoreCache.scores[$0.id] != nil }
    }
    
    // Sort friends by friendship score (highest first), fallback to alphabetical
    var sortedFriends: [User] {
        if hasLoadedScores {
            return viewModel.friends.sorted { friend1, friend2 in
                let score1 = scoreCache.scores[friend1.id]?.score ?? 0
                let score2 = scoreCache.scores[friend2.id]?.score ?? 0
                if score1 != score2 {
                    return score1 > score2
                }
                // Tiebreaker: alphabetical
                return friend1.displayName.lowercased() < friend2.displayName.lowercased()
            }
        } else {
            // Fallback: alphabetical sort
            return viewModel.friends.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
        }
    }
    
    // Best friend is the one with highest score (if they have any score)
    var bestFriendId: String? {
        guard !viewModel.friends.isEmpty, hasLoadedScores else { return nil }
        let topFriend = sortedFriends.first
        // Only mark as best friend if they have a meaningful score
        if let id = topFriend?.id, let score = scoreCache.scores[id]?.score, score >= 10 {
            return id
        }
        return nil
    }
    
    var filteredFriends: [User] {
        var base = sortedFriends
        
        // Filter by selected group first
        base = groupsManager.filterFriends(base)
        
        // Then filter by search text
        if searchText.isEmpty {
            return base
        }
        return base.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var pendingRequestsCount: Int {
        viewModel.friendRequests.filter { $0.status == .pending }.count
    }
    
    // Get top 3 badges by rarity
    var topBadges: [BadgeDefinition] {
        let earned = badgeManager.earnedBadgeDefinitions
        let sorted = earned.sorted { $0.rarity.glowIntensity > $1.rarity.glowIntensity }
        return Array(sorted.prefix(3))
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            SmartScrollView {
                VStack(spacing: themeManager.spacing.xl) {
                    // Header
                    header
                        .padding(.top, themeManager.spacing.lg)
                    
                    // Your Profile Card
                    profileCard
                    
                    // Friend Requests Banner (if any)
                    if pendingRequestsCount > 0 {
                        requestsBanner
                    }
                    
                    // Search
                    searchBar
                    
                    // Friends Section (includes groups row)
                    friendsSection
                    
                    // Add Friend Button
                    addFriendButton
                    
                    // Connection of the Week
                    connectionOfTheWeekCard
                        .padding(.top, themeManager.spacing.md)
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, themeManager.spacing.screenHorizontal)
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                }
            }
            
            // Badge toast notification
            if let badge = selectedBadgeForToast {
                BadgeToastNotification(
                    badge: badge,
                    isVisible: Binding(
                        get: { selectedBadgeForToast != nil },
                        set: { if !$0 { selectedBadgeForToast = nil } }
                    )
                )
                .padding(.bottom, 100)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(themeManager.colors.background.ignoresSafeArea())
        .task {
            // Preload all friendship scores in background
            await viewModel.preloadAllFriendshipScores()
            // Load user's groups
            await groupsManager.loadGroups()
        }
        .fullScreenCover(item: $selectedFriend) { friend in
            FriendDetailView(friend: friend)
        }
        .fullScreenCover(isPresented: $showAddFriend) {
            AddFriendView()
        }
        .fullScreenCover(isPresented: $showRequests) {
            FriendRequestsView()
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
    }
    
    // MARK: - Header
    
    var header: some View {
        Text("friends")
            .font(themeManager.fonts.title)
            .foregroundColor(themeManager.colors.textPrimary)
            .tracking(themeManager.letterSpacing.wide)
    }
    
    // MARK: - Profile Card
    
    var profileCard: some View {
        DepthCard {
            VStack(spacing: themeManager.spacing.md) {
                HStack(spacing: themeManager.spacing.md) {
                    // Avatar
                    ZStack {
                        // Outer glow for premium users
                        if PremiumManager.shared.isPremium {
                            Circle()
                                .stroke(themeManager.currentTheme.glowColor.opacity(0.4), lineWidth: 2)
                                .frame(width: 60, height: 60)
                                .blur(radius: 3)
                        }
                        
                        Circle()
                            .fill(themeManager.colors.cardBackground)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle()
                                    .stroke(PremiumManager.shared.isPremium ? themeManager.currentTheme.glowColor.opacity(0.5) : Color.clear, lineWidth: 1.5)
                            )
                            .overlay(
                                Text(String(viewModel.currentUserProfile?.displayName.prefix(1) ?? "?").lowercased())
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundColor(PremiumManager.shared.isPremium ? themeManager.currentTheme.glowColor : themeManager.colors.textSecondary)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(viewModel.currentUserProfile?.displayName.lowercased() ?? "you")
                                .font(themeManager.fonts.body)
                                .foregroundColor(themeManager.colors.textPrimary)
                            
                            // ten+ badge for premium users
                            if PremiumManager.shared.isPremium {
                                TenPlusBadge(glowColor: themeManager.currentTheme.glowColor, size: .small)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Text("@\(viewModel.currentUserProfile?.username ?? "username")")
                                .font(themeManager.fonts.caption)
                                .foregroundColor(themeManager.colors.textTertiary)
                            
                            // Show theme name for premium users
                            if PremiumManager.shared.isPremium {
                                Text("·")
                                    .foregroundColor(themeManager.colors.textTertiary)
                                Text(themeManager.currentTheme.name.lowercased())
                                    .font(themeManager.fonts.caption)
                                    .foregroundColor(themeManager.currentTheme.glowColor.opacity(0.8))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Settings button
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(themeManager.colors.textTertiary)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(themeManager.colors.background)
                            )
                    }
                }
                
                // Badges and Streak Row
                if !topBadges.isEmpty || badgeManager.currentStreak > 0 {
                    HStack(spacing: themeManager.spacing.md) {
                        // Top Badges
                        if !topBadges.isEmpty {
                            HStack(spacing: -8) {
                                ForEach(topBadges) { badge in
                                    Button(action: {
                                        selectedBadgeForToast = badge
                                    }) {
                                        BadgeIconView(badge: badge, isEarned: true, size: 28)
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Streak
                        if badgeManager.currentStreak > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                                Text("\(badgeManager.currentStreak) day streak")
                                    .font(themeManager.fonts.caption)
                                    .foregroundColor(themeManager.colors.textTertiary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }            }
            .padding(themeManager.spacing.md)
        }
    }
    
    // MARK: - Requests Banner
    
    var requestsBanner: some View {
        Button(action: { showRequests = true }) {
            HStack {
                Circle()
                    .fill(themeManager.colors.accent1)
                    .frame(width: 8, height: 8)
                
                Text("\(pendingRequestsCount) pending request\(pendingRequestsCount > 1 ? "s" : "")")
                    .font(themeManager.fonts.caption)
                    .foregroundColor(themeManager.colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(themeManager.colors.textTertiary)
            }
            .padding(themeManager.spacing.md)
            .background(
                RoundedRectangle(cornerRadius: themeManager.radius.md)
                    .fill(themeManager.colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: themeManager.radius.md)
                            .stroke(themeManager.colors.accent1.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Search Bar
    
    var searchBar: some View {
        HStack(spacing: themeManager.spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(themeManager.colors.textTertiary)
            
            TextField("", text: $searchText)
                .placeholder(when: searchText.isEmpty) {
                    Text("search friends")
                        .foregroundColor(themeManager.colors.textTertiary)
                }
                .font(themeManager.fonts.body)
                .foregroundColor(themeManager.colors.textPrimary)
                .submitLabel(.search)
                .onSubmit {
                    hideKeyboard()
                }
        }
        .padding(.horizontal, themeManager.spacing.md)
        .padding(.vertical, themeManager.spacing.sm + 4)
        .background(
            RoundedRectangle(cornerRadius: themeManager.radius.md)
                .fill(themeManager.colors.cardBackground)
        )
    }
    
    // MARK: - Friends Section
    
    var friendsSectionTitle: String {
        let limit = PremiumManager.shared.friendLimit
        let count = viewModel.friends.count
        if PremiumManager.shared.isPremium {
            return "your circle (\(count)/\(limit))"
        } else {
            return "your ten (\(count)/\(limit))"
        }
    }
    
    var friendsSection: some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            Text(friendsSectionTitle)
                .font(themeManager.fonts.caption)
                .foregroundColor(themeManager.colors.textTertiary)
                .tracking(themeManager.letterSpacing.wide)
                .textCase(.uppercase)
            
            // Groups row (under the title)
            GroupChipsRow(friendCount: viewModel.friends.count)
            
            if filteredFriends.isEmpty {
                emptyState
            } else {
                friendsScrollRow
            }
        }
    }
    
    var emptyState: some View {
        VStack(spacing: themeManager.spacing.md) {
            Image(systemName: "person.2")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(themeManager.colors.textTertiary)
            
            Text(searchText.isEmpty ? "no friends yet" : "no results")
                .font(themeManager.fonts.body)
                .foregroundColor(themeManager.colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, themeManager.spacing.xxl)
    }
    
    var friendsScrollRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: themeManager.spacing.md) {
                ForEach(filteredFriends) { friend in
                    FriendScrollCard(
                        friend: friend,
                        isBestFriend: friend.id == bestFriendId
                    ) {
                        selectedFriend = friend
                    }
                }
            }
        }
    }
    
    // MARK: - Add Friend Button
    
    var addFriendButton: some View {
        Button(action: { showAddFriend = true }) {
            HStack {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                Text("add friend")
                    .font(themeManager.fonts.caption)
                    .tracking(themeManager.letterSpacing.wide)
            }
            .foregroundColor(themeManager.colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, themeManager.spacing.md)
            .background(
                RoundedRectangle(cornerRadius: themeManager.radius.md)
                    .stroke(
                        themeManager.colors.cardBackground,
                        style: StrokeStyle(lineWidth: 1, dash: [8, 4])
                    )
            )
        }
        .disabled(viewModel.friends.count >= PremiumManager.shared.friendLimit)
        .opacity(viewModel.friends.count >= PremiumManager.shared.friendLimit ? 0.5 : 1)
    }
    
    var connectionOfTheWeekCard: some View {
        // Check if connection user is now a friend (for hiding refresh button)
        let isConnectionMatched: Bool = {
            guard let connection = viewModel.connectionOfTheWeek else { return false }
            return connection.isMatched || viewModel.friends.contains { $0.id == connection.matchedUser.id }
        }()
        
        return VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            HStack {
                Text("connection of the week")
                    .font(themeManager.fonts.caption)
                    .foregroundColor(themeManager.colors.textTertiary)
                    .tracking(themeManager.letterSpacing.wide)
                    .textCase(.uppercase)
                
                Spacer()
                
                // Only show refresh if not matched (check both stored state AND current friends list)
                if !isConnectionMatched {
                    Button(action: {
                        connectionRequestSent = false
                        Task {
                            await viewModel.refreshConnectionOfTheWeek()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(themeManager.colors.textTertiary)
                            .rotationEffect(.degrees(viewModel.isLoadingConnection ? 360 : 0))
                            .animation(viewModel.isLoadingConnection ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoadingConnection)
                    }
                    .disabled(viewModel.isLoadingConnection)
                }
            }
            
            if viewModel.friends.count >= PremiumManager.shared.friendLimit {
                circleCompleteCard
            } else if viewModel.isLoadingConnection {
                loadingConnectionCard
            } else if let connection = viewModel.connectionOfTheWeek {
                ConnectionNetworkCard(
                    connection: connection,
                    connectionRequestSent: $connectionRequestSent,
                    showConnectionProfile: $showConnectionProfile,
                    onSendRequest: {
                        Task {
                            await viewModel.sendFriendRequest(toUserId: connection.matchedUser.id)
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                connectionRequestSent = true
                            }
                        }
                    }
                )
                .environmentObject(viewModel)
            } else {
                noMatchCard
            }
        }
    }
    var circleCompleteCard: some View {
        VStack(spacing: themeManager.spacing.md) {
            ZStack {
                Circle()
                    .fill(themeManager.colors.textPrimary.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(themeManager.colors.textPrimary)
            }
            
            Text("your circle is complete")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(themeManager.colors.textPrimary)
            
            Text("you've reached \(PremiumManager.shared.friendLimit) friends")
                .font(themeManager.fonts.caption)
                .foregroundColor(themeManager.colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, themeManager.spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: themeManager.radius.lg)
                .fill(themeManager.colors.cardBackground)
        )
    }
    
    var loadingConnectionCard: some View {
        VStack(spacing: themeManager.spacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.colors.textTertiary))
            
            Text("finding your match...")
                .font(themeManager.fonts.caption)
                .foregroundColor(themeManager.colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .background(
            RoundedRectangle(cornerRadius: themeManager.radius.lg)
                .fill(themeManager.colors.cardBackground)
        )
    }
    
    var noMatchCard: some View {
        VStack(spacing: themeManager.spacing.md) {
            ZStack {
                Circle()
                    .fill(themeManager.colors.cardBackground)
                    .frame(width: 60, height: 60)
                
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 26, weight: .ultraLight))
                    .foregroundColor(themeManager.colors.textTertiary)
            }
            
            Text("no matches yet")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(themeManager.colors.textPrimary)
            
            Text("check back soon")
                .font(themeManager.fonts.caption)
                .foregroundColor(themeManager.colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, themeManager.spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: themeManager.radius.lg)
                .fill(themeManager.colors.cardBackground)
        )
    }
    
    // MARK: - Friend Grid Card
    
    struct FriendGridCard: View {
        @ObservedObject private var themeManager = ThemeManager.shared
        let friend: User
        var isBestFriend: Bool = false
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                VStack(spacing: themeManager.spacing.sm) {
                    // Avatar with rating
                    ZStack {
                        Circle()
                            .fill(themeManager.colors.cardBackground)
                            .frame(width: 64, height: 64)
                        
                        if let rating = friend.todayRating {
                            Text("\(rating)")
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(themeManager.colors.textPrimary)
                        } else {
                            Text(String(friend.displayName.prefix(1)).lowercased())
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(themeManager.colors.textTertiary)
                        }
                    }
                    
                    // Name with BFF indicator
                    HStack(spacing: 4) {
                        Text(friend.displayName.lowercased())
                            .font(themeManager.fonts.caption)
                            .foregroundColor(themeManager.colors.textSecondary)
                            .lineLimit(1)
                        
                        if isBestFriend {
                            Text("bff")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(themeManager.colors.textTertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, themeManager.spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: themeManager.radius.lg)
                        .fill(themeManager.colors.cardBackground)
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    
    // MARK: - Friend Scroll Card (Horizontal)
    
    struct FriendScrollCard: View {
        @ObservedObject private var themeManager = ThemeManager.shared
        let friend: User
        var isBestFriend: Bool = false
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                VStack(spacing: themeManager.spacing.sm) {
                    // Avatar with rating
                    ZStack {
                        Circle()
                            .fill(themeManager.colors.cardBackground)
                            .frame(width: 56, height: 56)
                        
                        if let rating = friend.todayRating {
                            Text("\(rating)")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(themeManager.colors.textPrimary)
                        } else {
                            Text(String(friend.displayName.prefix(1)).lowercased())
                                .font(.system(size: 20, weight: .light))
                                .foregroundColor(themeManager.colors.textTertiary)
                        }
                    }
                    
                    // Name with BFF indicator
                    VStack(spacing: 2) {
                        Text(friend.displayName.components(separatedBy: " ").first?.lowercased() ?? friend.displayName.lowercased())
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(themeManager.colors.textSecondary)
                            .lineLimit(1)
                        
                        if isBestFriend {
                            Text("bff")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(themeManager.colors.accent1)
                        }
                    }
                }
                .frame(width: 70)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    
    // MARK: - Ten Plus Badge Component
    
    struct TenPlusBadge: View {
        let glowColor: Color
        let size: BadgeSize
        @State private var glowAnimation = false
        
        enum BadgeSize {
            case small
            case medium
            case large
            
            var iconSize: CGFloat {
                switch self {
                case .small: return 10
                case .medium: return 14
                case .large: return 18
                }
            }
            
            var fontSize: CGFloat {
                switch self {
                case .small: return 9
                case .medium: return 12
                case .large: return 14
                }
            }
            
            var tracking: CGFloat {
                switch self {
                case .small: return 0.5
                case .medium: return 1
                case .large: return 1.5
                }
            }
        }
        
        var body: some View {
            HStack(spacing: 2) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: size.iconSize))
                Text("ten+")
                    .font(.system(size: size.fontSize, weight: .medium))
                    .tracking(size.tracking)
            }
            .foregroundColor(glowColor)
            .shadow(color: glowColor.opacity(glowAnimation ? 0.6 : 0.3), radius: glowAnimation ? 4 : 2)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowAnimation = true
                }
            }
        }
    }
    
    // MARK: - Friend Detail View
    
    struct FriendDetailView: View {
        let friend: User
        @EnvironmentObject var viewModel: SupabaseAppViewModel
        @EnvironmentObject var badgeManager: BadgeManager
        
        var body: some View {
            UserProfileView(
                user: friend,
                isFriend: true,
                showAddButton: false,
                onAddFriend: nil,
                onRemoveFriend: {
                    Task {
                        await viewModel.removeFriend(friend.id)
                    }
                }
            )
            .environmentObject(viewModel)
            .environmentObject(badgeManager)
        }
    }
    
    // MARK: - Settings View
    
    struct SettingsView: View {
        @EnvironmentObject var viewModel: SupabaseAppViewModel
        @EnvironmentObject var authViewModel: AuthViewModel
        @ObservedObject private var themeManager = ThemeManager.shared
        @ObservedObject private var developerManager = DeveloperManager.shared
        @Environment(\.dismiss) private var dismiss
        @State private var showTenPlus = false
        @State private var showEditProfile = false
        @State private var showBadges = false
        @State private var showNotificationSettings = false
        @State private var showDeleteConfirmation = false
        @State private var isDeleting = false
        @State private var showDeveloperStats = false
        @State private var showDeveloperFeedback = false
        @State private var showDeveloperChangelog = false
        @State private var showFeedback = false
        @State private var showChangelog = false
        @State private var unreadChangelogCount = 0
        
        var body: some View {
            ZStack {
                themeManager.colors.background.ignoresSafeArea()
                
                VStack(spacing: themeManager.spacing.xl) {
                    // Header
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
                        
                        Text("settings")
                            .font(themeManager.fonts.body)
                            .foregroundColor(themeManager.colors.textPrimary)
                            .tracking(themeManager.letterSpacing.wide)
                        
                        Spacer()
                        
                        // Invisible spacer for centering
                        Color.clear.frame(width: 40, height: 40)
                    }
                    .padding(.horizontal, themeManager.spacing.screenHorizontal)
                    .padding(.top, themeManager.spacing.lg)
                    
                    SmartScrollView {
                        VStack(spacing: themeManager.spacing.lg) {
                            // Account Section
                            settingsSection(title: "account") {
                                SettingsRow(icon: "person", title: "Edit Profile") {
                                    showEditProfile = true
                                }
                                SettingsRow(icon: "trophy", title: "Badges") {
                                    showBadges = true
                                }
                                SettingsRow(icon: "bell", title: "Notifications") {
                                    showNotificationSettings = true
                                }
                            }
                            
                            // ten + Section
                            settingsSection(title: "ten +") {
                                if PremiumManager.shared.isPremium {
                                    SettingsRow(icon: "checkmark.seal.fill", title: "Manage Premium", subtitle: "\(PremiumManager.shared.daysRemaining ?? 0) days left") {
                                        showTenPlus = true
                                    }
                                } else {
                                    SettingsRow(icon: "sparkles", title: "Upgrade to ten +", showBadge: true) {
                                        showTenPlus = true
                                    }
                                }
                            }
                            
                            // Support Section
                            settingsSection(title: "support") {
                                SettingsRow(icon: "sparkles", title: "What's New", showBadge: unreadChangelogCount > 0) {
                                    showChangelog = true
                                }
                                SettingsRow(icon: "questionmark.circle", title: "Help Center") {
                                    // TODO: Help
                                }
                                SettingsRow(icon: "text.bubble", title: "Send Feedback") {
                                    showFeedback = true
                                }
                            }
                            
                            // Developer Section (only visible to developers)
                            if developerManager.isDeveloper {
                                settingsSection(title: "developer") {
                                    SettingsRow(icon: "chart.bar.fill", title: "App Stats") {
                                        showDeveloperStats = true
                                    }
                                    SettingsRow(icon: "text.bubble.fill", title: "User Feedback") {
                                        showDeveloperFeedback = true
                                    }
                                    SettingsRow(icon: "doc.text.fill", title: "Changelogs") {
                                        showDeveloperChangelog = true
                                    }
                                }
                            }
                            
                            // Sign Out
                            Button(action: {
                                Task {
                                    await authViewModel.signOut()
                                    dismiss()
                                }
                            }) {
                                Text("sign out")
                                    .font(themeManager.fonts.body)
                                    .foregroundColor(.red.opacity(0.8))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, themeManager.spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: themeManager.radius.md)
                                            .fill(themeManager.colors.cardBackground)
                                    )
                            }
                            .padding(.top, themeManager.spacing.lg)
                            
                            // Delete Account
                            Button(action: {
                                showDeleteConfirmation = true
                            }) {
                                HStack(spacing: 8) {
                                    if isDeleting {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .red))
                                            .scaleEffect(0.8)
                                    }
                                    Text(isDeleting ? "deleting..." : "delete account")
                                        .font(themeManager.fonts.body)
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, themeManager.spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: themeManager.radius.md)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .disabled(isDeleting)
                            .padding(.top, themeManager.spacing.sm)
                        }
                        .padding(.horizontal, themeManager.spacing.screenHorizontal)
                        .padding(.top, themeManager.spacing.lg)
                    }
                }
            }
            .fullScreenCover(isPresented: $showTenPlus) {
                TenPlusView()
            }
            .fullScreenCover(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .fullScreenCover(isPresented: $showBadges) {
                BadgeCollectionView()
            }
            .sheet(isPresented: $showNotificationSettings) {
                NotificationSettingsView()
            }
            .fullScreenCover(isPresented: $showDeveloperStats) {
                DeveloperStatsView()
            }
            .fullScreenCover(isPresented: $showDeveloperFeedback) {
                DeveloperFeedbackView()
            }
            .fullScreenCover(isPresented: $showDeveloperChangelog) {
                DeveloperChangelogView()
            }
            .fullScreenCover(isPresented: $showChangelog) {
                ChangelogView()
            }
            .fullScreenCover(isPresented: $showFeedback) {
                FeedbackView()
                    .environmentObject(viewModel)
            }
            .task {
                // Check developer status when settings open
                if let userId = viewModel.currentUserProfile?.id {
                    await developerManager.checkDeveloperStatus(userId: userId)
                }
                // Load unread changelog count
                await loadUnreadChangelogCount()
            }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        isDeleting = true
                        let success = await authViewModel.deleteAccount()
                        isDeleting = false
                        if success {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("This action is permanent and cannot be undone.\n\nAll your data will be permanently deleted, including:\n• Your profile\n• All posts and replies\n• All vibes\n• Friends and friend requests\n• Badges and stats\n\nAre you sure you want to delete your account?")
            }
        }
        
        private func loadUnreadChangelogCount() async {
            do {
                let count: Int = try await SupabaseManager.shared.client
                    .rpc("get_unread_changelog_count")
                    .execute()
                    .value
                
                await MainActor.run {
                    unreadChangelogCount = count
                }
            } catch {
                print("❌ Error loading unread changelog count: \(error)")
            }
        }
        
        func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
            VStack(alignment: .leading, spacing: themeManager.spacing.sm) {
                Text(title)
                    .font(themeManager.fonts.caption)
                    .foregroundColor(themeManager.colors.textTertiary)
                    .tracking(themeManager.letterSpacing.wide)
                    .textCase(.uppercase)
                
                VStack(spacing: 1) {
                    content()
                }
                .background(
                    RoundedRectangle(cornerRadius: themeManager.radius.md)
                        .fill(themeManager.colors.cardBackground)
                )
                .clipShape(RoundedRectangle(cornerRadius: themeManager.radius.md))
            }
            .id("\(title)-\(themeManager.currentTheme.id)") // Force refresh when theme changes
        }
    }
    
    // MARK: - Settings Row
    
    struct SettingsRow: View {
        @ObservedObject private var themeManager = ThemeManager.shared
        let icon: String
        let title: String
        var subtitle: String? = nil
        var showBadge: Bool = false
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: themeManager.spacing.md) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(themeManager.colors.textSecondary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(themeManager.fonts.body)
                            .foregroundColor(themeManager.colors.textPrimary)
                        
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(themeManager.fonts.caption)
                                .foregroundColor(themeManager.colors.accent2)
                        }
                    }
                    
                    if showBadge {
                        Text("NEW")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(themeManager.colors.accent1)
                            )
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(themeManager.colors.textTertiary)
                }
                .padding(.horizontal, themeManager.spacing.md)
                .padding(.vertical, themeManager.spacing.md)
                .background(themeManager.colors.cardBackground)
            }
            .id(themeManager.currentTheme.id) // Force refresh when theme changes
        }
    }
    
    // MARK: - Add Friend View
    
    struct AddFriendView: View {
        @EnvironmentObject var viewModel: SupabaseAppViewModel
        @ObservedObject private var themeManager = ThemeManager.shared
        @Environment(\.dismiss) private var dismiss
        @State private var searchText = ""
        @State private var searchResults: [User] = []
        @State private var isSearching = false
        @State private var sentRequests: Set<String> = []
        @State private var searchTask: Task<Void, Never>?
        
        var body: some View {
            ZStack {
                themeManager.colors.background.ignoresSafeArea()
                    .onTapGesture {
                        hideKeyboard()
                    }
                
                VStack(spacing: themeManager.spacing.xl) {
                    // Header
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
                        
                        Text("add friend")
                            .font(themeManager.fonts.body)
                            .foregroundColor(themeManager.colors.textPrimary)
                            .tracking(themeManager.letterSpacing.wide)
                        
                        Spacer()
                        
                        Color.clear.frame(width: 40, height: 40)
                    }
                    .padding(.horizontal, themeManager.spacing.screenHorizontal)
                    .padding(.top, themeManager.spacing.lg)
                    
                    // Search
                    HStack(spacing: themeManager.spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(themeManager.colors.textTertiary)
                        
                        TextField("", text: $searchText)
                            .placeholder(when: searchText.isEmpty) {
                                Text("search by username")
                                    .foregroundColor(themeManager.colors.textTertiary)
                            }
                            .font(themeManager.fonts.body)
                            .foregroundColor(themeManager.colors.textPrimary)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                            .onSubmit {
                                hideKeyboard()
                            }
                            .onChange(of: searchText) { _, newValue in
                                // Debounce search
                                searchTask?.cancel()
                                searchTask = Task {
                                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                                    if !Task.isCancelled {
                                        await performSearch()
                                    }
                                }
                            }
                        
                        if isSearching {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.colors.textTertiary))
                                .scaleEffect(0.8)
                        } else if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(themeManager.colors.textTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, themeManager.spacing.md)
                    .padding(.vertical, themeManager.spacing.sm + 4)
                    .background(
                        RoundedRectangle(cornerRadius: themeManager.radius.md)
                            .fill(themeManager.colors.cardBackground)
                    )
                    .padding(.horizontal, themeManager.spacing.screenHorizontal)
                    
                    // Results
                    if searchText.isEmpty {
                        Spacer()
                        VStack(spacing: themeManager.spacing.md) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40, weight: .ultraLight))
                                .foregroundColor(themeManager.colors.textTertiary)
                            
                            Text("search for friends")
                                .font(themeManager.fonts.body)
                                .foregroundColor(themeManager.colors.textTertiary)
                            
                            Text("enter a username to find friends")
                                .font(themeManager.fonts.caption)
                                .foregroundColor(themeManager.colors.textTertiary)
                        }
                        Spacer()
                    } else if searchResults.isEmpty && !isSearching {
                        Spacer()
                        VStack(spacing: themeManager.spacing.md) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 40, weight: .ultraLight))
                                .foregroundColor(themeManager.colors.textTertiary)
                            
                            Text("no users found")
                                .font(themeManager.fonts.body)
                                .foregroundColor(themeManager.colors.textTertiary)
                            
                            Text("try a different username")
                                .font(themeManager.fonts.caption)
                                .foregroundColor(themeManager.colors.textTertiary)
                        }
                        Spacer()
                    } else {
                        SmartScrollView {
                            LazyVStack(spacing: themeManager.spacing.sm) {
                                ForEach(searchResults) { user in
                                    UserSearchResultRow(
                                        user: user,
                                        hasSentRequest: sentRequests.contains(user.id) || viewModel.sentFriendRequests.contains(user.id),
                                        onSendRequest: {
                                            await sendRequest(to: user)
                                        },
                                        onCancelRequest: {
                                            let success = await viewModel.cancelFriendRequest(toUserId: user.id)
                                            if success {
                                                sentRequests.remove(user.id)
                                            }
                                        },
                                        onAcceptRequest: { requestId in
                                            await viewModel.acceptFriendRequest(requestId)
                                        },
                                        onDeclineRequest: { requestId in
                                            await viewModel.rejectFriendRequest(requestId)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, themeManager.spacing.screenHorizontal)
                        }
                    }
                }
            }
        }
        
        func performSearch() async {
            guard !searchText.isEmpty else {
                searchResults = []
                return
            }
            
            isSearching = true
            searchResults = await viewModel.searchUsers(query: searchText)
            isSearching = false
        }
        
        func sendRequest(to user: User) async {
            let success = await viewModel.sendFriendRequest(toUserId: user.id)
            if success {
                sentRequests.insert(user.id)
            }
        }
    }
    
    // MARK: - User Search Result Row
    
    struct UserSearchResultRow: View {
        @ObservedObject private var themeManager = ThemeManager.shared
        let user: User
        let hasSentRequest: Bool
        let onSendRequest: () async -> Void
        let onCancelRequest: (() async -> Void)?
        let onAcceptRequest: ((String) async -> Void)?
        let onDeclineRequest: ((String) async -> Void)?
        
        @EnvironmentObject var viewModel: SupabaseAppViewModel
        @State private var isSending = false
        @State private var showProfile = false
        @State private var localHasSentRequest = false
        @State private var localHasHandledIncoming = false
        
        init(
            user: User,
            hasSentRequest: Bool,
            onSendRequest: @escaping () async -> Void,
            onCancelRequest: (() async -> Void)? = nil,
            onAcceptRequest: ((String) async -> Void)? = nil,
            onDeclineRequest: ((String) async -> Void)? = nil
        ) {
            self.user = user
            self.hasSentRequest = hasSentRequest
            self.onSendRequest = onSendRequest
            self.onCancelRequest = onCancelRequest
            self.onAcceptRequest = onAcceptRequest
            self.onDeclineRequest = onDeclineRequest
        }
        
        var requestPending: Bool {
            hasSentRequest || localHasSentRequest || viewModel.sentFriendRequests.contains(user.id)
        }
        
        var hasIncomingRequest: Bool {
            !localHasHandledIncoming && viewModel.hasIncomingRequestFrom(userId: user.id)
        }
        
        var body: some View {
            Button(action: { showProfile = true }) {
                HStack(spacing: themeManager.spacing.md) {
                    // Avatar
                    Circle()
                        .fill(themeManager.colors.cardBackground)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Text(String(user.displayName.prefix(1)).lowercased())
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(themeManager.colors.textSecondary)
                        )
                    
                    // User info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName.lowercased())
                            .font(themeManager.fonts.body)
                            .foregroundColor(themeManager.colors.textPrimary)
                        
                        Text("@\(user.username)")
                            .font(themeManager.fonts.caption)
                            .foregroundColor(themeManager.colors.textTertiary)
                        
                        if hasIncomingRequest {
                            Text("wants to connect with you")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.green)
                        } else if requestPending {
                            Text("request pending")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(themeManager.colors.textTertiary)
                        }
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    if isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: themeManager.colors.textTertiary))
                            .scaleEffect(0.8)
                            .frame(width: 40, height: 40)
                    } else if hasIncomingRequest {
                        // Accept/Decline buttons for incoming requests
                        HStack(spacing: 8) {
                            // Decline button
                            Button(action: {
                                Task {
                                    isSending = true
                                    if let requestId = viewModel.getIncomingRequestId(fromUserId: user.id),
                                       let decline = onDeclineRequest {
                                        await decline(requestId)
                                    }
                                    localHasHandledIncoming = true
                                    isSending = false
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(themeManager.colors.textTertiary)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .stroke(themeManager.colors.textTertiary.opacity(0.3), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            
                            // Accept button
                            Button(action: {
                                Task {
                                    isSending = true
                                    if let requestId = viewModel.getIncomingRequestId(fromUserId: user.id),
                                       let accept = onAcceptRequest {
                                        await accept(requestId)
                                    }
                                    localHasHandledIncoming = true
                                    isSending = false
                                }
                            }) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.green)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .stroke(Color.green.opacity(0.5), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    } else if requestPending {
                        // Cancel request button
                        Button(action: {
                            Task {
                                isSending = true
                                if let cancel = onCancelRequest {
                                    await cancel()
                                }
                                localHasSentRequest = false
                                isSending = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(themeManager.colors.textTertiary)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .stroke(themeManager.colors.textTertiary.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Send request button
                        Button(action: {
                            Task {
                                isSending = true
                                await onSendRequest()
                                localHasSentRequest = true
                                isSending = false
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(themeManager.colors.textPrimary)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .stroke(themeManager.colors.textPrimary.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(themeManager.spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: themeManager.radius.md)
                        .fill(themeManager.colors.cardBackground)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .fullScreenCover(isPresented: $showProfile) {
                UserProfileView(
                    user: user,
                    isFriend: false,
                    showAddButton: !requestPending && !hasIncomingRequest,
                    onAddFriend: {
                        await onSendRequest()
                        localHasSentRequest = true
                    },
                    onRemoveFriend: nil
                )
                .environmentObject(viewModel)
            }
        }
    }
        
        // MARK: - Friend Requests View

        struct FriendRequestsView: View {
            @EnvironmentObject var viewModel: SupabaseAppViewModel
            @ObservedObject private var themeManager = ThemeManager.shared
            @Environment(\.dismiss) private var dismiss
            @State private var requestUsers: [String: User] = [:]
            @State private var isLoading = true
            
            var pendingRequests: [FriendRequest] {
                viewModel.friendRequests.filter { $0.status == .pending }
            }
            
            var body: some View {
                ZStack {
                    themeManager.colors.background.ignoresSafeArea()
                    
                    VStack(spacing: themeManager.spacing.xl) {
                        // Header
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
                            
                            Text("requests")
                                .font(themeManager.fonts.body)
                                .foregroundColor(themeManager.colors.textPrimary)
                                .tracking(themeManager.letterSpacing.wide)
                            
                            Spacer()
                            
                            Color.clear.frame(width: 40, height: 40)
                        }
                        .padding(.horizontal, themeManager.spacing.screenHorizontal)
                        .padding(.top, themeManager.spacing.lg)
                        
                        if isLoading {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.colors.textTertiary))
                            Spacer()
                        } else if pendingRequests.isEmpty {
                            Spacer()
                            VStack(spacing: themeManager.spacing.md) {
                                Image(systemName: "tray")
                                    .font(.system(size: 40, weight: .ultraLight))
                                    .foregroundColor(themeManager.colors.textTertiary)
                                
                                Text("no pending requests")
                                    .font(themeManager.fonts.body)
                                    .foregroundColor(themeManager.colors.textTertiary)
                            }
                            Spacer()
                        } else {
                            SmartScrollView {
                                LazyVStack(spacing: themeManager.spacing.sm) {
                                    ForEach(pendingRequests) { request in
                                        FriendRequestRow(
                                            request: request,
                                            fromUser: requestUsers[request.fromUserId],
                                            onAccept: {
                                                await viewModel.acceptFriendRequest(request.id)
                                            },
                                            onReject: {
                                                await viewModel.rejectFriendRequest(request.id)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, themeManager.spacing.screenHorizontal)
                            }
                        }
                    }
                }
                .task {
                    await loadRequestUsers()
                }
            }
            
            func loadRequestUsers() async {
                isLoading = true
                
                for request in pendingRequests {
                    if let user = await viewModel.getUser(byId: request.fromUserId) {
                        requestUsers[request.fromUserId] = user
                    }
                }
                
                isLoading = false
            }
        }
    }
    
    // MARK: - Connection Network Card
    
    struct ConnectionNetworkCard: View {
        @EnvironmentObject var viewModel: SupabaseAppViewModel
        @ObservedObject private var themeManager = ThemeManager.shared
        let connection: SupabaseAppViewModel.ConnectionPairing
        @Binding var connectionRequestSent: Bool
        @Binding var showConnectionProfile: Bool  // Keep for compatibility but won't use
        let onSendRequest: () -> Void
        
        @State private var showNetwork = false
        @State private var showCentralUser = false
        @State private var showContent = false
        @State private var showSparkles = false
        @State private var currentTime = Date()
        
        // Live countdown timer
        let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        
        // Check if the matched user is now a friend
        var isNowFriends: Bool {
            viewModel.friends.contains { $0.id == connection.matchedUser.id }
        }
        
        var isMatched: Bool {
            connection.isMatched || isNowFriends
        }
        
        var isPending: Bool {
            connectionRequestSent || viewModel.sentFriendRequests.contains(connection.matchedUser.id)
        }
        
        var timeRemaining: String {
            let remaining = connection.expiresAt.timeIntervalSince(currentTime)
            if remaining <= 0 { return "refreshing soon..." }
            
            let days = Int(remaining / 86400)
            let hours = Int((remaining.truncatingRemainder(dividingBy: 86400)) / 3600)
            let minutes = Int((remaining.truncatingRemainder(dividingBy: 3600)) / 60)
            let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
            
            if days > 0 {
                return "\(days):\(String(format: "%02d", hours)):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds)) remaining"
            } else {
                return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds)) remaining"
            }
        }
        
        var body: some View {
            Button(action: {
                // Only send request if not matched and not already pending
                if !isMatched && !isPending {
                    onSendRequest()
                }
            }) {
                VStack(spacing: 0) {
                    // Top label
                    Text(isMatched ? "you connected!" : "you matched with")
                        .font(.system(size: 12, weight: .light))
                        .tracking(1)
                        .foregroundColor(themeManager.colors.textTertiary)
                        .opacity(showContent ? 1 : 0)
                        .padding(.top, themeManager.spacing.lg)
                    
                    // Network visualization area
                    ZStack {
                        // Connection web
                        ConnectionWeb(showNetwork: showNetwork)
                        
                        // Central focused user
                        CentralUserAvatar(
                            initial: String(connection.matchedUser.displayName.prefix(1)),
                            show: showCentralUser,
                            isMatched: isMatched
                        )
                    }
                    .frame(height: 180)
                    
                    // User name - large and prominent
                    Text(connection.matchedUser.displayName)
                        .font(.system(size: 32, weight: .light))
                        .tracking(2)
                        .foregroundColor(themeManager.colors.textPrimary)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)
                    
                    // Action text / Matched state
                    if isMatched {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                            Text("connection complete!")
                                .font(.system(size: 13, weight: .light))
                                .tracking(0.5)
                                .foregroundColor(.green)
                        }
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .scale))
                    } else if isPending {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 11, weight: .medium))
                            Text("request pending")
                                .font(.system(size: 13, weight: .light))
                                .tracking(0.5)
                        }
                        .foregroundColor(themeManager.colors.textSecondary)
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .scale))
                    } else {
                        Text("tap to connect")
                            .font(.system(size: 13, weight: .light))
                            .tracking(0.5)
                            .foregroundColor(themeManager.colors.textTertiary)
                            .padding(.top, 8)
                            .opacity(showContent ? 1 : 0)
                    }
                    
                    // Time remaining - live countdown
                    Text(isMatched ? "next match \(timeRemaining)" : timeRemaining)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(themeManager.colors.textTertiary.opacity(0.7))
                        .padding(.top, 12)
                        .padding(.bottom, themeManager.spacing.lg)
                        .opacity(showContent ? 1 : 0)
                    
                    // Reason badge at bottom (only if not matched)
                    if showContent && !isMatched {
                        HStack(spacing: 4) {
                            Image(systemName: connection.similarityReason == "mutuals" ? "person.2" : "sparkle")
                                .font(.system(size: 10))
                            Text(connection.reasonText)
                                .font(.system(size: 11, weight: .regular))
                        }
                        .foregroundColor(themeManager.colors.textTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(themeManager.colors.background.opacity(0.5))
                        )
                        .padding(.bottom, themeManager.spacing.md)
                    } else if isMatched {
                        Spacer().frame(height: themeManager.spacing.md)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: themeManager.radius.lg)
                        .fill(themeManager.colors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: themeManager.radius.lg)
                        .stroke(isMatched ? Color.green.opacity(0.3) : themeManager.colors.textPrimary.opacity(0.05), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isMatched || isPending)  // Disable tap when matched or pending
            .onAppear {
                startAnimations()
            }
            .onReceive(timer) { time in
                currentTime = time
            }
        }
        
        private func startAnimations() {
            // Staggered reveal
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                showNetwork = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
                showCentralUser = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                showContent = true
            }
        }
    }
    
    // MARK: - Connection Web
    
    struct ConnectionWeb: View {
        @ObservedObject private var themeManager = ThemeManager.shared
        let showNetwork: Bool
        
        // Node positions - asymmetric, larger sizes (x, y, size, depthLevel)
        let nodes: [(x: CGFloat, y: CGFloat, size: CGFloat, depthLevel: Int)] = [
            // Smaller distant nodes (most blur)
            (-0.7, -0.3, 26, 1),      // Left, slightly high
            (0.6, 0.5, 24, 1),        // Lower right
            (0.12, -0.72, 24, 1),     // Top, slightly right
            
            // Medium nodes (medium blur)
            (0.72, -0.15, 30, 2),     // Right side
            (-0.45, 0.55, 32, 2),     // Bottom left area
            (-0.35, -0.6, 30, 2),     // Upper left
            
            // Larger closer nodes (least blur)
            (0.52, -0.5, 36, 3),      // Upper right
            (-0.65, 0.18, 34, 3),     // Left side
        ]
        
        var body: some View {
            GeometryReader { geometry in
                let centerX = geometry.size.width / 2
                let centerY = geometry.size.height / 2
                let scaleX = geometry.size.width * 0.42  // Reduced from 0.48
                let scaleY = geometry.size.height * 0.42 // Reduced from 0.48
                
                ZStack {
                    // Connection lines from nodes to center
                    ForEach(0..<nodes.count, id: \.self) { index in
                        let node = nodes[index]
                        Path { path in
                            path.move(to: CGPoint(
                                x: centerX + node.x * scaleX,
                                y: centerY + node.y * scaleY
                            ))
                            path.addLine(to: CGPoint(x: centerX, y: centerY))
                        }
                        .stroke(
                            themeManager.colors.textPrimary.opacity(showNetwork ? 0.1 : 0),
                            lineWidth: 0.5
                        )
                        .animation(.easeOut(duration: 0.6).delay(Double(index) * 0.05), value: showNetwork)
                    }
                    
                    // Inter-node connections (organic, not all connected)
                    Group {
                        nodeLine(from: 2, to: 5, centerX: centerX, centerY: centerY, scaleX: scaleX, scaleY: scaleY)
                        nodeLine(from: 5, to: 6, centerX: centerX, centerY: centerY, scaleX: scaleX, scaleY: scaleY)
                        nodeLine(from: 2, to: 6, centerX: centerX, centerY: centerY, scaleX: scaleX, scaleY: scaleY)
                        nodeLine(from: 6, to: 3, centerX: centerX, centerY: centerY, scaleX: scaleX, scaleY: scaleY)
                        nodeLine(from: 3, to: 1, centerX: centerX, centerY: centerY, scaleX: scaleX, scaleY: scaleY)
                        nodeLine(from: 0, to: 5, centerX: centerX, centerY: centerY, scaleX: scaleX, scaleY: scaleY)
                        nodeLine(from: 0, to: 7, centerX: centerX, centerY: centerY, scaleX: scaleX, scaleY: scaleY)
                        nodeLine(from: 7, to: 4, centerX: centerX, centerY: centerY, scaleX: scaleX, scaleY: scaleY)
                        nodeLine(from: 4, to: 1, centerX: centerX, centerY: centerY, scaleX: scaleX, scaleY: scaleY)
                    }
                    
                    // Peripheral nodes - render back to front
                    ForEach(nodes.indices.filter { nodes[$0].depthLevel == 1 }, id: \.self) { index in
                        nodeView(index: index, centerX: centerX, centerY: centerY, scaleX: scaleX, scaleY: scaleY)
                    }
                    ForEach(nodes.indices.filter { nodes[$0].depthLevel == 2 }, id: \.self) { index in
                        nodeView(index: index, centerX: centerX, centerY: centerY, scaleX: scaleX, scaleY: scaleY)
                    }
                    ForEach(nodes.indices.filter { nodes[$0].depthLevel == 3 }, id: \.self) { index in
                        nodeView(index: index, centerX: centerX, centerY: centerY, scaleX: scaleX, scaleY: scaleY)
                    }
                }
            }
        }
        
        @ViewBuilder
        private func nodeView(index: Int, centerX: CGFloat, centerY: CGFloat, scaleX: CGFloat, scaleY: CGFloat) -> some View {
            let node = nodes[index]
            PeripheralNode(
                size: node.size,
                depthLevel: node.depthLevel
            )
            .position(
                x: centerX + node.x * scaleX,
                y: centerY + node.y * scaleY
            )
            .opacity(showNetwork ? 1 : 0)
            .scaleEffect(showNetwork ? 1 : 0.5)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.06), value: showNetwork)
        }
        
        @ViewBuilder
        private func nodeLine(from: Int, to: Int, centerX: CGFloat, centerY: CGFloat, scaleX: CGFloat, scaleY: CGFloat) -> some View {
            let fromNode = nodes[from]
            let toNode = nodes[to]
            
            Path { path in
                path.move(to: CGPoint(
                    x: centerX + fromNode.x * scaleX,
                    y: centerY + fromNode.y * scaleY
                ))
                path.addLine(to: CGPoint(
                    x: centerX + toNode.x * scaleX,
                    y: centerY + toNode.y * scaleY
                ))
            }
            .stroke(
                themeManager.colors.textPrimary.opacity(showNetwork ? 0.06 : 0),
                lineWidth: 0.5
            )
            .animation(.easeOut(duration: 0.6).delay(0.3), value: showNetwork)
        }
    }
    
    struct ConnectionLine: View {
        @ObservedObject private var themeManager = ThemeManager.shared
        let from: CGPoint
        let to: CGPoint
        let show: Bool
        
        var body: some View {
            Path { path in
                path.move(to: from)
                path.addLine(to: to)
            }
            .stroke(
                themeManager.colors.textPrimary.opacity(show ? 0.08 : 0),
                lineWidth: 1
            )
            .animation(.easeOut(duration: 0.6).delay(0.3), value: show)
        }
    }
    
    struct PeripheralNode: View {
        @ObservedObject private var themeManager = ThemeManager.shared
        let size: CGFloat
        let depthLevel: Int  // 1 = furthest (most blur), 2 = medium, 3 = closest (least blur)
        
        private var blurAmount: CGFloat {
            switch depthLevel {
            case 1: return 4    // Furthest - most blur
            case 2: return 2    // Medium distance
            case 3: return 0.5  // Closest - almost sharp
            default: return 2
            }
        }
        
        private var opacity: Double {
            switch depthLevel {
            case 1: return 0.4   // Furthest - more faded
            case 2: return 0.6   // Medium
            case 3: return 0.85  // Closest - more visible
            default: return 0.6
            }
        }
        
        var body: some View {
            ZStack {
                // Node circle
                Circle()
                    .fill(themeManager.colors.cardBackground)
                    .frame(width: size, height: size)
                
                // Subtle border
                Circle()
                    .stroke(themeManager.colors.textPrimary.opacity(0.2), lineWidth: 0.5)
                    .frame(width: size, height: size)
                
                // Person icon
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.35, weight: .ultraLight))
                    .foregroundColor(themeManager.colors.textTertiary)
            }
            .blur(radius: blurAmount)
            .opacity(opacity)
        }
    }
    
    // MARK: - Central User Avatar
    
    struct CentralUserAvatar: View {
        @ObservedObject private var themeManager = ThemeManager.shared
        let initial: String
        let show: Bool
        var isMatched: Bool = false
        
        var body: some View {
            ZStack {
                // Premium static glow - outer layer
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (isMatched ? Color.green : themeManager.colors.textPrimary).opacity(0.12),
                                (isMatched ? Color.green : themeManager.colors.textPrimary).opacity(0.06),
                                (isMatched ? Color.green : themeManager.colors.textPrimary).opacity(0.02),
                                .clear
                            ],
                            center: .center,
                            startRadius: 32,
                            endRadius: 70
                        )
                    )
                    .frame(width: 120, height: 120)
                
                // Inner glow ring
                Circle()
                    .stroke(
                        RadialGradient(
                            colors: [
                                (isMatched ? Color.green : themeManager.colors.textPrimary).opacity(0.2),
                                (isMatched ? Color.green : themeManager.colors.textPrimary).opacity(0.05)
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 40
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 76, height: 76)
                    .blur(radius: 2)
                
                // Outer ring
                Circle()
                    .stroke((isMatched ? Color.green : themeManager.colors.textPrimary).opacity(0.15), lineWidth: 1)
                    .frame(width: 72, height: 72)
                
                // Main avatar circle
                Circle()
                    .fill(themeManager.colors.cardBackground)
                    .frame(width: 64, height: 64)
                
                // Inner subtle border
                Circle()
                    .stroke((isMatched ? Color.green : themeManager.colors.textPrimary).opacity(0.08), lineWidth: 1)
                    .frame(width: 64, height: 64)
                
                // Initial or checkmark
                if isMatched {
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.green)
                } else {
                    Text(initial.lowercased())
                        .font(.system(size: 28, weight: .ultraLight))
                        .tracking(2)
                        .foregroundColor(themeManager.colors.textPrimary)
                }
            }
            .scaleEffect(show ? 1 : 0.5)
            .opacity(show ? 1 : 0)
        }
    }
    
    // MARK: - Friend Request Row
    
    struct FriendRequestRow: View {
        @ObservedObject private var themeManager = ThemeManager.shared
        let request: FriendRequest
        let fromUser: User?
        let onAccept: () async -> Void
        let onReject: () async -> Void
        
        @State private var isAccepting = false
        @State private var isRejecting = false
        
        var body: some View {
            HStack(spacing: themeManager.spacing.md) {
                // Avatar
                Circle()
                    .fill(themeManager.colors.cardBackground)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(String(fromUser?.displayName.prefix(1) ?? "?").lowercased())
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(themeManager.colors.textSecondary)
                    )
                
                // User info
                VStack(alignment: .leading, spacing: 4) {
                    Text(fromUser?.displayName.lowercased() ?? "unknown")
                        .font(themeManager.fonts.body)
                        .foregroundColor(themeManager.colors.textPrimary)
                    
                    Text("@\(fromUser?.username ?? "unknown")")
                        .font(themeManager.fonts.caption)
                        .foregroundColor(themeManager.colors.textTertiary)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: themeManager.spacing.sm) {
                    // Reject
                    Button(action: {
                        Task {
                            isRejecting = true
                            await onReject()
                            isRejecting = false
                        }
                    }) {
                        Group {
                            if isRejecting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .red))
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                        }
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.1))
                        )
                    }
                    .disabled(isAccepting || isRejecting)
                    
                    // Accept
                    Button(action: {
                        Task {
                            isAccepting = true
                            await onAccept()
                            isAccepting = false
                        }
                    }) {
                        Group {
                            if isAccepting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .green))
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.green.opacity(0.15))
                        )
                    }
                    .disabled(isAccepting || isRejecting)
                }
            }
            .padding(themeManager.spacing.md)
            .background(
                RoundedRectangle(cornerRadius: themeManager.radius.md)
                    .fill(themeManager.colors.cardBackground)
            )
        }
    }
    
    
    
    #Preview {
        FriendsView()
            .environmentObject(SupabaseAppViewModel())
            .environmentObject(AuthViewModel())
            .environmentObject(BadgeManager.shared)
    }

