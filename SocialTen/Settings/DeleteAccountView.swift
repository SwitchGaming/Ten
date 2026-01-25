//
//  DeleteAccountView.swift
//  SocialTen
//

import SwiftUI

struct DeleteAccountView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep: DeleteStep = .warning
    @State private var emailInput = ""
    @State private var isDeleting = false
    @FocusState private var isEmailFocused: Bool
    
    enum DeleteStep {
        case warning
        case confirmEmail
        case deleting
    }
    
    var userEmail: String {
        authViewModel.currentSession?.user.email ?? ""
    }
    
    var emailMatches: Bool {
        emailInput.lowercased().trimmingCharacters(in: .whitespaces) == userEmail.lowercased()
    }
    
    var body: some View {
        ZStack {
            themeManager.colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        authViewModel.cancelDeleteFlow()
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(themeManager.colors.textSecondary)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(themeManager.colors.cardBackground)
                            )
                    }
                    
                    Spacer()
                    
                    Text("delete account")
                        .font(.system(size: 16, weight: .light))
                        .tracking(4)
                        .foregroundColor(themeManager.colors.textPrimary)
                    
                    Spacer()
                    
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, themeManager.spacing.screenHorizontal)
                .padding(.top, themeManager.spacing.lg)
                
                Spacer()
                
                // Content based on step
                switch currentStep {
                case .warning:
                    warningView
                case .confirmEmail:
                    confirmEmailView
                case .deleting:
                    deletingView
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Warning View
    
    var warningView: some View {
        VStack(spacing: themeManager.spacing.xl) {
            // Warning icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
            }
            
            // Title
            Text("Are you sure?")
                .font(.system(size: 24, weight: .light))
                .tracking(2)
                .foregroundColor(themeManager.colors.textPrimary)
            
            // Description
            VStack(spacing: 16) {
                Text("This action is permanent and cannot be undone.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red.opacity(0.8))
                
                Text("All your data will be permanently deleted, including:")
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(themeManager.colors.textSecondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    deleteItemRow("Your profile and account")
                    deleteItemRow("All posts, replies, and likes")
                    deleteItemRow("All vibes you've created")
                    deleteItemRow("Friends and friend requests")
                    deleteItemRow("Messages and conversations")
                    deleteItemRow("Badges, stats, and streaks")
                    deleteItemRow("Premium status and referrals")
                }
                .padding(.horizontal, 20)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, themeManager.spacing.screenHorizontal)
            
            // Error message
            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            // Buttons
            VStack(spacing: 12) {
                // Continue button
                Button {
                    currentStep = .confirmEmail
                } label: {
                    Text("Continue")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: themeManager.radius.md)
                                .fill(Color.red)
                        )
                }
                
                // Cancel button
                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(themeManager.colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: themeManager.radius.md)
                                .fill(themeManager.colors.cardBackground)
                        )
                }
            }
            .padding(.horizontal, themeManager.spacing.screenHorizontal)
            .padding(.top, themeManager.spacing.lg)
        }
    }
    
    func deleteItemRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.red.opacity(0.6))
                .frame(width: 5, height: 5)
            
            Text(text)
                .font(.system(size: 13, weight: .light))
                .foregroundColor(themeManager.colors.textTertiary)
            
            Spacer()
        }
    }
    
    // MARK: - Sending OTP View
    
    // MARK: - Confirm Email View
    
    var confirmEmailView: some View {
        VStack(spacing: themeManager.spacing.xl) {
            // Lock icon
            ZStack {
                Circle()
                    .fill(themeManager.colors.cardBackground)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "envelope.badge.shield.half.filled.fill")
                    .font(.system(size: 32))
                    .foregroundColor(themeManager.colors.textSecondary)
            }
            
            // Title
            VStack(spacing: 8) {
                Text("Confirm your email")
                    .font(.system(size: 22, weight: .light))
                    .tracking(2)
                    .foregroundColor(themeManager.colors.textPrimary)
                
                Text("Enter the email address associated with your account to confirm deletion")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(themeManager.colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, themeManager.spacing.screenHorizontal)
            
            // Email Input
            VStack(spacing: 16) {
                TextField("Enter your email", text: $emailInput)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(themeManager.colors.textPrimary)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: themeManager.radius.md)
                            .fill(themeManager.colors.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: themeManager.radius.md)
                            .stroke(emailMatches ? Color.red : themeManager.colors.textTertiary.opacity(0.3), lineWidth: 1)
                    )
                    .focused($isEmailFocused)
                
                if !emailInput.isEmpty && !emailMatches {
                    Text("Email doesn't match your account")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, themeManager.spacing.screenHorizontal)
            .onAppear {
                isEmailFocused = true
            }
            
            // Error message
            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            // Delete button
            Button {
                Task {
                    await confirmAndDelete()
                }
            } label: {
                HStack(spacing: 8) {
                    if authViewModel.isDeleteLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(authViewModel.isDeleteLoading ? "Deleting..." : "Delete My Account")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: themeManager.radius.md)
                        .fill(emailMatches ? Color.red : Color.red.opacity(0.4))
                )
            }
            .disabled(!emailMatches || authViewModel.isDeleteLoading)
            .padding(.horizontal, themeManager.spacing.screenHorizontal)
            .padding(.top, themeManager.spacing.md)
            
            // Cancel button
            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeManager.colors.textSecondary)
            }
        }
    }
    
    func confirmAndDelete() async {
        guard emailMatches else { return }
        currentStep = .deleting
        let success = await authViewModel.deleteAccount()
        if success {
            dismiss()
        } else {
            currentStep = .confirmEmail
        }
    }
    
    // MARK: - Deleting View
    
    var deletingView: some View {
        VStack(spacing: themeManager.spacing.xl) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .red))
                .scaleEffect(1.5)
            
            Text("Deleting your account...")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(themeManager.colors.textSecondary)
            
            Text("This may take a moment")
                .font(.system(size: 13, weight: .light))
                .foregroundColor(themeManager.colors.textTertiary)
        }
    }
}

#Preview {
    DeleteAccountView()
        .environmentObject(AuthViewModel())
        .environmentObject(SupabaseAppViewModel())
}
