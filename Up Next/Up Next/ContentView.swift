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
    var endDate: Date?
    var color: String // Store color as a String
    var category: String? // New property for category, now optional
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
    @State private var selectedColor: String = "Black" // Default color set to Black
    @State private var selectedCategory: String? = nil // Default category set to nil
    @State private var selectedCategoryFilter: String? = nil // State to track selected category for filtering
    @State private var categories: [String] = ["Work", "Movies", "Social", "Music"] // Dynamic categories list
    @State private var showCategoryManagementView: Bool = false // State to show category management view

    var body: some View {
         NavigationView {
            ZStack(alignment: .bottom) {
                VStack {
                    
                    // Category Pills
                    let categoriesWithEvents = categories.filter { category in
                        events.contains { $0.category == category }
                    }
                    if categoriesWithEvents.count >= 2 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(categoriesWithEvents, id: \.self) { category in
                                    Button(action: {
                                        self.selectedCategoryFilter = self.selectedCategoryFilter == category ? nil : category
                                    }) {
                                        Text(category)
                                            .font(.footnote)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(self.selectedCategoryFilter == category ? Color.blue : Color.clear) // No background color when not selected
                                            .foregroundColor(self.selectedCategoryFilter == category ? .white : .black)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Color.gray, lineWidth: 1) // Gray border for all
                                            )
                                            .cornerRadius(20)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top)
                    }
                    
                    // List of events
                    List {
                        // Group events by relative date
                        let groupedEvents = Dictionary(grouping: filteredEvents().sorted(by: { $0.date < $1.date }), by: { $0.date.relativeDate() })
                        // Sort keys chronologically
                        let sortedKeys = groupedEvents.keys.sorted { key1, key2 in
                            // Convert keys back to dates for comparison
                            let date1 = Date().addingTimeInterval(TimeInterval(daysFromRelativeDate(key1)))
                            let date2 = Date().addingTimeInterval(TimeInterval(daysFromRelativeDate(key2)))
                            return date1 < date2
                        }
                        ForEach(sortedKeys, id: \.self) { key in
                            Section(header: Text(key).font(.headline)) {
                                ForEach(groupedEvents[key]!, id: \.id) { event in
                                    EventRow(event: event, formatter: itemDateFormatter,
                                             selectedEvent: $selectedEvent,
                                             newEventTitle: $newEventTitle,
                                             newEventDate: $newEventDate,
                                             newEventEndDate: $newEventEndDate,
                                             showEndDate: $showEndDate,
                                             showEditSheet: $showEditSheet,
                                             showRelativeDate: true)
                                    .listRowSeparator(.hidden) // Hide dividers
                                }
                                .onDelete(perform: deleteEvent)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }

                // Navigation Bar
                .navigationTitle("Events")
                .navigationBarItems(
                    leading: Button(action: {
                        self.showPastEventsSheet = true
                    }) {
                        Image(systemName: "clock.arrow.circlepath") // Icon for past events
                    },
                    trailing: Button(action: {
                        self.showCategoryManagementView = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                    }
                )
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
                    Section() {
                        TextField("Title", text: $newEventTitle)
                        
                    }
                    Section() {
                        DatePicker("Date", selection: $newEventDate, displayedComponents: .date)
                            .datePickerStyle(DefaultDatePickerStyle())
                        if showEndDate {
                            DatePicker("End Date", selection: $newEventEndDate, in: newEventDate.addingTimeInterval(86400)..., displayedComponents: .date)
                                .datePickerStyle(DefaultDatePickerStyle()) 
                            Button("Remove End Date") {
                                showEndDate = false
                                newEventEndDate = Date() 
                            }
                        } else {
                            Button("Add End Date") {
                                showEndDate = true
                                newEventEndDate = Calendar.current.date(byAdding: .day, value: 1, to: newEventDate) ?? Date() // Set default end date to one day after start date
                            }
                        }
                    }
                    Section() {
                        HStack {
                            Text("Color")
                            Spacer()
                            Menu {
                                Picker("Select Color", selection: $selectedColor) {
                                    Text("Black").tag("Black")
                                    Text("Red").tag("Red")
                                    Text("Blue").tag("Blue")
                                    Text("Green").tag("Green")
                                    Text("Purple").tag("Purple")
                                }
                            } label: {
                                HStack {
                                    Text(selectedColor)
                                        .foregroundColor(.gray)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        HStack {
                            Text("Category")
                            Spacer()
                            Menu {
                                Picker("Select Category", selection: $selectedCategory) {
                                    ForEach(categories, id: \.self) { category in
                                        Text(category).tag(category as String?)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedCategory ?? "Select")
                                        .foregroundColor(.gray)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundColor(.gray)
                                }
                            }
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
                    Section() {
                        TextField("Title", text: $newEventTitle)
                    }
                    Section() {
                        DatePicker("Start Date", selection: $newEventDate, displayedComponents: .date)
                            .datePickerStyle(DefaultDatePickerStyle()) // Set to WheelDatePickerStyle for expanded view
                        if showEndDate {
                            DatePicker("End Date", selection: $newEventEndDate, in: newEventDate.addingTimeInterval(86400)..., displayedComponents: .date)
                                .datePickerStyle(DefaultDatePickerStyle()) // Set to WheelDatePickerStyle for expanded view
                            Button("Remove End Date") {
                                showEndDate = false
                                newEventEndDate = Date() // Reset end date to default
                            }
                        } else {
                            Button("Add End Date") {
                                showEndDate = true
                                newEventEndDate = Calendar.current.date(byAdding: .day, value: 1, to: newEventDate) ?? Date() // Set default end date to one day after start date
                            }
                        }
                    }
                    Section() {
                        HStack {
                            Text("Color")
                            Spacer()
                            Menu {
                                Picker("Select Color", selection: $selectedColor) {
                                    Text("Black").tag("Black")
                                    Text("Red").tag("Red")
                                    Text("Blue").tag("Blue")
                                    Text("Green").tag("Green")
                                    Text("Purple").tag("Purple")
                                }
                            } label: {
                                HStack {
                                    Text(selectedColor)
                                        .foregroundColor(.gray)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        HStack {
                            Text("Category")
                            Spacer()
                            Menu {
                                Picker("Select Category", selection: $selectedCategory) {
                                    ForEach(categories, id: \.self) { category in
                                        Text(category).tag(category as String?)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedCategory ?? "Select")
                                        .foregroundColor(.gray)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundColor(.gray)
                                }
                            }
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
                        .disabled(newEventTitle.isEmpty) // Disable the button if newEventTitle is empty
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
                .listStyle(PlainListStyle()) // Apply PlainListStyle to the past events list
                .navigationTitle("Past Events")
                .navigationBarTitleDisplayMode(.inline) // Set title display mode to inline
                .navigationBarItems(trailing: Button("Done") {
                    self.showPastEventsSheet = false
                })
            }
        }

        // Sheet for managing categories
        .sheet(isPresented: $showCategoryManagementView) {
            NavigationView {
                List {
                    ForEach(categories.indices, id: \.self) { index in
                        TextField("Category Name", text: Binding(
                            get: { categories[index] },
                            set: { categories[index] = $0 }
                        ))
                    }
                    .onDelete(perform: removeCategory)
                    .onMove(perform: moveCategory)
                    
                    Button(action: {
                        addCategory("New Category")
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Category")
                        }
                    }
                    .foregroundColor(.blue)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
                .navigationBarTitle("Categories", displayMode: .inline)
            }
        }
    }

    func filteredEvents() -> [Event] {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        var allEvents = [Event]()

        for event in events {
            if let filter = selectedCategoryFilter {
                if event.category == filter && (event.date >= startOfToday || (event.endDate != nil && event.date < startOfToday && event.endDate! >= startOfToday)) {
                    allEvents.append(event)
                }
            } else {
                if event.date >= startOfToday || (event.endDate != nil && event.date < startOfToday && event.endDate! >= startOfToday) {
                    allEvents.append(event)
                }
            }
        }

        return allEvents.sorted { $0.date < $1.date }
    }

    func deleteEvent(at offsets: IndexSet) {
        // First, reconstruct the list as it appears in the UI
        let allEvents = filteredEvents()
        
        // Convert the offsets to actual event IDs
        let idsToDelete = offsets.map { allEvents[$0].id }
        
        // Remove events based on their IDs
        events.removeAll { event in
            idsToDelete.contains(event.id)
        }
        
        saveEvents()  // Save after deleting
    }

    func addNewEvent() {
        let defaultEndDate = showEndDate ? newEventEndDate : nil // Only set end date if showEndDate is true
        let newEvent = Event(title: newEventTitle, date: newEventDate, endDate: defaultEndDate, color: selectedColor, category: selectedCategory) // Handle nil category
        events.append(newEvent)
        saveEvents()
        sortEvents()
        newEventTitle = ""
        newEventDate = Date()
        newEventEndDate = Date()
        showEndDate = false
        selectedColor = "Black" // Reset to default color
        selectedCategory = nil // Reset to no category
    }

    func saveChanges() {
        if let selectedEvent = selectedEvent, let index = events.firstIndex(where: { $0.id == selectedEvent.id }) {
            events[index].title = newEventTitle
            events[index].date = newEventDate
            events[index].endDate = showEndDate ? newEventEndDate : nil
            events[index].color = selectedColor
            events[index].category = selectedCategory // Handle nil category
            saveEvents()
        }
    }

    func sortEvents() {
        events.sort { $0.date < $1.date }
    }

    // Function to filter and sort past events
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

    // Function to add a new category
    func addCategory(_ category: String) {
        categories.append(category)
    }

    // Function to remove a category
    func removeCategory(at offsets: IndexSet) {
        categories.remove(atOffsets: offsets)
    }

    // Function to move a category
    func moveCategory(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
    }

    // Function to edit a category
    func editCategory(index: Int, newCategory: String) {
        categories[index] = newCategory
    }

    // Helper function to convert relative date string to TimeInterval
    func daysFromRelativeDate(_ relativeDate: String) -> Int {
        switch relativeDate {
        case "Today":
            return 0
        case "Tomorrow":
            return 1
        case let otherDay where otherDay.contains("days ago"):
            let days = Int(otherDay.replacingOccurrences(of: " days ago", with: "")) ?? 0
            return -days
        case let otherDay where otherDay.contains("day ago"):
            return -1
        case let otherDay where otherDay.starts(with: "in ") && otherDay.hasSuffix(" days"):
            let days = Int(otherDay.replacingOccurrences(of: "in ", with: "").replacingOccurrences(of: " days", with: "")) ?? 0
            return days
        default:
            return 0
        }
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

// EVENT ROW
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
        HStack(alignment: .top, spacing: 20) {
            if showRelativeDate {
                Text(event.date.relativeDate())
                    .font(.system(.caption, design: .monospaced))
                    .font(.system(.body, design: .monospaced))
                    .textCase(.uppercase)
                    .frame(width: 80, alignment: .leading)
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
            VStack(alignment: .leading) {
                HStack {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(colorFromString(event.color)) // Convert string to Color
                    Spacer()
                    // Conditionally display the category if it exists
                    if let category = event.category, !category.isEmpty {
                        Text(category)
                            .font(.caption)
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
            .padding(.vertical, 10)
            .padding(.leading, 20)
            .background(
                colorFromString(event.color).opacity(0.1) // Set background color with 10% opacity
            )
            .cornerRadius(10) // Apply rounded corners
            .background(
                Rectangle()
                    .fill(colorFromString(event.color)) // Use event's color for the border
                    .frame(width: 4),
                alignment: .leading
            )
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

    // Helper function to convert color name to Color
    func colorFromString(_ colorName: String) -> Color {
        switch colorName {
        case "Red": return .red
        case "Blue": return .blue
        case "Green": return .green
        case "Black": return .black // Added Black
        case "Purple": return .purple
        default: return .black // Default color if none is matched
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

