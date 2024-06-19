//
//  ContentView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/19/24.
//

import SwiftUI
import Foundation

struct Event: Identifiable, Codable {
    let id = UUID()
    var title: String
    var date: Date
}

struct ContentView: View {
    @State private var events: [Event] = []
    @State private var newEventTitle: String = ""
    @State private var newEventDate: Date = Date()
    @State private var showAddEventSheet: Bool = false
    @State private var showEditSheet: Bool = false
    @State private var selectedEvent: Event?
    @State private var selectedSegment: String = "Upcoming" // Default selection
    @FocusState private var newEventTitleFocus: Bool

    private let segments = ["Past", "Upcoming"]

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                VStack {
                    Picker("Filter", selection: $selectedSegment) {
                        ForEach(segments, id: \.self) { segment in
                            Text(segment)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    List {
                        ForEach(monthlyGroupedEvents(), id: \.key) { month, events in
                            Section(header: CustomSectionHeader(title: month)) {
                                ForEach(events, id: \.id) { event in
                                    HStack(alignment: .top) {
                                        VStack (alignment: .leading) {
                                            Text(event.title)
                                            Text(event.date, style: .date)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Text("\(event.date.relativeDate())")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    .onTapGesture {
                                        self.selectedEvent = event
                                        self.newEventTitle = event.title
                                        self.newEventDate = event.date
                                        self.showEditSheet = true
                                    }
                                    .listRowSeparator(.hidden) // Hides the divider
                                }
                                .onDelete(perform: deleteEvent)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())  // Use PlainListStyle to minimize padding
                }
                .navigationTitle("Events")
                .navigationBarTitleDisplayMode(.inline)

                Button(action: {
                    self.newEventTitle = ""
                    self.newEventDate = Date()
                    self.showAddEventSheet = true
                    self.newEventTitleFocus = true
                }) {
                    Image(systemName: "plus")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(40)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }

        // Add Event Sheet
        .sheet(isPresented: $showAddEventSheet, onDismiss: {
            newEventTitleFocus = false
        }) {
            NavigationView {
                Form {
                    TextField("Event Title", text: $newEventTitle)
                        .focused($newEventTitleFocus)
                    DatePicker("Event Date", selection: $newEventDate, displayedComponents: .date)
                        .datePickerStyle(GraphicalDatePickerStyle())
                }
                .navigationTitle("Add Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Add") {
                            addNewEvent()
                            showAddEventSheet = false
                        }
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    self.newEventTitleFocus = true
                }
            }
        }

        // Edit Event Sheet
        .sheet(isPresented: $showEditSheet, onDismiss: {
            newEventTitleFocus = false
        }) {
            NavigationView {
                Form {
                    TextField("Edit Event Title", text: $newEventTitle)
                        .focused($newEventTitleFocus)
                    DatePicker("Edit Event Date", selection: $newEventDate, displayedComponents: .date)
                        .datePickerStyle(GraphicalDatePickerStyle())
                }
                .navigationTitle("Edit Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveChanges()
                            showEditSheet = false
                        }
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    self.newEventTitleFocus = true
                }
            }
        }
    }

    func filteredEvents() -> [Event] {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        var filtered = events.filter { event in
            let startOfEvent = Calendar.current.startOfDay(for: event.date)
            if selectedSegment == "Past" {
                return startOfEvent < startOfToday
            } else { // "Upcoming"
                return startOfEvent >= startOfToday
            }
        }
        
        if selectedSegment == "Past" {
            filtered.sort { $0.date > $1.date } // Reverse chronological order
        } else {
            filtered.sort { $0.date < $1.date } // Chronological order
        }
        
        return filtered
    }

    func monthlyGroupedEvents() -> [(key: String, value: [Event])] {
        let sortedEvents = filteredEvents()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        var grouped = Dictionary(grouping: sortedEvents) { event -> String in
            return formatter.string(from: event.date)
        }

        let sortedGroupedEvents = grouped.map { (key: String, value: [Event]) -> (key: String, value: [Event]) in
            (key, value)
        }
        .sorted { first, second in
            guard let firstDate = formatter.date(from: first.key), let secondDate = formatter.date(from: second.key) else {
                return false
            }
            if selectedSegment == "Past" {
                return firstDate > secondDate // Reverse chronological order for "Past"
            } else {
                return firstDate < secondDate // Chronological order for "Upcoming"
            }
        }
        return sortedGroupedEvents
    }

    func deleteEvent(at offsets: IndexSet) {
        events.remove(atOffsets: offsets)
        saveEvents()  // Save after deleting
    }

    func addNewEvent() {
        let newEvent = Event(title: newEventTitle, date: newEventDate)
        events.append(newEvent)
        saveEvents()  // Save after adding
        sortEvents()
        newEventTitle = ""
        newEventDate = Date()
    }

    func saveChanges() {
        if let selectedEvent = selectedEvent, let index = events.firstIndex(where: { $0.id == selectedEvent.id }) {
            events[index].title = newEventTitle
            events[index].date = newEventDate
            saveEvents()  // Save after editing
        }
    }

    func sortEvents() {
        events.sort { $0.date < $1.date }
    }
}

extension ContentView {
    func loadEvents() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601  // Match the encoding strategy
        if let data = UserDefaults.standard.data(forKey: "events"),
           let decoded = try? decoder.decode([Event].self, from: data) {
            events = decoded
            print("Loaded events: \(events)")
        } else {
            print("No events found in UserDefaults.")
        }
    }

    func saveEvents() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601  // Or another appropriate format
        if let encoded = try? encoder.encode(events) {
            UserDefaults.standard.set(encoded, forKey: "events")
            print("Saved events: \(events)")
        } else {
            print("Failed to encode events.")
        }
    }
}

// Custom Section Header
struct CustomSectionHeader: View {
    var title: String

    var body: some View {
        Text(title)
            .border(Color.clear, width: 0) // Removes bottom border by setting a clear border with zero width
            .font(.title3)
            .background(Color(UIColor.systemBackground))
            .textCase(nil)  // Ensures text is not automatically capitalized
    }
}

extension Date {
    func relativeDate() -> String {
        let calendar = Calendar.current
        let now = Date()
        let startOfNow = calendar.startOfDay(for: now)
        let startOfSelf = calendar.startOfDay(for: self)

        let components = calendar.dateComponents([.day], from: startOfNow, to: startOfSelf)
        guard let dayCount = components.day else { return "Error" }

        switch dayCount {
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
            return "Error"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
