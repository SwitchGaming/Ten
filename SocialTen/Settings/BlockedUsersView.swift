//
//  BlockedUsersView.swift
//  SocialTen
//

import SwiftUI

struct BlockedUsersView: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var blockManager = BlockManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var blockedUsers: [User] = []
    @State private var isLoading = true
    @State private var unblockingUserId: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.colors.background.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: themeManager.colors.textTertiary))
                } else if blockedUsers.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(blockedUsers) { user in
                                blockedUserRow(user)
                            }
                        }
                        .padding(.horizontal, themeManager.spacing.screenHorizontal)
                        .padding(.top, themeManager.spacing.lg)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("blocked users")
                        .font(themeManager.fonts.body)
                        .foregroundColor(themeManager.colors.textPrimary)
                        .tracking(themeManager.letterSpacing.wide)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.colors.accent1)
                }
            }
        }
        .task {
            await loadBlockedUsers()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(themeManager.colors.textTertiary)
            
            Text("no blocked users")
                .font(themeManager.fonts.body)
                .foregroundColor(themeManager.colors.textSecondary)
            
            Text("users you block will appear here")
                .font(.system(size: 13, weight: .light))
                .foregroundColor(themeManager.colors.textTertiary)
        }
    }
    
    // MARK: - Blocked User Row
    
    private func blockedUserRow(_ user: User) -> some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(themeManager.colors.cardBackground)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(user.displayName.prefix(1)).lowercased())
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(themeManager.colors.textSecondary)
                )
            
            // Name and username
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName.lowercased())
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(themeManager.colors.textPrimary)
                
                Text("@\(user.username)")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(themeManager.colors.textTertiary)
            }
            
            Spacer()
            
            // Unblock button
            Button(action: {
                Task {
                    await unblockUser(user)
                }
            }) {
                if unblockingUserId == user.id {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: themeManager.colors.accent1))
                        .scaleEffect(0.8)
                } else {
                    Text("unblock")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(themeManager.colors.accent1)
                }
            }
            .disabled(unblockingUserId != nil)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.colors.cardBackground)
        )
    }
    
    // MARK: - Load Blocked Users
    
    private func loadBlockedUsers() async {
        isLoading = true
        
        // First ensure we have the blocked IDs
        await blockManager.loadBlockedUsers()
        
        // Then fetch the user details for each blocked ID
        let blockedIds = Array(blockManager.blockedUserIds)
        
        if blockedIds.isEmpty {
            blockedUsers = []
            isLoading = false
            return
        }
        
        do {
            // Fetch user details for blocked users
            struct DBUserBasic: Codable {
                let id: UUID
                let username: String
                let displayName: String
                
                enum CodingKeys: String, CodingKey {
                    case id
                    case username
                    case displayName = "display_name"
                }
            }
            
            let users: [DBUserBasic] = try await SupabaseManager.shared.client
                .from("users")
                .select("id, username, display_name")
                .in("id", values: blockedIds)
                .execute()
                .value
            
            blockedUsers = users.map { dbUser in
                User(
                    id: dbUser.id.uuidString,
                    username: dbUser.username,
                    displayName: dbUser.displayName,
                    bio: "",
                    todayRating: nil,
                    ratingTimestamp: nil,
                    friendIds: [],
                    ratingHistory: [],
                    lastRating: nil,
                    premiumExpiresAt: nil,
                    selectedThemeId: nil
                )
            }
        } catch {
            print("❌ Error loading blocked user details: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Unblock User
    
    private func unblockUser(_ user: User) async {
        unblockingUserId = user.id
        
        let result = await blockManager.unblockUser(userId: user.id)
        
        if result.success {
            // Remove from local list with animation
            withAnimation(.easeInOut(duration: 0.2)) {
                blockedUsers.removeAll { $0.id == user.id }
            }
        }
        
        unblockingUserId = nil
    }
}

#Preview {
    BlockedUsersView()
}
