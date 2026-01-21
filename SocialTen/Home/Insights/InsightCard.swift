//
//  InsightCard.swift
//  SocialTen
//
//  Minimal insight cards with AI-powered conversational insights
//

import SwiftUI

// MARK: - Insight Card

struct InsightCard: View {
    let insight: DailyInsight
    let isPremiumUser: Bool
    var isVisible: Bool = true
    var onFriendTap: ((User) -> Void)? = nil
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var hasAnimated = false
    @State private var showCelebration = false
    
    private var isLocked: Bool {
        insight.isPremium && !isPremiumUser
    }
    
    var body: some View {
        ZStack {
            // Main card content using DepthCard
            DepthCard(depth: .medium) {
                cardContent
                    .blur(radius: isLocked ? 8 : 0)
            }
            
            // Celebration overlay
            if showCelebration && insight.celebration != .none {
                celebrationOverlay
            }
            
            // Premium lock overlay
            if isLocked {
                premiumLockOverlay
            }
        }
        .padding(.horizontal, 4)
        .opacity(hasAnimated ? 1 : 0)
        .offset(y: hasAnimated ? 0 : 20)
        .task {
            // Only animate once per card instance
            guard !hasAnimated else { return }
            
            // Small delay then animate in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                hasAnimated = true
            }
            
            // Trigger celebration after card appears
            if insight.celebration != .none {
                try? await Task.sleep(nanoseconds: 700_000_000) // 0.7s
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showCelebration = true
                }
            }
        }
    }
    
    // MARK: - Card Content
    
    @ViewBuilder
    private var cardContent: some View {
        // Check for empty state first
        if insight.isEmptyState {
            emptyStateCard
        } else {
            switch insight.type {
            case .weekTrend:
                weekTrendCard
            case .streak:
                streakCard
            case .friendsActivity:
                friendsActivityCard
            case .aiCoach:
                aiCoachCard
            case .ratingPattern:
                ratingPatternCard
            case .friendshipMomentum:
                friendshipMomentumCard
            default:
                defaultCard
            }
        }
    }
    
    // MARK: - Empty State Card
    
    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // Animated icon based on card type
            emptyStateIcon
                .scaleEffect(hasAnimated ? 1 : 0.5)
                .opacity(hasAnimated ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: hasAnimated)
            
            // Title and value
            VStack(spacing: 4) {
                Text(insight.title)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(themeManager.colors.textSecondary)
                
                Text(insight.highlightedValue)
                    .font(.system(size: 20, weight: .light, design: .rounded))
                    .foregroundColor(themeManager.colors.textPrimary)
            }
            .opacity(hasAnimated ? 1 : 0)
            .offset(y: hasAnimated ? 0 : 10)
            .animation(.easeOut(duration: 0.4).delay(0.3), value: hasAnimated)
            
            Spacer()
            
            // AI insight as call-to-action
            if let aiInsight = insight.aiInsight {
                aiInsightFooter(aiInsight)
                    .padding(.bottom, 16)
            }
        }
        .frame(height: 160)
    }
    
    // Empty state icon based on card type
    @ViewBuilder
    private var emptyStateIcon: some View {
        ZStack {
            // Pulsing background circle
            Circle()
                .fill(insight.accentColor.opacity(0.15))
                .frame(width: 56, height: 56)
            
            // Dashed border
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .foregroundColor(insight.accentColor.opacity(0.4))
                .frame(width: 56, height: 56)
            
            // Icon
            Image(systemName: emptyStateIconName)
                .font(.system(size: 22, weight: .light))
                .foregroundColor(insight.accentColor.opacity(0.8))
        }
    }
    
    private var emptyStateIconName: String {
        switch insight.type {
        case .weekTrend:
            return "chart.line.uptrend.xyaxis"
        case .friendsActivity:
            return "person.2"
        case .ratingPattern:
            return "calendar"
        case .friendshipMomentum:
            return "heart"
        default:
            return "sparkles"
        }
    }
    
    // MARK: - AI Insight Footer
    
    private func aiInsightFooter(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .regular))
            .foregroundColor(themeManager.colors.textSecondary)
            .opacity(hasAnimated ? 1 : 0)
            .offset(y: hasAnimated ? 0 : 5)
            .animation(.easeOut(duration: 0.4).delay(0.5), value: hasAnimated)
    }
    
    // MARK: - Week Trend Card
    
    private var weekTrendCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left - Bar chart
                weeklyBarChart
                    .padding(.leading, 20)
                
                Spacer()
                
                // Right - Key stat
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: insight.highlightedValue.contains("+") ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(insight.highlightedValue.contains("+") ? themeManager.colors.accent1 : themeManager.colors.textTertiary)
                        
                        Text(insight.highlightedValue)
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundColor(themeManager.colors.textPrimary)
                    }
                    
                    Text("vs last week")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(themeManager.colors.textTertiary)
                }
                .padding(.trailing, 20)
            }
            .padding(.top, 20)
            
            Spacer()
            
            // AI insight at bottom
            if let aiInsight = insight.aiInsight {
                aiInsightFooter(aiInsight)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .frame(height: 160)
    }
    
    // Animated weekly bar chart
    private var weeklyBarChart: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if let visualData = insight.visualData,
               case .comparison(let current, let previous, _, _) = visualData {
                let weekValues = generateWeeklyValues(current: current, previous: previous)
                
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(index == 6 ? themeManager.colors.accent1 : themeManager.colors.surfaceLight.opacity(0.5))
                            .frame(width: 12, height: hasAnimated ? CGFloat(weekValues[index] / 10) * 70 + 8 : 8)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.7)
                                    .delay(Double(index) * 0.05 + 0.2),
                                value: hasAnimated
                            )
                        
                        Text(["M", "T", "W", "T", "F", "S", "S"][index])
                            .font(.system(size: 9, weight: .regular))
                            .foregroundColor(index == 6 ? themeManager.colors.textSecondary : themeManager.colors.textTertiary.opacity(0.6))
                    }
                }
            }
        }
    }
    
    private func generateWeeklyValues(current: Double, previous: Double) -> [Double] {
        let diff = current - previous
        return [
            previous - 0.3,
            previous + 0.2,
            previous + diff * 0.3,
            previous + diff * 0.4,
            previous + diff * 0.6,
            previous + diff * 0.8,
            current
        ].map { max(1, min(10, $0)) }
    }
    
    // MARK: - Streak Card (Now replaced by AI Coach)
    
    private var streakCard: some View {
        aiCoachCard // Redirect to AI coach since streak is now there
    }
    
    // MARK: - AI Coach Card
    
    private var aiCoachCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                // Streak ring
                streakRing
                
                // Streak info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(insight.title)
                            .font(.system(size: 36, weight: .light, design: .rounded))
                            .foregroundColor(themeManager.colors.textPrimary)
                            .opacity(hasAnimated ? 1 : 0)
                            .offset(x: hasAnimated ? 0 : -10)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: hasAnimated)
                        
                        if !insight.highlightedValue.isEmpty {
                            Text(insight.highlightedValue)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(themeManager.colors.textTertiary)
                                .opacity(hasAnimated ? 1 : 0)
                                .animation(.easeOut(duration: 0.3).delay(0.4), value: hasAnimated)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Milestone progress (if available)
            if let visualData = insight.visualData,
               case .progress(let value, let max) = visualData {
                milestoneProgress(value: value, max: max)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            
            // AI insight at bottom
            if let aiInsight = insight.aiInsight {
                aiInsightFooter(aiInsight)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .frame(height: 160)
    }
    
    // Animated streak ring
    private var streakRing: some View {
        ZStack {
            Circle()
                .stroke(themeManager.colors.surfaceLight.opacity(0.3), lineWidth: 4)
                .frame(width: 56, height: 56)
            
            if let visualData = insight.visualData,
               case .progress(let value, let max) = visualData {
                Circle()
                    .trim(from: 0, to: hasAnimated ? min(value / max, 1.0) : 0)
                    .stroke(
                        themeManager.colors.accent1,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: hasAnimated)
            }
            
            Image(systemName: "flame")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(themeManager.colors.accent1)
                .scaleEffect(hasAnimated ? 1 : 0.5)
                .opacity(hasAnimated ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.4), value: hasAnimated)
        }
    }
    
    // Milestone progress dots
    private func milestoneProgress(value: Double, max: Double) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 3) {
                ForEach(0..<10, id: \.self) { index in
                    let threshold = max / 10 * Double(index + 1)
                    Circle()
                        .fill(value >= threshold ? themeManager.colors.accent1 : themeManager.colors.surfaceLight.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .scaleEffect(hasAnimated ? 1 : 0)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.6)
                                .delay(Double(index) * 0.04 + 0.5),
                            value: hasAnimated
                        )
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Friends Activity Card
    
    private var friendsActivityCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left - Activity ring
                if let visualData = insight.visualData,
                   case .grid(let filled, let total, let average) = visualData {
                    friendsRingVisualization(filled: filled, total: total, average: average)
                        .padding(.leading, 20)
                }
                
                Spacer()
                
                // Right - Stats
                VStack(alignment: .trailing, spacing: 12) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if let visualData = insight.visualData,
                           case .grid(let filled, let total, _) = visualData {
                            HStack(spacing: 4) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(themeManager.colors.accent1)
                                
                                Text("\(filled)/\(total)")
                                    .font(.system(size: 22, weight: .light, design: .rounded))
                                    .foregroundColor(themeManager.colors.textPrimary)
                            }
                        }
                        
                        Text("rated today")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(themeManager.colors.textTertiary)
                    }
                    .opacity(hasAnimated ? 1 : 0)
                    .offset(x: hasAnimated ? 0 : 10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: hasAnimated)
                    
                    // Average rating
                    if let visualData = insight.visualData,
                       case .grid(_, _, let average) = visualData,
                       let avg = average, avg > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.1f", avg))
                                .font(.system(size: 22, weight: .light, design: .rounded))
                                .foregroundColor(themeManager.colors.textPrimary)
                            
                            Text("avg rating")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(themeManager.colors.textTertiary)
                        }
                        .opacity(hasAnimated ? 1 : 0)
                        .offset(x: hasAnimated ? 0 : 10)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4), value: hasAnimated)
                    }
                }
                .padding(.trailing, 20)
            }
            .padding(.top, 16)
            
            Spacer()
            
            // AI insight at bottom
            if let aiInsight = insight.aiInsight {
                aiInsightFooter(aiInsight)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .frame(height: 160)
    }
    
    // Friends ring visualization
    private func friendsRingVisualization(filled: Int, total: Int, average: Double?) -> some View {
        let displayTotal = min(total, 10)
        let displayFilled = min(filled, displayTotal)
        
        return ZStack {
            ForEach(0..<displayTotal, id: \.self) { index in
                let angle = (Double(index) / Double(displayTotal)) * 360 - 90
                let radius: CGFloat = 36
                
                Circle()
                    .fill(
                        index < displayFilled
                            ? themeManager.colors.accent1
                            : themeManager.colors.surfaceLight.opacity(0.4)
                    )
                    .frame(width: 12, height: 12)
                    .offset(
                        x: cos(angle * .pi / 180) * radius,
                        y: sin(angle * .pi / 180) * radius
                    )
                    .scaleEffect(hasAnimated ? 1 : 0)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.6)
                            .delay(Double(index) * 0.05 + 0.2),
                        value: hasAnimated
                    )
            }
            
            Image(systemName: "heart")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(themeManager.colors.textTertiary)
                .opacity(hasAnimated ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.6), value: hasAnimated)
        }
        .frame(width: 100, height: 100)
    }
    
    // MARK: - Rating Pattern Card
    
    @ViewBuilder
    private var ratingPatternCard: some View {
        // Check if this is an unlock placeholder
        if let visualData = insight.visualData,
           case .unlock(let progress, let goal) = visualData {
            unlockPlaceholderCard(progress: progress, goal: goal)
        } else {
            ratingPatternHeatmapCard
        }
    }
    
    // Unlock placeholder for when user doesn't have enough data
    private func unlockPlaceholderCard(progress: Int, goal: Int) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Centered content
            VStack(spacing: 16) {
                // Crystal ball emoji with glow
                ZStack {
                    Circle()
                        .fill(themeManager.colors.accent1.opacity(0.15))
                        .frame(width: 56, height: 56)
                        .blur(radius: 8)
                    
                    Text("🔮")
                        .font(.system(size: 32))
                }
                .scaleEffect(hasAnimated ? 1 : 0.5)
                .opacity(hasAnimated ? 1 : 0)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: hasAnimated)
                
                // Progress dots
                HStack(spacing: 6) {
                    ForEach(0..<goal, id: \.self) { index in
                        Circle()
                            .fill(index < progress ? themeManager.colors.accent1 : themeManager.colors.surfaceLight.opacity(0.5))
                            .frame(width: 8, height: 8)
                            .scaleEffect(hasAnimated ? 1 : 0)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.6)
                                    .delay(Double(index) * 0.03 + 0.3),
                                value: hasAnimated
                            )
                    }
                }
            }
            
            Spacer()
            
            // AI insight footer
            if let aiInsight = insight.aiInsight {
                aiInsightFooter(aiInsight)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .frame(height: 160)
    }
    
    // The actual heatmap card when data is available
    private var ratingPatternHeatmapCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left - Weekday heatmap grid
                weekdayHeatmapGrid
                    .padding(.leading, 20)
                
                Spacer()
                
                // Right - Best day highlight
                VStack(alignment: .trailing, spacing: 8) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("best day")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(themeManager.colors.textTertiary)
                        
                        Text(insight.highlightedValue)
                            .font(.system(size: 26, weight: .light, design: .rounded))
                            .foregroundColor(themeManager.colors.textPrimary)
                    }
                    .opacity(hasAnimated ? 1 : 0)
                    .offset(x: hasAnimated ? 0 : 10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: hasAnimated)
                    
                    Image(systemName: "calendar")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(themeManager.colors.accent1)
                        .opacity(hasAnimated ? 1 : 0)
                        .animation(.easeOut(duration: 0.3).delay(0.4), value: hasAnimated)
                }
                .padding(.trailing, 20)
            }
            .padding(.top, 20)
            
            Spacer()
            
            // AI insight footer
            if let aiInsight = insight.aiInsight {
                aiInsightFooter(aiInsight)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .frame(height: 160)
    }
    
    // Weekday heatmap grid - 7 squares in a row with varying opacity
    private var weekdayHeatmapGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Week grid
            HStack(spacing: 6) {
                if let visualData = insight.visualData,
                   case .weekdayHeatmap(let data) = visualData {
                    // Days: Sun(1), Mon(2), Tue(3), Wed(4), Thu(5), Fri(6), Sat(7)
                    let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]
                    let minRating = data.values.min() ?? 1
                    let maxRating = data.values.max() ?? 10
                    let range = max(maxRating - minRating, 1)
                    
                    ForEach(1...7, id: \.self) { day in
                        let avg = data[day]
                        let opacity = avg != nil ? (avg! - minRating) / range * 0.7 + 0.3 : 0.15
                        let isHighest = avg == maxRating && avg != nil
                        
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(themeManager.colors.accent1.opacity(opacity))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(isHighest ? themeManager.colors.accent1 : Color.clear, lineWidth: 1.5)
                                )
                                .scaleEffect(hasAnimated ? 1 : 0)
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.6)
                                        .delay(Double(day) * 0.05 + 0.2),
                                    value: hasAnimated
                                )
                            
                            Text(dayLabels[day - 1])
                                .font(.system(size: 9, weight: .regular))
                                .foregroundColor(isHighest ? themeManager.colors.accent1 : themeManager.colors.textTertiary)
                                .opacity(hasAnimated ? 1 : 0)
                                .animation(.easeOut(duration: 0.3).delay(0.5), value: hasAnimated)
                        }
                    }
                } else {
                    // Placeholder when no data
                    ForEach(0..<7, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(themeManager.colors.surfaceLight.opacity(0.3))
                            .frame(width: 28, height: 28)
                            .scaleEffect(hasAnimated ? 1 : 0)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.6)
                                    .delay(Double(index) * 0.05 + 0.2),
                                value: hasAnimated
                            )
                    }
                }
            }
        }
    }
    
    // MARK: - Friendship Momentum Card
    
    private var friendshipMomentumCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left - Friend's profile bubble (tappable)
                if let friend = insight.friendUser {
                    Button {
                        onFriendTap?(friend)
                    } label: {
                        friendProfileBubble(friend: friend)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 20)
                } else {
                    // Fallback placeholder
                    placeholderBubble
                        .padding(.leading, 20)
                }
                
                Spacer()
                
                // Right - Friend info
                VStack(alignment: .trailing, spacing: 8) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(insight.friendName ?? "Friend")
                            .font(.system(size: 18, weight: .light, design: .rounded))
                            .foregroundColor(themeManager.colors.textPrimary)
                            .lineLimit(1)
                        
                        Text(insight.highlightedValue)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(themeManager.colors.accent1)
                    }
                    .opacity(hasAnimated ? 1 : 0)
                    .offset(x: hasAnimated ? 0 : 10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: hasAnimated)
                    
                    // Level badge
                    if let visualData = insight.visualData,
                       case .momentum(_, let current, _) = visualData {
                        Text("\(current) pts")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(themeManager.colors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(themeManager.colors.surfaceLight.opacity(0.5))
                            .clipShape(Capsule())
                            .opacity(hasAnimated ? 1 : 0)
                            .animation(.easeOut(duration: 0.3).delay(0.4), value: hasAnimated)
                    }
                }
                .padding(.trailing, 20)
            }
            .padding(.top, 16)
            
            Spacer()
            
            // AI insight footer
            if let aiInsight = insight.aiInsight {
                aiInsightFooter(aiInsight)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .frame(height: 160)
    }
    
    // Friend profile bubble with their theme glow
    @State private var glowAnimation = false
    
    private func friendProfileBubble(friend: User) -> some View {
        let bubbleColor = friend.isPremium ? friend.selectedTheme.glowColor : themeManager.colors.accent2
        let bubbleBackground = friend.isPremium ? friend.selectedTheme.colors.cardBackground : themeManager.colors.cardBackground
        
        return ZStack {
            // Premium glow ring (only for premium friends)
            if friend.isPremium {
                Circle()
                    .fill(bubbleColor)
                    .frame(width: 74, height: 74)
                    .blur(radius: glowAnimation ? 12 : 8)
                    .opacity(glowAnimation ? 0.5 : 0.3)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                            glowAnimation = true
                        }
                    }
                
                Circle()
                    .stroke(bubbleColor.opacity(0.6), lineWidth: 2)
                    .frame(width: 70, height: 70)
            }
            
            // Main bubble
            Circle()
                .fill(bubbleBackground)
                .frame(width: 64, height: 64)
            
            // Rating or initial
            if let rating = friend.todayRating {
                Text("\(rating)")
                    .font(.system(size: 24, weight: .light, design: .rounded))
                    .foregroundColor(bubbleColor)
            } else {
                Text(String(friend.displayName.prefix(1)).lowercased())
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(bubbleColor.opacity(0.7))
            }
        }
        .scaleEffect(hasAnimated ? 1 : 0.5)
        .opacity(hasAnimated ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: hasAnimated)
    }
    
    // Placeholder when no friend data
    private var placeholderBubble: some View {
        ZStack {
            Circle()
                .fill(themeManager.colors.surfaceLight.opacity(0.3))
                .frame(width: 64, height: 64)
            
            Image(systemName: "person.fill")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(themeManager.colors.textTertiary)
        }
        .scaleEffect(hasAnimated ? 1 : 0.5)
        .opacity(hasAnimated ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: hasAnimated)
    }
    
    // MARK: - Default Card
    
    private var defaultCard: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "chart.bar")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(themeManager.colors.textTertiary)
            
            Text(insight.highlightedValue)
                .font(.system(size: 24, weight: .light, design: .rounded))
                .foregroundColor(themeManager.colors.textPrimary)
            
            if let aiInsight = insight.aiInsight {
                aiInsightFooter(aiInsight)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(height: 160)
    }
    
    // MARK: - Celebration Overlay
    
    private var celebrationOverlay: some View {
        ZStack {
            switch insight.celebration {
            case .confetti:
                ConfettiView()
            case .sparkle:
                SparkleView()
            case .heart:
                // Use friend's theme color if available, otherwise default pink
                let heartColor = insight.friendUser?.isPremium == true 
                    ? insight.friendUser!.selectedTheme.glowColor 
                    : Color(hex: "EC4899")
                BigHeartView(color: heartColor)
            case .none:
                EmptyView()
            }
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Premium Lock Overlay
    
    private var premiumLockOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: themeManager.radius.lg)
                .fill(themeManager.colors.cardBackground.opacity(0.9))
            
            VStack(spacing: 8) {
                Image(systemName: "lock")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(themeManager.colors.textTertiary)
                
                Text("ten+")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(themeManager.colors.textSecondary)
            }
        }
    }
}

// MARK: - Celebration Views

struct ConfettiView: View {
    @State private var particles: [(id: Int, x: CGFloat, y: CGFloat, rotation: Double, scale: CGFloat, opacity: Double)] = []
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles, id: \.id) { particle in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hue: Double.random(in: 0...1), saturation: 0.7, brightness: 0.9))
                        .frame(width: 6, height: 10)
                        .rotationEffect(.degrees(particle.rotation))
                        .scaleEffect(particle.scale)
                        .opacity(particle.opacity)
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                // Generate particles
                for i in 0..<20 {
                    let startX = geo.size.width / 2
                    let startY = geo.size.height / 2
                    particles.append((
                        id: i,
                        x: startX,
                        y: startY,
                        rotation: Double.random(in: 0...360),
                        scale: CGFloat.random(in: 0.5...1.2),
                        opacity: 1.0
                    ))
                }
                
                // Animate particles
                withAnimation(.easeOut(duration: 1.5)) {
                    for i in particles.indices {
                        particles[i].x += CGFloat.random(in: -100...100)
                        particles[i].y += CGFloat.random(in: -80...80)
                        particles[i].rotation += Double.random(in: 180...540)
                        particles[i].opacity = 0
                    }
                }
            }
        }
    }
}

struct SparkleView: View {
    @State private var sparkles: [(id: Int, x: CGFloat, y: CGFloat, scale: CGFloat, opacity: Double)] = []
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(sparkles, id: \.id) { sparkle in
                    Image(systemName: "sparkle")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.white)
                        .scaleEffect(sparkle.scale)
                        .opacity(sparkle.opacity)
                        .position(x: sparkle.x, y: sparkle.y)
                }
            }
            .onAppear {
                // Generate sparkles
                for i in 0..<8 {
                    sparkles.append((
                        id: i,
                        x: CGFloat.random(in: 20...(geo.size.width - 20)),
                        y: CGFloat.random(in: 20...(geo.size.height - 20)),
                        scale: 0,
                        opacity: 0
                    ))
                }
                
                // Animate sparkles with stagger
                for i in sparkles.indices {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(i) * 0.1)) {
                        sparkles[i].scale = CGFloat.random(in: 0.8...1.5)
                        sparkles[i].opacity = 1
                    }
                    
                    withAnimation(.easeOut(duration: 0.3).delay(Double(i) * 0.1 + 0.5)) {
                        sparkles[i].opacity = 0
                    }
                }
            }
        }
    }
}

struct HeartBurstView: View {
    @State private var hearts: [(id: Int, x: CGFloat, y: CGFloat, scale: CGFloat, opacity: Double)] = []
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(hearts, id: \.id) { heart in
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "EC4899").opacity(0.8))
                        .scaleEffect(heart.scale)
                        .opacity(heart.opacity)
                        .position(x: heart.x, y: heart.y)
                }
            }
            .onAppear {
                let centerX = geo.size.width / 2
                let centerY = geo.size.height / 2
                
                for i in 0..<6 {
                    let angle = (Double(i) / 6.0) * 360
                    hearts.append((
                        id: i,
                        x: centerX,
                        y: centerY,
                        scale: 0,
                        opacity: 0
                    ))
                }
                
                for i in hearts.indices {
                    let angle = (Double(i) / 6.0) * 2 * .pi
                    let radius: CGFloat = 40
                    
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(Double(i) * 0.05)) {
                        hearts[i].x = geo.size.width / 2 + cos(angle) * radius
                        hearts[i].y = geo.size.height / 2 + sin(angle) * radius
                        hearts[i].scale = 1
                        hearts[i].opacity = 1
                    }
                    
                    withAnimation(.easeOut(duration: 0.4).delay(Double(i) * 0.05 + 0.6)) {
                        hearts[i].opacity = 0
                        hearts[i].scale = 0.5
                    }
                }
            }
        }
    }
}

// Big heart animation like Instagram double-tap
struct BigHeartView: View {
    let color: Color
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var glowScale: CGFloat = 0.8
    
    var body: some View {
        ZStack {
            // Soft glow layer
            Image(systemName: "heart.fill")
                .font(.system(size: 50, weight: .regular))
                .foregroundColor(color)
                .blur(radius: 20)
                .scaleEffect(glowScale)
                .opacity(glowOpacity * 0.6)
            
            // Main heart
            Image(systemName: "heart.fill")
                .font(.system(size: 44, weight: .regular))
                .foregroundColor(color)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            // Gentle fade and scale in
            withAnimation(.easeOut(duration: 0.5)) {
                scale = 1.0
                opacity = 1
                glowScale = 1.3
                glowOpacity = 1
            }
            
            // Subtle pulse
            withAnimation(.easeInOut(duration: 0.3).delay(0.5)) {
                scale = 0.95
                glowScale = 1.2
            }
            
            withAnimation(.easeInOut(duration: 0.3).delay(0.8)) {
                scale = 1.0
                glowScale = 1.3
            }
            
            // Graceful fade out
            withAnimation(.easeIn(duration: 0.6).delay(1.4)) {
                opacity = 0
                glowOpacity = 0
                scale = 1.1
                glowScale = 1.5
            }
        }
    }
}

// MARK: - Preview

#Preview("Week Trend") {
    InsightCard(
        insight: DailyInsight(
            type: .weekTrend,
            emoji: "",
            title: "Your vibe is",
            highlightedValue: "+10%",
            subtitle: "",
            accentColor: .white,
            visualData: .comparison(current: 8.3, previous: 7.5, currentLabel: "This week", previousLabel: "Last week"),
            aiInsight: "You're up 10% from last week",
            celebration: .confetti
        ),
        isPremiumUser: true
    )
    .padding()
    .background(Color(hex: "0A0A0A"))
}

#Preview("AI Coach") {
    InsightCard(
        insight: DailyInsight(
            type: .aiCoach,
            emoji: "",
            title: "16",
            highlightedValue: "day streak",
            subtitle: "",
            accentColor: .white,
            visualData: .progress(value: 16, max: 30),
            aiInsight: "14 days until your first month!",
            celebration: .sparkle
        ),
        isPremiumUser: true
    )
    .padding()
    .background(Color(hex: "0A0A0A"))
}

#Preview("Friends") {
    InsightCard(
        insight: DailyInsight(
            type: .friendsActivity,
            emoji: "",
            title: "Friends",
            highlightedValue: "2/10",
            subtitle: "",
            accentColor: .white,
            visualData: .grid(filled: 3, total: 8, average: 7.2),
            aiInsight: "Jack is having a great day"
        ),
        isPremiumUser: true
    )
    .padding()
    .background(Color(hex: "0A0A0A"))
}

#Preview("Rating Pattern") {
    InsightCard(
        insight: DailyInsight(
            type: .ratingPattern,
            emoji: "",
            title: "Best day",
            highlightedValue: "Sat",
            subtitle: "",
            accentColor: Color(hex: "8B5CF6"),
            visualData: .weekdayHeatmap(data: [
                1: 6.5,  // Sun
                2: 5.8,  // Mon
                3: 6.2,  // Tue
                4: 7.0,  // Wed
                5: 6.8,  // Thu
                6: 7.5,  // Fri
                7: 8.2   // Sat
            ]),
            isPremium: true,
            aiInsight: "Saturdays are your best days",
            celebration: .sparkle
        ),
        isPremiumUser: true
    )
    .padding()
    .background(Color(hex: "0A0A0A"))
}

#Preview("Friendship Momentum") {
    InsightCard(
        insight: DailyInsight(
            type: .friendshipMomentum,
            emoji: "",
            title: "Sarah",
            highlightedValue: "close friend",
            subtitle: "",
            accentColor: Color(hex: "EC4899"),
            visualData: .momentum(previousScore: 60, currentScore: 85, level: "close friend"),
            isPremium: true,
            aiInsight: "65 more interactions to best friend status with Sarah",
            celebration: .none,
            friendName: "Sarah",
            friendUser: User(
                id: "preview",
                username: "sarah",
                displayName: "Sarah",
                bio: "",
                todayRating: 8,
                premiumExpiresAt: Date().addingTimeInterval(86400 * 30)
            )
        ),
        isPremiumUser: true,
        onFriendTap: { friend in
            print("Tapped on \(friend.displayName)")
        }
    )
    .padding()
    .background(Color(hex: "0A0A0A"))
}

#Preview("Empty State - Trends") {
    InsightCard(
        insight: DailyInsight(
            type: .weekTrend,
            emoji: "",
            title: "Rate daily to unlock",
            highlightedValue: "trends",
            subtitle: "",
            accentColor: Color(hex: "8B5CF6"),
            aiInsight: "2 more ratings to see your first trend",
            isEmptyState: true
        ),
        isPremiumUser: true
    )
    .padding()
    .background(Color(hex: "0A0A0A"))
}

#Preview("Empty State - Friends") {
    InsightCard(
        insight: DailyInsight(
            type: .friendsActivity,
            emoji: "",
            title: "Add friends to see",
            highlightedValue: "their vibes",
            subtitle: "",
            accentColor: Color(hex: "EC4899"),
            visualData: .grid(filled: 0, total: 0, average: nil),
            aiInsight: "Your circle is waiting to be built",
            isEmptyState: true
        ),
        isPremiumUser: true
    )
    .padding()
    .background(Color(hex: "0A0A0A"))
}
