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
    @Binding var showEditSheet: Bool
    @Binding var selectedCategory: String? // Add this line
    var categories: [(name: String, color: Color)]
    @Environment(\.colorScheme) var colorScheme // Inject the color scheme environment variable

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading) {
                HStack {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(colorForCategory(event.category)) // Use category color
                    Spacer()
                }
                if let endDate = event.endDate {
                    let today = Date()
                    let duration = Calendar.current.dateComponents([.day], from: event.date, to: endDate).day! + 1
                    if today > event.date && today < endDate {
                        let daysLeft = Calendar.current.dateComponents([.day], from: today, to: endDate).day! + 1
                        let daysLeftText = daysLeft == 1 ? "1 day left" : "\(daysLeft) days left"
                        Text("\(event.date, formatter: formatter) — \(endDate, formatter: formatter) (\(daysLeftText))")
                            .font(.subheadline)
                            .foregroundColor(colorForCategory(event.category).opacity(0.5)) // Set color to category color at 50% opacity
                    } else {
                        Text("\(event.date, formatter: formatter) — \(endDate, formatter: formatter) (\(duration) days)")
                            .font(.subheadline)
                            .foregroundColor(colorForCategory(event.category).opacity(0.5)) // Set color to category color at 50% opacity
                    }
                } else {
                    Text(event.date, formatter: formatter)
                        .font(.subheadline)
                        .foregroundColor(colorForCategory(event.category).opacity(0.5)) // Set color to category color at 50% opacity
                }
            }
            .padding(.vertical, 10)
            .padding(.leading, 10)
            .background(
                colorForCategory(event.category).opacity(colorScheme == .light ? 0.05 : 0.2) // Use the injected color scheme here
            )
            .cornerRadius(10) // Apply rounded corners
        }
        .onTapGesture {
            self.selectedEvent = event
            self.newEventTitle = event.title
            self.newEventDate = event.date
            self.newEventEndDate = event.endDate ?? Date()
            self.showEndDate = event.endDate != nil
            self.selectedCategory = event.category 
            self.showEditSheet = true
        }
    }

    // Function to determine color based on category
    func colorForCategory(_ category: String?) -> Color {
        guard let category = category else { return .gray } 
        return categories.first(where: { $0.name == category })?.color ?? .gray
    }
}
