//
//  ActiveVibeBanner.swift
//  SocialTen
//

import SwiftUI

struct ActiveVibeBanner: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
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
                    HStack(spacing: ThemeManager.shared.spacing.sm) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundColor(ThemeManager.shared.colors.accent2)
                        
                        Text(vibe.title)
                            .font(ThemeManager.shared.fonts.body)
                            .foregroundColor(ThemeManager.shared.colors.textPrimary)
                        
                        Text("·")
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        
                        Text(vibe.timeDescription)
                            .font(ThemeManager.shared.fonts.caption)
                            .foregroundColor(ThemeManager.shared.colors.textSecondary)
                        
                        Spacer()
                        
                        if vibe.yesCount > 0 {
                            Text("\(vibe.yesCount + 1) in") // +1 for creator
                                .font(ThemeManager.shared.fonts.caption)
                                .foregroundColor(.green)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    }
                    .padding(ThemeManager.shared.spacing.md)
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

