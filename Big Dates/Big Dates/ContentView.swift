//
//  ContentView.swift
//  Big Dates
//
//  Created by Gabriel Valdivia on 6/17/24.
//

import SwiftUI

struct ContentView: View {
    @State var events: [Event] = []
    @State private var showingAddEvent = false  // Added this line
    private let eventManager = EventManager()

    // Create a static date formatter
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"  // Updated date format
        return formatter
    }()

    var body: some View {
        NavigationStack {
            mainContent
        }
        .onAppear {
            loadEvents()
        }
        .onChange(of: events) { _ in
            sortAndSaveEvents()
        }
    }

    private func loadEvents() {
        events = eventManager.loadEvents()
    }

    private func sortAndSaveEvents() {
        events = eventManager.sortEvents(events)
        eventManager.saveEvents(events)
    }

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            EventListView(events: events)
            addButton
        }
        .navigationTitle("Upcoming")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: EventHistoryView(events: $events)) {
                    Image(systemName: "clock.arrow.circlepath")
                }
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(events: $events)
        }
        .presentationDetents([.medium])
        .navigationDestination(for: Event.self) { event in
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                EventDetailView(event: events[index], onDelete: {
                    var updatedEvents = events
                    updatedEvents.remove(at: index)
                    events = updatedEvents
                    eventManager.saveEvents(events)
                }, onSave: {
                    eventManager.saveEvents(events)
                })
            }
        }
    }

    private var addButton: some View {
        VStack {
            Spacer()
            Button(action: {
                self.showingAddEvent = true
            }) {
                Image(systemName: "plus")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(radius: 10)
            }
        }
    }

    func removeEvents(at offsets: IndexSet) {
        var updatedEvents = events
        updatedEvents.remove(atOffsets: offsets)
        events = updatedEvents
    }

    private func isEventDateTodayOrLater(_ date: Date) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let eventDate = Calendar.current.startOfDay(for: date)
        return eventDate >= today
    }
}



#Preview {
    ContentView()
}
