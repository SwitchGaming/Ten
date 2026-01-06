//
//  EditProfileView.swift
//  SocialTen
//

import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var username: String = ""
    @State private var displayName: String = ""
    @State private var isCheckingUsername: Bool = false
    @State private var usernameError: String? = nil
    @State private var displayNameError: String? = nil
    @State private var isSaving: Bool = false
    @State private var showSuccessMessage: Bool = false
    
    private let maxLength = 10
    
    var isUsernameValid: Bool {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return false }
        if trimmed.count > maxLength { return false }
        if trimmed.contains(" ") { return false }
        // Only allow alphanumeric and underscores
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        if trimmed.unicodeScalars.contains(where: { !allowed.contains($0) }) { return false }
        return true
    }
    
    var isDisplayNameValid: Bool {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return false }
        if trimmed.count > maxLength { return false }
        return true
    }
    
    var hasChanges: Bool {
        let currentUsername = viewModel.currentUserProfile?.username ?? ""
        let currentDisplayName = viewModel.currentUserProfile?.displayName ?? ""
        return username.lowercased() != currentUsername.lowercased() || displayName != currentDisplayName
    }
    
    var canSave: Bool {
        isUsernameValid && isDisplayNameValid && hasChanges && usernameError == nil && !isCheckingUsername && !isSaving
    }
    
    var body: some View {
        ZStack {
            ThemeManager.shared.colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                header
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: ThemeManager.shared.spacing.xl) {
                        // Avatar
                        avatarSection
                        
                        // Username Field
                        usernameField
                        
                        // Display Name Field
                        displayNameField
                        
                        // Info text
                        infoText
                    }
                    .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
                    .padding(.top, ThemeManager.shared.spacing.xl)
                }
            }
            
            // Success toast
            if showSuccessMessage {
                VStack {
                    Spacer()
                    Text("profile updated!")
                        .font(ThemeManager.shared.fonts.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.9))
                        )
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            username = viewModel.currentUserProfile?.username ?? ""
            displayName = viewModel.currentUserProfile?.displayName ?? ""
        }
    }
    
    // MARK: - Header
    
    var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ThemeManager.shared.colors.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(ThemeManager.shared.colors.cardBackground)
                    )
            }
            
            Spacer()
            
            Text("edit profile")
                .font(ThemeManager.shared.fonts.body)
                .foregroundColor(ThemeManager.shared.colors.textPrimary)
                .tracking(ThemeManager.shared.letterSpacing.wide)
            
            Spacer()
            
            Button(action: saveProfile) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ThemeManager.shared.colors.accent1))
                        .frame(width: 40, height: 40)
                } else {
                    Text("save")
                        .font(ThemeManager.shared.fonts.caption)
                        .foregroundColor(canSave ? ThemeManager.shared.colors.accent1 : ThemeManager.shared.colors.textTertiary)
                        .frame(width: 40)
                }
            }
            .disabled(!canSave)
        }
        .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
        .padding(.top, ThemeManager.shared.spacing.lg)
        .padding(.bottom, ThemeManager.shared.spacing.md)
    }
    
    // MARK: - Avatar Section
    
    var avatarSection: some View {
        VStack(spacing: ThemeManager.shared.spacing.md) {
            Circle()
                .fill(ThemeManager.shared.colors.cardBackground)
                .frame(width: 80, height: 80)
                .overlay(
                    Text(String(displayName.prefix(1)).lowercased())
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textSecondary)
                )
        }
    }
    
    // MARK: - Username Field
    
    var usernameField: some View {
        VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.sm) {
            HStack {
                Text("username")
                    .font(ThemeManager.shared.fonts.caption)
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    .tracking(ThemeManager.shared.letterSpacing.wide)
                    .textCase(.uppercase)
                
                Spacer()
                
                Text("\(username.count)/\(maxLength)")
                    .font(ThemeManager.shared.fonts.small)
                    .foregroundColor(username.count > maxLength ? .red : ThemeManager.shared.colors.textTertiary)
            }
            
            HStack {
                Text("@")
                    .font(ThemeManager.shared.fonts.body)
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                
                TextField("", text: $username)
                    .font(ThemeManager.shared.fonts.body)
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .onChange(of: username) { _, newValue in
                        // Remove spaces and limit length
                        let filtered = newValue.lowercased().filter { !$0.isWhitespace }
                        if filtered != newValue {
                            username = filtered
                        }
                        if username.count > maxLength {
                            username = String(username.prefix(maxLength))
                        }
                        usernameError = nil
                    }
                
                if isCheckingUsername {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ThemeManager.shared.colors.textTertiary))
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, ThemeManager.shared.spacing.md)
            .padding(.vertical, ThemeManager.shared.spacing.md)
            .background(
                RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                    .fill(ThemeManager.shared.colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                            .stroke(usernameError != nil ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            )
            
            if let error = usernameError {
                Text(error)
                    .font(ThemeManager.shared.fonts.small)
                    .foregroundColor(.red.opacity(0.8))
            } else if !isUsernameValid && !username.isEmpty {
                Text("letters, numbers, and underscores only")
                    .font(ThemeManager.shared.fonts.small)
                    .foregroundColor(.orange.opacity(0.8))
            }
        }
    }
    
    // MARK: - Display Name Field
    
    var displayNameField: some View {
        VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.sm) {
            HStack {
                Text("display name")
                    .font(ThemeManager.shared.fonts.caption)
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    .tracking(ThemeManager.shared.letterSpacing.wide)
                    .textCase(.uppercase)
                
                Spacer()
                
                Text("\(displayName.count)/\(maxLength)")
                    .font(ThemeManager.shared.fonts.small)
                    .foregroundColor(displayName.count > maxLength ? .red : ThemeManager.shared.colors.textTertiary)
            }
            
            TextField("", text: $displayName)
                .font(ThemeManager.shared.fonts.body)
                .foregroundColor(ThemeManager.shared.colors.textPrimary)
                .onChange(of: displayName) { _, newValue in
                    if displayName.count > maxLength {
                        displayName = String(displayName.prefix(maxLength))
                    }
                    displayNameError = nil
                }
                .padding(.horizontal, ThemeManager.shared.spacing.md)
                .padding(.vertical, ThemeManager.shared.spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                        .fill(ThemeManager.shared.colors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                                .stroke(displayNameError != nil ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                )
            
            if let error = displayNameError {
                Text(error)
                    .font(ThemeManager.shared.fonts.small)
                    .foregroundColor(.red.opacity(0.8))
            }
        }
    }
    
    // MARK: - Info Text
    
    var infoText: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("• username must be unique and 1-10 characters")
            Text("• only letters, numbers, and underscores allowed")
            Text("• display name is what friends see")
        }
        .font(ThemeManager.shared.fonts.small)
        .foregroundColor(ThemeManager.shared.colors.textTertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ThemeManager.shared.spacing.md)
        .background(
            RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                .fill(ThemeManager.shared.colors.cardBackground.opacity(0.5))
        )
    }
    
    // MARK: - Save Profile
    
    func saveProfile() {
        guard canSave else { return }
        
        isSaving = true
        usernameError = nil
        
        Task {
            let result = await viewModel.updateProfile(
                username: username.lowercased(),
                displayName: displayName
            )
            
            isSaving = false
            
            switch result {
            case .success:
                withAnimation {
                    showSuccessMessage = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        showSuccessMessage = false
                    }
                    dismiss()
                }
            case .usernameTaken:
                usernameError = "username is already taken"
            case .error(let message):
                usernameError = message
            }
        }
    }
}

#Preview {
    EditProfileView()
        .environmentObject(SupabaseAppViewModel())
}
