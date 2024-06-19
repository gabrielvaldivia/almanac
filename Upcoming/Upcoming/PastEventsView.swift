//
//  PastEventsView.swift
//  Upcoming
//
//  Created by Gabriel Valdivia on 6/18/24.
//

import Foundation
import SwiftUI

struct PastEventsView: View {
    @Binding var events: [Event]
    @State private var selectedEvent: Event?
    let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    var body: some View {
        List {
            ForEach(pastGroupedEvents.keys.sorted(by: { (key1, key2) -> Bool in
                guard let date1 = monthYearFormatter.date(from: key1),
                      let date2 = monthYearFormatter.date(from: key2) else {
                    return false
                }
                return date1 < date2
            }), id: \.self) { key in
                Section(header: Text(key)) {
                    ForEach(pastGroupedEvents[key] ?? [], id: \.id) { event in
                        HStack {
                            Text(event.title)
                            Spacer()
                            Text(eventDateFormatted(event.date))
                                .foregroundColor(.gray)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            self.selectedEvent = event
                        }
                    }
                }
            }
        }
        .navigationTitle("Past Events")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedEvent) { event in
            EditEventView(event: .constant(event))
        }
    }

    var pastGroupedEvents: [String: [Event]] {
        Dictionary(grouping: events.filter { $0.date < Date().midnight }, by: { monthYear(from: $0.date) })
    }

    func monthYear(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    func eventDateFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}