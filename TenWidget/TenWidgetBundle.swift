//
//  TenWidgetBundle.swift
//  TenWidget
//
//  Widget bundle containing all Ten widgets
//

import WidgetKit
import SwiftUI

@main
struct TenWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Free widgets
        RatingWidget()
        PromptWidget()
        FriendsWidget()
        
        // Premium widgets
        LatestPostWidget()
        OverviewWidget()
    }
}
