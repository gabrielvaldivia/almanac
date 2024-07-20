//
//  EventRow.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI

// EVENT ROW
struct EventRow: View {
    var event: Event
    var formatter: DateFormatter
    @Binding var selectedEvent: Event?
    @Binding var newEventTitle: String
    @Binding var newEventDate: Date
    @Binding var newEventEndDate: Date
    @Binding var showEndDate: Bool
    @Binding var selectedCategory: String?
    @Binding var showEditSheet: Bool
    var categories: [(name: String, color: Color)]
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading) {
                HStack {
                    Text(event.title)
                        .roundedFont(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(colorScheme == .dark ? .white : event.color.color)
                    Spacer()
                }
                if let endDate = event.endDate, event.date != endDate {
                    let today = Date()
                    let duration = Calendar.current.dateComponents([.day], from: event.date, to: endDate).day! + 1
                    if today > event.date && today < endDate {
                        let daysLeft = Calendar.current.dateComponents([.day], from: today, to: endDate).day! + 1
                        let daysLeftText = daysLeft == 1 ? "1 day left" : "\(daysLeft) days left"
                        Text("\(event.date, formatter: monthDayFormatter) → \(endDate, formatter: monthDayFormatter) (\(daysLeftText))")
                            .roundedFont(.footnote)
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.5) : event.color.color.opacity(0.7))
                    } else {
                        Text("\(event.date, formatter: monthDayFormatter) → \(endDate, formatter: monthDayFormatter) (\(duration) days)")
                            .roundedFont(.footnote)
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.5) : event.color.color.opacity(0.7))
                    }
                } else {
                    Text(event.date, formatter: monthDayFormatter)
                        .roundedFont(.footnote)
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.5) : event.color.color.opacity(0.7))
                }
                if event.repeatOption != .never {
                    if event.repeatOption == .custom, let count = event.customRepeatCount, let unit = event.repeatUnit {
                        let unitText = count == 1 ? String(unit.lowercased().dropLast()) : unit.lowercased()
                        Text("Repeats every \(count) \(unitText)")
                            .roundedFont(.footnote)
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.5) : event.color.color.opacity(0.7))
                    } else {
                        Text("Repeats \(event.repeatOption.rawValue.lowercased())")
                            .roundedFont(.footnote)
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.5) : event.color.color.opacity(0.7))
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.leading, 10)
            .background(
                event.color.color.opacity(colorScheme == .light ? 0.1 : 0.3)
            )
            .cornerRadius(10)
        }
    }

    // New DateFormatter for month and day
    private var monthDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }
}