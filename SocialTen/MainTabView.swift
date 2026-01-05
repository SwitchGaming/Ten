//
//  MainTabView.swift
//  SocialTen
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @State private var selectedTab = 0
    @State private var vibeTabExpandedId: String? = nil
    
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
                .badge(viewModel.hasUnreadPosts ? "•" : nil)
            
            FriendsView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "person.2.fill" : "person.2")
                    Text("friends")
                }
                .tag(3)
                .badge(viewModel.pendingRequestCount > 0 ? viewModel.pendingRequestCount : 0)
        }
        .tint(ThemeManager.shared.colors.accent1)
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
