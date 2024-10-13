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
    @Binding var selectedCategory: String?
    @Binding var showEditSheet: Bool
    @Binding var selectedColor: CodableColor
    var categories: [(name: String, color: Color)]
    var itemDateFormatter: DateFormatter
    var saveEvents: () -> Void
    @EnvironmentObject var appData: AppData
    @State private var isEditSheetPresented = false

    var body: some View {
        ScrollView {
            pastEventsList
        }
        .navigationTitle("Past Events")
        .roundedFont(.title)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $isEditSheetPresented) {
            editEventSheet
        }
    }

    private var pastEventsList: some View {
        LazyVStack {
            ForEach(groupedPastEvents().sorted(by: { $1.key > $0.key }), id: \.key) { monthYear, events in
                pastEventSection(monthYear: monthYear, events: events)
            }
        }
        .listStyle(PlainListStyle())
        .listRowSeparator(.hidden)
        .padding()
    }

    private func pastEventSection(monthYear: String, events: [Event]) -> some View {
        Section(header: sectionHeader(title: monthYear)) {
            ForEach(events, id: \.id) { event in
                pastEventButton(event: event)
            }
            .onDelete(perform: deletePastEvent)
        }
    }

    private func sectionHeader(title: String) -> some View {
        Text(title)
            .roundedFont(.headline)
            .fontWeight(.semibold)
            .padding(.top, 20)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pastEventButton(event: Event) -> some View {
        Button(action: {
            selectEvent(event)
            isEditSheetPresented = true
        }) {
            EventRow(event: event,
                     selectedEvent: $selectedEvent,
                     newEventTitle: $newEventTitle,
                     newEventDate: $newEventDate,
                     newEventEndDate: $newEventEndDate,
                     showEndDate: $showEndDate,
                     selectedCategory: $selectedCategory,
                     showEditSheet: $isEditSheetPresented,
                     categories: appData.categories.map { (name: $0.name, color: $0.color) })
        }
        .listRowSeparator(.hidden)
    }

    private var editEventSheet: some View {
        EditEventView(
            events: $events,
            selectedEvent: $selectedEvent,
            showEditSheet: $isEditSheetPresented,
            saveEvents: saveEvents
        )
        .environmentObject(appData)
    }

    private func selectEvent(_ event: Event) {
        selectedEvent = event
        newEventTitle = event.title
        newEventDate = event.date
        newEventEndDate = event.endDate ?? Calendar.current.date(byAdding: .day, value: 1, to: event.date) ?? event.date
        showEndDate = event.endDate != nil
        selectedCategory = event.category
        selectedColor = event.color
    }

    func groupedPastEvents() -> [String: [Event]] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        
        let pastEvents = self.pastEvents()
        var groupedEvents = [String: [Event]]()
        
        for event in pastEvents {
            let monthYear = dateFormatter.string(from: event.date)
            if groupedEvents[monthYear] != nil {
                groupedEvents[monthYear]?.append(event)
            } else {
                groupedEvents[monthYear] = [event]
            }
        }
        
        return groupedEvents
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
        offsets.forEach { index in
            let event = pastEvents[index]
            if let eventIndex = events.firstIndex(where: { $0.id == event.id }) {
                events.remove(at: eventIndex)
            }
        }
        saveEvents()
    }

    // func saveEvents() {
    //     if let selectedEvent = selectedEvent,
    //        let index = events.firstIndex(where: { $0.id == selectedEvent.id }) {
    //         events[index].title = newEventTitle
    //         events[index].date = newEventDate
    //         events[index].endDate = showEndDate ? newEventEndDate : nil
    //         events[index].category = selectedCategory
    //         events[index].color = selectedColor
    //         saveEvents()
    //     }
    //     isEditSheetPresented = false
    // }
}

struct PastEventsView_Previews: PreviewProvider {
    static var previews: some View {
        PastEventsView(events: .constant([]),
                       selectedEvent: .constant(nil),
                       newEventTitle: .constant(""),
                       newEventDate: .constant(Date()),
                       newEventEndDate: .constant(Date()),
                       showEndDate: .constant(false),
                       selectedCategory: .constant(nil),
                       showEditSheet: .constant(false),
                       selectedColor: .constant(CodableColor(color: .black)),
                       categories: [],
                       itemDateFormatter: DateFormatter(),
                       saveEvents: {})
            .environmentObject(AppData())
    }
}
