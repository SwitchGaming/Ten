//
//  GroupsView.swift
//  SocialTen
//
//  Friend Groups management and display
//

import SwiftUI

// MARK: - Groups Manager

class GroupsManager: ObservableObject {
    static let shared = GroupsManager()
    
    @Published var groups: [FriendGroup] = []
    @Published var isLoading = false
    @Published var selectedGroupId: UUID? = nil // For filtering friends
    
    private init() {}
    
    var selectedGroup: FriendGroup? {
        groups.first { $0.id == selectedGroupId }
    }
    
    func loadGroups() async {
        await MainActor.run { isLoading = true }
        
        do {
            let response = try await SupabaseManager.shared.client
                .rpc("get_my_groups")
                .execute()
            
            let decoder = JSONDecoder()
            let loadedGroups = try decoder.decode([FriendGroup].self, from: response.data)
            
            await MainActor.run {
                groups = loadedGroups
                isLoading = false
            }
        } catch {
            print("❌ Error loading groups: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
    
    func createGroup(name: String, emoji: String, memberIds: [String]) async -> Bool {
        do {
            let params: [String: String] = [
                "p_name": name,
                "p_emoji": emoji,
                "p_member_ids": memberIds.joined(separator: ",")
            ]
            let response = try await SupabaseManager.shared.client
                .rpc("create_friend_group", params: params)
                .execute()
            
            if let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
               json["error"] != nil {
                print("❌ Create group error: \(json["error"] ?? "")")
                return false
            }
            
            await loadGroups()
            return true
        } catch {
            print("❌ Error creating group: \(error)")
            return false
        }
    }
    
    func updateGroup(id: UUID, name: String, emoji: String, memberIds: [String]) async -> Bool {
        do {
            let params: [String: String] = [
                "p_group_id": id.uuidString,
                "p_name": name,
                "p_emoji": emoji,
                "p_member_ids": memberIds.joined(separator: ",")
            ]
            try await SupabaseManager.shared.client
                .rpc("update_friend_group", params: params)
                .execute()
            
            await loadGroups()
            return true
        } catch {
            print("❌ Error updating group: \(error)")
            return false
        }
    }
    
    func deleteGroup(id: UUID) async -> (success: Bool, deletedVibes: Int, deletedPosts: Int) {
        do {
            let response = try await SupabaseManager.shared.client
                .rpc("delete_friend_group", params: ["p_group_id": id.uuidString])
                .execute()
            
            if let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
               let success = json["success"] as? Bool, success {
                let vibes = json["deleted_vibes"] as? Int ?? 0
                let posts = json["deleted_posts"] as? Int ?? 0
                
                await MainActor.run {
                    if selectedGroupId == id {
                        selectedGroupId = nil
                    }
                }
                
                await loadGroups()
                return (true, vibes, posts)
            }
            return (false, 0, 0)
        } catch {
            print("❌ Error deleting group: \(error)")
            return (false, 0, 0)
        }
    }
    
    func getGroupLimitInfo() async -> GroupLimitInfo? {
        do {
            let response = try await SupabaseManager.shared.client
                .rpc("get_group_limit_info")
                .execute()
            
            return try JSONDecoder().decode(GroupLimitInfo.self, from: response.data)
        } catch {
            print("❌ Error getting group limit: \(error)")
            return nil
        }
    }
    
    func filterFriends(_ friends: [User]) -> [User] {
        guard let groupId = selectedGroupId,
              let group = groups.first(where: { $0.id == groupId }) else {
            return friends
        }
        
        let memberIds = Set(group.members.map { $0.id.uuidString })
        return friends.filter { memberIds.contains($0.id) }
    }
}

// MARK: - Group Chips Row

struct GroupChipsRow: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var groupsManager = GroupsManager.shared
    @ObservedObject private var premiumManager = PremiumManager.shared
    
    @State private var showCreateGroup = false
    @State private var editingGroup: FriendGroup? = nil
    @State private var showPremiumUpsell = false
    
    let friendCount: Int
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: themeManager.spacing.sm) {
                // All Friends chip
                GroupChip(
                    emoji: "👥",
                    name: "all",
                    count: friendCount,
                    isSelected: groupsManager.selectedGroupId == nil,
                    onTap: {
                        withAnimation(.spring(response: 0.3)) {
                            groupsManager.selectedGroupId = nil
                        }
                    },
                    onLongPress: nil
                )
                
                // User's groups
                ForEach(groupsManager.groups) { group in
                    GroupChip(
                        emoji: group.emoji,
                        name: group.name,
                        count: group.memberCount,
                        isSelected: groupsManager.selectedGroupId == group.id,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                if groupsManager.selectedGroupId == group.id {
                                    groupsManager.selectedGroupId = nil
                                } else {
                                    groupsManager.selectedGroupId = group.id
                                }
                            }
                        },
                        onLongPress: {
                            editingGroup = group
                        }
                    )
                }
                
                // Add new group button - only show if under limit
                if groupsManager.groups.count < premiumManager.groupLimit {
                    AddGroupChip(
                        isLocked: false,
                        onTap: {
                            showCreateGroup = true
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showCreateGroup) {
            CreateGroupSheet()
        }
        .sheet(item: $editingGroup) { group in
            EditGroupSheet(group: group)
        }
    }
}

// MARK: - Group Chip

struct GroupChip: View {
    let emoji: String
    let name: String
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: (() -> Void)?
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 14))
                
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                
                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : themeManager.colors.textTertiary)
            }
            .foregroundStyle(isSelected ? .white : themeManager.colors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? themeManager.colors.accent1 : themeManager.colors.cardBackground)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    onLongPress?()
                }
        )
    }
}

// MARK: - Add Group Chip

struct AddGroupChip: View {
    let isLocked: Bool
    let onTap: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: isLocked ? "lock.fill" : "plus")
                    .font(.system(size: 12, weight: .medium))
                
                Text("new")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(isLocked ? themeManager.colors.textTertiary : themeManager.colors.accent1)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .stroke(
                        isLocked ? themeManager.colors.textTertiary.opacity(0.3) : themeManager.colors.accent1.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create Group Sheet

struct CreateGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var groupsManager = GroupsManager.shared
    
    @State private var name = ""
    @State private var emoji = "👥"
    @State private var selectedFriendIds: Set<String> = []
    @State private var isCreating = false
    @State private var showEmojiPicker = false
    
    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedFriendIds.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: themeManager.spacing.xl) {
                        // Emoji & Name
                        groupInfoSection
                        
                        // Friend Selection
                        friendSelectionSection
                    }
                    .padding(.horizontal, themeManager.spacing.screenHorizontal)
                    .padding(.vertical, themeManager.spacing.md)
                }
            }
            .navigationTitle("new group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(themeManager.colors.accent1)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createGroup()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(canCreate && !isCreating ? themeManager.colors.accent1 : themeManager.colors.textTertiary)
                    .disabled(!canCreate || isCreating)
                }
            }
        }
    }
    
    private var groupInfoSection: some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            Text("group info")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(themeManager.colors.textSecondary)
                .textCase(.uppercase)
                .tracking(1)
            
            HStack(spacing: 12) {
                // Emoji button
                Button(action: { showEmojiPicker = true }) {
                    Text(emoji)
                        .font(.system(size: 32))
                        .frame(width: 60, height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: themeManager.radius.md)
                                .fill(themeManager.colors.cardBackground)
                        )
                }
                .sheet(isPresented: $showEmojiPicker) {
                    EmojiPickerSheet(selectedEmoji: $emoji)
                }
                
                // Name field
                TextField("group name", text: $name)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(themeManager.colors.textPrimary)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: themeManager.radius.md)
                            .fill(themeManager.colors.cardBackground)
                    )
                    .onChange(of: name) { _, newValue in
                        if newValue.count > 20 {
                            name = String(newValue.prefix(20))
                        }
                    }
            }
            
            Text("\(name.count)/20 characters")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(themeManager.colors.textTertiary)
        }
    }
    
    private var friendSelectionSection: some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            HStack {
                Text("select friends")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.colors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(1)
                
                Spacer()
                
                Text("\(selectedFriendIds.count) selected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.colors.accent1)
            }
            
            if viewModel.friends.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(themeManager.colors.textTertiary)
                    
                    Text("add friends first")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(themeManager.colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(viewModel.friends) { friend in
                        FriendSelectionCell(
                            friend: friend,
                            isSelected: selectedFriendIds.contains(friend.id)
                        ) {
                            withAnimation(.spring(response: 0.2)) {
                                if selectedFriendIds.contains(friend.id) {
                                    selectedFriendIds.remove(friend.id)
                                } else {
                                    selectedFriendIds.insert(friend.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func createGroup() {
        isCreating = true
        Task {
            let success = await groupsManager.createGroup(
                name: name.trimmingCharacters(in: .whitespaces),
                emoji: emoji,
                memberIds: Array(selectedFriendIds)
            )
            
            await MainActor.run {
                isCreating = false
                if success {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Edit Group Sheet

struct EditGroupSheet: View {
    let group: FriendGroup
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var groupsManager = GroupsManager.shared
    
    @State private var name: String = ""
    @State private var emoji: String = ""
    @State private var selectedFriendIds: Set<String> = []
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false
    @State private var showEmojiPicker = false
    @State private var deleteInfo: (vibes: Int, posts: Int) = (0, 0)
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedFriendIds.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: themeManager.spacing.xl) {
                        // Emoji & Name
                        groupInfoSection
                        
                        // Friend Selection
                        friendSelectionSection
                        
                        // Delete Button
                        deleteButton
                    }
                    .padding(.horizontal, themeManager.spacing.screenHorizontal)
                    .padding(.vertical, themeManager.spacing.md)
                }
            }
            .navigationTitle("edit group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(themeManager.colors.accent1)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGroup()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(canSave && !isSaving ? themeManager.colors.accent1 : themeManager.colors.textTertiary)
                    .disabled(!canSave || isSaving)
                }
            }
            .onAppear {
                name = group.name
                emoji = group.emoji
                selectedFriendIds = Set(group.members.map { $0.id.uuidString })
            }
            .alert("Delete Group", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteGroup()
                }
            } message: {
                Text("This will permanently delete \"\(group.emoji) \(group.name)\" and ALL associated data:\n\n• \(deleteInfo.vibes) vibe(s)\n• \(deleteInfo.posts) post(s)\n\nThis cannot be undone.")
            }
        }
    }
    
    private var groupInfoSection: some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            Text("group info")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(themeManager.colors.textSecondary)
                .textCase(.uppercase)
                .tracking(1)
            
            HStack(spacing: 12) {
                // Emoji button
                Button(action: { showEmojiPicker = true }) {
                    Text(emoji)
                        .font(.system(size: 32))
                        .frame(width: 60, height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: themeManager.radius.md)
                                .fill(themeManager.colors.cardBackground)
                        )
                }
                .sheet(isPresented: $showEmojiPicker) {
                    EmojiPickerSheet(selectedEmoji: $emoji)
                }
                
                // Name field
                TextField("group name", text: $name)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(themeManager.colors.textPrimary)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: themeManager.radius.md)
                            .fill(themeManager.colors.cardBackground)
                    )
                    .onChange(of: name) { _, newValue in
                        if newValue.count > 20 {
                            name = String(newValue.prefix(20))
                        }
                    }
            }
            
            Text("\(name.count)/20 characters")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(themeManager.colors.textTertiary)
        }
    }
    
    private var friendSelectionSection: some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            HStack {
                Text("select friends")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.colors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(1)
                
                Spacer()
                
                Text("\(selectedFriendIds.count) selected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.colors.accent1)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.friends) { friend in
                    FriendSelectionCell(
                        friend: friend,
                        isSelected: selectedFriendIds.contains(friend.id)
                    ) {
                        withAnimation(.spring(response: 0.2)) {
                            if selectedFriendIds.contains(friend.id) {
                                selectedFriendIds.remove(friend.id)
                            } else {
                                selectedFriendIds.insert(friend.id)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var deleteButton: some View {
        Button(action: {
            // Get delete info before showing confirmation
            Task {
                // Count associated content
                let vibeCount = await countGroupVibes()
                let postCount = await countGroupPosts()
                deleteInfo = (vibeCount, postCount)
                showDeleteConfirmation = true
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                Text("delete group")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: themeManager.radius.md)
                    .fill(.red.opacity(0.1))
            )
        }
        .padding(.top, themeManager.spacing.lg)
    }
    
    private func countGroupVibes() async -> Int {
        // This would ideally be an RPC call, but for now we'll estimate
        return 0 // Will be shown in delete result
    }
    
    private func countGroupPosts() async -> Int {
        return 0 // Will be shown in delete result
    }
    
    private func saveGroup() {
        isSaving = true
        Task {
            let success = await groupsManager.updateGroup(
                id: group.id,
                name: name.trimmingCharacters(in: .whitespaces),
                emoji: emoji,
                memberIds: Array(selectedFriendIds)
            )
            
            await MainActor.run {
                isSaving = false
                if success {
                    dismiss()
                }
            }
        }
    }
    
    private func deleteGroup() {
        Task {
            let result = await groupsManager.deleteGroup(id: group.id)
            if result.success {
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Friend Selection Cell

struct FriendSelectionCell: View {
    let friend: User
    let isSelected: Bool
    let onTap: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    // Avatar (initials only - no profile images in app)
                    initialsView
                    
                    // Selection indicator
                    if isSelected {
                        Circle()
                            .fill(themeManager.colors.accent1)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .offset(x: 4, y: 4)
                    }
                }
                
                Text(friend.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.colors.textPrimary)
                    .lineLimit(1)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: themeManager.radius.md)
                    .fill(isSelected ? themeManager.colors.accent1.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: themeManager.radius.md)
                    .stroke(isSelected ? themeManager.colors.accent1.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var initialsView: some View {
        Circle()
            .fill(themeManager.colors.cardBackground)
            .frame(width: 56, height: 56)
            .overlay(
                Text(String(friend.displayName.prefix(1)).lowercased())
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(themeManager.colors.textSecondary)
            )
    }
}

// MARK: - Emoji Picker Sheet

struct EmojiPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedEmoji: String
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var searchText = ""
    
    private let commonEmojis = [
        "👥", "👨‍👩‍👧‍👦", "💼", "🎓", "🏠", "🎮", "⚽️", "🎵",
        "🍕", "✈️", "💪", "🎉", "❤️", "🔥", "⭐️", "🌟",
        "🏆", "🎯", "💡", "📚", "🎨", "🎬", "🎸", "🏃",
        "🧘", "🍻", "☕️", "🌴", "🏖️", "⛷️", "🎿", "🏀",
        "🎾", "🏈", "⚾️", "🎳", "🚴", "🏊", "🧗", "🤝"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.background.ignoresSafeArea()
                
                VStack(spacing: themeManager.spacing.lg) {
                    // Preview
                    Text(selectedEmoji)
                        .font(.system(size: 64))
                        .padding(.top, themeManager.spacing.lg)
                    
                    // Common emojis grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(commonEmojis, id: \.self) { emoji in
                            Button(action: {
                                selectedEmoji = emoji
                                dismiss()
                            }) {
                                Text(emoji)
                                    .font(.system(size: 28))
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(selectedEmoji == emoji ? themeManager.colors.accent1.opacity(0.2) : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, themeManager.spacing.screenHorizontal)
                    
                    Spacer()
                    
                    // Tip
                    Text("or use the keyboard emoji picker")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(themeManager.colors.textTertiary)
                        .padding(.bottom, themeManager.spacing.lg)
                }
            }
            .navigationTitle("choose emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Group Picker for Vibe/Post Creation

struct GroupPicker: View {
    @Binding var selectedGroupId: UUID?
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var groupsManager = GroupsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.sm) {
            Text("send to")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(themeManager.colors.textSecondary)
                .textCase(.uppercase)
                .tracking(1)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: themeManager.spacing.sm) {
                    // All friends option
                    GroupPickerChip(
                        emoji: "👥",
                        name: "all friends",
                        isSelected: selectedGroupId == nil,
                        onTap: {
                            withAnimation(.spring(response: 0.2)) {
                                selectedGroupId = nil
                            }
                        }
                    )
                    
                    // User's groups
                    ForEach(groupsManager.groups) { group in
                        GroupPickerChip(
                            emoji: group.emoji,
                            name: group.name,
                            isSelected: selectedGroupId == group.id,
                            onTap: {
                                withAnimation(.spring(response: 0.2)) {
                                    selectedGroupId = group.id
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}

struct GroupPickerChip: View {
    let emoji: String
    let name: String
    let isSelected: Bool
    let onTap: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 14))
                
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : themeManager.colors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? themeManager.colors.accent1 : themeManager.colors.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    GroupChipsRow(friendCount: 5)
        .padding()
        .background(Color.black)
}
