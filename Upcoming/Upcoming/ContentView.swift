//
//  ContentView.swift
//  Upcoming
//
//  Created by Gabriel Valdivia on 6/18/24.
//

import SwiftUI

struct ContentView: View {
    @State private var events: [Event] = []
    @State private var showingAddEvent = false
    @State private var selectedEvent: Event?
    @State private var showingPastEvents = false
    
    let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy" // Matches the format used to create the keys
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(groupedEvents.keys.sorted(by: { (key1, key2) -> Bool in
                    guard let date1 = monthYearFormatter.date(from: key1),
                          let date2 = monthYearFormatter.date(from: key2) else {
                        return false
                    }
                    return date1 < date2
                }), id: \.self) { key in
                    Section(header: Text(key)) {
                        ForEach(groupedEvents[key]?.filter { $0.date >= Date().midnight } ?? [], id: \.id) { event in
                            EventRow(event: .constant(event), onTap: {
                                selectedEvent = event
                            })
                        }
                        .onDelete { offsets in
                            removeEvents(at: offsets, from: key)
                        }
                    }
                }
            }
            .navigationTitle("Upcoming")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button(action: {
                showingPastEvents = true
            }) {
                Image(systemName: "clock.arrow.circlepath") // Icon for past events
            }, trailing: Button(action: {
                showingAddEvent = true
            }) {
                Image(systemName: "plus")
            })
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(events: $events)
            }
            .sheet(item: $selectedEvent) { event in
                EditEventView(event: .constant(event))
            }
            .sheet(isPresented: $showingPastEvents) {
                NavigationView {
                    PastEventsView(events: $events)
                }
            }
        }
    }
    
    func removeEvents(at offsets: IndexSet, from monthYearKey: String) {
        guard var eventsForMonth = groupedEvents[monthYearKey] else { return }
        eventsForMonth.remove(atOffsets: offsets)
        events = events.filter { monthYear(from: $0.date) != monthYearKey }
        events.append(contentsOf: eventsForMonth)
        saveEvents()
    }
    
    func saveEvents() {
        if let encoded = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(encoded, forKey: "Events")
        }
    }
    
    func loadEvents() {
        if let savedEvents = UserDefaults.standard.object(forKey: "Events") as? Data {
            if let decodedEvents = try? JSONDecoder().decode([Event].self, from: savedEvents) {
                events = decodedEvents
            }
        }
    }
    
    func monthYear(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy" // e.g., January 2023
        return formatter.string(from: date)
    }
    
    var groupedEvents: [String: [Event]] {
        let allGroupedEvents = Dictionary(grouping: events, by: { monthYear(from: $0.date) })
        let now = Date().midnight
        return allGroupedEvents.filter { key, events in
            events.contains { $0.date >= now }
        }
    }
    
    init() {
        loadEvents()
    }
}

struct EventRow: View {
    @Binding var event: Event
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(event.title)
                Spacer()
                Text(event.date, style: .date)
                    .foregroundColor(.gray)
            }
        }
        .buttonStyle(PlainButtonStyle()) // Use PlainButtonStyle to keep the default list row look
    }
}

#Preview {
    ContentView()
}