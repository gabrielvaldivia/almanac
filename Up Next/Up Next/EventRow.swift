//
//  EventRow.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI
import UIKit

// EVENT ROW
struct EventRow: View {
    var event: Event
    var isHighlighted = false
    @Binding var selectedEvent: Event?
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appData: AppData

    static func backgroundShape(for eventStyle: String) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: eventStyle == "bubbly" ? 24 : 8)
    }

    var body: some View {
        let colors = EventRowColors(category: event.color, style: appData.eventStyle,
                                    dark: colorScheme == .dark, highlighted: isHighlighted)
        Button { selectedEvent = event } label: {
        HStack(alignment: .top, spacing: appData.eventStyle == "naked" ? 8 : 20) {
            // Event Style Indicator
            if appData.eventStyle == "naked" {
                RoundedRectangle(cornerRadius: 3)
                    .fill(event.color.color)
                    .frame(width: 3)
                    .padding(.vertical, 4)
            }
            VStack(alignment: .leading) {
                // Event Title
                HStack {
                    Text(event.title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(colors.title.color)
                        .padding(.bottom, 1)
                    Spacer()
                }

                // Event date and duration
                Text(EventDateText.range(start: event.date, end: event.endDate, reference: Date()))
                    .font(.footnote)
                    .foregroundColor(colors.date.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, appData.eventStyle == "naked" ? 4 : 12)
            .padding(.horizontal, appData.eventStyle == "naked" ? 0 : 16)
        }
        .background(backgroundColor, in: Self.backgroundShape(for: appData.eventStyle))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var backgroundColor: Color {
        if isHighlighted { return event.color.color.opacity(colorScheme == .dark ? 0.4 : 0.24) }
        return appData.eventStyle == "naked" ? .clear : event.color.color.opacity(colorScheme == .dark ? 0.2 : 0.1)
    }

}

/// Adjust only text that needs more contrast; category decoration remains unchanged.
struct EventRowColors {
    let title: CodableColor
    let date: CodableColor
    let background: CodableColor

    init(category: CodableColor, style: String, dark: Bool, highlighted: Bool) {
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        func resolved(_ color: UIColor) -> CodableColor {
            CodableColor(color: Color(uiColor: color.resolvedColor(with: traits)))
        }
        var tint = category
        tint.opacity *= highlighted ? (dark ? 0.4 : 0.24) : (style == "naked" ? 0 : dark ? 0.2 : 0.1)
        background = Self.composite(tint, over: resolved(.systemBackground))
        let preferredTitle = dark ? resolved(.white) : style == "naked" ? resolved(.label) : category
        var preferredDate = dark ? resolved(.white) : style == "naked" ? resolved(.secondaryLabel) : category
        preferredDate.opacity *= dark ? 0.5 : style == "naked" ? 1 : 0.7
        title = Self.readable(preferredTitle, over: background)
        date = Self.readable(preferredDate, over: background)
    }

    static func secondaryLabel(dark: Bool) -> Color {
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        let foreground = CodableColor(color: Color(uiColor: UIColor.secondaryLabel.resolvedColor(with: traits)))
        let background = CodableColor(color: Color(uiColor: UIColor.systemBackground.resolvedColor(with: traits)))
        return readable(foreground, over: background).color
    }

    private static func composite(_ foreground: CodableColor, over background: CodableColor) -> CodableColor {
        let alpha = min(1, max(0, foreground.opacity))
        var result = foreground
        result.red = foreground.red * alpha + background.red * (1 - alpha)
        result.green = foreground.green * alpha + background.green * (1 - alpha)
        result.blue = foreground.blue * alpha + background.blue * (1 - alpha)
        result.opacity = 1
        return result
    }

    static func contrast(_ first: CodableColor, _ second: CodableColor) -> Double {
        func luminance(_ color: CodableColor) -> Double {
            func linear(_ channel: Double) -> Double {
                let value = min(1, max(0, channel))
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
        }
        let a = luminance(first), b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    static func readable(_ foreground: CodableColor, over background: CodableColor) -> CodableColor {
        let original = composite(foreground, over: background)
        guard contrast(original, background) < 4.6 else { return original }
        let black = CodableColor(color: .black), white = CodableColor(color: .white)
        let endpoint = contrast(black, background) > contrast(white, background) ? black : white
        var low = 0.0, high = 1.0
        var result = endpoint
        for _ in 0..<12 {
            let amount = (low + high) / 2
            var overlay = endpoint
            overlay.opacity = amount
            let candidate = composite(overlay, over: original)
            if contrast(candidate, background) >= 4.6 {
                result = candidate
                high = amount
            } else { low = amount }
        }
        return result
    }
}
