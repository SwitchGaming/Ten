//
//  BlockManager.swift
//  SocialTen
//

import SwiftUI
import Foundation

// MARK: - Block Manager

class BlockManager: ObservableObject {
    static let shared = BlockManager()
    
    // Blocked users list
    @Published var blockedUserIds: Set<String> = []
    @Published var isLoading: Bool = false
    
    private let supabase = SupabaseManager.shared.client
    
    private init() {}
    
    // MARK: - Load Blocked Users
    
    @MainActor
    func loadBlockedUsers() async {
        do {
            guard let authUser = try? await supabase.auth.session.user else {
                print("❌ BlockManager: No auth user")
                return
            }
            
            let response = try await supabase
                .rpc("get_blocked_users", params: ["p_user_id": authUser.id.uuidString])
                .execute()
            
            // Debug
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("📦 Blocked users response: \(jsonString)")
            }
            
            // Decode response
            struct BlockedResponse: Codable {
                let success: Bool
                let error: String?
                let blockedIds: [String]?
            }
            
            let result = try JSONDecoder().decode(BlockedResponse.self, from: response.data)
            
            if result.success, let ids = result.blockedIds {
                blockedUserIds = Set(ids)
                print("✅ Loaded \(ids.count) blocked users")
            }
        } catch {
            print("❌ Error loading blocked users: \(error)")
        }
    }
    
    // MARK: - Block User
    
    @MainActor
    func blockUser(userId: String) async -> BlockResult {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let authUser = try? await supabase.auth.session.user else {
                return BlockResult(success: false, error: "Not authenticated")
            }
            
            let params: [String: String] = [
                "p_user_id": authUser.id.uuidString,
                "p_blocked_id": userId
            ]
            
            let response = try await supabase
                .rpc("block_user", params: params)
                .execute()
            
            // Debug
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("📦 Block response: \(jsonString)")
            }
            
            let result = try JSONDecoder().decode(BlockResult.self, from: response.data)
            
            if result.success {
                blockedUserIds.insert(userId)
                print("✅ Blocked user: \(userId)")
            }
            
            return result
        } catch {
            print("❌ Error blocking user: \(error)")
            return BlockResult(success: false, error: error.localizedDescription)
        }
    }
    
    // MARK: - Unblock User
    
    @MainActor
    func unblockUser(userId: String) async -> BlockResult {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let authUser = try? await supabase.auth.session.user else {
                return BlockResult(success: false, error: "Not authenticated")
            }
            
            let params: [String: String] = [
                "p_user_id": authUser.id.uuidString,
                "p_blocked_id": userId
            ]
            
            let response = try await supabase
                .rpc("unblock_user", params: params)
                .execute()
            
            let result = try JSONDecoder().decode(BlockResult.self, from: response.data)
            
            if result.success {
                blockedUserIds.remove(userId)
                print("✅ Unblocked user: \(userId)")
            }
            
            return result
        } catch {
            print("❌ Error unblocking user: \(error)")
            return BlockResult(success: false, error: error.localizedDescription)
        }
    }
    
    // MARK: - Report User
    
    @MainActor
    func reportUser(userId: String, reason: String) async -> ReportResult {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let authUser = try? await supabase.auth.session.user else {
                return ReportResult(success: false, error: "Not authenticated")
            }
            
            let params: [String: String] = [
                "p_user_id": authUser.id.uuidString,
                "p_reported_id": userId,
                "p_reason": reason
            ]
            
            let response = try await supabase
                .rpc("report_user", params: params)
                .execute()
            
            // Debug
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("📦 Report response: \(jsonString)")
            }
            
            let result = try JSONDecoder().decode(ReportResult.self, from: response.data)
            
            if result.success {
                print("✅ Reported user: \(userId)")
            }
            
            return result
        } catch {
            print("❌ Error reporting user: \(error)")
            return ReportResult(success: false, error: error.localizedDescription)
        }
    }
    
    // MARK: - Helpers
    
    func isBlocked(_ userId: String) -> Bool {
        blockedUserIds.contains(userId)
    }
}

// MARK: - Result Types

struct BlockResult: Codable {
    let success: Bool
    let error: String?
    
    init(success: Bool, error: String? = nil) {
        self.success = success
        self.error = error
    }
}

struct ReportResult: Codable {
    let success: Bool
    let error: String?
    
    init(success: Bool, error: String? = nil) {
        self.success = success
        self.error = error
    }
}
