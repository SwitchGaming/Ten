//
//  DeveloperFeedbackView.swift
//  SocialTen
//
//  Developer dashboard for managing user feedback
//

import SwiftUI

// MARK: - Feedback Item Model

struct FeedbackItem: Codable, Identifiable {
    let id: UUID
    let user_id: UUID?
    let username: String?
    let email: String?
    let message: String
    let tag: String
    let is_anonymous: Bool
    let status: String
    let created_at: Date
    
    var tagType: FeedbackTag? {
        FeedbackTag(rawValue: tag)
    }
    
    var isAnonymous: Bool { is_anonymous }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: created_at, relativeTo: Date())
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: created_at)
    }
}

// MARK: - Filter Options

enum FeedbackFilter: String, CaseIterable {
    case all = "all"
    case bug = "bug"
    case enhancement = "enhancement"
    case general = "general"
    case completed = "completed"
    
    var icon: String {
        switch self {
        case .all: return "tray.full.fill"
        case .bug: return "ladybug.fill"
        case .enhancement: return "lightbulb.fill"
        case .general: return "bubble.left.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return Color(hex: "8B5CF6") // Purple for "All"
        case .bug: return Color(hex: "F87171")
        case .enhancement: return Color(hex: "FBBF24")
        case .general: return Color(hex: "60A5FA")
        case .completed: return Color(hex: "4ADE80")
        }
    }
}

// MARK: - Developer Feedback View

struct DeveloperFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var feedbackItems: [FeedbackItem] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedFilter: FeedbackFilter = .all
    @State private var expandedItemId: UUID?
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: FeedbackItem?
    
    var body: some View {
        ZStack {
            themeManager.colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                if isLoading {
                    loadingView
                } else if let error = error {
                    errorView(error)
                } else if feedbackItems.isEmpty {
                    emptyView
                } else {
                    feedbackList
                }
            }
        }
        .task {
            await loadFeedback()
        }
        .alert("Delete Feedback", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    Task { await deleteFeedback(item) }
                }
            }
        } message: {
            Text("This feedback will be permanently hidden.")
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: themeManager.spacing.md) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(themeManager.colors.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(themeManager.colors.cardBackground)
                        )
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("user feedback")
                        .font(themeManager.fonts.headline)
                        .foregroundColor(themeManager.colors.textPrimary)
                    
                    Text("\(feedbackItems.count) items")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    Task { await loadFeedback() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.colors.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(themeManager.colors.cardBackground)
                        )
                }
            }
            .padding(.horizontal, themeManager.spacing.screenHorizontal)
            .padding(.top, themeManager.spacing.md)
            
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FeedbackFilter.allCases, id: \.self) { filter in
                        FilterChip(
                            filter: filter,
                            isSelected: selectedFilter == filter,
                            count: countForFilter(filter)
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedFilter = filter
                            }
                            Task { await loadFeedback() }
                        }
                    }
                }
                .padding(.horizontal, themeManager.spacing.screenHorizontal)
            }
            .padding(.bottom, themeManager.spacing.sm)
        }
    }
    
    // MARK: - Feedback List
    
    private var feedbackList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: themeManager.spacing.md) {
                ForEach(feedbackItems) { item in
                    FeedbackCard(
                        item: item,
                        isExpanded: expandedItemId == item.id,
                        isCompleted: selectedFilter == .completed,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                if expandedItemId == item.id {
                                    expandedItemId = nil
                                } else {
                                    expandedItemId = item.id
                                }
                            }
                        },
                        onComplete: {
                            Task { await markComplete(item) }
                        },
                        onDelete: {
                            itemToDelete = item
                            showDeleteConfirmation = true
                        }
                    )
                }
            }
            .padding(.horizontal, themeManager.spacing.screenHorizontal)
            .padding(.top, themeManager.spacing.sm)
            .padding(.bottom, 100)
        }
        .refreshable {
            await loadFeedback()
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: themeManager.colors.accent1))
            Text("loading feedback...")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Spacer()
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry") {
                Task { await loadFeedback() }
            }
            .buttonStyle(.bordered)
            .padding(.top)
            Spacer()
        }
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: themeManager.spacing.lg) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(themeManager.colors.cardBackground)
                    .frame(width: 100, height: 100)
                
                Image(systemName: selectedFilter == .completed ? "checkmark.circle" : "tray")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 8) {
                Text(selectedFilter == .completed ? "no completed feedback" : "no feedback yet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(themeManager.colors.textPrimary)
                
                Text(selectedFilter == .completed ? "completed items will appear here" : "user feedback will appear here")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Helpers
    
    private func countForFilter(_ filter: FeedbackFilter) -> Int? {
        // Return nil for now - could be implemented with separate count queries
        nil
    }
    
    // MARK: - Data Loading
    
    private func loadFeedback() async {
        isLoading = feedbackItems.isEmpty
        error = nil
        
        let tagParam: String? = {
            switch selectedFilter {
            case .all, .completed: return nil
            case .bug: return "bug"
            case .enhancement: return "enhancement"
            case .general: return "general"
            }
        }()
        
        let statusParam = selectedFilter == .completed ? "completed" : "pending"
        
        do {
            var params: [String: String] = ["p_status": statusParam]
            if let tag = tagParam {
                params["p_tag"] = tag
            }
            
            print("📋 Loading feedback with params: \(params)")
            
            let result: [FeedbackItem] = try await SupabaseManager.shared.client
                .rpc("get_all_feedback", params: params)
                .execute()
                .value
            
            print("📋 Loaded \(result.count) feedback items")
            
            await MainActor.run {
                self.feedbackItems = result
                self.isLoading = false
            }
        } catch {
            print("❌ Error loading feedback: \(error)")
            await MainActor.run {
                self.error = "Failed to load feedback: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func markComplete(_ item: FeedbackItem) async {
        print("🔄 Marking complete: \(item.id)")
        do {
            let response = try await SupabaseManager.shared.client
                .rpc("update_feedback_status", params: [
                    "p_feedback_id": item.id.uuidString,
                    "p_status": "completed"
                ])
                .execute()
            
            print("✅ Mark complete response: \(String(data: response.data, encoding: .utf8) ?? "no data")")
            
            await MainActor.run {
                withAnimation {
                    feedbackItems.removeAll { $0.id == item.id }
                }
            }
        } catch {
            print("❌ Error updating feedback: \(error)")
        }
    }
    
    private func deleteFeedback(_ item: FeedbackItem) async {
        print("🗑️ Deleting feedback: \(item.id)")
        do {
            let response = try await SupabaseManager.shared.client
                .rpc("update_feedback_status", params: [
                    "p_feedback_id": item.id.uuidString,
                    "p_status": "deleted"
                ])
                .execute()
            
            print("✅ Delete response: \(String(data: response.data, encoding: .utf8) ?? "no data")")
            
            await MainActor.run {
                withAnimation {
                    feedbackItems.removeAll { $0.id == item.id }
                }
            }
        } catch {
            print("❌ Error deleting feedback: \(error)")
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let filter: FeedbackFilter
    let isSelected: Bool
    let count: Int?
    let action: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 11))
                
                Text(filter.rawValue)
                    .font(.system(size: 12, weight: .medium))
                
                if let count = count {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? .white.opacity(0.2) : filter.color.opacity(0.2))
                        )
                }
            }
            .foregroundStyle(isSelected ? .white : themeManager.colors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? filter.color : themeManager.colors.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feedback Card

struct FeedbackCard: View {
    let item: FeedbackItem
    let isExpanded: Bool
    let isCompleted: Bool
    let onTap: () -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 12) {
                    // Tag indicator
                    Circle()
                        .fill(item.tagType?.color ?? .gray)
                        .frame(width: 10, height: 10)
                        .padding(.top, 5)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // Tag and time
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: item.tagType?.icon ?? "bubble.left")
                                    .font(.system(size: 10))
                                Text(item.tag)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(item.tagType?.color ?? .gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill((item.tagType?.color ?? .gray).opacity(0.15))
                            )
                            
                            if item.isAnonymous {
                                HStack(spacing: 3) {
                                    Image(systemName: "eye.slash")
                                        .font(.system(size: 9))
                                    Text("anon")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(item.timeAgo)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        
                        // Message preview
                        Text(item.message)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(themeManager.colors.textPrimary)
                            .lineLimit(isExpanded ? nil : 2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .padding(.top, 4)
                }
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.vertical, 8)
                    
                    // User info (if not anonymous)
                    if !item.isAnonymous, let username = item.username {
                        HStack(spacing: 8) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("@\(username)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(themeManager.colors.textPrimary)
                                
                                if let email = item.email {
                                    Text(email)
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    
                    // Timestamp
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(item.formattedDate)
                            .font(.system(size: 12, weight: .regular))
                    }
                    .foregroundStyle(.secondary)
                    
                    // Actions
                    HStack(spacing: 12) {
                        if !isCompleted {
                            Button(action: onComplete) {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 12))
                                    Text("mark complete")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(Color(hex: "4ADE80"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: "4ADE80").opacity(0.15))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button(action: onDelete) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                Text("delete")
                                    .font(.system(size: 13, weight: .medium))
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
                .padding(.leading, 22)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(themeManager.spacing.md)
        .background(
            RoundedRectangle(cornerRadius: themeManager.radius.md)
                .fill(themeManager.colors.cardBackground)
        )
    }
}

// MARK: - Preview

#Preview {
    DeveloperFeedbackView()
}
