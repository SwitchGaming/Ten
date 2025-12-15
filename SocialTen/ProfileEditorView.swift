//
//  ProfileEditorView.swift
//  SocialTen
//
//  Created on 12/3/25.
//

import SwiftUI

struct ProfileEditorView: View {
    var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName: String = ""
    @State private var bio: String = ""
    @State private var showGlow: Bool = true
    @State private var glowIntensity: Double = 0.3
    @State private var selectedGlowPreset: GlowPreset = .white
    @State private var selectedLayout: ProfileLayout = .minimal
    
    var body: some View {
        ZStack {
            ShadowTheme.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Text("cancel")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(ShadowTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        Text("customize")
                            .font(.system(size: 16, weight: .light))
                            .tracking(2)
                            .foregroundColor(ShadowTheme.textPrimary)
                        
                        Spacer()
                        
                        Button(action: {
                            saveProfile()
                            dismiss()
                        }) {
                            Text("save")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Preview
                    ProfilePreviewCard(
                        displayName: displayName,
                        bio: bio,
                        showGlow: showGlow,
                        glowColor: selectedGlowPreset.color,
                        glowIntensity: glowIntensity
                    )
                    .padding(.horizontal, 20)
                    
                    // Profile Info Section
                    SettingsSection(title: "profile") {
                        VStack(spacing: 16) {
                            CustomTextField(title: "name", text: $displayName)
                            CustomTextField(title: "bio", text: $bio, isMultiline: true)
                        }
                    }
                    
                    // Glow Section
                    SettingsSection(title: "glow") {
                        VStack(spacing: 20) {
                            // Toggle
                            HStack {
                                Text("enable glow")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(ShadowTheme.textPrimary)
                                
                                Spacer()
                                
                                Toggle("", isOn: $showGlow)
                                    .toggleStyle(SwitchToggleStyle(tint: Color.white.opacity(0.3)))
                            }
                            
                            if showGlow {
                                // Glow color presets
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("color")
                                        .font(.system(size: 12, weight: .medium))
                                        .tracking(1)
                                        .foregroundColor(ShadowTheme.textTertiary)
                                        .textCase(.uppercase)
                                    
                                    HStack(spacing: 12) {
                                        ForEach(GlowPreset.allCases, id: \.self) { preset in
                                            GlowPresetButton(
                                                preset: preset,
                                                isSelected: selectedGlowPreset == preset,
                                                action: { selectedGlowPreset = preset }
                                            )
                                        }
                                    }
                                }
                                
                                // Intensity slider
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("intensity")
                                            .font(.system(size: 12, weight: .medium))
                                            .tracking(1)
                                            .foregroundColor(ShadowTheme.textTertiary)
                                            .textCase(.uppercase)
                                        
                                        Spacer()
                                        
                                        Text("\(Int(glowIntensity * 100))%")
                                            .font(.system(size: 12, weight: .light))
                                            .foregroundColor(ShadowTheme.textSecondary)
                                    }
                                    
                                    CustomSlider(value: $glowIntensity, color: selectedGlowPreset.color)
                                }
                            }
                        }
                    }
                    
                    // Layout Section
                    SettingsSection(title: "layout") {
                        HStack(spacing: 12) {
                            ForEach(ProfileLayout.allCases, id: \.self) { layout in
                                LayoutOption(
                                    layout: layout,
                                    isSelected: selectedLayout == layout,
                                    action: { selectedLayout = layout }
                                )
                            }
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .onAppear {
            loadCurrentProfile()
        }
    }
    
    func loadCurrentProfile() {
        guard let user = viewModel.currentUser else { return }
        displayName = user.displayName
        bio = user.bio
        showGlow = user.profileCustomization.showGlow
        glowIntensity = user.profileCustomization.glowIntensity
        selectedLayout = user.profileCustomization.profileLayout
        
        // Find matching preset
        let currentGlow = user.profileCustomization.glowColor.color
        for preset in GlowPreset.allCases {
            if colorsMatch(preset.color, currentGlow) {
                selectedGlowPreset = preset
                break
            }
        }
    }
    
    func colorsMatch(_ c1: Color, _ c2: Color) -> Bool {
        // Simple color comparison
        return true // Default to white preset for simplicity
    }
    
    func saveProfile() {
        let customization = ProfileCustomization(
            glowColor: CodableColor(color: selectedGlowPreset.color),
            glowIntensity: glowIntensity,
            glassOpacity: 0.08,
            shadowIntensity: 0.5,
            showGlow: showGlow,
            profileLayout: selectedLayout
        )
        viewModel.updateProfile(displayName: displayName, bio: bio, customization: customization)
    }
}

// MARK: - Components

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .tracking(2)
                .foregroundColor(ShadowTheme.textTertiary)
                .textCase(.uppercase)
                .padding(.horizontal, 24)
            
            VStack(spacing: 0) {
                content
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

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    var isMultiline: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .tracking(1)
                .foregroundColor(ShadowTheme.textTertiary)
                .textCase(.uppercase)
            
            if isMultiline {
                TextField("", text: $text, axis: .vertical)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(ShadowTheme.textPrimary)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
            } else {
                TextField("", text: $text)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(ShadowTheme.textPrimary)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
            }
        }
    }
}

struct GlowPresetButton: View {
    let preset: GlowPreset
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(preset.color.opacity(0.3))
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .stroke(preset.color.opacity(isSelected ? 0.8 : 0.3), lineWidth: isSelected ? 2 : 1)
                )
                .shadow(color: preset.color.opacity(isSelected ? 0.4 : 0), radius: 8)
        }
    }
}

struct CustomSlider: View {
    @Binding var value: Double
    var color: Color = .white
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 2)
                
                // Progress
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.5))
                    .frame(width: geo.size.width * CGFloat(value), height: 2)
                
                // Thumb
                Circle()
                    .fill(ShadowTheme.cardBackground)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.5), lineWidth: 1)
                    )
                    .shadow(color: color.opacity(0.3), radius: 6)
                    .offset(x: geo.size.width * CGFloat(value) - 10)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let newValue = gesture.location.x / geo.size.width
                                value = max(0.1, min(1.0, newValue))
                            }
                    )
            }
            .frame(height: 20)
        }
        .frame(height: 20)
    }
}

struct LayoutOption: View {
    let layout: ProfileLayout
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(isSelected ? 0.1 : 0.03))
                    .frame(height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(isSelected ? 0.3 : 0.06), lineWidth: 1)
                    )
                    .overlay(
                        layoutIcon
                    )
                
                Text(layout.rawValue.lowercased())
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1)
                    .foregroundColor(isSelected ? ShadowTheme.textPrimary : ShadowTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    var layoutIcon: some View {
        switch layout {
        case .minimal:
            VStack(spacing: 4) {
                Circle().fill(Color.white.opacity(0.2)).frame(width: 12, height: 12)
                RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.1)).frame(width: 20, height: 2)
            }
        case .glass:
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.1))
                .frame(width: 30, height: 25)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        case .shadow:
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 16, height: 16)
                .shadow(color: .white.opacity(0.2), radius: 4)
        }
    }
}

struct ProfilePreviewCard: View {
    let displayName: String
    let bio: String
    let showGlow: Bool
    let glowColor: Color
    let glowIntensity: Double
    
    var effectiveGlow: Double {
        showGlow ? glowIntensity : 0
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(ShadowTheme.surfaceLight)
                .frame(width: 60, height: 60)
                .overlay(
                    Text(String(displayName.prefix(1)).lowercased())
                        .font(.system(size: 22, weight: .ultraLight))
                        .foregroundColor(ShadowTheme.textSecondary)
                )
                .overlay(
                    Circle()
                        .stroke(glowColor.opacity(effectiveGlow), lineWidth: 1)
                        .blur(radius: 1)
                )
                .shadow(color: glowColor.opacity(effectiveGlow * 0.6), radius: 15)
            
            VStack(spacing: 6) {
                Text(displayName.isEmpty ? "your name" : displayName.lowercased())
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(ShadowTheme.textPrimary)
                
                if !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(ShadowTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassCard(glowColor: glowColor, glowIntensity: effectiveGlow)
    }
}

#Preview {
    ProfileEditorView(viewModel: AppViewModel())
}

