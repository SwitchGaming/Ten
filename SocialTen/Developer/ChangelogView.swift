//
//  ChangelogView.swift
//  SocialTen
//
//  User-facing changelog view - shows what's new in each version
//

import SwiftUI

// MARK: - Models

struct ChangelogEntry: Codable, Identifiable {
    let id: UUID
    let version: String
    let title: String
    let entries: [ChangelogItem]
    let published_at: String?
    let is_read: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, version, title, entries, published_at, is_read
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        version = try container.decode(String.self, forKey: .version)
        title = try container.decode(String.self, forKey: .title)
        published_at = try container.decodeIfPresent(String.self, forKey: .published_at)
        is_read = try container.decodeIfPresent(Bool.self, forKey: .is_read)
        
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
    
    var publishedDate: Date? {
        guard let dateString = published_at else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
    }
    
    var formattedDate: String {
        guard let date = publishedDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

struct ChangelogItem: Codable, Identifiable {
    let id: UUID
    let type: String // "feature", "improvement", "fix", "fromFeedback"
    let text: String
    
    init(id: UUID = UUID(), type: String, text: String) {
        self.id = id
        self.type = type
        self.text = text
    }
    
    var icon: String {
        switch type {
        case "feature": return "sparkles"
        case "improvement": return "arrow.up.circle.fill"
        case "fix": return "wrench.and.screwdriver.fill"
        case "fromFeedback": return "heart.fill"
        default: return "circle.fill"
        }
    }
    
    var color: Color {
        switch type {
        case "feature": return Color(hex: "8B5CF6") // Purple
        case "improvement": return Color(hex: "60A5FA") // Blue
        case "fix": return Color(hex: "F87171") // Red
        case "fromFeedback": return Color(hex: "4ADE80") // Green
        default: return .gray
        }
    }
    
    var label: String {
        switch type {
        case "feature": return "New"
        case "improvement": return "Improved"
        case "fix": return "Fixed"
        case "fromFeedback": return "From Your Feedback"
        default: return ""
        }
    }
}

// MARK: - Changelog View

struct ChangelogView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var changelogs: [ChangelogEntry] = []
    @State private var isLoading = true
    @State private var expandedVersions: Set<String> = []
    
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
        .task {
            await loadChangelogs()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(themeManager.colors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(themeManager.colors.cardBackground))
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("what's new")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(themeManager.colors.textPrimary)
                
                Text("changelog")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(themeManager.colors.textSecondary)
            }
            
            Spacer()
            
            // Invisible spacer for balance
            Color.clear.frame(width: 36, height: 36)
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
            
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(themeManager.colors.textTertiary)
            
            Text("no updates yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(themeManager.colors.textSecondary)
            
            Spacer()
        }
    }
    
    // MARK: - Changelog List
    
    private var changelogList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: themeManager.spacing.lg) {
                ForEach(changelogs) { changelog in
                    VersionCard(
                        changelog: changelog,
                        isExpanded: expandedVersions.contains(changelog.version),
                        isLatest: changelog.id == changelogs.first?.id,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                if expandedVersions.contains(changelog.version) {
                                    expandedVersions.remove(changelog.version)
                                } else {
                                    expandedVersions.insert(changelog.version)
                                    // Mark as read when expanded
                                    if changelog.is_read == false {
                                        Task { await markAsRead(changelog.version) }
                                    }
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, themeManager.spacing.screenHorizontal)
            .padding(.vertical, themeManager.spacing.md)
            .padding(.bottom, 50)
        }
        .onAppear {
            // Auto-expand latest version
            if let latest = changelogs.first {
                expandedVersions.insert(latest.version)
                if latest.is_read == false {
                    Task { await markAsRead(latest.version) }
                }
            }
        }
    }
    
    // MARK: - Functions
    
    private func loadChangelogs() async {
        do {
            let response = try await SupabaseManager.shared.client
                .rpc("get_changelogs")
                .execute()
            
            let decoder = JSONDecoder()
            changelogs = try decoder.decode([ChangelogEntry].self, from: response.data)
            isLoading = false
        } catch {
            print("❌ Error loading changelogs: \(error)")
            isLoading = false
        }
    }
    
    private func markAsRead(_ version: String) async {
        do {
            try await SupabaseManager.shared.client
                .rpc("mark_changelog_read", params: ["p_version": version])
                .execute()
        } catch {
            print("❌ Error marking changelog read: \(error)")
        }
    }
}

// MARK: - Version Card

struct VersionCard: View {
    let changelog: ChangelogEntry
    let isExpanded: Bool
    let isLatest: Bool
    let onTap: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Version badge
                    Text("v\(changelog.version)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(isLatest ? themeManager.colors.accent1 : Color.gray.opacity(0.6))
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(changelog.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(themeManager.colors.textPrimary)
                            
                            if isLatest {
                                Text("LATEST")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(themeManager.colors.accent1)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(themeManager.colors.accent1.opacity(0.15))
                                    )
                            }
                            
                            if changelog.is_read == false {
                                Circle()
                                    .fill(themeManager.colors.accent1)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        
                        Text(changelog.formattedDate)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(themeManager.colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.vertical, 12)
                    
                    ForEach(changelog.entries) { item in
                        ChangelogItemRow(item: item)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(themeManager.spacing.md)
        .background(
            RoundedRectangle(cornerRadius: themeManager.radius.md)
                .fill(themeManager.colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: themeManager.radius.md)
                .stroke(isLatest ? themeManager.colors.accent1.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Changelog Item Row

struct ChangelogItemRow: View {
    let item: ChangelogItem
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: item.icon)
                .font(.system(size: 12))
                .foregroundStyle(item.color)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(item.color.opacity(0.15))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // Type label
                Text(item.label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(item.color)
                
                // Description
                Text(item.text)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(themeManager.colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - What's New Sheet (Auto-popup for new versions)

struct WhatsNewSheet: View {
    let changelog: ChangelogEntry
    let onDismiss: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var appear = false
    
    var body: some View {
        ZStack {
            themeManager.colors.background.ignoresSafeArea()
            
            VStack(spacing: themeManager.spacing.xl) {
                // Header
                VStack(spacing: themeManager.spacing.sm) {
                    // Sparkle animation
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(themeManager.colors.accent1)
                        .scaleEffect(appear ? 1 : 0.5)
                        .opacity(appear ? 1 : 0)
                    
                    Text("what's new in v\(changelog.version)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(themeManager.colors.textPrimary)
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 20)
                    
                    Text(changelog.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(themeManager.colors.textSecondary)
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 20)
                }
                .padding(.top, themeManager.spacing.xl)
                
                // Items
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(Array(changelog.entries.enumerated()), id: \.element.id) { index, item in
                            WhatsNewItemRow(item: item)
                                .opacity(appear ? 1 : 0)
                                .offset(y: appear ? 0 : 30)
                                .animation(.spring(response: 0.5).delay(Double(index) * 0.1 + 0.3), value: appear)
                        }
                    }
                    .padding(.horizontal, themeManager.spacing.screenHorizontal)
                }
                
                Spacer()
                
                // Continue button
                Button(action: onDismiss) {
                    Text("let's go")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: themeManager.radius.md)
                                .fill(themeManager.colors.accent1)
                        )
                }
                .padding(.horizontal, themeManager.spacing.screenHorizontal)
                .padding(.bottom, themeManager.spacing.xl)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6)) {
                appear = true
            }
        }
    }
}

struct WhatsNewItemRow: View {
    let item: ChangelogItem
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: item.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(item.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(item.color)
                
                Text(item.text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(themeManager.colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: themeManager.radius.md)
                .fill(themeManager.colors.cardBackground)
        )
    }
}

// MARK: - Preview

#Preview {
    ChangelogView()
}
