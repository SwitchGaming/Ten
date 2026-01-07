//
//  ActiveVibeBanner.swift
//  SocialTen
//

import SwiftUI

struct ActiveVibeBanner: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @Binding var navigateToVibeTab: Bool
    @Binding var expandedVibeId: String?
    
    var activeVibe: Vibe? {
        viewModel.getActiveVibes().first
    }
    
    var body: some View {
        if let vibe = activeVibe {
            Button(action: {
                expandedVibeId = vibe.id
                navigateToVibeTab = true
            }) {
                DepthCard(depth: .low) {
                    HStack(spacing: themeManager.spacing.sm) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundColor(themeManager.colors.accent2)
                        
                        Text(vibe.title)
                            .font(themeManager.fonts.body)
                            .foregroundColor(themeManager.colors.textPrimary)
                        
                        Text("·")
                            .foregroundColor(themeManager.colors.textTertiary)
                        
                        Text(vibe.timeDescription)
                            .font(themeManager.fonts.caption)
                            .foregroundColor(themeManager.colors.textSecondary)
                        
                        Spacer()
                        
                        if vibe.yesCount > 0 {
                            Text("\(vibe.yesCount + 1) in") // +1 for creator
                                .font(themeManager.fonts.caption)
                                .foregroundColor(.green)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(themeManager.colors.textTertiary)
                    }
                    .padding(themeManager.spacing.md)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ActiveVibeBanner(navigateToVibeTab: .constant(false), expandedVibeId: .constant(nil))
        .environmentObject(SupabaseAppViewModel())
        .padding()
        .background(Color.black)
}

