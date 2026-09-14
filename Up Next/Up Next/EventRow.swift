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
    @Binding var newEventTitle: String
    @Binding var newEventDate: Date
    @Binding var newEventEndDate: Date
    @Binding var showEndDate: Bool
    @Binding var selectedCategory: String?
    @Binding var showEditSheet: Bool
    var categories: [(name: String, color: Color)]
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appData: AppData

    static func backgroundShape(for eventStyle: String) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: eventStyle == "bubbly" ? 24 : 8)
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter
    }()

    private func getDurationText(start: Date, end: Date?) -> String {
        return rangeDescription(from: start, to: end)
    }

    var body: some View {
        Button(action: editEvent) {
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
                        .foregroundColor(
                            colorScheme == .dark
                                ? .white
                                : (appData.eventStyle == "naked" ? .primary : event.color.color)
                        )
                        .padding(.bottom, 1)
                    Spacer()
                }

                // Event date and duration
                Text(getDurationText(start: event.date, end: event.endDate))
                    .font(.footnote)
                    .foregroundColor(
                        colorScheme == .dark
                            ? Color.white.opacity(0.5)
                            : (appData.eventStyle == "naked"
                                ? .secondary : event.color.color.opacity(0.7))
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, appData.eventStyle == "naked" ? 4 : 12)
            .padding(.horizontal, appData.eventStyle == "naked" ? 0 : 16)
        }
        .background(backgroundColor)
        .clipShape(Self.backgroundShape(for: appData.eventStyle))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var backgroundColor: Color {
        if isHighlighted { return event.color.color.opacity(colorScheme == .dark ? 0.4 : 0.24) }
        return appData.eventStyle == "naked" ? .clear : event.color.color.opacity(colorScheme == .dark ? 0.2 : 0.1)
    }

    private func editEvent() {
            selectedEvent = event
            newEventTitle = event.title
            newEventDate = event.date
            newEventEndDate =
                event.endDate ?? Calendar.current.date(byAdding: .day, value: 1, to: event.date)
                ?? event.date
            showEndDate = event.endDate != nil
            selectedCategory = event.category
            showEditSheet = true
    }

    private func rangeDescription(from startDate: Date, to endDate: Date?) -> String {
        EventDateText.range(start: startDate, end: endDate, reference: Date())
    }
}

extension RepeatOption {
    var shorthand: String {
        switch self {
        case .daily: return "d"
        case .weekly: return "w"
        case .monthly: return "m"
        case .yearly: return "y"
        case .never, .custom: return ""
        }
    }
}
