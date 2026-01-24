//
//  AmbassadorDashboardView.swift
//  SocialTen
//
//  Dashboard for ambassadors to manage their referral codes
//

import SwiftUI

struct AmbassadorDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var premiumManager = PremiumManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var isGenerating = false
    @State private var copiedCode: String? = nil
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Stats header
                        statsHeader
                        
                        // Generate code button
                        generateCodeSection
                        
                        // Referral codes list
                        codesListSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Ambassador")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.colors.accent1)
                }
            }
        }
        .task {
            await premiumManager.checkAmbassadorStatus()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Stats Header
    
    private var statsHeader: some View {
        VStack(spacing: 16) {
            // Ambassador badge
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [themeManager.colors.accent1, themeManager.colors.accent2],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ambassador")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(themeManager.colors.textPrimary)
                    
                    Text("Invite friends to ten+")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(themeManager.colors.textSecondary)
                }
                
                Spacer()
            }
            
            // Stats grid
            HStack(spacing: 12) {
                AmbassadorStatCard(
                    value: "\(premiumManager.ambassadorStatus.activeCodes ?? 0)",
                    label: "Active Codes",
                    icon: "ticket.fill",
                    color: themeManager.colors.accent1
                )
                
                AmbassadorStatCard(
                    value: "\(premiumManager.ambassadorStatus.totalRedeemed ?? 0)",
                    label: "Invites Used",
                    icon: "person.badge.plus",
                    color: themeManager.colors.accent2
                )
                
                AmbassadorStatCard(
                    value: "\(premiumManager.ambassadorStatus.maxCodes ?? 5)",
                    label: "Max Codes",
                    icon: "crown.fill",
                    color: Color.yellow
                )
            }
        }
        .padding(20)
        .background(themeManager.colors.cardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Generate Code Section
    
    private var generateCodeSection: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await generateCode()
                }
            } label: {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }
                    Text("Generate New Code")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    (premiumManager.ambassadorStatus.canGenerateCode ?? false)
                        ? themeManager.colors.accent1
                        : themeManager.colors.textTertiary
                )
                .cornerRadius(12)
            }
            .disabled(!(premiumManager.ambassadorStatus.canGenerateCode ?? false) || isGenerating)
            
            if !(premiumManager.ambassadorStatus.canGenerateCode ?? true) {
                Text("You've reached the maximum number of active codes")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(themeManager.colors.textTertiary)
            } else {
                Text("Each code gives 7 days of ten+ and expires after 30 days")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(themeManager.colors.textTertiary)
            }
        }
    }
    
    private func generateCode() async {
        print("🔘 Generate button pressed")
        isGenerating = true
        
        if let result = await premiumManager.generateReferralCode() {
            print("🎫 Generation result: success=\(result.success), code=\(result.code ?? "nil")")
            if !result.success {
                errorMessage = result.error ?? "Failed to generate code"
                showError = true
            }
        } else {
            print("❌ Generation returned nil")
        }
        
        print("📊 Current codes count: \(premiumManager.referralCodes.count)")
        isGenerating = false
    }
    
    // MARK: - Codes List
    
    private var codesListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Codes")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(themeManager.colors.textSecondary)
                .textCase(.uppercase)
                .tracking(1)
            
            if premiumManager.referralCodes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "ticket")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(themeManager.colors.textTertiary)
                    
                    Text("No codes yet")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(themeManager.colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(premiumManager.referralCodes) { code in
                        ReferralCodeRow(
                            code: code,
                            isCopied: copiedCode == code.code,
                            onCopy: {
                                copyCode(code.code)
                            },
                            onDelete: {
                                Task {
                                    await premiumManager.revokeReferralCode(code.id)
                                }
                            }
                        )
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: premiumManager.referralCodes.count)
            }
        }
    }
    
    private func copyCode(_ code: String) {
        UIPasteboard.general.string = code
        copiedCode = code
        
        // Reset copied state after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedCode == code {
                copiedCode = nil
            }
        }
    }
}

// MARK: - Stat Card

struct AmbassadorStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.colors.textPrimary)
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(themeManager.colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(themeManager.colors.background)
        .cornerRadius(10)
    }
}

// MARK: - Referral Code Row

struct ReferralCodeRow: View {
    let code: ReferralCode
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            // Code
            VStack(alignment: .leading, spacing: 4) {
                Text(code.code)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(themeManager.colors.textPrimary)
                
                HStack(spacing: 8) {
                    Text(code.displayStatus)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(statusColor)
                    
                    if code.status == .redeemed, let name = code.redeemedByName {
                        Text("by \(name)")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(themeManager.colors.textTertiary)
                    } else if code.isActive {
                        Text("expires \(expiryString)")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(themeManager.colors.textTertiary)
                    }
                }
            }
            
            Spacer()
            
            // Buttons (only for active codes)
            if code.isActive {
                HStack(spacing: 8) {
                    Button(action: onCopy) {
                        HStack(spacing: 4) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 12, weight: .medium))
                            Text(isCopied ? "Copied" : "Copy")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(isCopied ? themeManager.colors.accent1 : themeManager.colors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(themeManager.colors.background)
                        .cornerRadius(8)
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red.opacity(0.7))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(themeManager.colors.background)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(themeManager.colors.cardBackground)
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch code.status {
        case .active:
            return code.expiresAt > Date() ? Color.green : Color.orange
        case .redeemed:
            return themeManager.colors.accent1
        case .expired:
            return Color.orange
        case .revoked:
            return Color.red
        }
    }
    
    private var expiryString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: code.expiresAt, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    AmbassadorDashboardView()
}
