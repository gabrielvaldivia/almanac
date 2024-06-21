//
//  ContentView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/19/24.
//

import SwiftUI
import Foundation

struct Event: Identifiable, Codable {
    var id = UUID()
    var title: String
    var date: Date
    var endDate: Date? // Optional end date
}

struct ContentView: View {
    @State private var events: [Event] = []
    @State private var newEventTitle: String = ""
    @State private var newEventDate: Date = Date()
    @State private var newEventEndDate: Date = Date()
    @State private var showAddEventSheet: Bool = false
    @State private var showEditSheet: Bool = false
    @State private var selectedEvent: Event?
    @State private var showEndDate: Bool = false
    @State private var showPastEventsSheet: Bool = false // State for showing past events

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                VStack {
                    List {
                        ForEach(Array(filteredEvents().keys.sorted()), id: \.self) { key in
                            Section(header: Text(key)) {
                                ForEach(filteredEvents()[key]!, id: \.id) { event in
                                    EventRow(event: event, formatter: itemDateFormatter,
                                             selectedEvent: $selectedEvent,
                                             newEventTitle: $newEventTitle,
                                             newEventDate: $newEventDate,
                                             newEventEndDate: $newEventEndDate,
                                             showEndDate: $showEndDate,
                                             showEditSheet: $showEditSheet,
                                             showRelativeDate: false) // Pass false here if you don't want to show relative dates in the main list
                                }
                                .onDelete(perform: deleteEvent)
                            }
                        }
                    }
                    .listStyle(GroupedListStyle())
                }
                .navigationTitle("Events")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(leading: Button(action: {
                    self.showPastEventsSheet = true
                }) {
                    Image(systemName: "clock.arrow.circlepath") // Icon for past events
                })
                .onAppear {
                    loadEvents()
                }

                Button(action: {
                    self.newEventTitle = ""
                    self.newEventDate = Date()
                    self.newEventEndDate = Date()
                    self.showEndDate = false
                    self.showAddEventSheet = true
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
        .sheet(isPresented: $showAddEventSheet) {
            NavigationView {
                Form {
                    TextField("Event Title", text: $newEventTitle)
                    DatePicker(showEndDate ? "Start Date" : "Event Date", selection: $newEventDate, displayedComponents: .date)
                    if showEndDate {
                        DatePicker("End Date", selection: $newEventEndDate, in: newEventDate.addingTimeInterval(86400)..., displayedComponents: .date)
                            .datePickerStyle(CompactDatePickerStyle())
                        Button("Remove End Date") {
                            showEndDate = false
                            newEventEndDate = Date() // Reset end date to default
                        }
                    } else {
                        Button("Add End Date") {
                            showEndDate = true
                        }
                    }
                }
                .navigationTitle("Add Event")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Add") {
                            addNewEvent()
                            showAddEventSheet = false
                        }
                        .disabled(newEventTitle.isEmpty) // Disable the button if newEventTitle is empty
                    }
                }
            }
        }

        // Edit Event Sheet
        .sheet(isPresented: $showEditSheet) {
            NavigationView {
                Form {
                    TextField("Event Title", text: $newEventTitle)
                    DatePicker(showEndDate ? "Start Date" : "Event Date", selection: $newEventDate, displayedComponents: .date)
                    if showEndDate {
                            DatePicker("End Date", selection: $newEventEndDate, in: newEventDate.addingTimeInterval(86400)..., displayedComponents: .date)
                                .datePickerStyle(CompactDatePickerStyle())
                            Button("Remove End Date") {
                                showEndDate = false
                                newEventEndDate = Date() // Reset end date to default
                            }
                        } else {
                            Button("Add End Date") {
                                showEndDate = true
                            }
                        }
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
        }

        // Sheet for past events
        .sheet(isPresented: $showPastEventsSheet) {
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
                                 showRelativeDate: true) // Pass true to show the relative date
                    }
                    .onDelete(perform: deletePastEvent)
                }
                .listStyle(GroupedListStyle()) // Apply grouped list style
                .navigationTitle("Past Events")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button("Done") {
                    self.showPastEventsSheet = false
                })
            }
        }
    }

    func filteredEvents() -> [String: [Event]] {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        var groupedEvents = [String: [Event]]()

        for event in events {
            let relativeDate = event.date.relativeDate(to: event.endDate)
            // Include events that start today or later, or are ongoing (started before today and end after or on today)
            if event.date >= startOfToday || (event.endDate != nil && event.date < startOfToday && event.endDate! >= startOfToday) {
                if groupedEvents[relativeDate] == nil {
                    groupedEvents[relativeDate] = []
                }
                groupedEvents[relativeDate]?.append(event)
            }
        }

        // Sort events in the "Today" section by start date
        if let todayEvents = groupedEvents["Today"] {
            groupedEvents["Today"] = todayEvents.sorted { $0.date < $1.date }
        }

        return groupedEvents
    }

    func deleteEvent(at offsets: IndexSet) {
        // First, reconstruct the list as it appears in the UI
        let allEvents = Array(filteredEvents().values).flatMap { $0 }
        
        // Convert the offsets to actual event IDs
        let idsToDelete = offsets.map { allEvents[$0].id }
        
        // Remove events based on their IDs
        events.removeAll { event in
            idsToDelete.contains(event.id)
        }
        
        saveEvents()  // Save after deleting
    }

    func addNewEvent() {
        let newEvent = Event(title: newEventTitle, date: newEventDate, endDate: showEndDate ? newEventEndDate : nil)
        events.append(newEvent)
        saveEvents()
        sortEvents()
        newEventTitle = ""
        newEventDate = Date()
        newEventEndDate = Date()
        showEndDate = false
    }

    func saveChanges() {
        if let selectedEvent = selectedEvent, let index = events.firstIndex(where: { $0.id == selectedEvent.id }) {
            events[index].title = newEventTitle
            events[index].date = newEventDate
            events[index].endDate = showEndDate ? newEventEndDate : nil
            saveEvents()
        }
    }

    func sortEvents() {
        events.sort { $0.date < $1.date }
    }

    // Function to filter and sort past events
    func pastEvents() -> [Event] {
        let now = Date()
        return events.filter { event in
            if let endDate = event.endDate {
                return endDate < now
            } else {
                return event.date < now
            }
        }
        .sorted { (event1, event2) -> Bool in
            // Sort using endDate if available, otherwise use startDate
            let endDate1 = event1.endDate ?? event1.date
            let endDate2 = event2.endDate ?? event2.date
            if endDate1 == endDate2 {
                // If end dates are the same, sort by start date
                return event1.date > event2.date
            } else {
                return endDate1 > endDate2 // Sort in reverse chronological order by end date
            }
        }
    }

    // Function to delete past events
    func deletePastEvent(at offsets: IndexSet) {
        let pastEvents = self.pastEvents()
        for index in offsets {
            if let mainIndex = events.firstIndex(where: { $0.id == pastEvents[index].id }) {
                events.remove(at: mainIndex)
            }
        }
        saveEvents()  // Save changes after deletion
    }
}

extension ContentView {
    var itemDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d" // Format without the year
        return formatter
    }
    
    func loadEvents() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let sharedDefaults = UserDefaults(suiteName: "group.com.UpNextIdentifier"),
           let data = sharedDefaults.data(forKey: "events"),
           let decoded = try? decoder.decode([Event].self, from: data) {
            events = decoded
            print("Loaded events: \(events)")
        } else {
            print("No events found in shared UserDefaults.")
        }
    }

    func saveEvents() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let encoded = try? encoder.encode(events),
           let sharedDefaults = UserDefaults(suiteName: "group.com.UpNextIdentifier") {
            sharedDefaults.set(encoded, forKey: "events")
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
            .font(.headline)
            .textCase(nil)  // Ensures text is not automatically capitalized
    }
}

extension Date {
    func relativeDate(to endDate: Date? = nil) -> String {
        let calendar = Calendar.current
        let now = Date()
        let startOfNow = calendar.startOfDay(for: now)
        let startOfSelf = calendar.startOfDay(for: self)

        if let endDate = endDate, startOfSelf <= startOfNow, calendar.startOfDay(for: endDate) >= startOfNow {
            return "Today"
        } else {
            let components = calendar.dateComponents([.day], from: startOfNow, to: startOfSelf)
            guard let dayCount = components.day else { return "Error" }

            switch dayCount {
            case 0:
                return "Today"
            case 1:
                return "Tomorrow"
            case let x where x > 1:
                return "in \(x) days"
            case -1:
                return "1 day ago"
            case let x where x < -1:
                return "\(abs(x)) days ago"
            default:
                return "Error"
            }
        }
    }
}

struct EventRow: View {
    var event: Event
    var formatter: DateFormatter
    @Binding var selectedEvent: Event?
    @Binding var newEventTitle: String
    @Binding var newEventDate: Date
    @Binding var newEventEndDate: Date
    @Binding var showEndDate: Bool
    @Binding var showEditSheet: Bool
    var showRelativeDate: Bool // New parameter to control display of relative date

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text(event.title)
                        .font(.headline)
                    Spacer()
                    if showRelativeDate {
                        Text(event.date.relativeDate())
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                if let endDate = event.endDate {
                    let today = Date()
                    let duration = Calendar.current.dateComponents([.day], from: event.date, to: endDate).day! + 1
                    if today > event.date && today < endDate {
                        let daysLeft = Calendar.current.dateComponents([.day], from: today, to: endDate).day! + 1
                        let daysLeftText = daysLeft == 1 ? "1 day left" : "\(daysLeft) days left"
                        Text("\(event.date, formatter: formatter) — \(endDate, formatter: formatter) (\(daysLeftText))")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    } else {
                        Text("\(event.date, formatter: formatter) — \(endDate, formatter: formatter) (\(duration) days)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    Text(event.date, formatter: formatter)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
        .onTapGesture {
            self.selectedEvent = event
            self.newEventTitle = event.title
            self.newEventDate = event.date
            self.newEventEndDate = event.endDate ?? Date()
            self.showEndDate = event.endDate != nil
            self.showEditSheet = true
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

