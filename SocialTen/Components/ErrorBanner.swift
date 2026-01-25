//
//  ErrorBanner.swift
//  SocialTen
//

import SwiftUI

struct ErrorBanner: View {
    let message: String
    let onRetry: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: themeManager.spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.orange)
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(themeManager.colors.textPrimary)
            
            Spacer()
            
            Button(action: onRetry) {
                Text("Retry")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(themeManager.colors.accent1)
            }
        }
        .padding(.horizontal, themeManager.spacing.md)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: themeManager.radius.md)
                .fill(themeManager.colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: themeManager.radius.md)
                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ErrorBanner(message: "Failed to load data. Pull to refresh.", onRetry: {})
        .padding()
        .background(Color.black)
}
