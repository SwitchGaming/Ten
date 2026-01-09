//
//  BadgeStatsCache.swift
//  SocialTen
//

import SwiftUI
import Supabase

// MARK: - Badge Stats Response Model

struct BadgeStatResponse: Codable {
    let badgeId: String
    let earnedCount: Int
    let totalUsers: Int
    let percentage: Double
    
    enum CodingKeys: String, CodingKey {
        case badgeId = "badge_id"
        case earnedCount = "earned_count"
        case totalUsers = "total_users"
        case percentage
    }
}

// MARK: - Badge Stats Cache

class BadgeStatsCache: ObservableObject {
    static let shared = BadgeStatsCache()
    
    @Published private(set) var stats: [String: BadgeStatResponse] = [:]
    @Published private(set) var totalUsers: Int = 0
    @Published private(set) var lastUpdated: Date? = nil
    @Published private(set) var isLoading: Bool = false
    
    private let cacheKey = "badgeStatsCache"
    private let cacheTimestampKey = "badgeStatsCacheTimestamp"
    private let staleDuration: TimeInterval = 3600 // 1 hour
    
    private init() {
        loadFromDisk()
    }
    
    // MARK: - Public API
    
    /// Get the actual percentage for a badge, or nil if not yet loaded
    func percentage(for badgeId: String) -> Double? {
        return stats[badgeId]?.percentage
    }
    
    /// Get the earned count for a badge
    func earnedCount(for badgeId: String) -> Int {
        return stats[badgeId]?.earnedCount ?? 0
    }
    
    /// Format the percentage for display
    /// Returns "be the first!" for 0 earners, or "X% of users" for others
    func formattedPercentage(for badgeId: String) -> String? {
        guard let stat = stats[badgeId] else { return nil }
        
        if stat.earnedCount == 0 {
            return "be the first!"
        }
        
        // Format percentage nicely
        let pct = stat.percentage
        if pct < 1 {
            return "<1% of users"
        } else if pct == 100 {
            return "100% of users"
        } else {
            return "\(Int(pct.rounded()))% of users"
        }
    }
    
    /// Fetch fresh stats from Supabase
    func fetchStats() async {
        guard !isLoading else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let response: [BadgeStatResponse] = try await SupabaseManager.shared.client
                .rpc("get_all_badge_stats")
                .execute()
                .value
            
            var newStats: [String: BadgeStatResponse] = [:]
            var maxTotalUsers = 0
            
            for stat in response {
                newStats[stat.badgeId] = stat
                if stat.totalUsers > maxTotalUsers {
                    maxTotalUsers = stat.totalUsers
                }
            }
            
            await MainActor.run {
                self.stats = newStats
                self.totalUsers = maxTotalUsers
                self.lastUpdated = Date()
                self.isLoading = false
            }
            
            saveToDisk()
            
            print("BadgeStatsCache: Loaded stats for \(response.count) badges, \(maxTotalUsers) total users")
        } catch {
            print("BadgeStatsCache: Error fetching stats - \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    /// Check if cache is stale and needs refresh
    var isStale: Bool {
        guard let lastUpdated = lastUpdated else { return true }
        return Date().timeIntervalSince(lastUpdated) > staleDuration
    }
    
    /// Fetch if stale, otherwise use cached data
    func fetchIfNeeded() async {
        if isStale {
            await fetchStats()
        }
    }
    
    /// Invalidate cache for a specific badge (call after awarding)
    func invalidate(badgeId: String) {
        // Mark as stale to trigger refresh on next access
        lastUpdated = nil
    }
    
    // MARK: - Disk Persistence
    
    private func saveToDisk() {
        let defaults = UserDefaults.standard
        
        if let encoded = try? JSONEncoder().encode(Array(stats.values)) {
            defaults.set(encoded, forKey: cacheKey)
        }
        
        if let timestamp = lastUpdated {
            defaults.set(timestamp, forKey: cacheTimestampKey)
        }
        
        defaults.set(totalUsers, forKey: "badgeStatsTotalUsers")
    }
    
    private func loadFromDisk() {
        let defaults = UserDefaults.standard
        
        if let data = defaults.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode([BadgeStatResponse].self, from: data) {
            var loadedStats: [String: BadgeStatResponse] = [:]
            for stat in decoded {
                loadedStats[stat.badgeId] = stat
            }
            stats = loadedStats
        }
        
        lastUpdated = defaults.object(forKey: cacheTimestampKey) as? Date
        totalUsers = defaults.integer(forKey: "badgeStatsTotalUsers")
    }
}
