//
//  AuthView.swift
//  SocialTen
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var isSignUp = false
    @State private var email = ""
    @State private var username = ""
    @State private var otpCode = ""
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, username, otp
    }
    
    var body: some View {
        ZStack {
            ThemeManager.shared.colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo
                VStack(spacing: 16) {
                    Text("ten")
                        .font(.system(size: 64, weight: .ultraLight))
                        .tracking(12)
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    
                    Text("real friends. real moments.")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                }
                .padding(.bottom, 60)
                
                Spacer()
                
                if authViewModel.otpSent {
                    // OTP Verification View
                    otpVerificationView
                } else {
                    // Email Entry View
                    emailEntryView
                }
                
                Spacer()
                    .frame(height: 60)
            }
        }
    }
    
    // MARK: - Email Entry View
    
    var emailEntryView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                if isSignUp {
                    // Username field (only for sign up)
                    TextField("", text: $username)
                        .placeholder(when: username.isEmpty) {
                            Text("username")
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        }
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .username)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(ThemeManager.shared.colors.cardBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                        )
                }
                
                // Email field
                TextField("", text: $email)
                    .placeholder(when: email.isEmpty) {
                        Text("email")
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    }
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .focused($focusedField, equals: .email)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(ThemeManager.shared.colors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
                
                // Error message
                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 32)
            
            // Send code button
            Button(action: sendCode) {
                Group {
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    } else {
                        Text("send code")
                            .font(.system(size: 15, weight: .medium))
                            .tracking(2)
                    }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isEmailValid ? Color.white : Color.white.opacity(0.3))
                )
            }
            .disabled(authViewModel.isLoading || !isEmailValid)
            .padding(.horizontal, 32)
            
            // Toggle sign in/up
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSignUp.toggle()
                    authViewModel.errorMessage = nil
                }
            }) {
                Text(isSignUp ? "already have an account? **sign in**" : "new here? **create account**")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(ThemeManager.shared.colors.textSecondary)
            }
            .padding(.top, 8)
        }
    }
    
    // MARK: - OTP Verification View
    
    var otpVerificationView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("check your email")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                
                Text("we sent a code to \(authViewModel.pendingEmail)")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            
            // OTP Code Input - 8 digits
            HStack(spacing: 8) {
                ForEach(0..<8, id: \.self) { index in
                    OTPDigitBox(
                        digit: getDigit(at: index),
                        isFocused: otpCode.count == index
                    )
                }
            }
            .padding(.vertical, 8)
            .onTapGesture {
                focusedField = .otp
            }
            
            // Hidden text field for input
            TextField("", text: $otpCode)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .otp)
                .opacity(0)
                .frame(width: 1, height: 1)
                .onChange(of: otpCode) { _, newValue in
                    // Limit to 8 digits and only numbers
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count > 8 {
                        otpCode = String(filtered.prefix(8))
                    } else if filtered != newValue {
                        otpCode = filtered
                    }
                    // Auto-verify when 8 digits entered
                    if otpCode.count == 8 {
                        Task {
                            await authViewModel.verifyOTP(code: otpCode)
                        }
                    }
                }
            
            // Error message
            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            // Verify button
            Button(action: verifyCode) {
                Group {
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    } else {
                        Text("verify")
                            .font(.system(size: 15, weight: .medium))
                            .tracking(2)
                    }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(otpCode.count == 8 ? Color.white : Color.white.opacity(0.3))
                )
            }
            .disabled(authViewModel.isLoading || otpCode.count != 8)
            .padding(.horizontal, 32)
            
            // Resend & Back buttons
            HStack(spacing: 24) {
                Button(action: {
                    Task {
                        await authViewModel.resendOTP()
                    }
                }) {
                    Text("resend code")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(ThemeManager.shared.colors.textSecondary)
                }
                
                Button(action: {
                    authViewModel.cancelOTP()
                    otpCode = ""
                }) {
                    Text("back")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 32)
        .onAppear {
            focusedField = .otp
        }
    }
    
    // MARK: - Helper Functions
    
    var isEmailValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        let emailValid = emailPredicate.evaluate(with: email)
        
        if isSignUp {
            return emailValid && username.count >= 3
        }
        return emailValid
    }
    
    func getDigit(at index: Int) -> String {
        if index < otpCode.count {
            let stringIndex = otpCode.index(otpCode.startIndex, offsetBy: index)
            return String(otpCode[stringIndex])
        }
        return ""
    }
    
    func sendCode() {
        Task {
            await authViewModel.sendOTP(
                email: email,
                username: isSignUp ? username : nil,
                isSignUp: isSignUp
            )
        }
    }
    
    func verifyCode() {
        Task {
            await authViewModel.verifyOTP(code: otpCode)
        }
    }
}

// MARK: - OTP Digit Box

struct OTPDigitBox: View {
    let digit: String
    let isFocused: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(ThemeManager.shared.colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isFocused ? Color.white.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
                )
                .frame(width: 38, height: 48)
            
            Text(digit)
                .font(.system(size: 20, weight: .light))
                .foregroundColor(ThemeManager.shared.colors.textPrimary)
        }
    }
}

// MARK: - Placeholder Extension

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthViewModel())
}
