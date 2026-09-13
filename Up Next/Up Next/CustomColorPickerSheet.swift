//
//  CustomColorPickerSheet.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 7/22/24.
//

import Foundation
import SwiftUI

struct CustomColorPickerSheet: View {
    @Binding var selectedColor: CodableColor
    @Binding var showColorPickerSheet: Bool
    @Environment(\.colorScheme) var colorScheme
    
    static let predefinedColors: [Color] = [
        .gray, .blue, .indigo, .purple, .red, .pink, .yellow, .orange, .brown, .green, .teal
    ]

    var contrastColor: Color {
        let brightness = (selectedColor.red * 299 + selectedColor.green * 587 + selectedColor.blue * 114) / 1000
        return brightness > 0.7 ? .black : .white
    }

    var body: some View {
        NavigationView {
            VStack {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 40, height: 6)
                    .padding(.top, 8)
                ScrollView {
                    ColorGrid()
                }
                .padding()
            }
        }
    }
    
    @ViewBuilder
    private func ColorGrid() -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
            ForEach(Array(colorOptions.enumerated()), id: \.offset) { index, color in
                Button(action: {
                    selectedColor = CodableColor(color: color)
                    showColorPickerSheet = false
                }) {
                    Circle()
                        .fill(color)
                        .frame(width: 50, height: 50)
                        .padding(.bottom, 10)
                        .accessibilityLabel(colorNames[index])
                        .accessibilityValue(selectedColor.color == color ? "Selected" : "")
                }
            }
        }
        .padding()
    }
    
    private var colorNames: [String] {
        [colorScheme == .dark ? "White" : "Black", "Gray", "Blue", "Indigo", "Purple", "Red", "Pink", "Yellow", "Orange", "Brown", "Green", "Teal"]
    }

    private var colorOptions: [Color] {
        return [colorScheme == .dark ? .white : .black] + Self.predefinedColors
    }
}