//
//  SwipeableRatingCard.swift
//  SocialTen
//

import SwiftUI

struct SwipeableRatingCard: View {
    let rating: Int?
    var onRatingChanged: ((Int) -> Void)?
    
    @State private var displayRating: Int = 5
    @State private var dragOffset: CGFloat = 0
    @State private var isPressed = false
    @State private var showHint = true
    @GestureState private var isDragging = false
    
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    private let dragThreshold: CGFloat = 30  // Points to drag for 1 rating change
    
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date()).lowercased()
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: Date()).lowercased()
    }
    
    var body: some View {
        DepthCard(depth: .medium) {
            VStack(spacing: 16) {
                Spacer()
                    .frame(height: 20)
                
                // Rating number
                Text("\(displayRating)")
                    .font(.system(size: 140, weight: .ultraLight))
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: displayRating)
                
                // Date info
                VStack(spacing: 4) {
                    Text(dayOfWeek)
                        .font(.system(size: 18, weight: .light))
                        .tracking(4)
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    
                    Text(formattedDate)
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                }
                
                // Rating dots indicator
                HStack(spacing: 8) {
                    ForEach(1...10, id: \.self) { i in
                        Circle()
                            .fill(i == displayRating ? ThemeManager.shared.colors.accent1 : ThemeManager.shared.colors.accent3.opacity(0.5))
                            .frame(width: i == displayRating ? 10 : 6, height: i == displayRating ? 10 : 6)
                            .animation(.spring(response: 0.3), value: displayRating)
                    }
                }
                .padding(.top, 16)
                
                // Hint text
                if showHint && rating == nil {
                    Text("swipe left or right to rate")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        .padding(.top, 8)
                        .transition(.opacity)
                }
                
                Spacer()
                    .frame(height: 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
        }
        .scaleEffect(isPressed || isDragging ? 0.98 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed || isDragging)
        .gesture(
            DragGesture()
                .updating($isDragging) { _, state, _ in
                    state = true
                }
                .onChanged { value in
                    // Use horizontal translation instead of vertical
                    let translation = value.translation.width
                    dragOffset = translation
                    
                    // Calculate potential new rating (positive = increase, negative = decrease)
                    let ratingChange = Int(translation / dragThreshold)
                    let baseRating = rating ?? 5
                    let newRating = max(1, min(10, baseRating + ratingChange))
                    
                    // Haptic feedback when crossing threshold
                    if newRating != displayRating {
                        feedbackGenerator.impactOccurred()
                        displayRating = newRating
                    }
                }
                .onEnded { _ in
                    dragOffset = 0
                    if showHint {
                        withAnimation {
                            showHint = false
                        }
                    }
                    // Only call onRatingChanged if the rating actually changed
                    if displayRating != (rating ?? 5) {
                        onRatingChanged?(displayRating)
                    }
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.1)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .onAppear {
            // Initialize display rating from passed value
            if let rating = rating {
                displayRating = rating
            }
        }
        .onChange(of: rating) { _, newValue in
            // Update display rating when the external value changes
            if let newValue = newValue {
                displayRating = newValue
            }
        }
    }
}

#Preview {
    ZStack {
        ThemeManager.shared.colors.background.ignoresSafeArea()
        SwipeableRatingCard(rating: 7) { _ in }
    }
}
