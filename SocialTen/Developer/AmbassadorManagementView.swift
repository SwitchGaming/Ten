//
//  AmbassadorManagementView.swift
//  SocialTen
//
//  Developer view for managing ambassadors
//

import SwiftUI

// MARK: - Models

struct AmbassadorInfo: Codable, Identifiable {
    let id: String
    let username: String
    let displayName: String
    let status: String
    let createdAt: String
    let invitedByName: String?
    let codesRedeemed: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case status
        case createdAt = "created_at"
        case invitedByName = "invited_by_name"
        case codesRedeemed = "codes_redeemed"
    }
}

struct PendingInvitation: Codable, Identifiable {
    let id: String
    let username: String
    let displayName: String
    let invitedAt: String
    let invitedByName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case invitedAt = "invited_at"
        case invitedByName = "invited_by_name"
    }
}

struct AmbassadorListResponse: Codable {
    let success: Bool
    let ambassadors: [AmbassadorInfo]?
    let pendingInvitations: [PendingInvitation]?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case ambassadors
        case pendingInvitations = "pending_invitations"
        case error
    }
}

struct InviteResponse: Codable {
    let success: Bool
    let displayName: String?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case displayName = "display_name"
        case error
    }
}

// MARK: - View

struct AmbassadorManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var ambassadors: [AmbassadorInfo] = []
    @State private var pendingInvitations: [PendingInvitation] = []
    @State private var isLoading = true
    @State private var searchUsername = ""
    @State private var inviteMessage = ""
    @State private var showInviteSheet = false
    @State private var isInviting = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var alertIsSuccess = false
    @State private var showRevokeConfirmation = false
    @State private var userToRevoke: AmbassadorInfo?
    
    // Gold theme colors for ambassador styling
    private let goldColor = Color(red: 1.0, green: 0.75, blue: 0.3)
    private let goldDark = Color(red: 0.8, green: 0.6, blue: 0.2)
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Invite Section
                        inviteSection
                        
                        // Pending Invitations
                        if !pendingInvitations.isEmpty {
                            pendingSection
                        }
                        
                        // Active Ambassadors
                        ambassadorsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
                
                if isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("Ambassadors")
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
            await loadAmbassadors()
        }
        .alert(alertIsSuccess ? "Success" : "Error", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog(
            "Revoke Ambassador Status",
            isPresented: $showRevokeConfirmation,
            titleVisibility: .visible
        ) {
            Button("Revoke", role: .destructive) {
                if let user = userToRevoke {
                    Task { await revokeAmbassador(username: user.username) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let user = userToRevoke {
                Text("Remove ambassador status from @\(user.username)?")
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            inviteSheet
        }
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: goldColor))
                    .scaleEffect(1.2)
                
                Text("loading...")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(themeManager.colors.textSecondary)
            }
            .padding(24)
            .background(themeManager.colors.cardBackground)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Invite Section
    
    private var inviteSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("invite ambassador")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(themeManager.colors.textTertiary)
                    .textCase(.uppercase)
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                // Username input
                HStack {
                    Text("@")
                        .foregroundColor(themeManager.colors.textTertiary)
                    
                    TextField("username", text: $searchUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundColor(themeManager.colors.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(themeManager.colors.cardBackground)
                .cornerRadius(12)
                
                // Invite button
                Button {
                    showInviteSheet = true
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 50, height: 50)
                        .background(
                            LinearGradient(
                                colors: [goldColor, goldDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                }
                .disabled(searchUsername.isEmpty)
                .opacity(searchUsername.isEmpty ? 0.5 : 1)
            }
        }
        .padding(20)
        .background(themeManager.colors.cardBackground.opacity(0.5))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(goldColor.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Invite Sheet
    
    private var inviteSheet: some View {
        NavigationView {
            ZStack {
                themeManager.colors.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // User preview
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(goldColor.opacity(0.2))
                                .frame(width: 80, height: 80)
                            
                            Text(searchUsername.prefix(1).lowercased())
                                .font(.system(size: 32, weight: .ultraLight))
                                .foregroundColor(goldColor)
                        }
                        
                        Text("@\(searchUsername)")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(themeManager.colors.textPrimary)
                    }
                    .padding(.top, 20)
                    
                    // Message input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("personal message (optional)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(themeManager.colors.textTertiary)
                        
                        TextEditor(text: $inviteMessage)
                            .frame(height: 120)
                            .padding(12)
                            .background(themeManager.colors.cardBackground)
                            .cornerRadius(12)
                            .foregroundColor(themeManager.colors.textPrimary)
                            .overlay(
                                Group {
                                    if inviteMessage.isEmpty {
                                        Text("Write a message to welcome them...")
                                            .foregroundColor(themeManager.colors.textTertiary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 20)
                                            .allowsHitTesting(false)
                                    }
                                },
                                alignment: .topLeading
                            )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Send invite button
                    Button {
                        Task { await sendInvite() }
                    } label: {
                        HStack(spacing: 8) {
                            if isInviting {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Image(systemName: "star.fill")
                                Text("Send Ambassador Invite")
                            }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [goldColor, goldDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                    }
                    .disabled(isInviting)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Invite Ambassador")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showInviteSheet = false
                    }
                    .foregroundColor(themeManager.colors.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Pending Section
    
    private var pendingSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("pending invitations")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(themeManager.colors.textTertiary)
                    .textCase(.uppercase)
                
                Spacer()
                
                Text("\(pendingInvitations.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(goldColor)
            }
            
            ForEach(pendingInvitations) { invitation in
                HStack(spacing: 12) {
                    Circle()
                        .fill(goldColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(invitation.displayName.prefix(1).lowercased())
                                .font(.system(size: 18, weight: .light))
                                .foregroundColor(goldColor)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(invitation.displayName.lowercased())
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(themeManager.colors.textPrimary)
                        
                        Text("@\(invitation.username) · awaiting response")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(themeManager.colors.textTertiary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundColor(goldColor.opacity(0.6))
                }
                .padding(16)
                .background(themeManager.colors.cardBackground)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Ambassadors Section
    
    private var ambassadorsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("active ambassadors")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(themeManager.colors.textTertiary)
                    .textCase(.uppercase)
                
                Spacer()
                
                Text("\(ambassadors.count)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(goldColor)
            }
            
            if ambassadors.isEmpty && !isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "star.circle")
                        .font(.system(size: 40))
                        .foregroundColor(themeManager.colors.textTertiary.opacity(0.5))
                    
                    Text("no ambassadors yet")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(themeManager.colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(ambassadors) { ambassador in
                    ambassadorRow(ambassador)
                }
            }
        }
    }
    
    private func ambassadorRow(_ ambassador: AmbassadorInfo) -> some View {
        HStack(spacing: 12) {
            // Avatar with gold ring
            ZStack {
                Circle()
                    .stroke(goldColor, lineWidth: 2)
                    .frame(width: 48, height: 48)
                
                Circle()
                    .fill(themeManager.colors.cardBackground)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(ambassador.displayName.prefix(1).lowercased())
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(goldColor)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(ambassador.displayName.lowercased())
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(themeManager.colors.textPrimary)
                    
                    // Ambassador badge
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                        Text("ambassador")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.5)
                    }
                    .foregroundColor(goldColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(goldColor.opacity(0.15))
                    .cornerRadius(6)
                }
                
                Text("@\(ambassador.username) · \(ambassador.codesRedeemed) codes redeemed")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(themeManager.colors.textTertiary)
            }
            
            Spacer()
            
            // Revoke button
            Button {
                userToRevoke = ambassador
                showRevokeConfirmation = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(themeManager.colors.textTertiary.opacity(0.5))
            }
        }
        .padding(16)
        .background(themeManager.colors.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(goldColor.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - API Calls
    
    private func loadAmbassadors() async {
        isLoading = true
        
        do {
            let response: AmbassadorListResponse = try await SupabaseManager.shared.client
                .rpc("list_ambassadors")
                .execute()
                .value
            
            await MainActor.run {
                if response.success {
                    ambassadors = response.ambassadors ?? []
                    pendingInvitations = response.pendingInvitations ?? []
                }
                isLoading = false
            }
        } catch {
            print("❌ Error loading ambassadors: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func sendInvite() async {
        isInviting = true
        
        do {
            let params: [String: String] = [
                "p_username": searchUsername,
                "p_developer_message": inviteMessage
            ]
            
            let response: InviteResponse = try await SupabaseManager.shared.client
                .rpc("invite_ambassador", params: params)
                .execute()
                .value
            
            await MainActor.run {
                isInviting = false
                showInviteSheet = false
                
                if response.success {
                    alertIsSuccess = true
                    alertMessage = "Invitation sent to \(response.displayName ?? searchUsername)!"
                    searchUsername = ""
                    inviteMessage = ""
                    Task { await loadAmbassadors() }
                } else {
                    alertIsSuccess = false
                    alertMessage = response.error ?? "Failed to send invitation"
                }
                showAlert = true
            }
        } catch {
            await MainActor.run {
                isInviting = false
                alertIsSuccess = false
                alertMessage = "Error: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func revokeAmbassador(username: String) async {
        isLoading = true
        
        do {
            let response: InviteResponse = try await SupabaseManager.shared.client
                .rpc("revoke_ambassador", params: ["p_username": username])
                .execute()
                .value
            
            await MainActor.run {
                if response.success {
                    alertIsSuccess = true
                    alertMessage = "Ambassador status revoked"
                    Task { await loadAmbassadors() }
                } else {
                    alertIsSuccess = false
                    alertMessage = response.error ?? "Failed to revoke"
                }
                showAlert = true
                isLoading = false
            }
        } catch {
            await MainActor.run {
                alertIsSuccess = false
                alertMessage = "Error: \(error.localizedDescription)"
                showAlert = true
                isLoading = false
            }
        }
    }
}

#Preview {
    AmbassadorManagementView()
}
