//
//  NotificationManager.swift
//  SocialTen
//

import Foundation
import UserNotifications
import UIKit

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isNotificationsEnabled = false
    @Published var notificationPreferences = NotificationPreferences()
    
    private init() {
        checkNotificationStatus()
        loadPreferences()
    }
    
    // MARK: - Check Permission Status
    
    func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isNotificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Request Permissions
    
    func requestPermissions() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                    isNotificationsEnabled = true
                }
            }
            
            return granted
        } catch {
            print("❌ Error requesting notification permissions: \(error)")
            return false
        }
    }
    
    // MARK: - Register Device Token with Supabase
    
    func registerDeviceToken(_ token: String) async {
        guard let userId = await getCurrentUserId() else {
            print("❌ Cannot register device token: No user logged in")
            return
        }
        
        do {
            let tokenData: [String: String] = [
                "user_id": userId,
                "token": token,
                "platform": "ios",
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ]
            
            try await SupabaseManager.shared.client
                .from("device_tokens")
                .upsert(tokenData, onConflict: "user_id,token")
                .execute()
            
            print("✅ Device token registered with Supabase")
        } catch {
            print("❌ Error registering device token: \(error)")
        }
    }
    
    // MARK: - Remove Device Token (on logout)
    
    func removeDeviceToken() async {
        guard let token = UserDefaults.standard.string(forKey: "deviceToken"),
              let userId = await getCurrentUserId() else { return }
        
        do {
            try await SupabaseManager.shared.client
                .from("device_tokens")
                .delete()
                .eq("user_id", value: userId)
                .eq("token", value: token)
                .execute()
            
            print("✅ Device token removed from Supabase")
        } catch {
            print("❌ Error removing device token: \(error)")
        }
    }
    
    // MARK: - Load/Save Preferences
    
    func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: "notificationPreferences"),
           let prefs = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            notificationPreferences = prefs
        }
        // Always update timezone to current device timezone
        notificationPreferences.timezone = TimeZone.current.identifier
    }
    
    func savePreferences() {
        // Ensure timezone is current before saving
        notificationPreferences.timezone = TimeZone.current.identifier
        
        if let data = try? JSONEncoder().encode(notificationPreferences) {
            UserDefaults.standard.set(data, forKey: "notificationPreferences")
        }
        
        Task {
            await savePreferencesToSupabase()
        }
    }
    
    private func savePreferencesToSupabase() async {
        guard let userId = await getCurrentUserId() else { return }
        
        do {
            // Use a Codable struct for type safety
            let prefsData = DBNotificationPreferences(
                userId: userId,
                vibesEnabled: notificationPreferences.vibesEnabled,
                friendRequestsEnabled: notificationPreferences.friendRequestsEnabled,
                repliesEnabled: notificationPreferences.repliesEnabled,
                ratingsEnabled: notificationPreferences.ratingsEnabled,
                vibeResponsesEnabled: notificationPreferences.vibeResponsesEnabled,
                connectionMatchEnabled: notificationPreferences.connectionMatchEnabled,
                dailyReminderEnabled: notificationPreferences.dailyReminderEnabled,
                dailyReminderTime: notificationPreferences.dailyReminderTime,
                quietHoursEnabled: notificationPreferences.quietHoursEnabled,
                quietHoursStart: notificationPreferences.quietHoursStart,
                quietHoursEnd: notificationPreferences.quietHoursEnd,
                timezone: notificationPreferences.timezone
            )
            
            try await SupabaseManager.shared.client
                .from("notification_preferences")
                .upsert(prefsData, onConflict: "user_id")
                .execute()
        } catch {
            print("❌ Error saving notification preferences: \(error)")
        }
    }
    
    // MARK: - Badge Count
    
    func updateBadgeCount(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }
    
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
    
    // MARK: - Helper
    
    private func getCurrentUserId() async -> String? {
        do {
            let user = try await SupabaseManager.shared.client.auth.session.user
            
            let users: [DBUser] = try await SupabaseManager.shared.client
                .from("users")
                .select()
                .eq("auth_id", value: user.id)
                .execute()
                .value
            
            return users.first?.id?.uuidString
        } catch {
            return nil
        }
    }
}

// MARK: - Notification Preferences Model

struct NotificationPreferences: Codable {
    var vibesEnabled: Bool = true
    var friendRequestsEnabled: Bool = true
    var repliesEnabled: Bool = true
    var ratingsEnabled: Bool = false
    var vibeResponsesEnabled: Bool = true
    var connectionMatchEnabled: Bool = true
    var dailyReminderEnabled: Bool = false
    var dailyReminderTime: String = "19:00"
    var quietHoursEnabled: Bool = true
    var quietHoursStart: String = "22:00"
    var quietHoursEnd: String = "08:00"
    var timezone: String = TimeZone.current.identifier
}

// MARK: - DB Model for Supabase

struct DBNotificationPreferences: Codable {
    let userId: String
    let vibesEnabled: Bool
    let friendRequestsEnabled: Bool
    let repliesEnabled: Bool
    let ratingsEnabled: Bool
    let vibeResponsesEnabled: Bool
    let connectionMatchEnabled: Bool
    let dailyReminderEnabled: Bool
    let dailyReminderTime: String
    let quietHoursEnabled: Bool
    let quietHoursStart: String
    let quietHoursEnd: String
    let timezone: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case vibesEnabled = "vibes_enabled"
        case friendRequestsEnabled = "friend_requests_enabled"
        case repliesEnabled = "replies_enabled"
        case ratingsEnabled = "ratings_enabled"
        case vibeResponsesEnabled = "vibe_responses_enabled"
        case connectionMatchEnabled = "connection_match_enabled"
        case dailyReminderEnabled = "daily_reminder_enabled"
        case dailyReminderTime = "daily_reminder_time"
        case quietHoursEnabled = "quiet_hours_enabled"
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd = "quiet_hours_end"
        case timezone
    }
}
