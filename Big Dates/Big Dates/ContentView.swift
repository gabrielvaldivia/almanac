//
//  ContentView.swift
//  Big Dates
//
//  Created by Gabriel Valdivia on 6/17/24.
//

import SwiftUI

struct ContentView: View {
    @State private var events: [Event] = []
    @State private var showingAddEvent = false  // Added this line
    private let eventManager = EventManager()

    init() {
        _events = State(initialValue: eventManager.loadEvents())
    }

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
            events = eventManager.loadEvents()
        }
        .onChange(of: events) { newValue, oldValue in
            events.sort(by: { $0.date < $1.date })
            eventManager.saveEvents(events)
        }
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
                    events.remove(at: index)
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
        events.remove(atOffsets: offsets)
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
