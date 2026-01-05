//
//  PromptCard.swift
//  SocialTen
//

import SwiftUI

struct PromptCard: View {
    let prompt: DailyPrompt
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            DepthCard(depth: .low) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("today's prompt")
                            .font(ThemeManager.shared.fonts.caption)
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            .tracking(ThemeManager.shared.letterSpacing.wide)
                            .textCase(.uppercase)
                        
                        Text(prompt.text)
                            .font(ThemeManager.shared.fonts.body)
                            .foregroundColor(ThemeManager.shared.colors.textSecondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                }
                .padding(ThemeManager.shared.spacing.md)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

#Preview {
    PromptCard(prompt: DailyPrompt(text: "What made you smile today?")) {}
        .padding()
        .background(Color.black)
}
