//
//  ProfileView.swift
//  SocialTen
//
//  Created on 12/3/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var showEditProfile = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                ShadowTheme.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    if let user = viewModel.currentUser {
                        VStack(spacing: 40) {
                            ProfileHeaderView(user: user)
                            
                            // Stats
                            StatsSection(user: user)
                            
                            // Glow preview
                            GlowPreviewSection(user: user, showEditProfile: $showEditProfile)
                            
                            Spacer(minLength: 40)
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("profile")
                        .font(.system(size: 20, weight: .light))
                        .tracking(4)
                        .foregroundColor(ShadowTheme.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showEditProfile = true }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(ShadowTheme.textSecondary)
                    }
                }
            }
            .fullScreenCover(isPresented: $showEditProfile) {
                ProfileEditorView()
            }
        }
    }
}

struct ProfileHeaderView: View {
    @EnvironmentObject var viewModel: AppViewModel
    let user: User
    
    var glowColor: Color {
        user.profileCustomization.glowColor.color
    }
    
    var glowIntensity: Double {
        user.profileCustomization.showGlow ? user.profileCustomization.glowIntensity : 0
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Avatar
            Circle()
                .fill(ShadowTheme.surfaceLight)
                .frame(width: 100, height: 100)
                .overlay(
                    Text(String(user.displayName.prefix(1)).lowercased())
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(ShadowTheme.textSecondary)
                )
                .overlay(
                    Circle()
                        .stroke(glowColor.opacity(glowIntensity), lineWidth: 1)
                        .blur(radius: 1)
                )
                .shadow(color: glowColor.opacity(glowIntensity * 0.6), radius: 20)
            
            // Name and bio
            VStack(spacing: 8) {
                Text(user.displayName.lowercased())
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(ShadowTheme.textPrimary)
                
                Text("@\(user.username)")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(ShadowTheme.textTertiary)
                
                if !user.bio.isEmpty {
                    Text(user.bio)
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(ShadowTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            
            // Today's rating
            if let rating = user.todayRating {
                HStack(spacing: 8) {
                    Text("\(rating)")
                        .font(.system(size: 48, weight: .ultraLight))
                        .foregroundColor(ShadowTheme.textPrimary)
                        .shadow(color: glowColor.opacity(glowIntensity * 0.6), radius: 15)
                    
                    Text("today")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(2)
                        .foregroundColor(ShadowTheme.textTertiary)
                        .textCase(.uppercase)
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct StatsSection: View {
    @EnvironmentObject var viewModel: AppViewModel
    let user: User
    
    var body: some View {
        HStack(spacing: 16) {
            StatCard(title: "friends", value: "\(viewModel.friends.count)")
            StatCard(title: "today", value: user.todayRating != nil ? "\(user.todayRating!)" : "—")
            StatCard(title: "streak", value: "1")
        }
        .padding(.horizontal, 20)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 24, weight: .ultraLight))
                .foregroundColor(ShadowTheme.textPrimary)
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .tracking(2)
                .foregroundColor(ShadowTheme.textTertiary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ShadowTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }
}

struct GlowPreviewSection: View {
    let user: User
    @Binding var showEditProfile: Bool
    
    var glowColor: Color {
        user.profileCustomization.glowColor.color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("your glow")
                .font(.system(size: 12, weight: .medium))
                .tracking(2)
                .foregroundColor(ShadowTheme.textTertiary)
                .textCase(.uppercase)
                .padding(.horizontal, 24)
            
            HStack(spacing: 16) {
                // Glow color preview
                Circle()
                    .fill(glowColor.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(glowColor.opacity(user.profileCustomization.showGlow ? 0.6 : 0.2), lineWidth: 2)
                    )
                    .shadow(color: glowColor.opacity(user.profileCustomization.showGlow ? 0.4 : 0), radius: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.profileCustomization.showGlow ? "glow enabled" : "glow disabled")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(ShadowTheme.textPrimary)
                    
                    Text("intensity: \(Int(user.profileCustomization.glowIntensity * 100))%")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(ShadowTheme.textTertiary)
                }
                
                Spacer()
                
                Button(action: { showEditProfile = true }) {
                    Text("edit")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(1)
                        .foregroundColor(ShadowTheme.textSecondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ShadowTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppViewModel())
}
