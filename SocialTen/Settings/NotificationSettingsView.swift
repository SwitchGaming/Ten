//
//  NotificationSettingsView.swift
//  SocialTen
//

import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeManager.shared.colors.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: ThemeManager.shared.spacing.xl) {
                        // Status Card
                        if !notificationManager.isNotificationsEnabled {
                            notificationsDisabledCard
                        }
                        
                        // Notification Types
                        VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.sm) {
                            Text("notify me about")
                                .font(ThemeManager.shared.fonts.caption)
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                .tracking(ThemeManager.shared.letterSpacing.wide)
                                .textCase(.uppercase)
                            
                            VStack(spacing: 1) {
                                NotificationToggleRow(
                                    icon: "sparkles",
                                    title: "New Vibes",
                                    subtitle: "When friends create vibes",
                                    isOn: $notificationManager.notificationPreferences.vibesEnabled
                                )
                                
                                NotificationToggleRow(
                                    icon: "person.badge.plus",
                                    title: "Friend Requests",
                                    subtitle: "When someone wants to connect",
                                    isOn: $notificationManager.notificationPreferences.friendRequestsEnabled
                                )
                                
                                NotificationToggleRow(
                                    icon: "bubble.left",
                                    title: "Replies",
                                    subtitle: "When someone replies to your posts",
                                    isOn: $notificationManager.notificationPreferences.repliesEnabled
                                )
                            }
                            .background(
                                RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                                    .fill(ThemeManager.shared.colors.cardBackground)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md))
                        }
                        
                        // Quiet Hours
                        VStack(alignment: .leading, spacing: ThemeManager.shared.spacing.sm) {
                            Text("quiet hours")
                                .font(ThemeManager.shared.fonts.caption)
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                .tracking(ThemeManager.shared.letterSpacing.wide)
                                .textCase(.uppercase)
                            
                            VStack(spacing: 1) {
                                QuietHoursRow(
                                    title: "Start",
                                    time: $notificationManager.notificationPreferences.quietHoursStart
                                )
                                
                                QuietHoursRow(
                                    title: "End",
                                    time: $notificationManager.notificationPreferences.quietHoursEnd
                                )
                            }
                            .background(
                                RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md)
                                    .fill(ThemeManager.shared.colors.cardBackground)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: ThemeManager.shared.radius.md))
                            
                            Text("notifications will be silenced during quiet hours")
                                .font(ThemeManager.shared.fonts.caption)
                                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                                .padding(.top, 4)
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, ThemeManager.shared.spacing.screenHorizontal)
                    .padding(.top, ThemeManager.shared.spacing.lg)
                }
            }
            .navigationTitle("notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(ThemeManager.shared.colors.textSecondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        notificationManager.savePreferences()
                        dismiss()
                    }
                    .font(ThemeManager.shared.fonts.body)
                    .foregroundColor(ThemeManager.shared.colors.accent1)
                }
            }
        }
    }
    
    var notificationsDisabledCard: some View {
        VStack(spacing: ThemeManager.shared.spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "bell.slash")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.orange)
            }
            
            Text("notifications disabled")
                .font(ThemeManager.shared.fonts.body)
                .foregroundColor(ThemeManager.shared.colors.textPrimary)
            
            Text("enable notifications in Settings to stay connected with friends")
                .font(ThemeManager.shared.fonts.caption)
                .foregroundColor(ThemeManager.shared.colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Open Settings")
                    .font(ThemeManager.shared.fonts.caption)
                    .tracking(ThemeManager.shared.letterSpacing.wide)
                    .foregroundColor(ThemeManager.shared.colors.accent1)
                    .padding(.horizontal, ThemeManager.shared.spacing.lg)
                    .padding(.vertical, ThemeManager.shared.spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: ThemeManager.shared.radius.full)
                            .stroke(ThemeManager.shared.colors.accent1, lineWidth: 1)
                    )
            }
            .padding(.top, 4)
        }
        .padding(ThemeManager.shared.spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: ThemeManager.shared.radius.lg)
                .fill(ThemeManager.shared.colors.cardBackground)
        )
    }
}

// MARK: - Notification Toggle Row

struct NotificationToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: ThemeManager.shared.spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(ThemeManager.shared.colors.textSecondary)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ThemeManager.shared.fonts.body)
                    .foregroundColor(ThemeManager.shared.colors.textPrimary)
                
                Text(subtitle)
                    .font(ThemeManager.shared.fonts.caption)
                    .foregroundColor(ThemeManager.shared.colors.textTertiary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(ThemeManager.shared.colors.accent1)
        }
        .padding(.horizontal, ThemeManager.shared.spacing.md)
        .padding(.vertical, ThemeManager.shared.spacing.md)
        .background(ThemeManager.shared.colors.cardBackground)
    }
}

// MARK: - Quiet Hours Row

struct QuietHoursRow: View {
    let title: String
    @Binding var time: String
    
    @State private var selectedTime: Date = Date()
    
    var body: some View {
        HStack {
            Text(title.lowercased())
                .font(ThemeManager.shared.fonts.body)
                .foregroundColor(ThemeManager.shared.colors.textPrimary)
            
            Spacer()
            
            DatePicker(
                "",
                selection: $selectedTime,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .colorScheme(.dark)
            .onChange(of: selectedTime) { _, newValue in
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                time = formatter.string(from: newValue)
            }
            .onAppear {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                if let date = formatter.date(from: time) {
                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.hour, .minute], from: date)
                    selectedTime = calendar.date(from: components) ?? Date()
                }
            }
        }
        .padding(.horizontal, ThemeManager.shared.spacing.md)
        .padding(.vertical, ThemeManager.shared.spacing.sm)
        .background(ThemeManager.shared.colors.cardBackground)
    }
}

#Preview {
    NotificationSettingsView()
}
