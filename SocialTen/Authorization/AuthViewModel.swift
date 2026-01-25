//
//  AuthViewModel.swift
//  SocialTen
//

import Foundation
import Supabase

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var isNewUser = false
    @Published var currentSession: Session?
    @Published var errorMessage: String?
    
    // OTP Flow State
    @Published var otpSent = false
    @Published var pendingEmail = ""
    @Published var pendingUsername = ""
    @Published var isSignUpFlow = false
    
    private let supabase = SupabaseManager.shared.client
    
    init() {
        Task {
            await checkSession()
        }
    }
    
    func checkSession() async {
        isLoading = true
        do {
            let session = try await supabase.auth.session
            self.currentSession = session
            self.isAuthenticated = true
            self.isNewUser = false
        } catch {
            self.currentSession = nil
            self.isAuthenticated = false
        }
        isLoading = false
    }
    
    // MARK: - Send OTP to Email
    
    func sendOTP(email: String, username: String? = nil, isSignUp: Bool) async {
        isLoading = true
        errorMessage = nil
        pendingEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        pendingUsername = username?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        isSignUpFlow = isSignUp
        
        do {
            // Check if username is taken (for sign up)
            if isSignUp, let username = username, !username.isEmpty {
                let existingUsers: [DBUser] = try await supabase
                    .from("users")
                    .select("id")
                    .eq("username", value: username.lowercased())
                    .execute()
                    .value
                
                if !existingUsers.isEmpty {
                    errorMessage = "Username is already taken"
                    isLoading = false
                    return
                }
            }
            
            // Send OTP email
            try await supabase.auth.signInWithOTP(
                email: pendingEmail,
                shouldCreateUser: isSignUp
            )
            
            otpSent = true
            errorMessage = nil
            
        } catch let error as AuthError {
            // Handle specific Supabase auth errors
            errorMessage = handleAuthError(error)
        } catch {
            // Show the actual error for debugging
            errorMessage = "Error: \(error.localizedDescription)"
            print("OTP Error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Verify OTP Code
    
    func verifyOTP(code: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await supabase.auth.verifyOTP(
                email: pendingEmail,
                token: code,
                type: .email
            )
            
            self.currentSession = session.session
            
            // If sign up flow, create user profile
            if isSignUpFlow && !pendingUsername.isEmpty {
                // Check if user profile already exists
                let existingUsers: [DBUser] = try await supabase
                    .from("users")
                    .select()
                    .eq("auth_id", value: session.user.id)
                    .execute()
                    .value
                
                if existingUsers.isEmpty {
                    // Create new user profile
                    let newUser = DBUser(
                        id: nil,
                        username: pendingUsername,
                        displayName: pendingUsername,
                        bio: "",
                        todayRating: nil,
                        ratingTimestamp: nil,
                        createdAt: nil,
                        authId: session.user.id,
                        premiumExpiresAt: nil,
                        selectedThemeId: nil,
                        isDeveloper: nil,
                        isAmbassador: nil
                    )
                    
                    try await supabase
                        .from("users")
                        .insert(newUser)
                        .execute()
                    
                    self.isNewUser = true
                } else {
                    self.isNewUser = false
                }
            } else {
                self.isNewUser = false
            }
            
            self.isAuthenticated = true
            self.otpSent = false
            self.pendingEmail = ""
            self.pendingUsername = ""
            
        } catch let error as AuthError {
            errorMessage = handleAuthError(error)
        } catch {
            errorMessage = "Invalid or expired code. Please try again."
            print("Verify OTP Error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Resend OTP
    
    func resendOTP() async {
        guard !pendingEmail.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.auth.signInWithOTP(
                email: pendingEmail,
                shouldCreateUser: isSignUpFlow
            )
            errorMessage = nil
        } catch let error as AuthError {
            errorMessage = handleAuthError(error)
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Cancel OTP Flow
    
    func cancelOTP() {
        otpSent = false
        pendingEmail = ""
        pendingUsername = ""
        errorMessage = nil
    }
    
    // MARK: - Sign Out
    
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            self.currentSession = nil
            self.isAuthenticated = false
            self.isNewUser = false
            self.otpSent = false
            self.pendingEmail = ""
            self.pendingUsername = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Delete Account with OTP Verification
    
    @Published var deleteOTPSent = false
    @Published var isDeleteFlow = false
    @Published var isDeleteLoading = false  // Separate loading state for delete flow
    
    /// Send OTP to user's email for account deletion verification (uses custom OTP system)
    func sendDeleteOTP() async -> Bool {
        print("🔐 sendDeleteOTP called")
        
        guard currentSession != nil else {
            print("🔐 No active session")
            errorMessage = "No active session"
            return false
        }
        
        // Use separate loading state to avoid dismissing the delete view
        isDeleteLoading = true
        errorMessage = nil
        isDeleteFlow = true
        
        do {
            // First, get the user's profile ID
            let users: [DBUser] = try await supabase
                .from("users")
                .select()
                .eq("auth_id", value: currentSession!.user.id)
                .execute()
                .value
            
            guard let userId = users.first?.id else {
                errorMessage = "User profile not found"
                isDeleteLoading = false
                return false
            }
            
            // Generate OTP using the database function
            let otpCode: String = try await supabase
                .rpc("generate_delete_otp", params: ["p_user_id": userId.uuidString])
                .execute()
                .value
            
            // Log OTP for development (remove in production when email is fully set up)
            print("Delete OTP Code: \(otpCode)")
            
            // Try to send via edge function (non-blocking)
            Task {
                do {
                    try await supabase.functions.invoke(
                        "send-delete-otp",
                        options: FunctionInvokeOptions(body: ["code": otpCode])
                    )
                } catch {
                    print("Edge function failed (email may not send): \(error)")
                }
            }
            
            deleteOTPSent = true
            isDeleteLoading = false
            return true
            
        } catch {
            errorMessage = "Failed to send verification code: \(error.localizedDescription)"
            print("Delete OTP Error: \(error)")
            isDeleteLoading = false
            return false
        }
    }
    
    /// Verify OTP and delete the account if successful (uses custom OTP system)
    func verifyDeleteOTP(code: String) async -> Bool {
        guard currentSession != nil else {
            errorMessage = "No active session"
            return false
        }
        
        isDeleteLoading = true
        errorMessage = nil
        
        do {
            // First, get the user's profile ID
            let users: [DBUser] = try await supabase
                .from("users")
                .select()
                .eq("auth_id", value: currentSession!.user.id)
                .execute()
                .value
            
            guard let userId = users.first?.id else {
                errorMessage = "User profile not found"
                isDeleteLoading = false
                return false
            }
            
            // Verify the OTP code using the custom function
            let isValid: Bool = try await supabase
                .rpc("verify_delete_otp", params: ["p_user_id": userId.uuidString, "p_code": code])
                .execute()
                .value
            
            if !isValid {
                errorMessage = "Invalid or expired verification code. Please try again."
                isDeleteLoading = false
                return false
            }
            
            // OTP verified successfully, now delete the account
            let success = await deleteAccount()
            
            // Reset delete flow state
            deleteOTPSent = false
            isDeleteFlow = false
            
            isDeleteLoading = false
            return success
            
        } catch {
            errorMessage = "Verification failed. Please try again."
            print("Delete OTP Verification Error: \(error)")
            isDeleteLoading = false
            return false
        }
    }
    
    /// Cancel the delete flow
    func cancelDeleteFlow() {
        deleteOTPSent = false
        isDeleteFlow = false
        errorMessage = nil
    }
    
    // MARK: - Delete Account (Internal)
    
    func deleteAccount() async -> Bool {
        guard let session = currentSession else {
            errorMessage = "No active session"
            return false
        }
        
        isDeleteLoading = true
        errorMessage = nil
        
        do {
            // First, get the user's profile ID from the users table
            let users: [DBUser] = try await supabase
                .from("users")
                .select()
                .eq("auth_id", value: session.user.id)
                .execute()
                .value
            
            guard let userId = users.first?.id else {
                errorMessage = "User profile not found"
                isDeleteLoading = false
                return false
            }
            
            // Call the database function to delete all user data
            try await supabase
                .rpc("delete_user_account", params: ["p_user_id": userId])
                .execute()
            
            // Sign out the user
            try await supabase.auth.signOut()
            
            // Reset all state
            self.currentSession = nil
            self.isAuthenticated = false
            self.isNewUser = false
            self.otpSent = false
            self.pendingEmail = ""
            self.pendingUsername = ""
            
            // Clear any local data
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            UserDefaults.standard.removeObject(forKey: "earnedBadges")
            UserDefaults.standard.removeObject(forKey: "deviceToken")
            UserDefaults.standard.removeObject(forKey: "notificationPreferences")
            UserDefaults.standard.removeObject(forKey: "badgeManager_lastUserId")
            // Clear all badge stats
            UserDefaults.standard.removeObject(forKey: "currentStreak")
            UserDefaults.standard.removeObject(forKey: "likesGiven")
            UserDefaults.standard.removeObject(forKey: "repliesGiven")
            UserDefaults.standard.removeObject(forKey: "vibesCreated")
            UserDefaults.standard.removeObject(forKey: "vibesJoined")
            UserDefaults.standard.removeObject(forKey: "nightRatings")
            UserDefaults.standard.removeObject(forKey: "morningRatings")
            UserDefaults.standard.removeObject(forKey: "daysActive")
            UserDefaults.standard.removeObject(forKey: "consecutiveSameRating")
            UserDefaults.standard.removeObject(forKey: "lastRating")
            UserDefaults.standard.removeObject(forKey: "lastRatingDate")
            UserDefaults.standard.removeObject(forKey: "totalRatings")
            UserDefaults.standard.removeObject(forKey: "weekendVibes")
            UserDefaults.standard.removeObject(forKey: "eveningVibes")
            
            isDeleteLoading = false
            return true
            
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            print("Delete account error: \(error)")
            isDeleteLoading = false
            return false
        }
    }

    // MARK dev tools

    func devAcc() {
        self.isAuthenticated = true
    }
    
    // MARK: - Error Handling

    private func handleAuthError(_ error: AuthError) -> String {
        let errorDescription = String(describing: error).lowercased()
        print("Auth Error: \(error)")
        
        if errorDescription.contains("email not confirmed") {
            return "Please check your email and confirm your account."
        } else if errorDescription.contains("invalid login") || errorDescription.contains("invalid credentials") {
            return "Invalid email or password."
        } else if errorDescription.contains("rate limit") {
            return "Too many requests. Please wait a minute and try again."
        } else if errorDescription.contains("user not found") {
            return "No account found with this email. Please sign up."
        } else if errorDescription.contains("already registered") || errorDescription.contains("already exists") {
            return "This email is already registered. Please sign in."
        } else if errorDescription.contains("invalid otp") || errorDescription.contains("token has expired") || errorDescription.contains("expired") {
            return "Invalid or expired code. Please try again."
        } else {
            return "Something went wrong. Please try again."
        }
    }
}
