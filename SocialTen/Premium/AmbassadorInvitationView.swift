//
//  AmbassadorInvitationView.swift
//  SocialTen
//
//  Celebration sheet when a user receives an ambassador invitation
//

import SwiftUI

// MARK: - Invitation Model

struct AmbassadorInvitation: Codable {
    let hasInvitation: Bool
    let invitationId: String?
    let developerName: String?
    let developerUsername: String?
    let developerMessage: String?
    let invitedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case hasInvitation = "has_invitation"
        case invitationId = "invitation_id"
        case developerName = "developer_name"
        case developerUsername = "developer_username"
        case developerMessage = "developer_message"
        case invitedAt = "invited_at"
    }
    
    static let none = AmbassadorInvitation(
        hasInvitation: false,
        invitationId: nil,
        developerName: nil,
        developerUsername: nil,
        developerMessage: nil,
        invitedAt: nil
    )
}

struct InvitationResponseResult: Codable {
    let success: Bool
    let status: String?
    let error: String?
}

// MARK: - Invitation Manager

class AmbassadorInvitationManager: ObservableObject {
    static let shared = AmbassadorInvitationManager()
    
    @Published var pendingInvitation: AmbassadorInvitation?
    @Published var showInvitationSheet = false
    
    private init() {}
    
    func checkForInvitation() async {
        do {
            let response: AmbassadorInvitation = try await SupabaseManager.shared.client
                .rpc("check_ambassador_invitation")
                .execute()
                .value
            
            await MainActor.run {
                if response.hasInvitation {
                    self.pendingInvitation = response
                    self.showInvitationSheet = true
                } else {
                    self.pendingInvitation = nil
                }
            }
        } catch {
            print("❌ Error checking ambassador invitation: \(error)")
        }
    }
    
    func respondToInvitation(accept: Bool) async -> Bool {
        do {
            let response: InvitationResponseResult = try await SupabaseManager.shared.client
                .rpc("respond_to_ambassador_invitation", params: ["p_accept": accept])
                .execute()
                .value
            
            await MainActor.run {
                if response.success {
                    self.pendingInvitation = nil
                    self.showInvitationSheet = false
                }
            }
            
            return response.success
        } catch {
            print("❌ Error responding to invitation: \(error)")
            return false
        }
    }
}

// MARK: - Invitation View

struct AmbassadorInvitationView: View {
    let invitation: AmbassadorInvitation
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var invitationManager = AmbassadorInvitationManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var showContent = false
    @State private var showPerks = false
    @State private var showButtons = false
    @State private var isResponding = false
    @State private var starRotation: Double = 0
    @State private var glowPulse = false
    @State private var particlePhase: CGFloat = 0
    
    // Gold theme colors
    private let goldLight = Color(red: 1.0, green: 0.85, blue: 0.4)
    private let goldPrimary = Color(red: 1.0, green: 0.75, blue: 0.3)
    private let goldDark = Color(red: 0.85, green: 0.6, blue: 0.2)
    private let goldDeep = Color(red: 0.6, green: 0.4, blue: 0.15)
    
    var body: some View {
        ZStack {
            // Background
            backgroundGradient
            
            // Floating particles
            floatingParticles
            
            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 60)
                    
                    // Star emblem
                    starEmblem
                        .padding(.bottom, 32)
                    
                    // Main text
                    if showContent {
                        mainContent
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    
                    // Perks section
                    if showPerks {
                        perksSection
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .padding(.top, 40)
                    }
                    
                    // Buttons
                    if showButtons {
                        buttonsSection
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .padding(.top, 48)
                    }
                    
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 32)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            // Base dark
            Color.black.ignoresSafeArea()
            
            // Gold radial glow from center
            RadialGradient(
                colors: [
                    goldDark.opacity(0.3),
                    goldDeep.opacity(0.1),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            // Top glow
            RadialGradient(
                colors: [
                    goldPrimary.opacity(glowPulse ? 0.15 : 0.08),
                    Color.clear
                ],
                center: .top,
                startRadius: 100,
                endRadius: 500
            )
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Floating Particles
    
    private var floatingParticles: some View {
        GeometryReader { geometry in
            ForEach(0..<20, id: \.self) { i in
                Circle()
                    .fill(goldPrimary.opacity(Double.random(in: 0.1...0.3)))
                    .frame(width: CGFloat.random(in: 2...6))
                    .position(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: geometry.size.height - (particlePhase * geometry.size.height * 1.5 + CGFloat(i * 50)).truncatingRemainder(dividingBy: geometry.size.height * 1.5)
                    )
            }
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Star Emblem
    
    private var starEmblem: some View {
        ZStack {
            // Outer glow rings
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(
                        goldPrimary.opacity(0.1 - Double(i) * 0.03),
                        lineWidth: 1
                    )
                    .frame(width: 160 + CGFloat(i * 40), height: 160 + CGFloat(i * 40))
                    .opacity(glowPulse ? 1 : 0.5)
            }
            
            // Main glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            goldPrimary.opacity(0.4),
                            goldDark.opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .blur(radius: 20)
            
            // Star container
            ZStack {
                // Background circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [goldPrimary, goldDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: goldPrimary.opacity(0.5), radius: 20, x: 0, y: 10)
                
                // Star icon
                Image(systemName: "star.fill")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundColor(.black.opacity(0.8))
                    .rotationEffect(.degrees(starRotation))
            }
        }
        .scaleEffect(showContent ? 1 : 0.5)
        .opacity(showContent ? 1 : 0)
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(spacing: 20) {
            Text("you've been chosen")
                .font(.system(size: 14, weight: .semibold))
                .tracking(4)
                .foregroundColor(goldPrimary)
                .textCase(.uppercase)
            
            Text("ambassador")
                .font(.system(size: 42, weight: .ultraLight))
                .tracking(2)
                .foregroundColor(.white)
            
            // Developer message
            if let developerName = invitation.developerName {
                VStack(spacing: 16) {
                    Text("invited by \(developerName.lowercased())")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.white.opacity(0.6))
                    
                    if let message = invitation.developerMessage, !message.isEmpty {
                        VStack(spacing: 12) {
                            Text("\"")
                                .font(.system(size: 32, weight: .ultraLight))
                                .foregroundColor(goldPrimary.opacity(0.5))
                            
                            Text(message)
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 20)
                            
                            Text("— \(developerName)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(goldPrimary.opacity(0.8))
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Perks Section
    
    private var perksSection: some View {
        VStack(spacing: 20) {
            Text("ambassador perks")
                .font(.system(size: 11, weight: .semibold))
                .tracking(3)
                .foregroundColor(goldPrimary.opacity(0.8))
                .textCase(.uppercase)
            
            VStack(spacing: 16) {
                perkRow(icon: "ticket.fill", title: "referral codes", description: "Generate up to 5 premium codes per week")
                perkRow(icon: "gift.fill", title: "gift premium", description: "Share ten+ with friends & community")
                perkRow(icon: "star.circle.fill", title: "ambassador badge", description: "Exclusive badge on your profile")
                perkRow(icon: "crown.fill", title: "recognition", description: "Be part of the ten community leaders")
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(goldPrimary.opacity(0.15), lineWidth: 1)
                )
        )
    }
    
    private func perkRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(goldPrimary.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(goldPrimary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title.lowercased())
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
        }
    }
    
    // MARK: - Buttons Section
    
    private var buttonsSection: some View {
        VStack(spacing: 16) {
            // Accept button
            Button {
                Task { await respondToInvitation(accept: true) }
            } label: {
                HStack(spacing: 10) {
                    if isResponding {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Accept & Become Ambassador")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [goldLight, goldPrimary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: goldPrimary.opacity(0.4), radius: 16, x: 0, y: 8)
            }
            .disabled(isResponding)
            
            // Decline button
            Button {
                Task { await respondToInvitation(accept: false) }
            } label: {
                Text("Decline")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.vertical, 12)
            }
            .disabled(isResponding)
        }
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        // Star rotation
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            starRotation = 360
        }
        
        // Glow pulse
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            glowPulse = true
        }
        
        // Particle animation
        withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
            particlePhase = 1
        }
        
        // Content reveal sequence
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
            showContent = true
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8)) {
            showPerks = true
        }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.2)) {
            showButtons = true
        }
    }
    
    // MARK: - Response Handler
    
    private func respondToInvitation(accept: Bool) async {
        isResponding = true
        
        let success = await invitationManager.respondToInvitation(accept: accept)
        
        await MainActor.run {
            isResponding = false
            if success {
                // Refresh premium manager to update ambassador status
                if accept {
                    Task {
                        await PremiumManager.shared.checkAmbassadorStatus()
                    }
                }
                onComplete()
                dismiss()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AmbassadorInvitationView(
        invitation: AmbassadorInvitation(
            hasInvitation: true,
            invitationId: "123",
            developerName: "Joe",
            developerUsername: "joe",
            developerMessage: "You've been an amazing member of the ten community. I'd love for you to help spread the word and bring more awesome people into our circle.",
            invitedAt: nil
        ),
        onComplete: {}
    )
}
