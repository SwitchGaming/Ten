//
//  FriendsView.swift
//  SocialTen
//

import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @EnvironmentObject var badgeManager: BadgeManager
    @State private var searchText = ""
    @State private var selectedFriend: User?
    @State private var showAddFriend = false
    @State private var showRequests = false
    @State private var showSettings = false
    @State private var selectedBadgeForToast: BadgeDefinition? = nil
    @State private var showConnectionProfile = false
    @State private var connectionRequestSent = false
    
    var filteredFriends: [User] {
        if searchText.isEmpty {
            return viewModel.friends
        }
        return viewModel.friends.filter {
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
            ScrollView(showsIndicators: false) {
                VStack(spacing: ThemeManager.shared.spacing.xl) {
                    // Header
                    header
                        .padding(.top, ThemeManager.shared.spacing.lg)
                    
                    // Your Profile Card
                    profileCard
                    
                    // Friend Requests Banner (if any)
                    if pendingRequestsCount > 0 {
                        requestsBanner
                    }
                    
                    // Search
                    searchBar
                    
                    // Friends Grid
                    friendsSection
                    
                    // Add Friend Button
                    addFriendButton
                    
                    // Connection of the Week
                    connectionOfTheWeekCard
                        .padding(.top, ThemeManager.shared.spacing.md)
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
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
        .background(ThemeManager.shared.colors.background.ignoresSafeArea())
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
            .font(ThemeManager.shared.fonts.title)
            .foregroundColor(ThemeManager.shared.colors.textPrimary)
            .tracking(ThemeManager.shared.letterSpacing.wide)
    }
    
    // MARK: - Profile Card
    
    var profileCard: some View {
        DepthCard {
            VStack(spacing: ThemeManager.shared.spacing.md) {
                HStack(spacing: ThemeManager.shared.spacing.md) {
                    // Avatar
                    Circle()
                        .fill(ThemeManager.shared.colors.cardBackground)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text(String(viewModel.currentUserProfile?.displayName.prefix(1) ?? "?").lowercased())
                                .font(.system(size: 22, weight: .light))
                                .foregroundColor(ThemeManager.shared.colors.textSecondary)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.currentUserProfile?.displayName.lowercased() ?? "you")
                            .font(ThemeManager.shared.fonts.body)
                            .foregroundColor(ThemeManager.shared.colors.textPrimary)
                        
                        Text("@\(viewModel.currentUserProfile?.username ?? "username")")
                            .font(ThemeManager.shared.fonts.caption)
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    }
                    
                    Spacer()
                    
                    // Settings button
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(ThemeManager.shared.colors.background)
                            )
                    }
                }
                
                // Badges and Streak Row
                if !topBadges.isEmpty || badgeManager.currentStreak > 0 {
                    HStack(spacing: ThemeManager.shared.spacing.md) {
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
                                    .font(ThemeManager.shared.fonts.caption)
                                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }            }
            .padding(ThemeManager.shared.spacing.md)
        }
    }
    
    // MARK: - Requests Banner
    
    var requestsBanner: some View {
        Button(action: { showRequests = true }) {
            HStack {
                Circle()
                    .fill(ThemeManager.shared.colors.accent1)
                    .frame(width: 8, height: 8)
                
                Text("\(pendingRequestsCount) pending request\(pendingRequestsCount > 1 ? "s" : "")")
                    .font(ThemeManager.shared.fonts.caption)
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
            }
            .padding(ThemeManager.shared.spacing.md)
            .background(
                RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                    .fill(ThemeManager.shared.colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                            .stroke(ThemeManager.shared.colors.accent1.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Search Bar
    
    var searchBar: some View {
        HStack(spacing: ThemeManager.shared.spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(ThemeManager.shared.colors.textTertiary)
            
            TextField("", text: $searchText)
                .placeholder(when: searchText.isEmpty) {
                    Text("search friends")
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                }
                .font(ThemeManager.shared.fonts.body)
                .foregroundColor(ThemeManager.shared.colors.textPrimary)
        }
        .padding(.horizontal, ThemeManager.shared.spacing.md)
        .padding(.vertical, ThemeManager.shared.spacing.sm + 4)
        .background(
            RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                .fill(ThemeManager.shared.colors.cardBackground)
        )
    }
    
    // MARK: - Friends Section
    
    var friendsSection: some View {
        VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.md) {
            Text("your ten (\(viewModel.friends.count)/10)")
                .font(ThemeManager.shared.fonts.caption)
                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                .tracking(ThemeManager.shared.letterSpacing.wide)
                .textCase(.uppercase)
            
            if filteredFriends.isEmpty {
                emptyState
            } else {
                friendsGrid
            }
        }
    }
    
    var emptyState: some View {
        VStack(spacing: ThemeManager.shared.spacing.md) {
            Image(systemName: "person.2")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(ThemeManager.shared.colors.textTertiary)
            
            Text(searchText.isEmpty ? "no friends yet" : "no results")
                .font(ThemeManager.shared.fonts.body)
                .foregroundColor(ThemeManager.shared.colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ThemeManager.shared.spacing.xxl)
    }
    
    var friendsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: ThemeManager.shared.spacing.md),
            GridItem(.flexible(), spacing: ThemeManager.shared.spacing.md)
        ], spacing: ThemeManager.shared.spacing.md) {
            ForEach(filteredFriends) { friend in
                FriendGridCard(friend: friend) {
                    selectedFriend = friend
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
                    .font(ThemeManager.shared.fonts.caption)
                    .tracking(ThemeManager.shared.letterSpacing.wide)
            }
            .foregroundColor(ThemeManager.shared.colors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, ThemeManager.shared.spacing.md)
            .background(
                RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                    .stroke(
                        ThemeManager.shared.colors.cardBackground,
                        style: StrokeStyle(lineWidth: 1, dash: [8, 4])
                    )
            )
        }
        .disabled(viewModel.friends.count >= 10)
        .opacity(viewModel.friends.count >= 10 ? 0.5 : 1)
    }
    
    var connectionOfTheWeekCard: some View {
        // Check if connection user is now a friend (for hiding refresh button)
        let isConnectionMatched: Bool = {
            guard let connection = viewModel.connectionOfTheWeek else { return false }
            return connection.isMatched || viewModel.friends.contains { $0.id == connection.matchedUser.id }
        }()
        
        return VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.md) {
            HStack {
                Text("connection of the week")
                    .font(ThemeManager.shared.fonts.caption)
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    .tracking(ThemeManager.shared.letterSpacing.wide)
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
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            .rotationEffect(.degrees(viewModel.isLoadingConnection ? 360 : 0))
                            .animation(viewModel.isLoadingConnection ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: viewModel.isLoadingConnection)
                    }
                    .disabled(viewModel.isLoadingConnection)
                }
            }
            
            if viewModel.friends.count >= 10 {
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
        VStack(spacing: ThemeManager.shared.spacing.md) {
            ZStack {
                Circle()
                    .fill(ThemeManager.shared.colors.textPrimary.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
            }
            
            Text("your circle is complete")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(ThemeManager.shared.colors.textPrimary)
            
            Text("you've reached 10 friends")
                .font(ThemeManager.shared.fonts.caption)
                .foregroundColor(ThemeManager.shared.colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ThemeManager.shared.spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: ThemeManager.shared.radius.lg)
                .fill(ThemeManager.shared.colors.cardBackground)
        )
    }
    
    var loadingConnectionCard: some View {
        VStack(spacing: ThemeManager.shared.spacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: ThemeManager.shared.colors.textTertiary))
            
            Text("finding your match...")
                .font(ThemeManager.shared.fonts.caption)
                .foregroundColor(ThemeManager.shared.colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .background(
            RoundedRectangle(cornerRadius: ThemeManager.shared.radius.lg)
                .fill(ThemeManager.shared.colors.cardBackground)
        )
    }
    
    var noMatchCard: some View {
        VStack(spacing: ThemeManager.shared.spacing.md) {
            ZStack {
                Circle()
                    .fill(ThemeManager.shared.colors.cardBackground)
                    .frame(width: 60, height: 60)
                
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 26, weight: .ultraLight))
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
            }
            
            Text("no matches yet")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(ThemeManager.shared.colors.textPrimary)
            
            Text("check back soon")
                .font(ThemeManager.shared.fonts.caption)
                .foregroundColor(ThemeManager.shared.colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ThemeManager.shared.spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: ThemeManager.shared.radius.lg)
                .fill(ThemeManager.shared.colors.cardBackground)
        )
    }
    
    // MARK: - Friend Grid Card
    
    struct FriendGridCard: View {
        let friend: User
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                VStack(spacing: ThemeManager.shared.spacing.sm) {
                    // Avatar with rating
                    ZStack {
                        Circle()
                            .fill(ThemeManager.shared.colors.cardBackground)
                            .frame(width: 64, height: 64)
                        
                        if let rating = friend.todayRating {
                            Text("\(rating)")
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(ThemeManager.shared.colors.textPrimary)
                        } else {
                            Text(String(friend.displayName.prefix(1)).lowercased())
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        }
                    }
                    
                    // Name
                    Text(friend.displayName.lowercased())
                        .font(ThemeManager.shared.fonts.caption)
                        .foregroundColor(ThemeManager.shared.colors.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ThemeManager.shared.spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: ThemeManager.shared.radius.lg)
                        .fill(ThemeManager.shared.colors.cardBackground)
                )
            }
            .buttonStyle(ScaleButtonStyle())
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
        @Environment(\.dismiss) private var dismiss
        @State private var showTenPlus = false
        @State private var showEditProfile = false
        @State private var showBadges = false
        @State private var showNotificationSettings = false
        @State private var showDeleteConfirmation = false
        @State private var isDeleting = false
        
        var body: some View {
            ZStack {
                ThemeManager.shared.colors.background.ignoresSafeArea()
                
                VStack(spacing: ThemeManager.shared.spacing.xl) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ThemeManager.shared.colors.textSecondary)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(ThemeManager.shared.colors.cardBackground)
                                )
                        }
                        
                        Spacer()
                        
                        Text("settings")
                            .font(ThemeManager.shared.fonts.body)
                            .foregroundColor(ThemeManager.shared.colors.textPrimary)
                            .tracking(ThemeManager.shared.letterSpacing.wide)
                        
                        Spacer()
                        
                        // Invisible spacer for centering
                        Color.clear.frame(width: 40, height: 40)
                    }
                    .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
                    .padding(.top, ThemeManager.shared.spacing.lg)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: ThemeManager.shared.spacing.lg) {
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
                                SettingsRow(icon: "sparkles", title: "Upgrade to ten +", showBadge: true) {
                                    showTenPlus = true
                                }
                            }
                            
                            // Support Section
                            settingsSection(title: "support") {
                                SettingsRow(icon: "questionmark.circle", title: "Help Center") {
                                    // TODO: Help
                                }
                                SettingsRow(icon: "envelope", title: "Contact Us") {
                                    // TODO: Contact
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
                                    .font(ThemeManager.shared.fonts.body)
                                    .foregroundColor(.red.opacity(0.8))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, ThemeManager.shared.spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                                            .fill(ThemeManager.shared.colors.cardBackground)
                                    )
                            }
                            .padding(.top, ThemeManager.shared.spacing.lg)
                            
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
                                        .font(ThemeManager.shared.fonts.body)
                                }
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, ThemeManager.shared.spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .disabled(isDeleting)
                            .padding(.top, ThemeManager.shared.spacing.sm)
                        }
                        .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
                        .padding(.top, ThemeManager.shared.spacing.lg)
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
        
        func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
            VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.sm) {
                Text(title)
                    .font(ThemeManager.shared.fonts.caption)
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    .tracking(ThemeManager.shared.letterSpacing.wide)
                    .textCase(.uppercase)
                
                VStack(spacing: 1) {
                    content()
                }
                .background(
                    RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                        .fill(ThemeManager.shared.colors.cardBackground)
                )
                .clipShape(RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md))
            }
        }
    }
    
    // MARK: - Settings Row
    
    struct SettingsRow: View {
        let icon: String
        let title: String
        var showBadge: Bool = false
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack(spacing: ThemeManager.shared.spacing.md) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textSecondary)
                        .frame(width: 24)
                    
                    Text(title)
                        .font(ThemeManager.shared.fonts.body)
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    
                    if showBadge {
                        Text("NEW")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(ThemeManager.shared.colors.accent1)
                            )
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                }
                .padding(.horizontal, ThemeManager.shared.spacing.md)
                .padding(.vertical, ThemeManager.shared.spacing.md)
                .background(ThemeManager.shared.colors.cardBackground)
            }
        }
    }
    
    // MARK: - Add Friend View
    
    struct AddFriendView: View {
        @EnvironmentObject var viewModel: SupabaseAppViewModel
        @Environment(\.dismiss) private var dismiss
        @State private var searchText = ""
        @State private var searchResults: [User] = []
        @State private var isSearching = false
        @State private var sentRequests: Set<String> = []
        @State private var searchTask: Task<Void, Never>?
        
        var body: some View {
            ZStack {
                ThemeManager.shared.colors.background.ignoresSafeArea()
                
                VStack(spacing: ThemeManager.shared.spacing.xl) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ThemeManager.shared.colors.textSecondary)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(ThemeManager.shared.colors.cardBackground)
                                )
                        }
                        
                        Spacer()
                        
                        Text("add friend")
                            .font(ThemeManager.shared.fonts.body)
                            .foregroundColor(ThemeManager.shared.colors.textPrimary)
                            .tracking(ThemeManager.shared.letterSpacing.wide)
                        
                        Spacer()
                        
                        Color.clear.frame(width: 40, height: 40)
                    }
                    .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
                    .padding(.top, ThemeManager.shared.spacing.lg)
                    
                    // Search
                    HStack(spacing: ThemeManager.shared.spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        
                        TextField("", text: $searchText)
                            .placeholder(when: searchText.isEmpty) {
                                Text("search by username")
                                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            }
                            .font(ThemeManager.shared.fonts.body)
                            .foregroundColor(ThemeManager.shared.colors.textPrimary)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
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
                                .progressViewStyle(CircularProgressViewStyle(tint: ThemeManager.shared.colors.textTertiary))
                                .scaleEffect(0.8)
                        } else if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, ThemeManager.shared.spacing.md)
                    .padding(.vertical, ThemeManager.shared.spacing.sm + 4)
                    .background(
                        RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                            .fill(ThemeManager.shared.colors.cardBackground)
                    )
                    .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
                    
                    // Results
                    if searchText.isEmpty {
                        Spacer()
                        VStack(spacing: ThemeManager.shared.spacing.md) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40, weight: .ultraLight))
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            
                            Text("search for friends")
                                .font(ThemeManager.shared.fonts.body)
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            
                            Text("enter a username to find friends")
                                .font(ThemeManager.shared.fonts.caption)
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        }
                        Spacer()
                    } else if searchResults.isEmpty && !isSearching {
                        Spacer()
                        VStack(spacing: ThemeManager.shared.spacing.md) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 40, weight: .ultraLight))
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            
                            Text("no users found")
                                .font(ThemeManager.shared.fonts.body)
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            
                            Text("try a different username")
                                .font(ThemeManager.shared.fonts.caption)
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        }
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: ThemeManager.shared.spacing.sm) {
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
                                }                          }
                            .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
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
                HStack(spacing: ThemeManager.shared.spacing.md) {
                    // Avatar
                    Circle()
                        .fill(ThemeManager.shared.colors.cardBackground)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Text(String(user.displayName.prefix(1)).lowercased())
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(ThemeManager.shared.colors.textSecondary)
                        )
                    
                    // User info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.displayName.lowercased())
                            .font(ThemeManager.shared.fonts.body)
                            .foregroundColor(ThemeManager.shared.colors.textPrimary)
                        
                        Text("@\(user.username)")
                            .font(ThemeManager.shared.fonts.caption)
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        
                        if hasIncomingRequest {
                            Text("wants to connect with you")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.green)
                        } else if requestPending {
                            Text("request pending")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        }
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    if isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ThemeManager.shared.colors.textTertiary))
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
                                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .stroke(ThemeManager.shared.colors.textTertiary.opacity(0.3), lineWidth: 1)
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
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .stroke(ThemeManager.shared.colors.textTertiary.opacity(0.3), lineWidth: 1)
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
                                .foregroundColor(ThemeManager.shared.colors.textPrimary)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .stroke(ThemeManager.shared.colors.textPrimary.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(ThemeManager.shared.spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                        .fill(ThemeManager.shared.colors.cardBackground)
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
        @Environment(\.dismiss) private var dismiss
        @State private var requestUsers: [String: User] = [:]
        @State private var isLoading = true
        
        var pendingRequests: [FriendRequest] {
            viewModel.friendRequests.filter { $0.status == .pending }
        }
        
        var body: some View {
            ZStack {
                ThemeManager.shared.colors.background.ignoresSafeArea()
                
                VStack(spacing: ThemeManager.shared.spacing.xl) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(ThemeManager.shared.colors.textSecondary)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(ThemeManager.shared.colors.cardBackground)
                                )
                        }
                        
                        Spacer()
                        
                        Text("requests")
                            .font(ThemeManager.shared.fonts.body)
                            .foregroundColor(ThemeManager.shared.colors.textPrimary)
                            .tracking(ThemeManager.shared.letterSpacing.wide)
                        
                        Spacer()
                        
                        Color.clear.frame(width: 40, height: 40)
                    }
                    .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
                    .padding(.top, ThemeManager.shared.spacing.lg)
                    
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ThemeManager.shared.colors.textTertiary))
                        Spacer()
                    } else if pendingRequests.isEmpty {
                        Spacer()
                        VStack(spacing: ThemeManager.shared.spacing.md) {
                            Image(systemName: "tray")
                                .font(.system(size: 40, weight: .ultraLight))
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            
                            Text("no pending requests")
                                .font(ThemeManager.shared.fonts.body)
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        }
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: ThemeManager.shared.spacing.sm) {
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
                            .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
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
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    .opacity(showContent ? 1 : 0)
                    .padding(.top, ThemeManager.shared.spacing.lg)
                
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
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
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
                    .foregroundColor(ThemeManager.shared.colors.textSecondary)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .scale))
                } else {
                    Text("tap to connect")
                        .font(.system(size: 13, weight: .light))
                        .tracking(0.5)
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        .padding(.top, 8)
                        .opacity(showContent ? 1 : 0)
                }
                
                // Time remaining - live countdown
                Text(isMatched ? "next match \(timeRemaining)" : timeRemaining)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(ThemeManager.shared.colors.textTertiary.opacity(0.7))
                    .padding(.top, 12)
                    .padding(.bottom, ThemeManager.shared.spacing.lg)
                    .opacity(showContent ? 1 : 0)
                
                // Reason badge at bottom (only if not matched)
                if showContent && !isMatched {
                    HStack(spacing: 4) {
                        Image(systemName: connection.similarityReason == "mutuals" ? "person.2" : "sparkle")
                            .font(.system(size: 10))
                        Text(connection.reasonText)
                            .font(.system(size: 11, weight: .regular))
                    }
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(ThemeManager.shared.colors.background.opacity(0.5))
                    )
                    .padding(.bottom, ThemeManager.shared.spacing.md)
                } else if isMatched {
                    Spacer().frame(height: ThemeManager.shared.spacing.md)
                }
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: ThemeManager.shared.radius.lg)
                    .fill(ThemeManager.shared.colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ThemeManager.shared.radius.lg)
                    .stroke(isMatched ? Color.green.opacity(0.3) : ThemeManager.shared.colors.textPrimary.opacity(0.05), lineWidth: 1)
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
}// MARK: - Connection Web

struct ConnectionWeb: View {
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
                        ThemeManager.shared.colors.textPrimary.opacity(showNetwork ? 0.1 : 0),
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
            ThemeManager.shared.colors.textPrimary.opacity(showNetwork ? 0.06 : 0),
            lineWidth: 0.5
        )
        .animation(.easeOut(duration: 0.6).delay(0.3), value: showNetwork)
    }
}

struct ConnectionLine: View {
        let from: CGPoint
        let to: CGPoint
        let show: Bool
        
        var body: some View {
            Path { path in
                path.move(to: from)
                path.addLine(to: to)
            }
            .stroke(
                ThemeManager.shared.colors.textPrimary.opacity(show ? 0.08 : 0),
                lineWidth: 1
            )
            .animation(.easeOut(duration: 0.6).delay(0.3), value: show)
        }
    }

struct PeripheralNode: View {
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
                .fill(ThemeManager.shared.colors.cardBackground)
                .frame(width: size, height: size)
            
            // Subtle border
            Circle()
                .stroke(ThemeManager.shared.colors.textPrimary.opacity(0.2), lineWidth: 0.5)
                .frame(width: size, height: size)
            
            // Person icon
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.35, weight: .ultraLight))
                .foregroundColor(ThemeManager.shared.colors.textTertiary)
        }
        .blur(radius: blurAmount)
        .opacity(opacity)
    }
}

// MARK: - Central User Avatar

struct CentralUserAvatar: View {
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
                            (isMatched ? Color.green : ThemeManager.shared.colors.textPrimary).opacity(0.12),
                            (isMatched ? Color.green : ThemeManager.shared.colors.textPrimary).opacity(0.06),
                            (isMatched ? Color.green : ThemeManager.shared.colors.textPrimary).opacity(0.02),
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
                            (isMatched ? Color.green : ThemeManager.shared.colors.textPrimary).opacity(0.2),
                            (isMatched ? Color.green : ThemeManager.shared.colors.textPrimary).opacity(0.05)
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
                .stroke((isMatched ? Color.green : ThemeManager.shared.colors.textPrimary).opacity(0.15), lineWidth: 1)
                .frame(width: 72, height: 72)
            
            // Main avatar circle
            Circle()
                .fill(ThemeManager.shared.colors.cardBackground)
                .frame(width: 64, height: 64)
            
            // Inner subtle border
            Circle()
                .stroke((isMatched ? Color.green : ThemeManager.shared.colors.textPrimary).opacity(0.08), lineWidth: 1)
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
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
            }
        }
        .scaleEffect(show ? 1 : 0.5)
        .opacity(show ? 1 : 0)
    }
}
// MARK: - Friend Request Row

struct FriendRequestRow: View {
    let request: FriendRequest
    let fromUser: User?
    let onAccept: () async -> Void
    let onReject: () async -> Void
    
    @State private var isAccepting = false
    @State private var isRejecting = false
    
    var body: some View {
        HStack(spacing: ThemeManager.shared.spacing.md) {
            // Avatar
            Circle()
                .fill(ThemeManager.shared.colors.cardBackground)
                .frame(width: 48, height: 48)
                .overlay(
                    Text(String(fromUser?.displayName.prefix(1) ?? "?").lowercased())
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textSecondary)
                )
            
            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(fromUser?.displayName.lowercased() ?? "unknown")
                    .font(ThemeManager.shared.fonts.body)
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                
                Text("@\(fromUser?.username ?? "unknown")")
                    .font(ThemeManager.shared.fonts.caption)
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: ThemeManager.shared.spacing.sm) {
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
        .padding(ThemeManager.shared.spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                .fill(ThemeManager.shared.colors.cardBackground)
        )
    }
}
    
    

#Preview {
    FriendsView()
        .environmentObject(SupabaseAppViewModel())
        .environmentObject(AuthViewModel())
        .environmentObject(BadgeManager.shared)
}
