//
//  RatingHeatmapView.swift
//  SocialTen
//

import SwiftUI

// MARK: - Rating Heatmap View

/// heatmap showing the past 10 days of ratings
/// squares color reflects time-weighted average rating for that day
struct RatingHeatmapView: View {
    let ratingHistory: [RatingEntry]
    let isLoading: Bool
    
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var selectedDay: DayRatingData?
    
    private let daysToShow = 10
    private var dailyData: [DayRatingData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var result: [DayRatingData] = []
        
        // past 10 days from oldest to newest
        for dayOffset in stride(from: -(daysToShow - 1), through: 0, by: 1) {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else {
                continue
            }
            
            let dayStart = calendar.startOfDay(for: dayDate)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                continue
            }
            
            let isToday = calendar.isDateInToday(dayDate)
            
            // filter ratings for a day
            let dayRatings = ratingHistory.filter { entry in
                entry.date >= dayStart && entry.date < dayEnd
            }.sorted { $0.date < $1.date }
            
            if dayRatings.isEmpty {
                result.append(DayRatingData(date: dayDate, weightedAverage: nil, ratings: []))
            } else {
                // use the most recent rating for today, for past days weighted average
                let displayValue: Double
                if isToday, let lastRating = dayRatings.last {
                    displayValue = Double(lastRating.rating)
                } else {
                    displayValue = calculateWeightedAverage(ratings: dayRatings, dayEnd: dayEnd)
                }
                result.append(DayRatingData(date: dayDate, weightedAverage: displayValue, ratings: dayRatings))
            }
        }
        
        return result
    }
    
    // calculate the time-weighted average for ratings
    // weight is based on hours from rating time until midnight
    private func calculateWeightedAverage(ratings: [RatingEntry], dayEnd: Date) -> Double {
        guard !ratings.isEmpty else { return 0 }
        
        var totalWeightedValue: Double = 0
        var totalWeight: Double = 0
        
        for (index, rating) in ratings.enumerated() {
            // Calculate hours until next rating or midnight
            let nextTime: Date
            if index < ratings.count - 1 {
                nextTime = ratings[index + 1].date
            } else {
                nextTime = dayEnd
            }
            
            let hoursWeight = nextTime.timeIntervalSince(rating.date) / 3600.0
            // enforce 1hr min weighting
            let weight = max(hoursWeight, 1.0)
            
            totalWeightedValue += Double(rating.rating) * weight
            totalWeight += weight
        }
        
        return totalWeight > 0 ? totalWeightedValue / totalWeight : 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Section title
            Text("mood history")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundColor(themeManager.colors.textTertiary)
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: themeManager.colors.textTertiary))
                        .scaleEffect(0.8)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                // Heatmap grid - 2 rows of 5, full width
                VStack(spacing: 12) {
                    // First row: days 1-5 (oldest)
                    HStack(spacing: 0) {
                        ForEach(0..<5, id: \.self) { index in
                            if index < dailyData.count {
                                HeatmapSquare(
                                    data: dailyData[index],
                                    isSelected: selectedDay?.id == dailyData[index].id,
                                    onTap: { tappedData in
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if selectedDay?.id == tappedData.id {
                                                selectedDay = nil
                                            } else {
                                                selectedDay = tappedData
                                            }
                                        }
                                    }
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    
                    // Second row: days 6-10 (most recent)
                    HStack(spacing: 0) {
                        ForEach(5..<10, id: \.self) { index in
                            if index < dailyData.count {
                                HeatmapSquare(
                                    data: dailyData[index],
                                    isSelected: selectedDay?.id == dailyData[index].id,
                                    onTap: { tappedData in
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if selectedDay?.id == tappedData.id {
                                                selectedDay = nil
                                            } else {
                                                selectedDay = tappedData
                                            }
                                        }
                                    }
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    
                    // Rating details popup
                    if let selected = selectedDay {
                        RatingDetailView(data: selected)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(themeManager.colors.cardBackground.opacity(0.5))
                )
            }
        }
    }
}

// MARK: - Heatmap Square

struct HeatmapSquare: View {
    let data: DayRatingData
    let isSelected: Bool
    let onTap: (DayRatingData) -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: data.date).lowercased()
    }
    
    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: data.date)
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(data.date)
    }
    
    var body: some View {
        Button(action: { onTap(data) }) {
            VStack(spacing: 4) {
                // Day abbreviation
                Text(dayLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(themeManager.colors.textTertiary)
                
                // Square
                RoundedRectangle(cornerRadius: 8)
                    .fill(squareColor)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 52, maxHeight: 52)
                    .overlay(
                        Group {
                            if let avg = data.weightedAverage {
                                Text(String(format: "%.0f", avg))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(textColor(for: avg))
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: isSelected ? 2 : (isToday ? 1.5 : 0))
                    )
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                
                // Date number
                Text(dateLabel)
                    .font(.system(size: 9, weight: .light))
                    .foregroundColor(isToday ? themeManager.colors.textPrimary : themeManager.colors.textTertiary.opacity(0.7))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var squareColor: Color {
        guard let avg = data.weightedAverage else {
            return Color.gray.opacity(0.15)
        }
        return heatmapColor(for: avg)
    }
    
    private var borderColor: Color {
        if isSelected {
            return themeManager.colors.accent1
        } else if isToday {
            return themeManager.colors.accent1.opacity(0.5)
        }
        return Color.clear
    }
    
    private func textColor(for rating: Double) -> Color {
        if rating >= 7 {
            return Color.black.opacity(0.8)
        } else {
            return Color.white.opacity(0.9)
        }
    }
}

// MARK: - Rating Detail View

struct RatingDetailView: View {
    let data: DayRatingData
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    private var dateHeader: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(data.date) {
            return "today"
        } else if Calendar.current.isDateInYesterday(data.date) {
            return "yesterday"
        } else {
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: data.date).lowercased()
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Date header
            Text(dateHeader)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundColor(themeManager.colors.textSecondary)
            
            if data.ratings.isEmpty {
                Text("no ratings")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(themeManager.colors.textTertiary)
            } else {
                // Show each rating with time
                VStack(spacing: 4) {
                    ForEach(data.ratings, id: \.id) { rating in
                        HStack(spacing: 8) {
                            Text(roundedTimeString(for: rating.date))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(themeManager.colors.textTertiary)
                            
                            Text("→")
                                .font(.system(size: 10))
                                .foregroundColor(themeManager.colors.textTertiary.opacity(0.5))
                            
                            Text("\(rating.rating)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(heatmapColor(for: Double(rating.rating)))
                            
                            Text(ratingEmoji(for: rating.rating))
                                .font(.system(size: 12))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeManager.colors.accent1.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.top, 8)
    }
    
    /// round time before displaying rating
    private func roundedTimeString(for date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        let roundedMinute: Int
        if minute < 15 {
            roundedMinute = 0
        } else if minute < 45 {
            roundedMinute = 30
        } else {
            roundedMinute = 0
        }
        
        // Handle hour rollover when rounding up to next hour
        let roundedHour = minute >= 45 ? (hour + 1) % 24 : hour
        
        // Format as 12-hour time
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = roundedHour
        components.minute = roundedMinute
        
        if let roundedDate = calendar.date(from: components) {
            return formatter.string(from: roundedDate).lowercased()
        }
        return formatter.string(from: date).lowercased()
    }
    
    private func ratingEmoji(for rating: Int) -> String {
        switch rating {
        case 1: return "😢"
        case 2: return "😞"
        case 3: return "😔"
        case 4: return "😐"
        case 5: return "🙂"
        case 6: return "😊"
        case 7: return "😄"
        case 8: return "😁"
        case 9: return "🤩"
        case 10: return "🥳"
        default: return "🙂"
        }
    }
}

// MARK: - Data Model

struct DayRatingData: Identifiable {
    let id = UUID()
    let date: Date
    let weightedAverage: Double?
    let ratings: [RatingEntry]
}

// MARK: - Color Helper

/// Maps a rating (1-10) to a color on a gradient from red to green
func heatmapColor(for rating: Double) -> Color {
    let clampedRating = max(1.0, min(10.0, rating))
    let normalized = (clampedRating - 1.0) / 9.0 // 0.0 to 1.0
    
    // Color gradient: red (low) -> orange -> yellow -> light green -> green (high)
    if normalized < 0.25 {
        // Red to Orange (ratings 1-3)
        let t = normalized / 0.25
        return Color(
            red: 0.9,
            green: 0.3 + (0.35 * t),
            blue: 0.3 - (0.1 * t)
        )
    } else if normalized < 0.5 {
        // Orange to Yellow (ratings 3-5)
        let t = (normalized - 0.25) / 0.25
        return Color(
            red: 0.9 - (0.1 * t),
            green: 0.65 + (0.2 * t),
            blue: 0.2 + (0.1 * t)
        )
    } else if normalized < 0.75 {
        // Yellow to Light Green (ratings 5-8)
        let t = (normalized - 0.5) / 0.25
        return Color(
            red: 0.8 - (0.4 * t),
            green: 0.85 - (0.05 * t),
            blue: 0.3 + (0.1 * t)
        )
    } else {
        // Light Green to Vibrant Green (ratings 8-10)
        let t = (normalized - 0.75) / 0.25
        return Color(
            red: 0.4 - (0.2 * t),
            green: 0.8 + (0.1 * t),
            blue: 0.4 + (0.2 * t)
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            // Sample with mixed data
            RatingHeatmapView(
                ratingHistory: [
                    RatingEntry(rating: 7, date: Date().addingTimeInterval(-86400 * 9)),
                    RatingEntry(rating: 8, date: Date().addingTimeInterval(-86400 * 8)),
                    RatingEntry(rating: 5, date: Date().addingTimeInterval(-86400 * 6)),
                    RatingEntry(rating: 9, date: Date().addingTimeInterval(-86400 * 5)),
                    RatingEntry(rating: 3, date: Date().addingTimeInterval(-86400 * 3)),
                    RatingEntry(rating: 6, date: Date().addingTimeInterval(-86400 * 2)),
                    RatingEntry(rating: 8, date: Date().addingTimeInterval(-3600 * 8)),
                    RatingEntry(rating: 10, date: Date().addingTimeInterval(-3600 * 1))
                ],
                isLoading: false
            )
            .padding()
        }
    }
}
