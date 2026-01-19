//
//  MainTabView.swift
//  SocialTen
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var conversationManager = ConversationManager.shared
    @State private var selectedTab = 0
    @State private var vibeTabExpandedId: String? = nil
    @State private var showWhatsNew = false
    @State private var latestChangelog: ChangelogEntry? = nil
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("home")
                }
                .tag(0)
            
            VibeTab(initialExpandedVibeId: $vibeTabExpandedId)
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "sparkles" : "sparkles")
                    Text("vibe")
                }
                .tag(1)
                .badge(viewModel.hasUnreadVibes ? "•" : nil)
            
            FeedTab()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "square.stack.fill" : "square.stack")
                    Text("feed")
                }
                .tag(2)
                .badge(unreadBadge)
            
            FriendsView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "person.2.fill" : "person.2")
                    Text("friends")
                }
                .tag(3)
                .badge(viewModel.pendingRequestCount > 0 ? viewModel.pendingRequestCount : 0)
        }
        .tint(themeManager.colors.accent1)
        .onChange(of: selectedTab) { _, newTab in
            handleTabChange(newTab)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToVibeTab"))) { notification in
            if let vibeId = notification.object as? String {
                vibeTabExpandedId = vibeId
            }
            selectedTab = 1
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToFriendsTab"))) { _ in
            selectedTab = 3
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToFeedTab"))) { _ in
            selectedTab = 2
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToConversation"))) { _ in
            // Navigate to Feed tab (which contains messages)
            selectedTab = 2
        }
        .task {
            await checkForUnreadChangelog()
        }
        .fullScreenCover(isPresented: $showWhatsNew) {
            if let changelog = latestChangelog {
                WhatsNewSheet(changelog: changelog) {
                    showWhatsNew = false
                    Task { await markChangelogRead(changelog.version) }
                }
            }
        }
    }
    
    // Check for unread changelog on app launch
    private func checkForUnreadChangelog() async {
        do {
            let response = try await SupabaseManager.shared.client
                .rpc("get_changelogs")
                .execute()
            
            let decoder = JSONDecoder()
            let changelogs = try decoder.decode([ChangelogEntry].self, from: response.data)
            
            // Find the latest unread changelog
            if let unread = changelogs.first(where: { $0.is_read == false }) {
                await MainActor.run {
                    latestChangelog = unread
                    showWhatsNew = true
                }
            }
        } catch {
            print("❌ Error checking changelog: \(error)")
        }
    }
    
    private func markChangelogRead(_ version: String) async {
        do {
            try await SupabaseManager.shared.client
                .rpc("mark_changelog_read", params: ["p_version": version])
                .execute()
        } catch {
            print("❌ Error marking changelog read: \(error)")
        }
    }
    
    // Combined badge for feed tab (posts + messages)
    private var unreadBadge: Text? {
        let hasUnread = viewModel.hasUnreadPosts || conversationManager.totalUnreadCount > 0
        return hasUnread ? Text("•") : nil
    }
    
    func handleTabChange(_ tab: Int) {
        switch tab {
        case 1: // Vibe tab
            viewModel.markVibesAsSeen()
        case 2: // Feed tab
            viewModel.markPostsAsSeen()
        default:
            break
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(SupabaseAppViewModel())
        .environmentObject(AuthViewModel())
}
