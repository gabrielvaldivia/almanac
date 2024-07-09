//
//  CircleButton.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 7/1/24.
//

import SwiftUI

struct CircleButton: View {
    var iconName: String
    var action: () -> Void
    @EnvironmentObject var appData: AppData

    var body: some View {
        let defaultColor = appData.categories.first(where: { $0.name == appData.defaultCategory })?.color ?? Color.blue

        Button(action: action) {
            ZStack {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .bold)) // Adjust the size of the icon
                    .foregroundColor(defaultColor) // Set icon color to the default category color
            }
        }
    }
}