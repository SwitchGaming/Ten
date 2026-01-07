//
//  VibeTab.swift
//  SocialTen
//

import SwiftUI

struct VibeTab: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
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
            VStack(spacing: themeManager.spacing.xl) {
                // Header
                Text("vibes")
                    .font(themeManager.fonts.title)
                    .foregroundColor(themeManager.colors.textPrimary)
                    .tracking(themeManager.letterSpacing.wide)
                    .padding(.top, themeManager.spacing.lg)
                
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
            .padding(.horizontal, themeManager.spacing.screenHorizontal)
        }
        .background(themeManager.colors.background.ignoresSafeArea())
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
                HStack(spacing: themeManager.spacing.md) {
                    ZStack {
                        Circle()
                            .fill(themeManager.colors.accent2.opacity(0.15))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(themeManager.colors.accent2)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("start a vibe")
                            .font(themeManager.fonts.body)
                            .foregroundColor(themeManager.colors.textPrimary)
                        
                        Text("invite friends to hang")
                            .font(themeManager.fonts.caption)
                            .foregroundColor(themeManager.colors.textTertiary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(themeManager.colors.textTertiary)
                }
                .padding(themeManager.spacing.md)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - My Vibes Section
    
    var myVibesSection: some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            Text("your vibes")
                .font(themeManager.fonts.caption)
                .foregroundColor(themeManager.colors.textTertiary)
                .tracking(themeManager.letterSpacing.wide)
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
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            Text("from friends")
                .font(themeManager.fonts.caption)
                .foregroundColor(themeManager.colors.textTertiary)
                .tracking(themeManager.letterSpacing.wide)
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
        VStack(spacing: themeManager.spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(themeManager.colors.textTertiary)
            
            Text("no active vibes")
                .font(themeManager.fonts.body)
                .foregroundColor(themeManager.colors.textTertiary)
            
            Text("start one and invite friends!")
                .font(themeManager.fonts.caption)
                .foregroundColor(themeManager.colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, themeManager.spacing.xxl)
    }
}

// MARK: - Vibe Card

struct VibeCard: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
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
    // For own vibes, use current theme directly so it updates immediately on theme change
    var creatorGlowColor: Color {
        if isOwnVibe {
            return themeManager.currentTheme.glowColor
        }
        return creator?.selectedTheme.glowColor ?? themeManager.colors.accent2
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
                    HStack(spacing: themeManager.spacing.md) {
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
                                .fill(creatorIsPremium ? creatorGlowColor.opacity(0.3) : themeManager.colors.accent2.opacity(0.15))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .light))
                                .foregroundColor(creatorIsPremium ? creatorGlowColor : themeManager.colors.accent2)
                        }
                        
                        // Title and info
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(vibe.title)
                                    .font(themeManager.fonts.body)
                                    .foregroundColor(themeManager.colors.textPrimary)
                                
                                if isOwnVibe {
                                    HStack(spacing: 4) {
                                        Text("· you")
                                            .font(themeManager.fonts.caption)
                                            .foregroundColor(creatorIsPremium ? creatorGlowColor : themeManager.colors.accent2)
                                        
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
                                        .font(themeManager.fonts.caption)
                                        .foregroundColor(creatorIsPremium ? creatorGlowColor.opacity(0.8) : themeManager.colors.textSecondary)
                                    
                                    Text("·")
                                        .foregroundColor(themeManager.colors.textTertiary)
                                }
                                
                                Text(vibe.timeDescription)
                                    .font(themeManager.fonts.caption)
                                    .foregroundColor(themeManager.colors.textTertiary)
                                
                                Text("·")
                                    .foregroundColor(themeManager.colors.textTertiary)
                                
                                Text(vibe.location)
                                    .font(themeManager.fonts.caption)
                                    .foregroundColor(themeManager.colors.textTertiary)
                            }
                        }
                        
                        Spacer()
                        
                        // Response count
                        if vibe.yesCount > 0 {
                            HStack(spacing: 4) {
                                Text("\(vibe.yesCount)")
                                    .font(themeManager.fonts.caption)
                                    .foregroundColor(.green)
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(themeManager.colors.textTertiary)
                    }
                    .padding(themeManager.spacing.md)
                }
                .buttonStyle(.plain)
                
                // Expanded content
                if isExpanded {
                    expandedContent
                }
            }
        }
        .id("\(vibe.id)-\(themeManager.currentTheme.id)") // Force refresh when theme changes
        .onAppear {
            if creatorIsPremium {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowAnimation = true
                }
            }
        }
    }
    
    var expandedContent: some View {
        VStack(alignment: .leading, spacing: themeManager.spacing.md) {
            Divider()
                .background(themeManager.colors.cardBackground)
            
            // Who's in
            if !yesUsers.isEmpty {
                VStack(alignment: .leading, spacing: themeManager.spacing.sm) {
                    Text("who's in")
                        .font(themeManager.fonts.caption)
                        .foregroundColor(themeManager.colors.textTertiary)
                        .tracking(themeManager.letterSpacing.wide)
                        .textCase(.uppercase)
                    
                    HStack(spacing: -8) {
                        ForEach(yesUsers.prefix(5)) { user in
                            Button(action: {
                                selectedUser = user
                            }) {
                                Circle()
                                    .fill(themeManager.colors.background)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text(String(user.displayName.prefix(1)).lowercased())
                                            .font(.system(size: 12, weight: .light))
                                            .foregroundColor(themeManager.colors.textSecondary)
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
                                .fill(themeManager.colors.background)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text("+\(yesUsers.count - 5)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(themeManager.colors.textSecondary)
                                )
                        }
                    }
                }
            }
            
            // Who's not going
            if !noUsers.isEmpty {
                VStack(alignment: .leading, spacing: themeManager.spacing.sm) {
                    Text("can't make it")
                        .font(themeManager.fonts.caption)
                        .foregroundColor(themeManager.colors.textTertiary)
                        .tracking(themeManager.letterSpacing.wide)
                        .textCase(.uppercase)
                    
                    HStack(spacing: -8) {
                        ForEach(noUsers.prefix(5)) { user in
                            Button(action: {
                                selectedUser = user
                            }) {
                                Circle()
                                    .fill(themeManager.colors.background)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text(String(user.displayName.prefix(1)).lowercased())
                                            .font(.system(size: 12, weight: .light))
                                            .foregroundColor(themeManager.colors.textTertiary)
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
                                .fill(themeManager.colors.background)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text("+\(noUsers.count - 5)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(themeManager.colors.textTertiary)
                                )
                        }
                    }
                }
            }
            
            // Response buttons or Edit/Delete for own vibes
            if isOwnVibe {
                HStack(spacing: themeManager.spacing.sm) {
                    Button(action: {
                        Task {
                            await viewModel.deleteVibe(vibe.id)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                            Text("delete")
                                .font(themeManager.fonts.caption)
                        }
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.horizontal, themeManager.spacing.md)
                        .padding(.vertical, themeManager.spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: themeManager.radius.sm)
                                .fill(Color.red.opacity(0.1))
                        )
                    }
                }
            } else {
                HStack(spacing: themeManager.spacing.sm) {
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
        .padding(.horizontal, themeManager.spacing.md)
        .padding(.bottom, themeManager.spacing.md)
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
    @ObservedObject private var themeManager = ThemeManager.shared
    let text: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(themeManager.fonts.caption)
                .foregroundColor(isSelected ? color : themeManager.colors.textSecondary)
                .padding(.horizontal, themeManager.spacing.md)
                .padding(.vertical, themeManager.spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: themeManager.radius.sm)
                        .fill(isSelected ? color.opacity(0.15) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: themeManager.radius.sm)
                                .stroke(isSelected ? color.opacity(0.4) : themeManager.colors.textTertiary.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Create Vibe Sheet

struct CreateVibeSheet: View {
    @EnvironmentObject var viewModel: SupabaseAppViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
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
            themeManager.colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
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
                    
                    Text("new vibe")
                        .font(themeManager.fonts.body)
                        .foregroundColor(themeManager.colors.textPrimary)
                        .tracking(themeManager.letterSpacing.wide)
                    
                    Spacer()
                    
                    Button(action: createVibe) {
                        Text("send")
                            .font(themeManager.fonts.caption)
                            .foregroundColor(canCreate ? themeManager.colors.accent2 : themeManager.colors.textTertiary)
                    }
                    .disabled(!canCreate)
                    .frame(width: 40)
                }
                .padding(.horizontal, themeManager.spacing.screenHorizontal)
                .padding(.top, themeManager.spacing.lg)
                .padding(.bottom, themeManager.spacing.xl)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: themeManager.spacing.xl) {
                        // Title Input
                        VStack(alignment: .leading, spacing: themeManager.spacing.sm) {
                            HStack {
                                Text("what's the vibe?")
                                    .font(themeManager.fonts.caption)
                                    .foregroundColor(themeManager.colors.textTertiary)
                                    .tracking(themeManager.letterSpacing.wide)
                                    .textCase(.uppercase)
                                
                                Spacer()
                                
                                Text("\(title.count)/30")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(title.count > 30 ? .red : themeManager.colors.textTertiary)
                            }
                            
                            TextField("", text: $title)
                                .placeholder(when: title.isEmpty) {
                                    Text("basketball? coffee? study?")
                                        .foregroundColor(themeManager.colors.textTertiary)
                                }
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(themeManager.colors.textPrimary)
                                .focused($titleFocused)
                                .onChange(of: title) { _, newValue in
                                    if newValue.count > 30 {
                                        title = String(newValue.prefix(30))
                                    }
                                }
                        }
                        
                        // Time Selection
                        VStack(alignment: .leading, spacing: themeManager.spacing.sm) {
                            Text("when?")
                                .font(themeManager.fonts.caption)
                                .foregroundColor(themeManager.colors.textTertiary)
                                .tracking(themeManager.letterSpacing.wide)
                                .textCase(.uppercase)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: themeManager.spacing.sm) {
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
                        VStack(alignment: .leading, spacing: themeManager.spacing.sm) {
                            HStack {
                                Text("where?")
                                    .font(themeManager.fonts.caption)
                                    .foregroundColor(themeManager.colors.textTertiary)
                                    .tracking(themeManager.letterSpacing.wide)
                                    .textCase(.uppercase)
                                
                                Spacer()
                                
                                Text("\(location.count)/30")
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(location.count > 30 ? .red : themeManager.colors.textTertiary)
                            }
                            
                            TextField("", text: $location)
                                .placeholder(when: location.isEmpty) {
                                    Text("my place, the court, cafe...")
                                        .foregroundColor(themeManager.colors.textTertiary)
                                }
                                .font(.system(size: 20, weight: .light))
                                .foregroundColor(themeManager.colors.textPrimary)
                                .focused($locationFocused)
                                .onChange(of: location) { _, newValue in
                                    if newValue.count > 30 {
                                        location = String(newValue.prefix(30))
                                    }
                                }
                        }
                        // Preview
                        if canCreate {
                            VStack(alignment: .leading, spacing: themeManager.spacing.sm) {
                                Text("preview")
                                    .font(themeManager.fonts.caption)
                                    .foregroundColor(themeManager.colors.textTertiary)
                                    .tracking(themeManager.letterSpacing.wide)
                                    .textCase(.uppercase)
                                
                                DepthCard(depth: .low) {
                                    HStack {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 14))
                                            .foregroundColor(themeManager.colors.accent2)
                                        
                                        Text(title)
                                            .font(themeManager.fonts.body)
                                            .foregroundColor(themeManager.colors.textPrimary)
                                        
                                        Text("·")
                                            .foregroundColor(themeManager.colors.textTertiary)
                                        
                                        Text(timeDescription)
                                            .font(themeManager.fonts.caption)
                                            .foregroundColor(themeManager.colors.textSecondary)
                                        
                                        Text("·")
                                            .foregroundColor(themeManager.colors.textTertiary)
                                        
                                        Text(location)
                                            .font(themeManager.fonts.caption)
                                            .foregroundColor(themeManager.colors.textSecondary)
                                        
                                        Spacer()
                                    }
                                    .padding(themeManager.spacing.md)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, themeManager.spacing.screenHorizontal)
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
                        .font(themeManager.fonts.body)
                        .foregroundColor(themeManager.colors.textSecondary)
                        
                        Spacer()
                        
                        Text("choose date & time")
                            .font(themeManager.fonts.body)
                            .foregroundColor(themeManager.colors.textPrimary)
                        
                        Spacer()
                        
                        Button("Done") {
                            withAnimation {
                                showTimePicker = false
                            }
                        }
                        .font(themeManager.fonts.body)
                        .foregroundColor(themeManager.colors.accent2)
                    }
                    .padding()
                    .background(themeManager.colors.cardBackground)
                    
                    DatePicker(
                        "",
                        selection: $customTime,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding()
                    .background(themeManager.colors.background)
                }
                .background(themeManager.colors.background)
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
    @ObservedObject private var themeManager = ThemeManager.shared
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(themeManager.fonts.caption)
                .foregroundColor(isSelected ? themeManager.colors.accent2 : themeManager.colors.textSecondary)
                .padding(.horizontal, themeManager.spacing.md)
                .padding(.vertical, themeManager.spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: themeManager.radius.full)
                        .fill(isSelected ? themeManager.colors.accent2.opacity(0.15) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: themeManager.radius.full)
                                .stroke(isSelected ? themeManager.colors.accent2.opacity(0.4) : themeManager.colors.textTertiary.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
}

#Preview {
    VibeTab()
        .environmentObject(SupabaseAppViewModel())
}
