//
//  DeveloperChangelogView.swift
//  SocialTen
//
//  Developer view for managing changelogs
//

import SwiftUI

// MARK: - Developer Changelog Entry (for editing)

struct DevChangelogEntry: Codable, Identifiable {
    let id: UUID
    var version: String
    var title: String
    var entries: [ChangelogItem]
    var is_published: Bool
    let created_at: String?
    let published_at: String?
    
    enum CodingKeys: String, CodingKey {
        case id, version, title, entries, is_published, created_at, published_at
    }
    
    init(id: UUID, version: String, title: String, entries: [ChangelogItem], is_published: Bool, created_at: String?, published_at: String?) {
        self.id = id
        self.version = version
        self.title = title
        self.entries = entries
        self.is_published = is_published
        self.created_at = created_at
        self.published_at = published_at
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        version = try container.decode(String.self, forKey: .version)
        title = try container.decode(String.self, forKey: .title)
        is_published = try container.decode(Bool.self, forKey: .is_published)
        created_at = try container.decodeIfPresent(String.self, forKey: .created_at)
        published_at = try container.decodeIfPresent(String.self, forKey: .published_at)
        
        // Handle entries - could be array or JSON string
        if let entriesArray = try? container.decode([ChangelogItem].self, forKey: .entries) {
            entries = entriesArray
        } else if let entriesString = try? container.decode(String.self, forKey: .entries),
                  let data = entriesString.data(using: .utf8),
                  let parsedEntries = try? JSONDecoder().decode([ChangelogItem].self, from: data) {
            entries = parsedEntries
        } else {
            entries = []
        }
    }
    
    var formattedDate: String {
        guard let dateString = published_at ?? created_at else { return "Draft" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, yyyy"
            return displayFormatter.string(from: date)
        }
        return "Draft"
    }
}

// MARK: - Developer Changelog View

struct DeveloperChangelogView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var changelogs: [DevChangelogEntry] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false
    @State private var editingChangelog: DevChangelogEntry? = nil
    @State private var showDeleteConfirmation = false
    @State private var changelogToDelete: DevChangelogEntry? = nil
    
    var body: some View {
        ZStack {
            themeManager.colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                if isLoading {
                    loadingView
                } else if changelogs.isEmpty {
                    emptyView
                } else {
                    changelogList
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            ChangelogEditorSheet(
                changelog: nil,
                onSave: { newChangelog in
                    Task { await createChangelog(newChangelog) }
                }
            )
        }
        .sheet(item: $editingChangelog) { changelog in
            ChangelogEditorSheet(
                changelog: changelog,
                onSave: { updatedChangelog in
                    Task { await updateChangelog(updatedChangelog) }
                }
            )
        }
        .confirmationDialog(
            "Delete Changelog",
            isPresented: $showDeleteConfirmation,
            presenting: changelogToDelete
        ) { changelog in
            Button("Delete v\(changelog.version)", role: .destructive) {
                Task { await deleteChangelog(changelog) }
            }
        } message: { changelog in
            Text("This will permanently delete the changelog for v\(changelog.version).")
        }
        .task {
            await loadChangelogs()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(themeManager.colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(themeManager.colors.cardBackground))
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("changelogs")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(themeManager.colors.textPrimary)
                
                Text("\(changelogs.count) versions")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.colors.textSecondary)
            }
            
            Spacer()
            
            Button(action: { showCreateSheet = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(themeManager.colors.accent1))
            }
        }
        .padding(.horizontal, themeManager.spacing.screenHorizontal)
        .padding(.vertical, themeManager.spacing.md)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(themeManager.colors.accent1)
            Spacer()
        }
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: themeManager.spacing.md) {
            Spacer()
            
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(themeManager.colors.textTertiary)
            
            Text("no changelogs yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(themeManager.colors.textSecondary)
            
            Text("tap + to create your first changelog")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(themeManager.colors.textTertiary)
            
            Spacer()
        }
    }
    
    // MARK: - Changelog List
    
    private var changelogList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: themeManager.spacing.md) {
                ForEach(changelogs) { changelog in
                    DevChangelogCard(
                        changelog: changelog,
                        onEdit: { editingChangelog = changelog },
                        onDelete: {
                            changelogToDelete = changelog
                            showDeleteConfirmation = true
                        },
                        onPublish: { Task { await togglePublish(changelog) } }
                    )
                }
            }
            .padding(.horizontal, themeManager.spacing.screenHorizontal)
            .padding(.vertical, themeManager.spacing.sm)
            .padding(.bottom, 50)
        }
        .refreshable {
            await loadChangelogs()
        }
    }
    
    // MARK: - Functions
    
    private func loadChangelogs() async {
        do {
            let response: [DevChangelogEntry] = try await SupabaseManager.shared.client
                .rpc("get_all_changelogs")
                .execute()
                .value
            
            await MainActor.run {
                changelogs = response
                isLoading = false
            }
        } catch {
            print("❌ Error loading changelogs: \(error)")
            isLoading = false
        }
    }
    
    private func createChangelog(_ changelog: DevChangelogEntry) async {
        do {
            let entriesData = try JSONEncoder().encode(changelog.entries)
            let entriesString = String(data: entriesData, encoding: .utf8) ?? "[]"
            
            try await SupabaseManager.shared.client
                .rpc("create_changelog", params: [
                    "p_version": changelog.version,
                    "p_title": changelog.title,
                    "p_entries": entriesString,
                    "p_publish": changelog.is_published ? "true" : "false"
                ])
                .execute()
            
            await loadChangelogs()
        } catch {
            print("❌ Error creating changelog: \(error)")
        }
    }
    
    private func updateChangelog(_ changelog: DevChangelogEntry) async {
        do {
            let entriesData = try JSONEncoder().encode(changelog.entries)
            let entriesString = String(data: entriesData, encoding: .utf8) ?? "[]"
            
            try await SupabaseManager.shared.client
                .rpc("update_changelog", params: [
                    "p_id": changelog.id.uuidString,
                    "p_version": changelog.version,
                    "p_title": changelog.title,
                    "p_entries": entriesString,
                    "p_publish": changelog.is_published ? "true" : "false"
                ])
                .execute()
            
            await loadChangelogs()
        } catch {
            print("❌ Error updating changelog: \(error)")
        }
    }
    
    private func deleteChangelog(_ changelog: DevChangelogEntry) async {
        do {
            try await SupabaseManager.shared.client
                .rpc("delete_changelog", params: ["p_id": changelog.id.uuidString])
                .execute()
            
            await MainActor.run {
                withAnimation {
                    changelogs.removeAll { $0.id == changelog.id }
                }
            }
        } catch {
            print("❌ Error deleting changelog: \(error)")
        }
    }
    
    private func togglePublish(_ changelog: DevChangelogEntry) async {
        var updated = changelog
        updated.is_published.toggle()
        await updateChangelog(updated)
    }
}

// MARK: - Dev Changelog Card

struct DevChangelogCard: View {
    let changelog: DevChangelogEntry
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onPublish: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                // Version
                Text("v\(changelog.version)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(changelog.is_published ? themeManager.colors.accent1 : Color.gray)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(changelog.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(themeManager.colors.textPrimary)
                    
                    HStack(spacing: 8) {
                        Text(changelog.formattedDate)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(themeManager.colors.textSecondary)
                        
                        if !changelog.is_published {
                            Text("DRAFT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.orange.opacity(0.15))
                                )
                        }
                    }
                }
                
                Spacer()
            }
            
            // Entry count
            Text("\(changelog.entries.count) items")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(themeManager.colors.textTertiary)
            
            Divider()
            
            // Actions
            HStack(spacing: 12) {
                Button(action: onPublish) {
                    HStack(spacing: 6) {
                        Image(systemName: changelog.is_published ? "eye.slash" : "eye")
                            .font(.system(size: 11))
                        Text(changelog.is_published ? "unpublish" : "publish")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(changelog.is_published ? .orange : Color(hex: "4ADE80"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill((changelog.is_published ? Color.orange : Color(hex: "4ADE80")).opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
                
                Button(action: onEdit) {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                        Text("edit")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: "60A5FA"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(hex: "60A5FA").opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text("delete")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(Color(hex: "F87171"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(hex: "F87171").opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
        }
        .padding(themeManager.spacing.md)
        .background(
            RoundedRectangle(cornerRadius: themeManager.radius.md)
                .fill(themeManager.colors.cardBackground)
        )
    }
}

// MARK: - Changelog Editor Sheet

struct ChangelogEditorSheet: View {
    let changelog: DevChangelogEntry?
    let onSave: (DevChangelogEntry) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var version: String = ""
    @State private var title: String = ""
    @State private var entries: [ChangelogItem] = []
    @State private var isPublished: Bool = false
    @State private var showAddItemSheet = false
    
    private var isEditing: Bool { changelog != nil }
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: themeManager.spacing.xl) {
                        // Version & Title
                        versionSection
                        
                        // Entries
                        entriesSection
                        
                        // Publish toggle
                        publishToggle
                    }
                    .padding(.horizontal, themeManager.spacing.screenHorizontal)
                    .padding(.vertical, themeManager.spacing.md)
                }
            }
            .navigationTitle(isEditing ? "Edit Changelog" : "New Changelog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChangelog() }
                        .fontWeight(.semibold)
                        .disabled(version.isEmpty || title.isEmpty)
                }
            }
            .sheet(isPresented: $showAddItemSheet) {
                AddChangelogItemSheet { item in
                    entries.append(item)
                }
            }
        }
        .onAppear {
            if let existing = changelog {
                version = existing.version
                title = existing.title
                entries = existing.entries
                isPublished = existing.is_published
            }
        }
    }
    
    // MARK: - Version Section
    
    private var versionSection: some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            Text("details")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(themeManager.colors.textSecondary)
            
            VStack(spacing: 12) {
                // Version
                HStack {
                    Text("v")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(themeManager.colors.textSecondary)
                    
                    TextField("1.0.0", text: $version)
                        .font(.system(size: 16, weight: .medium))
                        .keyboardType(.numbersAndPunctuation)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: themeManager.radius.sm)
                        .fill(themeManager.colors.cardBackground)
                )
                
                // Title
                TextField("What's in this release?", text: $title)
                    .font(.system(size: 16, weight: .medium))
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: themeManager.radius.sm)
                            .fill(themeManager.colors.cardBackground)
                    )
            }
        }
    }
    
    // MARK: - Entries Section
    
    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            HStack {
                Text("changelog items")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeManager.colors.textSecondary)
                
                Spacer()
                
                Button(action: { showAddItemSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("add")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(themeManager.colors.accent1)
                }
            }
            
            if entries.isEmpty {
                Text("No items yet. Tap 'add' to add changelog entries.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(themeManager.colors.textTertiary)
                    .padding(.vertical, themeManager.spacing.lg)
            } else {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(item.color)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(item.color.opacity(0.15)))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(item.color)
                            
                            Text(item.text)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(themeManager.colors.textPrimary)
                        }
                        
                        Spacer()
                        
                        Button(action: { entries.remove(at: index) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(themeManager.colors.textTertiary)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: themeManager.radius.sm)
                            .fill(themeManager.colors.cardBackground)
                    )
                }
            }
        }
    }
    
    // MARK: - Publish Toggle
    
    private var publishToggle: some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            Toggle(isOn: $isPublished) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Publish immediately")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(themeManager.colors.textPrimary)
                    
                    Text("Users will see this changelog when they open the app")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(themeManager.colors.textSecondary)
                }
            }
            .tint(themeManager.colors.accent1)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: themeManager.radius.sm)
                    .fill(themeManager.colors.cardBackground)
            )
        }
    }
    
    // MARK: - Functions
    
    private func saveChangelog() {
        let newChangelog = DevChangelogEntry(
            id: changelog?.id ?? UUID(),
            version: version,
            title: title,
            entries: entries,
            is_published: isPublished,
            created_at: changelog?.created_at,
            published_at: changelog?.published_at
        )
        onSave(newChangelog)
        dismiss()
    }
}

// MARK: - Add Changelog Item Sheet

struct AddChangelogItemSheet: View {
    let onAdd: (ChangelogItem) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var selectedType: String = "feature"
    @State private var text: String = ""
    
    private let itemTypes = [
        ("feature", "New Feature", "sparkles", Color(hex: "8B5CF6")),
        ("improvement", "Improvement", "arrow.up.circle.fill", Color(hex: "60A5FA")),
        ("fix", "Bug Fix", "wrench.and.screwdriver.fill", Color(hex: "F87171")),
        ("fromFeedback", "From Feedback", "heart.fill", Color(hex: "4ADE80"))
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.colors.background.ignoresSafeArea()
                
                VStack(spacing: themeManager.spacing.xl) {
                    // Type selection
                    VStack(alignment: .leading, spacing: themeManager.spacing.md) {
                        Text("type")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(themeManager.colors.textSecondary)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(itemTypes, id: \.0) { type in
                                Button(action: { selectedType = type.0 }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: type.2)
                                            .font(.system(size: 14))
                                        Text(type.1)
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundStyle(selectedType == type.0 ? .white : type.3)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: themeManager.radius.sm)
                                            .fill(selectedType == type.0 ? type.3 : type.3.opacity(0.15))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: themeManager.spacing.md) {
                        Text("description")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(themeManager.colors.textSecondary)
                        
                        TextField("What changed?", text: $text, axis: .vertical)
                            .font(.system(size: 16))
                            .lineLimit(3...6)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: themeManager.radius.sm)
                                    .fill(themeManager.colors.cardBackground)
                            )
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, themeManager.spacing.screenHorizontal)
                .padding(.vertical, themeManager.spacing.md)
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let item = ChangelogItem(type: selectedType, text: text)
                        onAdd(item)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(text.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DeveloperChangelogView()
}
