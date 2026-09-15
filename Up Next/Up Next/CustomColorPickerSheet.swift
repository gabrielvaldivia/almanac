//
//  CustomColorPickerSheet.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 7/22/24.
//

import Foundation
import SwiftUI

struct ColorSelectionRow: View {
    let color: Color
    var action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack {
                Text("Color")
                    .foregroundStyle(.primary)
                Spacer(minLength: 32)
            }
            .overlay(alignment: .trailing) {
                // Keep the swatch from changing the standard text row height.
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Color")
        .accessibilityValue(CustomColorPickerSheet.colorName(for: CodableColor(color: color), scheme: colorScheme))
        .accessibilityHint("Choose a color")
    }
}

struct CustomColorPickerSheet: View {
    @Binding var selectedColor: CodableColor
    @Binding var showColorPickerSheet: Bool
    @Environment(\.colorScheme) var colorScheme
    
    private static let namedColors: [(name: String, color: Color)] = [
        ("Gray", .gray), ("Blue", .blue), ("Indigo", .indigo), ("Purple", .purple),
        ("Red", .red), ("Pink", .pink), ("Yellow", .yellow), ("Orange", .orange),
        ("Brown", .brown), ("Green", .green), ("Teal", .teal)
    ]

    static let predefinedColors: [Color] = namedColors.map(\.color)

    static func colorChoices(for scheme: ColorScheme) -> [(name: String, color: Color)] {
        [(scheme == .dark ? "White" : "Black", scheme == .dark ? .white : .black)] + namedColors
    }

    static func colorName(for color: CodableColor, scheme: ColorScheme) -> String {
        colorChoices(for: scheme).first { choice in
            let candidate = CodableColor(color: choice.color)
            // SwiftUI/UIKit color conversion can round the stored RGB components.
            return abs(candidate.red - color.red) < 0.001 && abs(candidate.green - color.green) < 0.001 &&
                abs(candidate.blue - color.blue) < 0.001 && abs(candidate.opacity - color.opacity) < 0.001
        }?.name ?? "Custom"
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
            ForEach(Self.colorChoices(for: colorScheme), id: \.name) { choice in
                Button(action: {
                    selectedColor = CodableColor(color: choice.color)
                    showColorPickerSheet = false
                }) {
                    Circle()
                        .fill(choice.color)
                        .frame(width: 50, height: 50)
                        .padding(.bottom, 10)
                        .accessibilityLabel(choice.name)
                        .accessibilityValue(selectedColor == CodableColor(color: choice.color) ? "Selected" : "")
                }
            }
        }
        .padding()
    }
    
}
