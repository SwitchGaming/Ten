//
//  SmartScrollView.swift
//  SocialTen
//

import SwiftUI

/// A vertical ScrollView wrapper that:
/// - always shows scroll indicators
/// - shows a subtle "scroll down" prompt when there is content below the viewport
/// - shows a floating "jump to top" button once the user scrolls down
struct SmartScrollView<Content: View>: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var showsIndicators: Bool = true
    var topButtonThreshold: CGFloat = 40
    var scrollPromptInset: CGFloat = 18
    var contentPaddingBottom: CGFloat = 0

    @ViewBuilder var content: () -> Content

    @State private var showScrollToTop = false
    @State private var showScrollPrompt = true
    @State private var contentSize: CGSize = .zero
    @State private var scrollViewSize: CGSize = .zero

    private var hasOverflow: Bool {
        contentSize.height > scrollViewSize.height + 10
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView(.vertical, showsIndicators: showsIndicators) {
                    VStack(spacing: 0) {
                        content()
                            .padding(.bottom, contentPaddingBottom)
                    }
                    .id("__smartScrollTop")
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    contentSize = geo.size
                                }
                                .onChange(of: geo.size) { _, newSize in
                                    contentSize = newSize
                                }
                                .onChange(of: geo.frame(in: .named("scroll")).minY) { _, minY in
                                    let scrolled = -minY
                                    showScrollToTop = scrolled > topButtonThreshold
                                    showScrollPrompt = scrolled < 10
                                }
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                scrollViewSize = geo.size
                            }
                            .onChange(of: geo.size) { _, newSize in
                                scrollViewSize = newSize
                            }
                    }
                )
                
                // Jump to top button
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            proxy.scrollTo("__smartScrollTop", anchor: .top)
                        }
                    } label: {
                        #if compiler(>=6.2)
                        if #available(iOS 26.0, *) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(themeManager.colors.textPrimary)
                                .frame(width: 44, height: 44)
                                .glassEffect(.regular.interactive())
                                .clipShape(Circle())
                        } else {
                            scrollToTopFallbackButton
                        }
                        #else
                        scrollToTopFallbackButton
                        #endif
                    }
                    .contentShape(Circle())
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                    .offset(y: hasOverflow && showScrollToTop ? 0 : 80)
                    .opacity(hasOverflow && showScrollToTop ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showScrollToTop)
                }
            }
        }
    }
    
    private var scrollToTopFallbackButton: some View {
        Image(systemName: "arrow.up")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(themeManager.colors.textPrimary)
            .frame(width: 44, height: 44)
            .background(themeManager.colors.cardBackground.opacity(0.9))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(themeManager.colors.accent3.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 4)
    }
}

private struct SmartScrollDownPrompt: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .opacity(pulse ? 0.45 : 0.9)
            Text("scroll")
                .font(.system(size: 12, weight: .medium))
                .tracking(1)
                .opacity(0.85)
        }
        .foregroundColor(themeManager.colors.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(themeManager.colors.cardBackground.opacity(0.9))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(themeManager.colors.accent3.opacity(0.25), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
