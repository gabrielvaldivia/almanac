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
    
    var body: some View {
        NavigationView {
            List {
                ForEach($events) { $event in
                    if Calendar.current.isDate(event.date, inSameDayAs: Date()) || event.date > Date() {
                        EventRow(event: $event, onTap: {
                            selectedEvent = event
                        })
                    }
                }
                .onDelete(perform: removeEvents)
            }
            .navigationTitle("Upcoming")
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
                PastEventsView(events: $events)
            }
        }
    }
    
    func removeEvents(at offsets: IndexSet) {
        events.remove(atOffsets: offsets)
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