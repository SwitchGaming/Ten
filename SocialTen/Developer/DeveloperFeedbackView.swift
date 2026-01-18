//
//  DeveloperFeedbackView.swift
//  SocialTen
//
//  Placeholder view for user feedback management (to be implemented)
//

import SwiftUI

struct DeveloperFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ZStack {
            themeManager.colors.background.ignoresSafeArea()
            
            VStack(spacing: themeManager.spacing.xl) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(themeManager.colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Text("user feedback")
                        .font(themeManager.fonts.headline)
                        .foregroundColor(themeManager.colors.textPrimary)
                    
                    Spacer()
                    
                    // Placeholder for balance
                    Color.clear.frame(width: 24, height: 24)
                }
                .padding(.horizontal, themeManager.spacing.screenHorizontal)
                .padding(.top, themeManager.spacing.md)
                
                Spacer()
                
                // Coming soon placeholder
                VStack(spacing: themeManager.spacing.lg) {
                    ZStack {
                        Circle()
                            .fill(themeManager.colors.cardBackground)
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "envelope.badge")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(themeManager.colors.accent1)
                    }
                    
                    VStack(spacing: themeManager.spacing.sm) {
                        Text("coming soon")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(themeManager.colors.textPrimary)
                        
                        Text("user feedback collection and management\nwill be available here")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(themeManager.colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    
                    // Feature preview cards
                    VStack(spacing: themeManager.spacing.sm) {
                        FeaturePreviewRow(icon: "text.bubble.fill", title: "In-App Feedback", description: "Collect feedback directly from users")
                        FeaturePreviewRow(icon: "star.fill", title: "App Store Reviews", description: "Monitor and respond to reviews")
                        FeaturePreviewRow(icon: "chart.bar.fill", title: "Sentiment Analysis", description: "Track user satisfaction trends")
                        FeaturePreviewRow(icon: "flag.fill", title: "Bug Reports", description: "Manage user-reported issues")
                    }
                    .padding(.top, themeManager.spacing.lg)
                }
                .padding(.horizontal, themeManager.spacing.screenHorizontal)
                
                Spacer()
                Spacer()
            }
        }
    }
}

struct FeaturePreviewRow: View {
    let icon: String
    let title: String
    let description: String
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: themeManager.spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(themeManager.colors.accent1)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeManager.colors.textPrimary)
                
                Text(description)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(themeManager.colors.textTertiary)
            }
            
            Spacer()
            
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundColor(themeManager.colors.textTertiary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: themeManager.radius.md)
                .fill(themeManager.colors.cardBackground)
        )
    }
}

#Preview {
    DeveloperFeedbackView()
}
