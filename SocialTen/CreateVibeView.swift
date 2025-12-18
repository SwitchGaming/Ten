//
//  CreateVibeView.swift
//  SocialTen
//

import SwiftUI

struct CreateVibeView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var vibeTitle: String = ""
    @State private var selectedTime: VibeTimePreset = .in15
    @State private var location: String = ""
    
    @FocusState private var titleFocused: Bool
    @FocusState private var locationFocused: Bool
    
    var canCreate: Bool {
        !vibeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        ZStack {
            ShadowTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(ShadowTheme.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    
                    Spacer()
                    
                    Text("new vibe")
                        .font(.system(size: 16, weight: .light))
                        .tracking(2)
                        .foregroundColor(ShadowTheme.textPrimary)
                    
                    Spacer()
                    
                    Button(action: createVibe) {
                        Text("send")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(canCreate ? .purple : ShadowTheme.textTertiary)
                    }
                    .disabled(!canCreate)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 30)
                
                VStack(spacing: 32) {
                    // Vibe Title Input
                    VStack(alignment: .leading, spacing: 10) {
                        Text("what's the vibe?")
                            .font(.system(size: 12, weight: .medium))
                            .tracking(1)
                            .foregroundColor(ShadowTheme.textTertiary)
                            .textCase(.uppercase)
                        
                        TextField("Football? Coffee? Study?", text: $vibeTitle)
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(ShadowTheme.textPrimary)
                            .focused($titleFocused)
                            .submitLabel(.next)
                            .onSubmit {
                                locationFocused = true
                            }
                    }
                    .padding(.horizontal, 20)
                    
                    // Time Selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text("when?")
                            .font(.system(size: 12, weight: .medium))
                            .tracking(1)
                            .foregroundColor(ShadowTheme.textTertiary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(VibeTimePreset.allCases, id: \.self) { preset in
                                    TimePresetButton(
                                        preset: preset,
                                        isSelected: selectedTime == preset
                                    ) {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedTime = preset
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Location Input
                    VStack(alignment: .leading, spacing: 10) {
                        Text("where?")
                            .font(.system(size: 12, weight: .medium))
                            .tracking(1)
                            .foregroundColor(ShadowTheme.textTertiary)
                            .textCase(.uppercase)
                        
                        TextField("My place, Library, Cafe...", text: $location)
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(ShadowTheme.textPrimary)
                            .focused($locationFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                if canCreate {
                                    createVibe()
                                }
                            }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("preview")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(1)
                            .foregroundColor(ShadowTheme.textTertiary)
                            .textCase(.uppercase)
                        
                        HStack(spacing: 0) {
                            Text(vibeTitle.isEmpty ? "..." : vibeTitle)
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(ShadowTheme.textPrimary)
                            
                            Text(" · ")
                                .foregroundColor(ShadowTheme.textTertiary)
                            
                            Text(selectedTime.rawValue)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(ShadowTheme.textSecondary)
                            
                            Text(" · ")
                                .foregroundColor(ShadowTheme.textTertiary)
                            
                            Text(location.isEmpty ? "..." : location)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(ShadowTheme.textSecondary)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(ShadowTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.purple.opacity(0.3), .purple.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            titleFocused = true
        }
    }
    
    func createVibe() {
        viewModel.createVibe(
            title: vibeTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            timeDescription: selectedTime.rawValue,
            location: location.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        dismiss()
    }
}

// MARK: - Time Preset Button

struct TimePresetButton: View {
    let preset: VibeTimePreset
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(preset.rawValue)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundColor(isSelected ? .white : ShadowTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.purple.opacity(0.3) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    isSelected ? Color.purple.opacity(0.5) : Color.white.opacity(0.1),
                                    lineWidth: 1
                                )
                        )
                )
        }
    }
}

#Preview {
    CreateVibeView()
        .environmentObject(AppViewModel())
}
