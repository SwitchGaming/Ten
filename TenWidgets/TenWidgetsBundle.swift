//
//  TenWidgetsBundle.swift
//  TenWidgets
//

import WidgetKit
import SwiftUI

@main
struct TenWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RatingWidget()
        PromptWidget()
        FriendsWidget()
        StreakWidget()
    }
}
