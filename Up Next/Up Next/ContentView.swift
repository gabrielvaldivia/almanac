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

struct CategoryData: Codable {
    var name: String
    var color: String // Store color as a hex string
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
    @State private var categories: [(name: String, color: Color)] = [
        ("Work", .blue), 
        ("Movies", .red), 
        ("Social", .green), 
        ("Music", .purple)
    ] // Dynamic categories list
    @State private var showCategoryManagementView: Bool = false 
    @State private var newCategoryColor: Color = .gray 
    @State private var newCategoryName: String = "" 
    @State private var showAddCategoryView: Bool = false 
    @State private var defaultCategory: String? = "Work" // State to store the selected default category

    @Environment(\.colorScheme) var colorScheme // Inject the color scheme environment variable

    var body: some View {
         NavigationView {
            ZStack(alignment: .bottom) {
                VStack {
                    
                    // Category Pills
                    let categoriesWithEvents = categories.filter { category in
                        events.contains(where: { $0.category == category.name })
                    }
                    
                    if categoriesWithEvents.count >= 2 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(categoriesWithEvents, id: \.name) { category in
                                    Button(action: {
                                        self.selectedCategoryFilter = self.selectedCategoryFilter == category.name ? nil : category.name
                                    }) {
                                        Text(category.name)
                                            .font(.footnote)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(self.selectedCategoryFilter == category.name ? category.color : Color.clear) // Change background color based on selection
                                            .foregroundColor(self.selectedCategoryFilter == category.name ? .white : (colorScheme == .dark ? .white : .black)) // Adjust foreground color based on color scheme
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
                    let groupedEvents = Dictionary(grouping: filteredEvents().sorted(by: { $0.date < $1.date }), by: { $0.date.relativeDate() })
                    let sortedKeys = groupedEvents.keys.sorted { key1, key2 in
                        let date1 = Date().addingTimeInterval(TimeInterval(daysFromRelativeDate(key1)))
                        let date2 = Date().addingTimeInterval(TimeInterval(daysFromRelativeDate(key2)))
                        return date1 < date2
                    }
                    if sortedKeys.isEmpty {
                        VStack {
                            Spacer()
                            Text("No upcoming events")
                                .font(.headline)
                                // .foregroundColor(.gray)
                            Text("Add something you're looking forward to")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure the VStack fills the available space
                    } else {
                        List {
                            ForEach(sortedKeys, id: \.self) { key in
                                HStack(alignment: .top) {
                                    Text(key.uppercased())
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(.gray) 
                                        .frame(width: 100, alignment: .leading) 
                                        .padding(.vertical, 14)
                                    VStack(alignment: .leading) {
                                        ForEach(groupedEvents[key]!, id: \.id) { event in
                                            EventRow(event: event, formatter: itemDateFormatter,
                                                     selectedEvent: $selectedEvent,
                                                     newEventTitle: $newEventTitle,
                                                     newEventDate: $newEventDate,
                                                     newEventEndDate: $newEventEndDate,
                                                     showEndDate: $showEndDate,
                                                     showEditSheet: $showEditSheet,
                                                     selectedCategory: $selectedCategory, // Pass this binding
                                                     categories: categories)
                                            .listRowSeparator(.hidden) // Hide dividers
                                        }
                                    }
                                }
                                .listRowSeparator(.hidden) // Hide dividers for each group
                            }
                        }
                        .listStyle(PlainListStyle())
                        .listRowSeparator(.hidden) // Ensure all dividers are hidden globally in the list
                    }
                }

                // Navigation Bar
                .navigationTitle("Events")
                .navigationBarItems(
                    leading: Button(action: {
                        self.showPastEventsSheet = true
                    }) {
                        Image(systemName: "clock.arrow.circlepath") // Icon for past events
                            .bold() // Make the icon thicker
                    },
                    trailing: Button(action: {
                        self.showCategoryManagementView = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .bold() // Make the icon thicker
                    }
                )
                .onAppear {
                    loadEvents()
                    loadCategories() // Load categories from UserDefaults
                }

                Button(action: {
                    self.newEventTitle = ""
                    self.newEventDate = Date()
                    self.newEventEndDate = Date()
                    self.showEndDate = false
                    self.selectedCategory = self.defaultCategory ?? self.categories.first?.name // Set the default category to the selected default category or the first in the list
                    self.showAddEventSheet = true
                }) {
                    Image(systemName: "plus")
                        .font(.title)
                        .bold() // Make the icon thicker
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
                        DatePicker(showEndDate ? "Start Date" : "Date", selection: $newEventDate, displayedComponents: .date)
                            .datePickerStyle(DefaultDatePickerStyle())
                        if showEndDate {
                            DatePicker("End Date", selection: $newEventEndDate, in: newEventDate.addingTimeInterval(86400)..., displayedComponents: .date)
                                .datePickerStyle(DefaultDatePickerStyle()) 
                            Button("Remove End Date") {
                                showEndDate = false
                                newEventEndDate = Date() 
                            }
                            .foregroundColor(.red) // Set button text color to red
                        } else {
                            Button("Add End Date") {
                                showEndDate = true
                                newEventEndDate = Calendar.current.date(byAdding: .day, value: 1, to: newEventDate) ?? Date() // Set default end date to one day after start date
                            }
                        }
                    }
                    Section() {
                        HStack {
                            Text("Category")
                            Spacer()
                            Menu {
                                Picker("Select Category", selection: $selectedCategory) {
                                    ForEach(categories, id: \.name) { category in
                                        Text(category.name).tag(category.name as String?)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedCategory ?? defaultCategory ?? "Select") // Ensure default category is shown
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
                        DatePicker(showEndDate ? "Start Date" : "Date", selection: $newEventDate, displayedComponents: .date)
                            .datePickerStyle(DefaultDatePickerStyle()) // Set to WheelDatePickerStyle for expanded view
                        if showEndDate {
                            DatePicker("End Date", selection: $newEventEndDate, in: newEventDate.addingTimeInterval(86400)..., displayedComponents: .date)
                                .datePickerStyle(DefaultDatePickerStyle()) // Set to WheelDatePickerStyle for expanded view
                            Button("Remove End Date") {
                                showEndDate = false
                                newEventEndDate = Date() // Reset end date to default
                            }
                            .foregroundColor(.red) // Set button text color to red
                        } else {
                            Button("Add End Date") {
                                showEndDate = true
                                newEventEndDate = Calendar.current.date(byAdding: .day, value: 1, to: newEventDate) ?? Date() // Set default end date to one day after start date
                            }
                        }
                    }
                    Section() {
                        HStack {
                            Text("Category")
                            Spacer()
                            Menu {
                                Picker("Select Category", selection: $selectedCategory) {
                                    ForEach(categories, id: \.name) { category in
                                        Text(category.name).tag(category.name as String?)
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
                    ToolbarItem(placement: .bottomBar) { // Add this ToolbarItem for delete button
                        Button("Delete Event") {
                            if let event = selectedEvent {
                                deleteEvent(event)
                            }
                            showEditSheet = false // Dismiss the sheet
                        }
                        .foregroundColor(.red)
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
                                 selectedCategory: $selectedCategory, // Pass this binding
                                 categories: categories)
                        .listRowSeparator(.hidden) // Hide dividers
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

        .sheet(isPresented: $showCategoryManagementView) {
            NavigationView {
                List {
                    ForEach(categories.indices, id: \.self) { index in
                        HStack {
                            TextField("Category Name", text: Binding(
                                get: { categories[index].name },
                                set: { categories[index].name = $0 }
                            ))
                            Spacer()
                            ColorPicker("", selection: Binding(
                                get: { categories[index].color },
                                set: { categories[index].color = $0 }
                            ))
                            .labelsHidden() // Hide the label of the ColorPicker
                            .frame(width: 30, height: 30) // Adjust the size of the ColorPicker
                            .padding(.trailing, 10)
                        }
                    }
                    .onDelete(perform: removeCategory)
                    .onMove(perform: moveCategory)
                    
                    // Section for selecting the default category
                    Section(header: Text("Default Category")) {
                        Picker("Default Category", selection: $defaultCategory) {
                            ForEach(categories, id: \.name) { category in
                                Text(category.name).tag(category.name as String?)
                            }
                        }
                    }
                }
                .listStyle(GroupedListStyle())
                .navigationBarTitle("Manage Categories", displayMode: .inline)
                .navigationBarItems(leading: EditButton(), trailing: Button(action: {
                    self.showAddCategoryView = true
                }) {
                    Image(systemName: "plus")
                })
            }
            .sheet(isPresented: $showAddCategoryView) {
                addCategoryView()
            }
        }

        // Add Category Sheet
        .sheet(isPresented: $showAddCategoryView) {
            addCategoryView()
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

    // Function to add a new category and save to UserDefaults
    func addCategory(_ category: (name: String, color: Color)) {
        categories.append(category)
        saveCategories() // Save categories after adding a new one
    }

    // Function to save categories to UserDefaults
    func saveCategories() {
        print("Attempting to save categories...")
        let encoder = JSONEncoder()
        let categoriesData = categories.map { category -> CategoryData in
            let uiColor = UIColor(category.color)  // Convert SwiftUI Color to UIColor
            let hexColor = uiColor.toHex()
            print("Saving color: \(hexColor) for category: \(category.name)")
            return CategoryData(name: category.name, color: hexColor)
        }

        if let encoded = try? encoder.encode(categoriesData),
           let sharedDefaults = UserDefaults(suiteName: "group.com.UpNextIdentifier") {
            sharedDefaults.set(encoded, forKey: "categories")
            print("Successfully saved categories.")
        } else {
            print("Failed to encode categories.")
        }
    }

    // Function to load categories from UserDefaults
    func loadCategories() {
        let decoder = JSONDecoder()
        if let sharedDefaults = UserDefaults(suiteName: "group.com.UpNextIdentifier"),
           let data = sharedDefaults.data(forKey: "categories"),
           let decoded = try? decoder.decode([CategoryData].self, from: data) {
            categories = decoded.map { (categoryData) in
                let color = Color(UIColor(hex: categoryData.color) ?? UIColor.gray) // Convert hex string back to UIColor, then to SwiftUI Color
                print("Loaded color: \(categoryData.color) for category: \(categoryData.name)")
                return (categoryData.name, color)
            }
            // Set default category if not already set or if it's nil
            if defaultCategory == nil || !categories.contains(where: { $0.name == defaultCategory }) {
                defaultCategory = categories.first?.name
            }
        } else {
            print("Failed to load categories or no categories found.")
            // Set a default category if categories fail to load
            categories = [("Work", .blue)] // Default to "Work" if nothing is loaded
            defaultCategory = "Work"
        }
    }

    // Function to remove a category
    func removeCategory(at offsets: IndexSet) {
        categories.remove(atOffsets: offsets)
        saveCategories() // Save categories after removing one
    }

    // Function to move a category
    func moveCategory(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        saveCategories() // Save categories after moving one
    }

    // Function to edit a category
    func editCategory(index: Int, newCategory: String) {
        categories[index].name = newCategory
        saveCategories() // Save categories after editing one
    }

    // Helper function to convert relative date string to TimeInterval
    func daysFromRelativeDate(_ relativeDate: String) -> Int {
        switch relativeDate {
        case "Today":
            return 0
        case "Tomorrow":
            return 1
        case let otherDay where otherDay.contains(" days ago"):
            let days = Int(otherDay.replacingOccurrences(of: " days ago", with: "")) ?? 0
            return -days
        case let otherDay where otherDay.contains(" day ago"):
            return -1
        case let otherDay where otherDay.starts(with: "in ") && otherDay.hasSuffix(" days"):
            let days = Int(otherDay.replacingOccurrences(of: "in ", with: "").replacingOccurrences(of: " days", with: "")) ?? 0
            return days
        default:
            return 0
        }
    }
    
    func addCategoryView() -> some View {
        NavigationView {
            Form {
                Section(header: Text("Add New Category")) {
                    TextField("Category Name", text: $newCategoryName)
                    ColorPicker("Select Color", selection: $newCategoryColor)
                }
            }
            .navigationBarTitle("New Category", displayMode: .inline)
            .navigationBarItems(trailing: Button("Save") {
                if !newCategoryName.isEmpty {
                    addCategory((newCategoryName, newCategoryColor))
                    newCategoryName = ""
                    // Set a random color for the next new category
                    newCategoryColor = Color(
                        red: .random(in: 0...1),
                        green: .random(in: 0...1),
                        blue: .random(in: 0...1)
                    )
                    showAddCategoryView = false // Close the modal after adding
                }
            }
            .disabled(newCategoryName.isEmpty)) // Disable the button if the category name is empty
            .onAppear {
                // Initialize with a random color when the view appears
                newCategoryColor = Color(
                    red: .random(in: 0...1),
                    green: .random(in: 0...1),
                    blue: .random(in: 0...1)
                )
            }
        }
    }

    // Function to delete an event
    func deleteEvent(_ event: Event) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events.remove(at: index)
            saveEvents() // Save changes after deletion
        }
    }
}

extension ContentView {
    var itemDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d" // Format without the year
        return formatter
    }
    
    // Load events from UserDefaults
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

    // Save events to UserDefaults
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
    @Binding var selectedCategory: String? // Add this line
    var categories: [(name: String, color: Color)]
    @Environment(\.colorScheme) var colorScheme // Inject the color scheme environment variable

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading) {
                HStack {
                    Text(event.title)
                        .font(.headline)
                        .foregroundColor(colorForCategory(event.category)) // Use category color
                    Spacer()
                }
                if let endDate = event.endDate {
                    let today = Date()
                    let duration = Calendar.current.dateComponents([.day], from: event.date, to: endDate).day! + 1
                    if today > event.date && today < endDate {
                        let daysLeft = Calendar.current.dateComponents([.day], from: today, to: endDate).day! + 1
                        let daysLeftText = daysLeft == 1 ? "1 day left" : "\(daysLeft) days left"
                        Text("\(event.date, formatter: formatter) — \(endDate, formatter: formatter) (\(daysLeftText))")
                            .font(.subheadline)
                            .foregroundColor(colorForCategory(event.category).opacity(0.5)) // Set color to category color at 50% opacity
                    } else {
                        Text("\(event.date, formatter: formatter) — \(endDate, formatter: formatter) (\(duration) days)")
                            .font(.subheadline)
                            .foregroundColor(colorForCategory(event.category).opacity(0.5)) // Set color to category color at 50% opacity
                    }
                } else {
                    Text(event.date, formatter: formatter)
                        .font(.subheadline)
                        .foregroundColor(colorForCategory(event.category).opacity(0.5)) // Set color to category color at 50% opacity
                }
            }
            .padding(.vertical, 10)
            .padding(.leading, 10)
            .background(
                colorForCategory(event.category).opacity(colorScheme == .light ? 0.05 : 0.2) // Use the injected color scheme here
            )
            .cornerRadius(10) // Apply rounded corners
        }
        .onTapGesture {
            self.selectedEvent = event
            self.newEventTitle = event.title
            self.newEventDate = event.date
            self.newEventEndDate = event.endDate ?? Date()
            self.showEndDate = event.endDate != nil
            self.selectedCategory = event.category 
            self.showEditSheet = true
        }
    }

    // Function to determine color based on category
    func colorForCategory(_ category: String?) -> Color {
        guard let category = category else { return .gray } 
        return categories.first(where: { $0.name == category })?.color ?? .gray
    }
}

// Extension to convert UIColor to and from hex string
extension UIColor {
    func toHex(includeAlpha alpha: Bool = false) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)

        if alpha {
            return String(format: "#%02X%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
        } else {
            return String(format: "#%02X%02X%02%X", Int(r * 255), Int(g * 255), Int(b * 255))
        }
    }

    convenience init?(hex: String) {
        let r, g, b, a: CGFloat
        let start = hex.index(hex.startIndex, offsetBy: hex.hasPrefix("#") ? 1 : 0)
        let hexColor = String(hex[start...])

        if hexColor.count == 6 {
            let scanner = Scanner(string: hexColor)
            var hexNumber: UInt64 = 0

            if scanner.scanHexInt64(&hexNumber) {
                r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255
                g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255
                b = CGFloat(hexNumber & 0x0000FF) / 255
                a = 1.0
                self.init(red: r, green: g, blue: b, alpha: a)
                return
            }
        }
        return nil
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

