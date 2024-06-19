//
//  UpNextWidgetBundle.swift
//  UpNextWidget
//
//  Created by Gabriel Valdivia on 6/19/24.
//

import WidgetKit
import SwiftUI

@main
struct UpNextWidgetBundle: WidgetBundle {
    var body: some Widget {
        UpNextWidget()
        UpNextWidgetLiveActivity()
    }
}
