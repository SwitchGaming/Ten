//
//  FriendsView.swift
//  SocialTen
//

import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var searchText = ""
    @State private var selectedFriend: User?
    @State private var showAddFriend = false
    @State private var showRequests = false
    
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
        viewModel.getIncomingRequests().count
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ShadowTheme.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Friend requests banner
                        if pendingRequestsCount > 0 {
                            Button(action: { showRequests = true }) {
                                HStack {
                                    Text("\(pendingRequestsCount) pending request\(pendingRequestsCount > 1 ? "s" : "")")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(ShadowTheme.textPrimary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .light))
                                        .foregroundColor(ShadowTheme.textTertiary)
                                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.05))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                )
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Search bar
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(ShadowTheme.textTertiary)
                            
                            TextField("search friends", text: $searchText)
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(ShadowTheme.textPrimary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ShadowTheme.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                        
                        // Friends count
                        HStack {
                            Text("\(viewModel.friends.count)/\(User.maxFriends) friends")
                                .font(.system(size: 12, weight: .medium))
                                .tracking(2)
                                .foregroundColor(ShadowTheme.textTertiary)
                                .textCase(.uppercase)
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        
                        // Friends list
                        if filteredFriends.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 40, weight: .ultraLight))
                                    .foregroundColor(ShadowTheme.textTertiary)
                                
                                Text(searchText.isEmpty ? "no friends yet" : "no results")
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundColor(ShadowTheme.textTertiary)
                                
                                if searchText.isEmpty {
                                    Button(action: { showAddFriend = true }) {
                                        Text("add friends")
                                            .font(.system(size: 12, weight: .medium))
                                            .tracking(1)
                                            .foregroundColor(ShadowTheme.textPrimary)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredFriends) { friend in
                                    FriendListRow(friend: friend, onTap: {
                                        selectedFriend = friend
                                    })
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("friends")
                        .font(.system(size: 20, weight: .light))
                        .tracking(4)
                        .foregroundColor(ShadowTheme.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddFriend = true }) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(viewModel.currentUser?.canAddMoreFriends == true ? ShadowTheme.textSecondary : ShadowTheme.textTertiary)
                    }
                    .disabled(viewModel.currentUser?.canAddMoreFriends != true)
                }
            }
            .fullScreenCover(item: $selectedFriend) { friend in
                FriendProfileView(friend: friend)
            }
            .fullScreenCover(isPresented: $showAddFriend) {
                AddFriendView()
            }
            .fullScreenCover(isPresented: $showRequests) {
                FriendRequestsView()
            }
        }
    }
}

// MARK: - Friend List Row

struct FriendListRow: View {
    let friend: User
    let onTap: () -> Void
    @EnvironmentObject var viewModel: AppViewModel
    
    var glowColor: Color {
        friend.profileCustomization.glowColor.color
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Circle()
                    .fill(ShadowTheme.surfaceLight)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(String(friend.displayName.prefix(1)).lowercased())
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(ShadowTheme.textSecondary)
                    )
                    .overlay(
                        Circle()
                            .stroke(glowColor.opacity(friend.profileCustomization.showGlow ? 0.4 : 0.1), lineWidth: 1)
                    )
                    .shadow(color: glowColor.opacity(friend.profileCustomization.showGlow ? 0.25 : 0), radius: 10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.displayName.lowercased())
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(ShadowTheme.textPrimary)
                    
                    if !friend.bio.isEmpty {
                        Text(friend.bio)
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(ShadowTheme.textTertiary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if let rating = friend.todayRating {
                    Text("\(rating)")
                        .font(.system(size: 24, weight: .ultraLight))
                        .foregroundColor(ShadowTheme.textPrimary)
                        .shadow(color: glowColor.opacity(friend.profileCustomization.showGlow ? 0.3 : 0), radius: 6)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(ShadowTheme.textTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ShadowTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Friend Profile View

struct FriendProfileView: View {
    let friend: User
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showRemoveConfirmation = false
    
    var glowColor: Color {
        friend.profileCustomization.glowColor.color
    }
    
    var glowIntensity: Double {
        friend.profileCustomization.showGlow ? friend.profileCustomization.glowIntensity : 0
    }
    
    var body: some View {
        ZStack {
            ShadowTheme.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 40) {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(ShadowTheme.textSecondary)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(ShadowTheme.cardBackground)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    VStack(spacing: 32) {
                        Circle()
                            .fill(ShadowTheme.surfaceLight)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Text(String(friend.displayName.prefix(1)).lowercased())
                                    .font(.system(size: 36, weight: .ultraLight))
                                    .foregroundColor(ShadowTheme.textSecondary)
                            )
                            .overlay(
                                Circle()
                                    .stroke(glowColor.opacity(glowIntensity), lineWidth: 1)
                                    .blur(radius: 1)
                            )
                            .shadow(color: glowColor.opacity(glowIntensity * 0.6), radius: 20)
                        
                        VStack(spacing: 12) {
                            Text(friend.displayName.lowercased())
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(ShadowTheme.textPrimary)
                            
                            Text("@\(friend.username)")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(ShadowTheme.textTertiary)
                            
                            if !friend.bio.isEmpty {
                                Text(friend.bio)
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundColor(ShadowTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 8)
                            }
                        }
                        
                        if let rating = friend.todayRating {
                            VStack(spacing: 12) {
                                Text("\(rating)")
                                    .font(.system(size: 80, weight: .ultraLight))
                                    .foregroundColor(ShadowTheme.textPrimary)
                                    .shadow(color: glowColor.opacity(glowIntensity * 0.8), radius: 25)
                                
                                Text("today")
                                    .font(.system(size: 12, weight: .medium))
                                    .tracking(3)
                                    .foregroundColor(ShadowTheme.textTertiary)
                                    .textCase(.uppercase)
                            }
                            .padding(40)
                            .glassCard(glowColor: glowColor, glowIntensity: glowIntensity)
                        }
                        
                        Button(action: { showRemoveConfirmation = true }) {
                            Text("remove friend")
                                .font(.system(size: 12, weight: .medium))
                                .tracking(1)
                                .foregroundColor(Color.red.opacity(0.7))
                                .textCase(.uppercase)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .padding(.top, 20)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .alert("Remove Friend", isPresented: $showRemoveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                viewModel.removeFriend(friend.id)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to remove \(friend.displayName) from your friends?")
        }
    }
}

// MARK: - Add Friend View

struct AddFriendView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var hasSearched = false
    
    var body: some View {
        ZStack {
            ShadowTheme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(ShadowTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Text("add friend")
                        .font(.system(size: 16, weight: .light))
                        .tracking(2)
                        .foregroundColor(ShadowTheme.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                if viewModel.currentUser?.canAddMoreFriends != true {
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 14, weight: .light))
                        Text("You've reached the maximum of \(User.maxFriends) friends")
                            .font(.system(size: 12, weight: .light))
                    }
                    .foregroundColor(Color.orange.opacity(0.8))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.1))
                    )
                    .padding(.horizontal, 20)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(ShadowTheme.textTertiary)
                    
                    TextField("search by username", text: $searchText)
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(ShadowTheme.textPrimary)
                        .autocapitalization(.none)
                        .onSubmit { performSearch() }
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(ShadowTheme.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(ShadowTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                
                Button(action: performSearch) {
                    Text("search")
                        .font(.system(size: 14, weight: .medium))
                        .tracking(1)
                        .foregroundColor(ShadowTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.1))
                        )
                }
                .padding(.horizontal, 20)
                .disabled(searchText.isEmpty)
                .opacity(searchText.isEmpty ? 0.5 : 1)
                
                ScrollView(showsIndicators: false) {
                    if hasSearched && searchResults.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 32, weight: .ultraLight))
                                .foregroundColor(ShadowTheme.textTertiary)
                            
                            Text("no users found")
                                .font(.system(size: 14, weight: .light))
                                .foregroundColor(ShadowTheme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(searchResults) { user in
                                UserSearchRow(user: user)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    func performSearch() {
        hasSearched = true
        searchResults = viewModel.searchUsers(query: searchText)
    }
}

// MARK: - User Search Row

struct UserSearchRow: View {
    let user: User
    @EnvironmentObject var viewModel: AppViewModel
    
    var requestStatus: FriendRequestStatus {
        viewModel.getFriendRequestStatus(for: user.id)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(ShadowTheme.surfaceLight)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(user.displayName.prefix(1)).lowercased())
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(ShadowTheme.textSecondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName.lowercased())
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(ShadowTheme.textPrimary)
                
                Text("@\(user.username)")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(ShadowTheme.textTertiary)
            }
            
            Spacer()
            
            switch requestStatus {
            case .none:
                Button(action: { viewModel.sendFriendRequest(to: user.id) }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(ShadowTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                        )
                }
                .disabled(viewModel.currentUser?.canAddMoreFriends != true)
                .opacity(viewModel.currentUser?.canAddMoreFriends == true ? 1 : 0.5)
                
            case .pending:
                Text("pending")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1)
                    .foregroundColor(ShadowTheme.textTertiary)
                    .textCase(.uppercase)
                
            case .friends:
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.green.opacity(0.7))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ShadowTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }
}

// MARK: - Friend Requests View

struct FriendRequestsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    var incomingRequests: [FriendRequest] {
        viewModel.getIncomingRequests()
    }
    
    var outgoingRequests: [FriendRequest] {
        viewModel.getOutgoingRequests()
    }
    
    var body: some View {
        ZStack {
            ShadowTheme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(ShadowTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Text("requests")
                        .font(.system(size: 16, weight: .light))
                        .tracking(2)
                        .foregroundColor(ShadowTheme.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        if !incomingRequests.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("received")
                                    .font(.system(size: 12, weight: .medium))
                                    .tracking(2)
                                    .foregroundColor(ShadowTheme.textTertiary)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 4)
                                
                                ForEach(incomingRequests) { request in
                                    if let user = viewModel.getUserById(request.fromUserId) {
                                        IncomingRequestRow(user: user, request: request)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        if !outgoingRequests.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("sent")
                                    .font(.system(size: 12, weight: .medium))
                                    .tracking(2)
                                    .foregroundColor(ShadowTheme.textTertiary)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 4)
                                
                                ForEach(outgoingRequests) { request in
                                    if let user = viewModel.getUserById(request.toUserId) {
                                        OutgoingRequestRow(user: user, request: request)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        if incomingRequests.isEmpty && outgoingRequests.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tray")
                                    .font(.system(size: 32, weight: .ultraLight))
                                    .foregroundColor(ShadowTheme.textTertiary)
                                
                                Text("no pending requests")
                                    .font(.system(size: 14, weight: .light))
                                    .foregroundColor(ShadowTheme.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
        }
    }
}

// MARK: - Incoming Request Row

struct IncomingRequestRow: View {
    let user: User
    let request: FriendRequest
    @EnvironmentObject var viewModel: AppViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(ShadowTheme.surfaceLight)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(user.displayName.prefix(1)).lowercased())
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(ShadowTheme.textSecondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName.lowercased())
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(ShadowTheme.textPrimary)
                
                Text("@\(user.username)")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(ShadowTheme.textTertiary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: { viewModel.declineFriendRequest(request.id) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ShadowTheme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                
                Button(action: { viewModel.acceptFriendRequest(request.id) }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.white)
                        )
                }
                .disabled(viewModel.currentUser?.canAddMoreFriends != true)
                .opacity(viewModel.currentUser?.canAddMoreFriends == true ? 1 : 0.5)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ShadowTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }
}

// MARK: - Outgoing Request Row

struct OutgoingRequestRow: View {
    let user: User
    let request: FriendRequest
    @EnvironmentObject var viewModel: AppViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(ShadowTheme.surfaceLight)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(user.displayName.prefix(1)).lowercased())
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(ShadowTheme.textSecondary)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName.lowercased())
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(ShadowTheme.textPrimary)
                
                Text("@\(user.username)")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(ShadowTheme.textTertiary)
            }
            
            Spacer()
            
            Button(action: { viewModel.cancelFriendRequest(request.id) }) {
                Text("cancel")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1)
                    .foregroundColor(ShadowTheme.textSecondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ShadowTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }
}

// MARK: - Friend Request Status

enum FriendRequestStatus {
    case none
    case pending
    case friends
}

#Preview {
    FriendsView()
        .environmentObject(AppViewModel())
}
