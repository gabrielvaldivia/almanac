//
//  UpcomingWidgetBundle.swift
//  UpcomingWidget
//
//  Created by Gabriel Valdivia on 6/18/24.
//

import WidgetKit
import SwiftUI

@main
struct UpcomingWidgetBundle: WidgetBundle {
    var body: some Widget {
        UpcomingWidget()
        UpcomingWidgetLiveActivity()
    }
}
