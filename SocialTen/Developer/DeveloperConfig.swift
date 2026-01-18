//
//  DeveloperConfig.swift
//  SocialTen
//
//  Developer access control and configuration
//

import Foundation

/// Manages developer access for the app
class DeveloperManager: ObservableObject {
    static let shared = DeveloperManager()
    
    @Published private(set) var isDeveloper: Bool = false
    @Published private(set) var isLoading: Bool = false
    
    private init() {}
    
    /// Check if the current user is a developer (queries database)
    func checkDeveloperStatus(userId: String) async {
        await MainActor.run { isLoading = true }
        
        do {
            struct DeveloperCheck: Codable {
                let isDeveloper: Bool?
                
                enum CodingKeys: String, CodingKey {
                    case isDeveloper = "is_developer"
                }
            }
            
            let result: DeveloperCheck = try await SupabaseManager.shared.client
                .from("users")
                .select("is_developer")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                self.isDeveloper = result.isDeveloper ?? false
                self.isLoading = false
            }
        } catch {
            print("❌ Error checking developer status: \(error)")
            await MainActor.run {
                self.isDeveloper = false
                self.isLoading = false
            }
        }
    }
    
    /// Reset developer status (call on logout)
    func reset() {
        isDeveloper = false
        isLoading = false
    }
}
