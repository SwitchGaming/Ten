//
//  AnimatedNumber.swift
//  SocialTen
//

import SwiftUI

struct AnimatedNumber: View {
    let value: Int
    let font: Font
    let color: Color
    
    @State private var displayedValue: Int = 0
    
    var body: some View {
        Text("\(displayedValue)")
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText())
            .onChange(of: value) { oldValue, newValue in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    displayedValue = newValue
                }
            }
            .onAppear {
                displayedValue = value
            }
    }
}

#Preview {
    AnimatedNumber(
        value: 7,
        font: .system(size: 120, weight: .ultraLight),
        color: .white
    )
    .background(Color.black)
}
