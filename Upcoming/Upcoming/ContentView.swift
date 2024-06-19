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
    
    // Constants
    private let userDefaultsSuiteName = "group.Upcoming"
    
    let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy" // Matches the format used to create the keys
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            List { // List view for the upcoming events
                ForEach(groupedEvents.keys.sorted(by: { (key1, key2) -> Bool in
                    guard let date1 = monthYearFormatter.date(from: key1),
                          let date2 = monthYearFormatter.date(from: key2) else {
                        return false
                    }
                    return date1 < date2
                }), id: \.self) { key in
                
                    // Section for each month 
                    Section(header: Text(headerTitle(for: key))) {
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

            // Top section
            .navigationTitle("Upcoming")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button(action: {
                showingPastEvents = true
            }) {
                Image(systemName: "clock.arrow.circlepath") // Icon for past events
            })
            .toolbar {
                // Toolbar items here if needed
            }

            // Floating Action Button for adding new events
            .overlay(
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingAddEvent = true
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                                .font(.title)
                                .padding(15)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 10)
                        }
                        .padding()
                        Spacer()
                    }
                }
            )

            // Add event sheet
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(events: $events, onSave: saveEvents)
            }

            // Edit event sheet
            .sheet(item: $selectedEvent) { event in
                EditEventView(event: .constant(event)) {_ in 
                    self.updateEvent(event)
                }
            }

            // Past events sheet
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
    
    // Function to save the events to UserDefaults
    func saveEvents() {
        print("Attempting to save events: \(events)")
        do {
            let encoded = try JSONEncoder().encode(events)
            print("Encoding successful: \(encoded.count) bytes")
            let userDefaults = UserDefaults(suiteName: userDefaultsSuiteName)
            userDefaults?.set(encoded, forKey: "Events")
            let success = userDefaults?.synchronize() // Ensuring data is saved immediately
            if success == true {
                print("Events saved successfully.")
            } else {
                print("Failed to synchronize UserDefaults.")
            }
        } catch {
            print("Failed to encode events: \(error)")
        }
    }
    
    // Function to load the events from UserDefaults
    func loadEvents() {
        let userDefaults = UserDefaults(suiteName: userDefaultsSuiteName)
        if let savedEvents = userDefaults?.object(forKey: "Events") as? Data {
            do {
                let decodedEvents = try JSONDecoder().decode([Event].self, from: savedEvents)
                events = decodedEvents
                print("Events loaded successfully.")
            } catch {
                print("Failed to decode events: \(error)")
            }
        } else {
            print("No events data found in UserDefaults.")
        }
    }
    
    // Function to format the date
    func monthYear(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy" // e.g., January 2023
        return formatter.string(from: date)
    }
    
    // Function to group the events by month and year
    var groupedEvents: [String: [Event]] {
        let allGroupedEvents = Dictionary(grouping: events, by: { monthYear(from: $0.date) })
        let now = Date().midnight
        return allGroupedEvents.filter { key, events in
            events.contains { $0.date >= now }
        }
    }
    
    // Function to update the event
    func updateEvent(_ event: Event) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
            saveEvents()  // Save the updated events array
        }
    }
    
    // Helper function to determine the header title
    private func headerTitle(for key: String) -> String {
        let currentMonthYear = monthYear(from: Date())
        return key == currentMonthYear ? "This Month" : key
    }
    
    init() {
        loadEvents()
    }
    
    func testUserDefaults() {
        let userDefaults = UserDefaults(suiteName: userDefaultsSuiteName)
        userDefaults?.set("Test", forKey: "TestKey")
        userDefaults?.synchronize()
        if let testValue = userDefaults?.string(forKey: "TestKey") {
            print("Test value retrieved successfully: \(testValue)")
        } else {
            print("Failed to retrieve test value from UserDefaults.")
        }
    }
}

struct EventRow: View {
    @Binding var event: Event
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading) {
                HStack {
                    Text(event.title)
                        .font(.body) // Standard body font for the title
                    Spacer()
                    Text(relativeDateString(for: event.date)) // Relative date to the right
                        .font(.subheadline) // Slightly smaller than body, for relative date
                        .foregroundColor(.gray)
                }
                Text(eventDateFormatted(event.date)) // Actual date below the title
                    .font(.subheadline) // Smaller font size for the actual date
                    .foregroundColor(.gray)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func relativeDateString(for futureDate: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: futureDate)

        guard let days = components.day else {
            return "Date error"
        }

        switch days {
        case 0:
            return "Today"
        case 1:
            return "Tomorrow"
        case let x where x > 1:
            return "In \(x) days"
        case -1:
            return "Yesterday"
        case let x where x < -1:
            return "\(abs(x)) days ago"
        default:
            return "Date error"
        }
    }

    private func eventDateFormatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d" // Format like "June 21"
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
}
