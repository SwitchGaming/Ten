//
//  SupabaseManager.swift
//  SocialTen
//

import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://jrskewlthwnyzgagflxy.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impyc2tld2x0aHdueXpnYWdmbHh5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3Mzc3ODAsImV4cCI6MjA4MTMxMzc4MH0.EkgtRSl1Kdopo7cfIjhSMPv4K9dXNslLzRWEXg5r7x8"
        )
    }
}
