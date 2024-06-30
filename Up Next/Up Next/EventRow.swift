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
    var categories: [(name: String, color: Color)]
    @Environment(\.colorScheme) var colorScheme // Inject the color scheme environment variable

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading) {
                HStack {
                    Text(event.title)
                        .roundedFont(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(colorScheme == .dark ? .white : colorForCategory(event.category)) // Set title color based on color scheme
                    Spacer()
                    if event.notificationsEnabled {
                        Image(systemName: "bell.fill")
                            .foregroundColor(colorForCategory(event.category).opacity(0.9)) // Set bell icon color to match category color
                            .font(.caption)
                            .padding(.trailing)
                    }
                }
                if let endDate = event.endDate {
                    let today = Date()
                    let duration = Calendar.current.dateComponents([.day], from: event.date, to: endDate).day! + 1
                    if today > event.date && today < endDate {
                        let daysLeft = Calendar.current.dateComponents([.day], from: today, to: endDate).day! + 1
                        let daysLeftText = daysLeft == 1 ? "1 day left" : "\(daysLeft) days left"
                        Text("\(event.date, formatter: monthDayFormatter) — \(endDate, formatter: monthDayFormatter) (\(daysLeftText))")
                            .roundedFont(.subheadline)
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.5) : colorForCategory(event.category).opacity(0.7)) // Set date color based on color scheme
                    } else {
                        Text("\(event.date, formatter: monthDayFormatter) — \(endDate, formatter: monthDayFormatter) (\(duration) days)")
                            .roundedFont(.subheadline)
                            .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.5) : colorForCategory(event.category).opacity(0.7)) // Set date color based on color scheme
                    }
                } else {
                    Text(event.date, formatter: monthDayFormatter)
                        .roundedFont(.subheadline)
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.5) : colorForCategory(event.category).opacity(0.7)) // Set date color based on color scheme
                }
                if event.repeatOption != .never {
                    Text("Repeats \(event.repeatOption.rawValue.lowercased())")
                        .roundedFont(.subheadline)
                        .foregroundColor(colorScheme == .dark ? Color.white.opacity(0.5) : colorForCategory(event.category).opacity(0.7))
                }
            }
            .padding(.vertical, 10)
            .padding(.leading, 10)
            .background(
                colorForCategory(event.category).opacity(colorScheme == .light ? 0.1 : 0.3) // Use the injected color scheme here
            )
            .cornerRadius(10) // Apply rounded corners
        }
    }

    // Function to determine color based on category
    func colorForCategory(_ category: String?) -> Color {
        guard let category = category else { return .gray } 
        return categories.first(where: { $0.name == category })?.color ?? .gray
    }

    // New DateFormatter for month and day
    private var monthDayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter
    }
}