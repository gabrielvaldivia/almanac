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
    @State private var selectedSegment: String = "Upcoming" // Default selection
    @State private var showEndDate: Bool = false

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
                        ForEach(filteredEvents(), id: \.id) { event in
                            HStack(alignment: .top) {
                                VStack (alignment: .leading) {
                                    Text(event.title)
                                    if let endDate = event.endDate {
                                        let totalDays = Calendar.current.dateComponents([.day], from: event.date, to: endDate).day! + 1
                                        let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day! + 1
                                        let isEventToday = Calendar.current.isDateInToday(event.date) || (event.date...endDate).contains(Date())
                                        
                                        if isEventToday {
                                            Text("\(event.date, formatter: itemDateFormatter) — \(endDate, formatter: itemDateFormatter) (\(daysLeft) of \(totalDays) days left)")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        } else {
                                            Text("\(event.date, formatter: itemDateFormatter) — \(endDate, formatter: itemDateFormatter) (\(totalDays) days)")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                    } else {
                                        Text(event.date, formatter: itemDateFormatter)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                                Text("\(event.date.relativeDate(to: event.endDate))")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .onTapGesture {
                                self.selectedEvent = event
                                self.newEventTitle = event.title
                                self.newEventDate = event.date
                                self.newEventEndDate = event.endDate ?? Date()
                                self.showEndDate = event.endDate != nil
                                self.showEditSheet = true
                            }
                            .listRowSeparator(.hidden) // Hides the divider
                        }
                        .onDelete(perform: deleteEvent)
                    }
                    .listStyle(PlainListStyle())  // Use PlainListStyle to minimize padding
                    .clipped(antialiased: false)
                    .padding(.bottom, 80)
                }
                .navigationTitle("Events")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    loadEvents()  // Load events when the view appears
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
    }

    func filteredEvents() -> [Event] {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        var filtered = events.filter { event in
            let endOfEvent = event.endDate ?? event.date // Use endDate if it exists, otherwise use startDate
            let startOfEvent = Calendar.current.startOfDay(for: endOfEvent)
            if selectedSegment == "Past" {
                return startOfEvent < startOfToday
            } else { // "Upcoming"
                return startOfEvent >= startOfToday
            }
        }
        
        if selectedSegment == "Past" {
            filtered.sort { ($0.endDate ?? $0.date) > ($1.endDate ?? $1.date) } // Reverse chronological order based on end date
        } else {
            // Sort "Upcoming" events by relative date, prioritizing "Today" and "Tomorrow"
            filtered.sort { event1, event2 in
                let relativeDate1 = event1.date.relativeDate(to: event1.endDate)
                let relativeDate2 = event2.date.relativeDate(to: event2.endDate)
                if relativeDate1 == "Today" && relativeDate2 != "Today" {
                    return true
                } else if relativeDate1 == "Tomorrow" && relativeDate2 != "Tomorrow" && relativeDate2 != "Today" {
                    return true
                } else if relativeDate1 == relativeDate2 {
                    return (event1.endDate ?? event1.date) < (event2.endDate ?? event2.date)
                } else {
                    return false
                }
            }
        }
        
        return filtered
    }

    func deleteEvent(at offsets: IndexSet) {
        events.remove(atOffsets: offsets)
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
            // Changed to always return "Today" for ongoing events with an end date
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
