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
    @Binding var showPastEventsSheet: Bool
    @Binding var showEditSheet: Bool
    @Binding var selectedColor: CodableColor
    var categories: [(name: String, color: Color)]
    var itemDateFormatter: DateFormatter
    var saveEvents: () -> Void
    @EnvironmentObject var appData: AppData
    @State private var isEditSheetPresented = false

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack {
                    let groupedEvents = groupedPastEvents()
                    let sortedGroupedEvents = groupedEvents.sorted(by: { $1.key > $0.key })
                    
                    ForEach(sortedGroupedEvents, id: \.key) { monthYear, events in
                        Section(header: Text(monthYear)
                                    .roundedFont(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.top, 20)
                                    .padding(.horizontal, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)) {
                            ForEach(events, id: \.id) { event in
                                Button(action: {
                                    selectedEvent = event
                                    newEventTitle = event.title
                                    newEventDate = event.date
                                    newEventEndDate = event.endDate ?? Calendar.current.date(byAdding: .day, value: 1, to: event.date) ?? event.date
                                    showEndDate = event.endDate != nil
                                    selectedCategory = event.category
                                    selectedColor = event.color
                                    isEditSheetPresented = true
                                }) {
                                    VStack {
                                        EventRow(event: event, formatter: itemDateFormatter,
                                                 selectedEvent: $selectedEvent,
                                                 newEventTitle: $newEventTitle,
                                                 newEventDate: $newEventDate,
                                                 newEventEndDate: $newEventEndDate,
                                                 showEndDate: $showEndDate,
                                                 selectedCategory: $selectedCategory,
                                                 showEditSheet: $isEditSheetPresented,
                                                 categories: appData.categories)
                                    }
                                    .listRowSeparator(.hidden)
                                }
                                .listRowSeparator(.hidden)
                            }
                            .onDelete(perform: deletePastEvent)
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .listRowSeparator(.hidden)
                .padding()
            }
            .navigationTitle("Past Events")
            .roundedFont(.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                self.showPastEventsSheet = false
            })
            .sheet(isPresented: $isEditSheetPresented) {
                EditEventView(events: $events,
                              selectedEvent: $selectedEvent,
                              newEventTitle: $newEventTitle,
                              newEventDate: $newEventDate,
                              newEventEndDate: $newEventEndDate,
                              showEndDate: $showEndDate,
                              showEditSheet: $showEditSheet,
                              selectedCategory: $selectedCategory,
                              selectedColor: $selectedColor,
                              saveEvent: saveEvent)
            }
        }
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

    func saveEvent() {
        if let selectedEvent = selectedEvent,
           let index = events.firstIndex(where: { $0.id == selectedEvent.id }) {
            events[index].title = newEventTitle
            events[index].date = newEventDate
            events[index].endDate = showEndDate ? newEventEndDate : nil
            events[index].category = selectedCategory
            events[index].color = selectedColor
            saveEvents()
        }
        isEditSheetPresented = false
    }
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
                       showPastEventsSheet: .constant(false),
                       showEditSheet: .constant(false),
                       selectedColor: .constant(CodableColor(color: .black)),
                       categories: [],
                       itemDateFormatter: DateFormatter(),
                       saveEvents: {})
            .environmentObject(AppData())
    }
}