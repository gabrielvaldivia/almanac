//
//  ContentView.swift
//  Upcoming
//
//  Created by Gabriel Valdivia on 6/18/24.
//

import SwiftUI

struct ContentView: View {
    @Binding var events: [Event]
    @State private var selectedEvent: Event?
    @State private var showingAddEvent = false // State to control the visibility of the add event sheet
    
    let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy" // Matches the format used to create the keys
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(allGroupedEvents.keys.sorted(by: { (key1, key2) -> Bool in
                        guard let date1 = monthYearFormatter.date(from: key1),
                              let date2 = monthYearFormatter.date(from: key2) else {
                            return false
                        }
                        return date1 < date2
                    }), id: \.self) { key in
                        Section(header: Text(headerTitle(for: key))) {
                            ForEach(allGroupedEvents[key] ?? [], id: \.id) { event in
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
            }
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
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(events: $events, onSave: {
                    saveEvents()
                })
            }
            .sheet(item: $selectedEvent) { event in
                EditEventView(event: .constant(event)) {_ in 
                    self.updateEvent(event)
                }
            }
        }
    }
    
    // Function to group all events by month and year
    var allGroupedEvents: [String: [Event]] {
        Dictionary(grouping: events, by: { monthYear(from: $0.date) })
    }
    
    func removeEvents(at offsets: IndexSet, from monthYearKey: String) {
        guard var eventsForMonth = allGroupedEvents[monthYearKey] else { return }
        eventsForMonth.remove(atOffsets: offsets)
        events = events.filter { monthYear(from: $0.date) != monthYearKey }
        events.append(contentsOf: eventsForMonth)
        saveEvents()
    }
    
    
    // Function to load the events from UserDefaults
    func loadEvents() {
        let userDefaults = UserDefaults.standard
        if let savedEvents = userDefaults.data(forKey: "Events") {
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

    // Function to save the events to UserDefaults
    func saveEvents() {
        print("Attempting to save events: \(events)")
        do {
            let encoded = try JSONEncoder().encode(events)
            print("Encoding successful: \(encoded.count) bytes")
            let userDefaults = UserDefaults.standard
            userDefaults.set(encoded, forKey: "Events")
            userDefaults.synchronize()
            print("Event #\(events.count) saved successfully.")
        } catch {
            print("Failed to encode events: \(error)")
        }
    }
    
    // Function to format the date
    func monthYear(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy" // e.g., January 2023
        return formatter.string(from: date)
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
    
    init(events: Binding<[Event]>) {
        _events = events
    }
    
    init() {
        _events = Binding.constant([])  // Default to empty if needed
        loadEvents()
    }
    
    func checkUserDefaultsData() {
        let userDefaults = UserDefaults.standard
        if let data = userDefaults.data(forKey: "Events") {
            do {
                let events = try JSONDecoder().decode([Event].self, from: data)
                print("Number of events stored in UserDefaults: \(events.count)")
            } catch {
                print("Failed to decode events: \(error)")
            }
        } else {
            print("No data found for 'Events' in UserDefaults.")
        }
    }

    func testUserDefaults() {
        let userDefaults = UserDefaults.standard
        userDefaults.set("Test", forKey: "TestKey")
        userDefaults.synchronize()
        if let testValue = userDefaults.string(forKey: "TestKey") {
            print("Test value retrieved successfully: \(testValue)")
        } else {
            print("Failed to retrieve test value from UserDefaults.")
        }
    }

    struct EventRow: View {
        @Binding var event: Event
        var onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                VStack(alignment: .leading) {
                    HStack(alignment: .top) {                      
                        VStack(alignment: .leading) {
                            Text(event.title)
                                .font(.body) // Standard body font for the title
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(eventDateFormatted(event.date)) // Actual date below the title
                                .font(.subheadline) // Smaller font size for the actual date
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Text(relativeDateString(for: event.date)) // Relative date to the right
                            .font(.subheadline) // Slightly smaller than body, for relative date
                            .foregroundColor(.gray) 
                    }
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
}

// Define a sample event for preview purposes
extension Event {
    static var sampleData: [Event] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        
        return [
            Event(id: UUID(), title: "Old Event", date: formatter.date(from: "May 1, 2024")!),
            Event(id: UUID(), title: "Test event", date: Date()),
            Event(id: UUID(), title: "Config", date: formatter.date(from: "June 26, 2024")!),
            Event(id: UUID(), title: "The Bear S3", date: formatter.date(from: "June 27, 2024")!),
            Event(id: UUID(), title: "Deadpool and Wolverine", date: formatter.date(from: "July 25, 2024")!),
            Event(id: UUID(), title: "Ben Schwartz and Friends", date: formatter.date(from: "September 14, 2024")!),
            Event(id: UUID(), title: "RY X", date: formatter.date(from: "October 28, 2024")!),
            Event(id: UUID(), title: "Tora", date: formatter.date(from: "November 7, 2024")!)
        ]
    }
}

// Preview provider for ContentView
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(events: .constant(Event.sampleData))
        .preferredColorScheme(.dark)  // Preview in dark mode
    }
}