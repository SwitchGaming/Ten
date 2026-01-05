//
//  VibeTab.swift
//  SocialTen
//

import SwiftUI

struct VibeTab: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @State private var showCreateVibe = false
    @State private var expandedVibeId: String? = nil
    @Binding var initialExpandedVibeId: String?
    
    init(initialExpandedVibeId: Binding<String?> = .constant(nil)) {
        _initialExpandedVibeId = initialExpandedVibeId
    }
    
    var activeVibes: [Vibe] {
        viewModel.getActiveVibes()
    }
    
    // Separate user's own vibes
    var myVibes: [Vibe] {
        activeVibes.filter { $0.userId == viewModel.currentUserProfile?.id }
    }
    
    var friendVibes: [Vibe] {
        activeVibes.filter { $0.userId != viewModel.currentUserProfile?.id }
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: ThemeManager.shared.spacing.xl) {
                // Header
                Text("vibes")
                    .font(ThemeManager.shared.fonts.title)
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                    .tracking(ThemeManager.shared.letterSpacing.wide)
                    .padding(.top, ThemeManager.shared.spacing.lg)
                
                // Create Vibe Card
                createVibeCard
                
                // My Vibes Section
                if !myVibes.isEmpty {
                    myVibesSection
                }
                
                // Friend Vibes Section
                if !friendVibes.isEmpty {
                    friendVibesSection
                }
                
                // Empty state
                if activeVibes.isEmpty {
                    emptyState
                }
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
        }
        .background(ThemeManager.shared.colors.background.ignoresSafeArea())
        .fullScreenCover(isPresented: $showCreateVibe) {
            CreateVibeSheet()
        }
        .onAppear {
            viewModel.markVibesAsSeen()
            // Expand the vibe if navigated from home
            if let vibeId = initialExpandedVibeId {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    expandedVibeId = vibeId
                }
                initialExpandedVibeId = nil
            }
        }
    }
    
    // MARK: - Create Vibe Card
    
    var createVibeCard: some View {
        Button(action: { showCreateVibe = true }) {
            DepthCard(depth: .low) {
                HStack(spacing: ThemeManager.shared.spacing.md) {
                    ZStack {
                        Circle()
                            .fill(ThemeManager.shared.colors.accent2.opacity(0.15))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(ThemeManager.shared.colors.accent2)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("start a vibe")
                            .font(ThemeManager.shared.fonts.body)
                            .foregroundColor(ThemeManager.shared.colors.textPrimary)
                        
                        Text("invite friends to hang")
                            .font(ThemeManager.shared.fonts.caption)
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                }
                .padding(ThemeManager.shared.spacing.md)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - My Vibes Section
    
    var myVibesSection: some View {
        VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.md) {
            Text("your vibes")
                .font(ThemeManager.shared.fonts.caption)
                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                .tracking(ThemeManager.shared.letterSpacing.wide)
                .textCase(.uppercase)
            
            ForEach(myVibes) { vibe in
                VibeCard(
                    vibe: vibe,
                    isExpanded: expandedVibeId == vibe.id,
                    onTap: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            expandedVibeId = expandedVibeId == vibe.id ? nil : vibe.id
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Friend Vibes Section
    
    var friendVibesSection: some View {
        VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.md) {
            Text("from friends")
                .font(ThemeManager.shared.fonts.caption)
                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                .tracking(ThemeManager.shared.letterSpacing.wide)
                .textCase(.uppercase)
            
            ForEach(friendVibes) { vibe in
                VibeCard(
                    vibe: vibe,
                    isExpanded: expandedVibeId == vibe.id,
                    onTap: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            expandedVibeId = expandedVibeId == vibe.id ? nil : vibe.id
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    var emptyState: some View {
        VStack(spacing: ThemeManager.shared.spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(ThemeManager.shared.colors.textTertiary)
            
            Text("no active vibes")
                .font(ThemeManager.shared.fonts.body)
                .foregroundColor(ThemeManager.shared.colors.textTertiary)
            
            Text("start one and invite friends!")
                .font(ThemeManager.shared.fonts.caption)
                .foregroundColor(ThemeManager.shared.colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ThemeManager.shared.spacing.xxl)
    }
}

// MARK: - Vibe Card

struct VibeCard: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @State private var selectedUser: User?
    @State private var glowAnimation = false
    let vibe: Vibe
    let isExpanded: Bool
    let onTap: () -> Void
    
    var creator: User? {
        viewModel.getUser(by: vibe.userId)
    }
    
    var isOwnVibe: Bool {
        vibe.userId == viewModel.currentUserProfile?.id
    }
    
    var userResponse: VibeResponseType? {
        viewModel.getUserVibeResponse(for: vibe.id)
    }
    
    // Check if this vibe's creator is premium (visible to everyone)
    var creatorIsPremium: Bool {
        creator?.isPremium ?? false
    }
    
    // Get the creator's theme glow color
    var creatorGlowColor: Color {
        creator?.selectedTheme.glowColor ?? ThemeManager.shared.colors.accent2
    }
    
    var yesUsers: [User] {
        var users = vibe.responses
            .filter { $0.response == .yes }
            .compactMap { viewModel.getUser(by: $0.userId) }
        
        // Always include the vibe creator at the beginning
        if let creator = creator, !users.contains(where: { $0.id == creator.id }) {
            users.insert(creator, at: 0)
        }
        
        return users
    }
    
    var noUsers: [User] {
        vibe.responses
            .filter { $0.response == .no }
            .compactMap { viewModel.getUser(by: $0.userId) }
    }
    
    var body: some View {
        DepthCard(depth: .low) {
            VStack(alignment: .leading, spacing: 0) {
                // Main content
                Button(action: onTap) {
                    HStack(spacing: ThemeManager.shared.spacing.md) {
                        // Icon with premium glow
                        ZStack {
                            // Premium glow effect (visible to everyone if creator is premium)
                            if creatorIsPremium {
                                Circle()
                                    .fill(creatorGlowColor)
                                    .frame(width: 40, height: 40)
                                    .blur(radius: glowAnimation ? 12 : 8)
                                    .opacity(glowAnimation ? 0.6 : 0.3)
                                    .scaleEffect(glowAnimation ? 1.3 : 1.1)
                            }
                            
                            Circle()
                                .fill(creatorIsPremium ? creatorGlowColor.opacity(0.3) : ThemeManager.shared.colors.accent2.opacity(0.15))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(creatorIsPremium ? creatorGlowColor : ThemeManager.shared.colors.accent2)
                        }
                        
                        // Title and info
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(vibe.title)
                                    .font(ThemeManager.shared.fonts.body)
                                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                                
                                if isOwnVibe {
                                    HStack(spacing: 4) {
                                        Text("· you")
                                            .font(ThemeManager.shared.fonts.caption)
                                            .foregroundColor(creatorIsPremium ? creatorGlowColor : ThemeManager.shared.colors.accent2)
                                        
                                        if creatorIsPremium {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(creatorGlowColor)
                                        }
                                    }
                                } else if creatorIsPremium {
                                    // Show ten+ badge for other premium users' vibes
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(creatorGlowColor)
                                }
                            }
                            
                            HStack(spacing: 8) {
                                if !isOwnVibe, let creatorName = creator?.displayName {
                                    Text(creatorName.lowercased())
                                        .font(ThemeManager.shared.fonts.caption)
                                        .foregroundColor(creatorIsPremium ? creatorGlowColor.opacity(0.8) : ThemeManager.shared.colors.textSecondary)
                                    
                                    Text("·")
                                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                }
                                
                                Text(vibe.timeDescription)
                                    .font(ThemeManager.shared.fonts.caption)
                                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                
                                Text("·")
                                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                
                                Text(vibe.location)
                                    .font(ThemeManager.shared.fonts.caption)
                                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                            }
                        }
                        
                        Spacer()
                        
                        // Response count
                        if vibe.yesCount > 0 {
                            HStack(spacing: 4) {
                                Text("\(vibe.yesCount)")
                                    .font(ThemeManager.shared.fonts.caption)
                                    .foregroundColor(.green)
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                    }
                    .padding(ThemeManager.shared.spacing.md)
                }
                .buttonStyle(.plain)
                
                // Expanded content
                if isExpanded {
                    expandedContent
                }
            }
        }
        .onAppear {
            if creatorIsPremium {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowAnimation = true
                }
            }
        }
    }
    
    var expandedContent: some View {
        VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.md) {
            Divider()
                .background(ThemeManager.shared.colors.cardBackground)
            
            // Who's in
            if !yesUsers.isEmpty {
                VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.sm) {
                    Text("who's in")
                        .font(ThemeManager.shared.fonts.caption)
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        .tracking(ThemeManager.shared.letterSpacing.wide)
                        .textCase(.uppercase)
                    
                    HStack(spacing: -8) {
                        ForEach(yesUsers.prefix(5)) { user in
                            Button(action: {
                                selectedUser = user
                            }) {
                                Circle()
                                    .fill(ThemeManager.shared.colors.background)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text(String(user.displayName.prefix(1)).lowercased())
                                            .font(.system(size: 12, weight: .light))
                                            .foregroundColor(ThemeManager.shared.colors.textSecondary)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.green.opacity(0.4), lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if yesUsers.count > 5 {
                            Circle()
                                .fill(ThemeManager.shared.colors.background)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text("+\(yesUsers.count - 5)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(ThemeManager.shared.colors.textSecondary)
                                )
                        }
                    }
                }
            }
            
            // Who's not going
            if !noUsers.isEmpty {
                VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.sm) {
                    Text("can't make it")
                        .font(ThemeManager.shared.fonts.caption)
                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                        .tracking(ThemeManager.shared.letterSpacing.wide)
                        .textCase(.uppercase)
                    
                    HStack(spacing: -8) {
                        ForEach(noUsers.prefix(5)) { user in
                            Button(action: {
                                selectedUser = user
                            }) {
                                Circle()
                                    .fill(ThemeManager.shared.colors.background)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text(String(user.displayName.prefix(1)).lowercased())
                                            .font(.system(size: 12, weight: .light))
                                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.red.opacity(0.3), lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if noUsers.count > 5 {
                            Circle()
                                .fill(ThemeManager.shared.colors.background)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text("+\(noUsers.count - 5)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                )
                        }
                    }
                }
            }
            
            // Response buttons or Edit/Delete for own vibes
            if isOwnVibe {
                HStack(spacing: ThemeManager.shared.spacing.sm) {
                    Button(action: {
                        Task {
                            await viewModel.deleteVibe(vibe.id)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                            Text("delete")
                                .font(ThemeManager.shared.fonts.caption)
                        }
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.horizontal, ThemeManager.shared.spacing.md)
                        .padding(.vertical, ThemeManager.shared.spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: ThemeManager.shared.radius.sm)
                                .fill(Color.red.opacity(0.1))
                        )
                    }
                }
            } else {
                HStack(spacing: ThemeManager.shared.spacing.sm) {
                    VibeResponseButton(
                        text: "i'm in",
                        isSelected: userResponse == .yes,
                        color: .green
                    ) {
                        Task {
                            await viewModel.respondToVibe(vibe.id, response: .yes)
                        }
                    }
                    
                    VibeResponseButton(
                        text: "can't",
                        isSelected: userResponse == .no,
                        color: .red
                    ) {
                        Task {
                            await viewModel.respondToVibe(vibe.id, response: .no)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, ThemeManager.shared.spacing.md)
        .padding(.bottom, ThemeManager.shared.spacing.md)
        .fullScreenCover(item: $selectedUser) { user in
            UserProfileView(
                user: user,
                isFriend: viewModel.friends.contains { $0.id == user.id },
                showAddButton: !viewModel.friends.contains { $0.id == user.id } && user.id != viewModel.currentUserProfile?.id,
                onAddFriend: {
                    await viewModel.sendFriendRequest(toUserId: user.id)
                },
                onRemoveFriend: user.id != viewModel.currentUserProfile?.id ? {
                    Task {
                        await viewModel.removeFriend(user.id)
                    }
                } : nil
            )
            .environmentObject(viewModel)
            .environmentObject(BadgeManager.shared)
        }
    }
}

// MARK: - Vibe Response Button

struct VibeResponseButton: View {
    let text: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(ThemeManager.shared.fonts.caption)
                .foregroundColor(isSelected ? color : ThemeManager.shared.colors.textSecondary)
                .padding(.horizontal, ThemeManager.shared.spacing.md)
                .padding(.vertical, ThemeManager.shared.spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: ThemeManager.shared.radius.sm)
                        .fill(isSelected ? color.opacity(0.15) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: ThemeManager.shared.radius.sm)
                                .stroke(isSelected ? color.opacity(0.4) : ThemeManager.shared.colors.textTertiary.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Create Vibe Sheet

struct CreateVibeSheet: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var selectedTime: VibeTimePreset = .in5
    @State private var customTime: Date = Date().addingTimeInterval(30 * 60)
    @State private var showTimePicker = false
    @State private var location = ""
    @State private var showMaxVibesAlert = false
    
    @FocusState private var titleFocused: Bool
    @FocusState private var locationFocused: Bool
    
    var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var timeDescription: String {
        if selectedTime == .custom {
            let calendar = Calendar.current
            let formatter = DateFormatter()
            
            if calendar.isDateInToday(customTime) {
                // Today - just show time
                formatter.timeStyle = .short
                return "at \(formatter.string(from: customTime))"
            } else if calendar.isDateInTomorrow(customTime) {
                // Tomorrow
                formatter.timeStyle = .short
                return "tomorrow at \(formatter.string(from: customTime))"
            } else {
                // Another day
                formatter.dateFormat = "MMM d 'at' h:mm a"
                return formatter.string(from: customTime).lowercased()
            }
        }
        return selectedTime.rawValue
    }
    var body: some View {
        ZStack {
            ThemeManager.shared.colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
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
                    
                    Text("new vibe")
                        .font(ThemeManager.shared.fonts.body)
                        .foregroundColor(ThemeManager.shared.colors.textPrimary)
                        .tracking(ThemeManager.shared.letterSpacing.wide)
                    
                    Spacer()
                    
                    Button(action: createVibe) {
                        Text("send")
                            .font(ThemeManager.shared.fonts.caption)
                            .foregroundColor(canCreate ? ThemeManager.shared.colors.accent2 : ThemeManager.shared.colors.textTertiary)
                    }
                    .disabled(!canCreate)
                    .frame(width: 40)
                }
                .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
                .padding(.top, ThemeManager.shared.spacing.lg)
                .padding(.bottom, ThemeManager.shared.spacing.xl)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: ThemeManager.shared.spacing.xl) {
                        // Title Input
                        VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.sm) {
                            HStack {
                                Text("what's the vibe?")
                                    .font(ThemeManager.shared.fonts.caption)
                                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                    .tracking(ThemeManager.shared.letterSpacing.wide)
                                    .textCase(.uppercase)
                                
                                Spacer()
                                
                                Text("\(title.count)/30")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(title.count > 30 ? .red : ThemeManager.shared.colors.textTertiary)
                            }
                            
                            TextField("", text: $title)
                                .placeholder(when: title.isEmpty) {
                                    Text("basketball? coffee? study?")
                                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                }
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(ThemeManager.shared.colors.textPrimary)
                                .focused($titleFocused)
                                .onChange(of: title) { _, newValue in
                                    if newValue.count > 30 {
                                        title = String(newValue.prefix(30))
                                    }
                                }
                        }
                        
                        // Time Selection
                        VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.sm) {
                            Text("when?")
                                .font(ThemeManager.shared.fonts.caption)
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                .tracking(ThemeManager.shared.letterSpacing.wide)
                                .textCase(.uppercase)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: ThemeManager.shared.spacing.sm) {
                                    ForEach(VibeTimePreset.allCases, id: \.self) { preset in
                                        TimePresetChip(
                                            text: preset == .custom && selectedTime == .custom ? timeDescription : preset.rawValue,
                                            isSelected: selectedTime == preset
                                        ) {
                                            withAnimation(.spring(response: 0.3)) {
                                                selectedTime = preset
                                                if preset == .custom {
                                                    showTimePicker = true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Location Input
                        VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.sm) {
                            HStack {
                                Text("where?")
                                    .font(ThemeManager.shared.fonts.caption)
                                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                    .tracking(ThemeManager.shared.letterSpacing.wide)
                                    .textCase(.uppercase)
                                
                                Spacer()
                                
                                Text("\(location.count)/30")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(location.count > 30 ? .red : ThemeManager.shared.colors.textTertiary)
                            }
                            
                            TextField("", text: $location)
                                .placeholder(when: location.isEmpty) {
                                    Text("my place, the court, cafe...")
                                        .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                }
                                .font(.system(size: 20, weight: .light))
                                .foregroundColor(ThemeManager.shared.colors.textPrimary)
                                .focused($locationFocused)
                                .onChange(of: location) { _, newValue in
                                    if newValue.count > 30 {
                                        location = String(newValue.prefix(30))
                                    }
                                }
                        }
                        // Preview
                        if canCreate {
                            VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.sm) {
                                Text("preview")
                                    .font(ThemeManager.shared.fonts.caption)
                                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                    .tracking(ThemeManager.shared.letterSpacing.wide)
                                    .textCase(.uppercase)
                                
                                DepthCard(depth: .low) {
                                    HStack {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 14))
                                            .foregroundColor(ThemeManager.shared.colors.accent2)
                                        
                                        Text(title)
                                            .font(ThemeManager.shared.fonts.body)
                                            .foregroundColor(ThemeManager.shared.colors.textPrimary)
                                        
                                        Text("·")
                                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                        
                                        Text(timeDescription)
                                            .font(ThemeManager.shared.fonts.caption)
                                            .foregroundColor(ThemeManager.shared.colors.textSecondary)
                                        
                                        Text("·")
                                            .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                        
                                        Text(location)
                                            .font(ThemeManager.shared.fonts.caption)
                                            .foregroundColor(ThemeManager.shared.colors.textSecondary)
                                        
                                        Spacer()
                                    }
                                    .padding(ThemeManager.shared.spacing.md)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
                }
            }
            
            // Date & Time Picker Overlay
            if showTimePicker {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showTimePicker = false
                        }
                    }
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button("Cancel") {
                            withAnimation {
                                showTimePicker = false
                                if selectedTime == .custom {
                                    selectedTime = .in5
                                }
                            }
                        }
                        .font(ThemeManager.shared.fonts.body)
                        .foregroundColor(ThemeManager.shared.colors.textSecondary)
                        
                        Spacer()
                        
                        Text("choose date & time")
                            .font(ThemeManager.shared.fonts.body)
                            .foregroundColor(ThemeManager.shared.colors.textPrimary)
                        
                        Spacer()
                        
                        Button("Done") {
                            withAnimation {
                                showTimePicker = false
                            }
                        }
                        .font(ThemeManager.shared.fonts.body)
                        .foregroundColor(ThemeManager.shared.colors.accent2)
                    }
                    .padding()
                    .background(ThemeManager.shared.colors.cardBackground)
                    
                    DatePicker(
                        "",
                        selection: $customTime,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding()
                    .background(ThemeManager.shared.colors.background)
                }
                .background(ThemeManager.shared.colors.background)
                .cornerRadius(20)
                .padding(.horizontal, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            titleFocused = true
        }
        .alert("Maximum Vibes Reached", isPresented: $showMaxVibesAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You can only have 5 active vibes at a time. Wait for one to expire or delete an existing vibe.")
        }
    }
    
    func createVibe() {
        // Check if user already has 5 active vibes
        let activeVibeCount = viewModel.getActiveVibes().filter { $0.userId == viewModel.currentUserProfile?.id }.count
        if activeVibeCount >= 5 {
            showMaxVibesAlert = true
            return
        }
        
        // Calculate the actual expiration time
        let expiresAt: Date
        switch selectedTime {
        case .in5:
            expiresAt = Date().addingTimeInterval(35 * 60) // 5 min + 30 min buffer
        case .in1hr:
            expiresAt = Date().addingTimeInterval(90 * 60) // 1 hr + 30 min buffer
        case .custom:
            // Use the custom time + 30 min buffer for the event
            expiresAt = customTime.addingTimeInterval(30 * 60)
        }
        
        // Capture values before dismissing
        let vibeTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let vibeTimeDescription = timeDescription
        let vibeLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Dismiss immediately for instant feedback
        dismiss()
        
        // Create vibe in background (optimistic update happens in viewModel)
        Task {
            await viewModel.createVibe(
                title: vibeTitle,
                timeDescription: vibeTimeDescription,
                location: vibeLocation,
                expiresAt: expiresAt
            )
        }
    }
}

// MARK: - Time Preset Chip

struct TimePresetChip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(ThemeManager.shared.fonts.caption)
                .foregroundColor(isSelected ? ThemeManager.shared.colors.accent2 : ThemeManager.shared.colors.textSecondary)
                .padding(.horizontal, ThemeManager.shared.spacing.md)
                .padding(.vertical, ThemeManager.shared.spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: ThemeManager.shared.radius.full)
                        .fill(isSelected ? ThemeManager.shared.colors.accent2.opacity(0.15) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: ThemeManager.shared.radius.full)
                                .stroke(isSelected ? ThemeManager.shared.colors.accent2.opacity(0.4) : ThemeManager.shared.colors.textTertiary.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
}

#Preview {
    VibeTab()
        .environmentObject(SupabaseAppViewModel())
}
