//
//  DowngradeFlowView.swift
//  SocialTen
//
//  Blocking modal for premium expiry - forces users to select friends/delete groups
//

import SwiftUI

struct DowngradeFlowView: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @ObservedObject var premiumManager = PremiumManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var selectedFriendIds: Set<String> = []
    @State private var selectedGroupIds: Set<UUID> = []
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // Background
            themeManager.colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Content based on step
                switch premiumManager.downgradeState.currentStep {
                case .friendSelection(let currentCount, let maxAllowed):
                    friendSelectionContent(currentCount: currentCount, maxAllowed: maxAllowed)
                case .groupDeletion(let currentCount, let maxAllowed):
                    groupDeletionContent(currentCount: currentCount, maxAllowed: maxAllowed)
                case .themeReset:
                    themeResetContent
                case .complete, .none:
                    EmptyView()
                }
            }
            
            if isProcessing {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
        .interactiveDismissDisabled() // Cannot dismiss - must complete flow
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(themeManager.colors.accent2)
                .padding(.top, 40)
            
            Text("ten+ expired")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(themeManager.colors.textPrimary)
            
            Text("Let's adjust your account to continue")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(themeManager.colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.bottom, 32)
    }
    
    // MARK: - Friend Selection
    
    private func friendSelectionContent(currentCount: Int, maxAllowed: Int) -> some View {
        VStack(spacing: 24) {
            // Info card
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "person.3.fill")
                        .foregroundColor(themeManager.colors.accent1)
                    Text("Too many friends")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeManager.colors.textPrimary)
                    Spacer()
                }
                
                Text("You have \(currentCount) friends but the free tier allows \(maxAllowed). Select \(maxAllowed) friends to keep.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(themeManager.colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(themeManager.colors.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal, 20)
            
            // Selection counter
            HStack {
                Text("Selected: \(selectedFriendIds.count)/\(maxAllowed)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selectedFriendIds.count == maxAllowed ? themeManager.colors.accent1 : themeManager.colors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Friend list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.friends, id: \.id) { friend in
                        FriendSelectionRow(
                            friend: friend,
                            isSelected: selectedFriendIds.contains(friend.id),
                            canSelect: selectedFriendIds.count < maxAllowed || selectedFriendIds.contains(friend.id)
                        ) {
                            toggleFriendSelection(friend.id, maxAllowed: maxAllowed)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Continue button
            Button {
                Task {
                    await processFriendSelection()
                }
            } label: {
                HStack {
                    Text("Continue")
                    if selectedFriendIds.count == maxAllowed {
                        Image(systemName: "checkmark")
                    }
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    selectedFriendIds.count == maxAllowed
                        ? themeManager.colors.accent1
                        : themeManager.colors.textTertiary
                )
                .cornerRadius(12)
            }
            .disabled(selectedFriendIds.count != maxAllowed)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }
    
    private func toggleFriendSelection(_ friendId: String, maxAllowed: Int) {
        if selectedFriendIds.contains(friendId) {
            selectedFriendIds.remove(friendId)
        } else if selectedFriendIds.count < maxAllowed {
            selectedFriendIds.insert(friendId)
        }
    }
    
    private func processFriendSelection() async {
        isProcessing = true
        
        // Remove friends not in selection
        let friendsToRemove = viewModel.friends.filter { !selectedFriendIds.contains($0.id) }
        
        for friend in friendsToRemove {
            await viewModel.removeFriend(friend.id)
        }
        
        isProcessing = false
        
        // Move to next step
        await MainActor.run {
            // Check if groups need handling
            let groupCount = 0 // TODO: Get actual group count
            premiumManager.completeFriendSelection(groupCount: groupCount)
        }
    }
    
    // MARK: - Group Deletion
    
    private func groupDeletionContent(currentCount: Int, maxAllowed: Int) -> some View {
        VStack(spacing: 24) {
            // Info card
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(themeManager.colors.accent2)
                    Text("Too many groups")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeManager.colors.textPrimary)
                    Spacer()
                }
                
                Text("You have \(currentCount) groups but the free tier allows \(maxAllowed). Select groups to delete.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(themeManager.colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(themeManager.colors.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal, 20)
            
            // Selection counter
            let groupsToDelete = currentCount - maxAllowed
            HStack {
                Text("Select \(groupsToDelete) group\(groupsToDelete > 1 ? "s" : "") to delete")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selectedGroupIds.count >= groupsToDelete ? themeManager.colors.accent1 : themeManager.colors.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // TODO: Add group list when groups are loaded
            Text("Group deletion UI coming soon")
                .foregroundColor(themeManager.colors.textTertiary)
            
            Spacer()
            
            // Continue button
            Button {
                Task {
                    await processGroupDeletion()
                }
            } label: {
                Text("Continue")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(themeManager.colors.accent1)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }
    
    private func processGroupDeletion() async {
        isProcessing = true
        
        // TODO: Delete selected groups
        
        isProcessing = false
        
        await MainActor.run {
            premiumManager.completeGroupDeletion()
        }
    }
    
    // MARK: - Theme Reset
    
    private var themeResetContent: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Theme icon
            ZStack {
                Circle()
                    .fill(themeManager.colors.cardBackground)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "paintpalette")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(themeManager.colors.textSecondary)
            }
            
            VStack(spacing: 12) {
                Text("Theme Reset")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(themeManager.colors.textPrimary)
                
                Text("Your custom theme will be reset to the default midnight theme.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(themeManager.colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Complete button
            Button {
                premiumManager.completeDowngrade()
            } label: {
                Text("Complete")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(themeManager.colors.accent1)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Friend Selection Row

struct FriendSelectionRow: View {
    let friend: User
    let isSelected: Bool
    let canSelect: Bool
    let onTap: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar - show initial
                ZStack {
                    Circle()
                        .fill(themeManager.colors.accent1.opacity(0.2))
                    
                    Text(String((friend.displayName.first ?? friend.username.first) ?? "?"))
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(themeManager.colors.accent1)
                }
                .frame(width: 44, height: 44)
                
                // Name
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName.isEmpty ? friend.username : friend.displayName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(themeManager.colors.textPrimary)
                    
                    Text("@\(friend.username)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(themeManager.colors.textSecondary)
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? themeManager.colors.accent1 : themeManager.colors.textTertiary, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(themeManager.colors.accent1)
                            .frame(width: 16, height: 16)
                    }
                }
            }
            .padding(12)
            .background(themeManager.colors.cardBackground)
            .cornerRadius(12)
            .opacity(canSelect ? 1 : 0.5)
        }
        .disabled(!canSelect)
    }
}

// MARK: - Preview

#Preview {
    DowngradeFlowView()
}
