import SwiftUI

/// A gentle, multi-step check-in walkthrough for users who may be struggling
struct CheckInWalkthroughView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @ObservedObject var checkInManager = CheckInManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var currentStep: CheckInStep = .welcome
    @State private var notifyFriend = true  // Default ON
    @State private var reflectionText = ""
    @State private var gratitudeText = ""
    @State private var selectedPrompt: String = CheckInManager.getRandomCheckInPrompt()
    @State private var selectedGratitudePrompt: String = CheckInManager.getRandomGratitudePrompt()
    
    private var hasBestFriend: Bool {
        checkInManager.currentSession?.hasBestFriend ?? false
    }
    
    private var bestFriendName: String {
        checkInManager.currentSession?.bestFriendName ?? "your friend"
    }
    
    private var colors: ThemeColors {
        themeManager.colors
    }
    
    var body: some View {
        ZStack {
            // Theme background
            colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with close button and progress
                headerView
                
                // Content
                TabView(selection: $currentStep) {
                    welcomeStep
                        .tag(CheckInStep.welcome)
                    
                    acknowledgmentStep
                        .tag(CheckInStep.acknowledgment)
                    
                    if hasBestFriend {
                        friendNoticeStep
                            .tag(CheckInStep.friendNotice)
                    }
                    
                    reflectionStep
                        .tag(CheckInStep.reflection)
                    
                    gratitudeStep
                        .tag(CheckInStep.gratitude)
                    
                    closingStep
                        .tag(CheckInStep.closing)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button(action: { skipCheckIn() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(colors.cardBackground)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Progress dots
            HStack(spacing: 6) {
                ForEach(stepsToShow, id: \.rawValue) { step in
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? colors.accent1 : colors.textTertiary.opacity(0.3))
                        .frame(width: step.rawValue == currentStep.rawValue ? 8 : 6, height: step.rawValue == currentStep.rawValue ? 8 : 6)
                }
            }
            
            Spacer()
            
            // Placeholder for symmetry
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    private var stepsToShow: [CheckInStep] {
        var steps = CheckInStep.allCases
        if !hasBestFriend {
            steps.removeAll { $0 == .friendNotice }
        }
        return steps
    }
    
    // MARK: - Welcome Step
    
    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                // Liquid glass icon container
                ZStack {
                    Circle()
                        .fill(colors.accent1.opacity(0.15))
                        .frame(width: 88, height: 88)
                        .blur(radius: 1)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [colors.cardBackground, colors.cardBackground.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(colors.accent1.opacity(0.3), lineWidth: 1)
                        )
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(colors.accent1)
                }
                
                VStack(spacing: 12) {
                    Text("checking in")
                        .font(.system(size: 28, weight: .light))
                        .tracking(2)
                        .foregroundColor(colors.textPrimary)
                    
                    Text("your recent ratings have been lower than usual.\nlet's take a moment together.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                }
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                primaryButton(title: "i'm ready") { nextStep() }
                
                Button(action: { skipCheckIn() }) {
                    Text("not right now")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(colors.textTertiary)
                }
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Acknowledgment Step
    
    private var acknowledgmentStep: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(colors.accent2.opacity(0.15))
                        .frame(width: 88, height: 88)
                        .blur(radius: 1)
                    
                    Circle()
                        .fill(colors.cardBackground)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(colors.accent2.opacity(0.3), lineWidth: 1)
                        )
                    
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(colors.textPrimary, colors.accent2)
                }
                
                VStack(spacing: 12) {
                    Text("it's okay")
                        .font(.system(size: 28, weight: .light))
                        .tracking(2)
                        .foregroundColor(colors.textPrimary)
                    
                    Text("some days are harder than others.\nyour feelings are valid, and this will pass.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                }
            }
            
            Spacer()
            
            primaryButton(title: "continue") { nextStep() }
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Friend Notice Step
    
    private var friendNoticeStep: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(colors.accent1.opacity(0.15))
                        .frame(width: 88, height: 88)
                        .blur(radius: 1)
                    
                    Circle()
                        .fill(colors.cardBackground)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(colors.accent1.opacity(0.3), lineWidth: 1)
                        )
                    
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 30, weight: .light))
                        .foregroundColor(colors.accent1)
                }
                
                VStack(spacing: 12) {
                    Text("you have people")
                        .font(.system(size: 28, weight: .light))
                        .tracking(2)
                        .foregroundColor(colors.textPrimary)
                    
                    Text("we can send \(bestFriendName) a gentle nudge\nto check in on you. no details shared.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)
                }
            }
            
            // Friend notification toggle - cleaner design
            VStack(spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        notifyFriend.toggle()
                    }
                }) {
                    HStack(spacing: 14) {
                        // Friend icon/avatar placeholder
                        Circle()
                            .fill(colors.accent1.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(String(bestFriendName.prefix(1)).uppercased())
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(colors.accent1)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("notify \(bestFriendName)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(colors.textPrimary)
                            
                            Text(notifyFriend ? "they'll get a gentle heads up" : "won't be notified")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(colors.textTertiary)
                        }
                        
                        Spacer()
                        
                        // Custom toggle indicator
                        ZStack {
                            Capsule()
                                .fill(notifyFriend ? colors.accent1 : colors.textTertiary.opacity(0.3))
                                .frame(width: 48, height: 28)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 22, height: 22)
                                .offset(x: notifyFriend ? 10 : -10)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(colors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(notifyFriend ? colors.accent1.opacity(0.4) : colors.textTertiary.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            
            Spacer()
            
            primaryButton(title: "continue") { nextStep() }
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Reflection Step
    
    private var reflectionStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            
            // Privacy notice
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                Text("private · not saved")
                    .font(.system(size: 12, weight: .medium))
                    .tracking(0.5)
            }
            .foregroundColor(colors.textTertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(colors.cardBackground)
            .cornerRadius(12)
            
            Spacer(minLength: 24)
            
            // Prompt card with centered text area
            VStack(spacing: 0) {
                // Prompt text
                Text(selectedPrompt)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                
                // Text input area
                ZStack {
                    if reflectionText.isEmpty {
                        Text("take your time...")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(colors.textTertiary.opacity(0.5))
                    }
                    
                    TextEditor(text: $reflectionText)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .foregroundColor(colors.textSecondary)
                        .font(.system(size: 16, weight: .regular))
                        .multilineTextAlignment(.center)
                        .frame(height: 100)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                
                // Shuffle button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPrompt = CheckInManager.getRandomCheckInPrompt()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 12))
                        Text("different question")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(colors.textTertiary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(colors.background)
                    .cornerRadius(12)
                }
                .padding(.bottom, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(colors.accent1.opacity(0.15), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
            
            Spacer()
            
            primaryButton(title: "continue") { nextStep() }
                .padding(.bottom, 40)
        }
    }
    
    // MARK: - Gratitude Step
    
    private var gratitudeStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            
            // Section title
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(colors.accent2)
                
                Text("finding light")
                    .font(.system(size: 14, weight: .medium))
                    .tracking(2)
                    .foregroundColor(colors.textTertiary)
                    .textCase(.uppercase)
            }
            
            Spacer(minLength: 24)
            
            // Gratitude prompt card
            VStack(spacing: 0) {
                Text(selectedGratitudePrompt)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                
                // Text input area
                ZStack {
                    if gratitudeText.isEmpty {
                        Text("even something tiny...")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(colors.textTertiary.opacity(0.5))
                    }
                    
                    TextEditor(text: $gratitudeText)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .foregroundColor(colors.textSecondary)
                        .font(.system(size: 16, weight: .regular))
                        .multilineTextAlignment(.center)
                        .frame(height: 100)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                
                // Shuffle button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedGratitudePrompt = CheckInManager.getRandomGratitudePrompt()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 12))
                        Text("different question")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(colors.textTertiary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(colors.background)
                    .cornerRadius(12)
                }
                .padding(.bottom, 20)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(colors.accent2.opacity(0.15), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
            
            // Privacy note
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                Text("just for you")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(colors.textTertiary.opacity(0.6))
            .padding(.top, 12)
            
            Spacer()
            
            primaryButton(title: "continue") { nextStep() }
                .padding(.bottom, 40)
        }
    }
    
    // MARK: - Closing Step
    
    private var closingStep: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(colors.accent1.opacity(0.15))
                        .frame(width: 88, height: 88)
                        .blur(radius: 1)
                    
                    Circle()
                        .fill(colors.cardBackground)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(colors.accent1.opacity(0.3), lineWidth: 1)
                        )
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(colors.accent2)
                }
                
                VStack(spacing: 12) {
                    Text("you matter")
                        .font(.system(size: 28, weight: .light))
                        .tracking(2)
                        .foregroundColor(colors.textPrimary)
                    
                    Text("tough days don't last forever.\nyou don't have to face them alone.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                }
                
                // Friend notification confirmation
                if notifyFriend && hasBestFriend {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(colors.accent1)
                        Text("\(bestFriendName) will be notified")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(colors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(colors.cardBackground)
                    .cornerRadius(12)
                    .padding(.top, 8)
                }
            }
            
            Spacer()
            
            primaryButton(title: "done") { completeCheckIn() }
                .padding(.bottom, 40)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Helper Views
    
    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .tracking(1)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 26)
                        .fill(
                            LinearGradient(
                                colors: [colors.accent1, colors.accent2],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Actions
    
    private func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentStep {
            case .welcome:
                currentStep = .acknowledgment
            case .acknowledgment:
                currentStep = hasBestFriend ? .friendNotice : .reflection
            case .friendNotice:
                currentStep = .reflection
            case .reflection:
                currentStep = .gratitude
            case .gratitude:
                currentStep = .closing
            case .closing:
                completeCheckIn()
            }
        }
    }
    
    private func skipCheckIn() {
        checkInManager.skipCheckIn()
        dismiss()
    }
    
    private func completeCheckIn() {
        // Notify friend if opted in
        if notifyFriend && hasBestFriend {
            Task {
                await viewModel.sendCheckInAlert()
            }
        }
        
        checkInManager.completeCheckIn()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    CheckInWalkthroughView()
        .environmentObject(SupabaseAppViewModel())
}
