//
//  PastEventsView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI

struct PastEventsView: View {
    @Binding var events: [Event]
    @Binding var selectedEvent: Event?
    @Binding var newEventTitle: String
    @Binding var newEventDate: Date
    @Binding var newEventEndDate: Date
    @Binding var showEndDate: Bool
    @Binding var showEditSheet: Bool
    @Binding var selectedCategory: String?
    @Binding var showPastEventsSheet: Bool
    var categories: [(name: String, color: Color)]
    var itemDateFormatter: DateFormatter
    var saveEvents: () -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(pastEvents(), id: \.id) { event in
                    EventRow(event: event, formatter: itemDateFormatter,
                             selectedEvent: $selectedEvent,
                             newEventTitle: $newEventTitle,
                             newEventDate: $newEventDate,
                             newEventEndDate: $newEventEndDate,
                             showEndDate: $showEndDate,
                             showEditSheet: $showEditSheet,
                             selectedCategory: $selectedCategory,
                             categories: categories)
                    .listRowSeparator(.hidden)
                }
                .onDelete(perform: deletePastEvent)
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Past Events")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                self.showPastEventsSheet = false
            })
        }
    }

    func pastEvents() -> [Event] {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        return events.filter { event in
            if let endDate = event.endDate {
                return endDate < startOfToday
            } else {
                return event.date < startOfToday
            }
        }
        .sorted { (event1, event2) -> Bool in
            let endDate1 = event1.endDate ?? event1.date
            let endDate2 = event2.endDate ?? event2.date
            if endDate1 == endDate2 {
                return event1.date > event2.date
            } else {
                return endDate1 > endDate2
            }
        }
    }

    func deletePastEvent(at offsets: IndexSet) {
        let pastEvents = self.pastEvents()
        for index in offsets {
            if let mainIndex = events.firstIndex(where: { $0.id == pastEvents[index].id }) {
                events.remove(at: mainIndex)
            }
        }
        saveEvents()
    }
}

struct PastEventsView_Previews: PreviewProvider {
    static var previews: some View {
        PastEventsView(events: .constant([]), selectedEvent: .constant(nil), newEventTitle: .constant(""), newEventDate: .constant(Date()), newEventEndDate: .constant(Date()), showEndDate: .constant(false), showEditSheet: .constant(false), selectedCategory: .constant(nil), showPastEventsSheet: .constant(false), categories: [], itemDateFormatter: DateFormatter(), saveEvents: {})
    }
}