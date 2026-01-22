//
//  DailyInsightsSection.swift
//  SocialTen
//
//  Full-width insight cards with smooth animations
//

import SwiftUI

struct DailyInsightsSection: View {
    let insights: [DailyInsight]
    let isPremiumUser: Bool
    var onFriendTap: ((User) -> Void)? = nil
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var currentPage: Int = 0
    @State private var hasAppeared = false
    
    init(insights: [DailyInsight], isPremiumUser: Bool, onFriendTap: ((User) -> Void)? = nil) {
        self.insights = insights
        self.isPremiumUser = isPremiumUser
        self.onFriendTap = onFriendTap
        
        // Clear TabView's UIKit background
        UIPageControl.appearance().currentPageIndicatorTintColor = .clear
        UIPageControl.appearance().pageIndicatorTintColor = .clear
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            // Header with fade-in
            Text("insights")
                .font(themeManager.fonts.caption)
                .foregroundColor(themeManager.colors.textTertiary)
                .tracking(themeManager.letterSpacing.wide)
                .textCase(.uppercase)
                .opacity(hasAppeared ? 1 : 0)
                .offset(x: hasAppeared ? 0 : -20)
                .animation(.easeOut(duration: 0.4), value: hasAppeared)
            
            // Full-width cards with TabView for proper paging
            TabView(selection: $currentPage) {
                ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                    InsightCard(insight: insight, isPremiumUser: isPremiumUser, onFriendTap: onFriendTap)
                        .padding(.horizontal, 2)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 170)
            .background(Color.clear)
            
            // Custom page indicator dots with staggered animation
            if insights.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<insights.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? themeManager.colors.accent1 : themeManager.colors.textTertiary.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .scaleEffect(hasAppeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.6)
                                    .delay(Double(index) * 0.1 + 0.5),
                                value: hasAppeared
                            )
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            withAnimation {
                hasAppeared = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DailyInsightsSection(
        insights: [
            DailyInsight(
                type: .weekTrend,
                emoji: "📈",
                title: "Your vibe is",
                highlightedValue: "+10%",
                subtitle: "higher than last week. Keep it up!",
                accentColor: .white,
                visualData: .comparison(current: 8.3, previous: 7.5, currentLabel: "This week", previousLabel: "Last week")
            ),
            DailyInsight(
                type: .friendsActivity,
                emoji: "👥",
                title: "Friends activity",
                highlightedValue: "2 of 10",
                subtitle: "friends rated today. See how your circle is feeling.",
                accentColor: .white,
                visualData: .grid(filled: 2, total: 10)
            ),
            DailyInsight(
                type: .streak,
                emoji: "🔥",
                title: "You're on a",
                highlightedValue: "16 day",
                subtitle: "14 more days to hit 30!",
                accentColor: .white,
                visualData: .progress(value: 16, max: 30),
                isPremium: true
            )
        ],
        isPremiumUser: false
    )
    .padding()
    .background(Color(hex: "0A0A0A"))
}
