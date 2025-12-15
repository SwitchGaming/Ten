//
//  ContentView.swift
//  SocialTen
//
//  Created by Joe Alapat on 12/3/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MainTabView()
            .background(Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea())
            .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}

 

