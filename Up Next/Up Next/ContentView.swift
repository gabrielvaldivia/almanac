//
//  ContentView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/19/24.
//

import SwiftUI
import Foundation
import WidgetKit
import UserNotifications

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
    @State private var selectedCategoryFilter: String? = nil // State to track selected category for filtering
    @State private var showCategoryManagementView: Bool = false // State to show category management view
    @State private var selectedColor: CodableColor = CodableColor(color: .black) // Default color set to Black
    @State private var selectedCategory: String? = nil // Default category set to nil
    @State private var notificationsEnabled: Bool = true // New state to track notification status

    @EnvironmentObject var appData: AppData
    @Environment(\.colorScheme) var colorScheme // Inject the color scheme environment variable

    let itemDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
         NavigationView {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) { // Remove vertical padding by setting spacing to 0
                    // List of events
                    let groupedEvents = Dictionary(grouping: filteredEvents().sorted(by: { $0.date < $1.date }), by: { event in
                        if event.date <= Date() && (event.endDate ?? event.date) >= Date() {
                            return "Today"
                        } else {
                            return event.date.relativeDate()
                        }
                    })
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
                            Text("Add something you're looking forward to")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            // Sticky Category Pills
                            Section(header: categoryPillsView(appData: appData, events: events, selectedCategoryFilter: $selectedCategoryFilter, colorScheme: colorScheme)
                                        .padding(.leading, -20) // Remove left padding
                                        .padding(.trailing, -20) // Remove right padding
                            ) {
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
                                                         selectedCategory: $selectedCategory,
                                                         categories: appData.categories)
                                                    .onTapGesture { // Add tap gesture to open EditEventView
                                                        self.selectedEvent = event
                                                        self.newEventTitle = event.title
                                                        self.newEventDate = event.date
                                                        self.newEventEndDate = event.endDate ?? Date()
                                                        self.showEndDate = event.endDate != nil
                                                        self.selectedCategory = event.category
                                                        self.showEditSheet = true
                                                    }
                                                    .listRowSeparator(.hidden) // Hide dividers
                                            }
                                        }
                                    }
                                    .listRowSeparator(.hidden)
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                        .listRowSeparator(.hidden)
                    } 
                }
                .onOpenURL { url in
                    if url.scheme == "upnext" && url.host == "addEvent" {
                        self.newEventTitle = ""
                        self.newEventDate = Date()
                        self.newEventEndDate = Date()
                        self.showEndDate = false
                        self.selectedCategory = self.selectedCategoryFilter ?? (appData.defaultCategory.isEmpty ? "Work" : appData.defaultCategory)
                        self.showAddEventSheet = true
                    }
                }
               
                // Navigation Bar
                .navigationTitle("Up Next")
                .navigationBarItems(
                    leading: HStack {
                        Button(action: {
                            self.showPastEventsSheet = true
                        }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .bold()
                                .foregroundColor(self.selectedCategoryFilter != nil ? appData.categories.first(where: { $0.name == self.selectedCategoryFilter })?.color ?? Color.blue : appData.categories.first(where: { $0.name == appData.defaultCategory })?.color ?? Color.blue) // Change icon color based on selected category or default category
                        }
                    },
                    trailing: Button(action: {
                        self.showCategoryManagementView = true
                    }) {
                        Image(systemName: "slider.horizontal.3")
                            .bold()
                            .foregroundColor(self.selectedCategoryFilter != nil ? appData.categories.first(where: { $0.name == self.selectedCategoryFilter })?.color ?? Color.blue : appData.categories.first(where: { $0.name == appData.defaultCategory })?.color ?? Color.blue) // Change icon color based on selected category or default category
                    }
                )
                .onAppear {
                    print("ContentView appeared")
                    loadEvents()
                    appData.loadCategories() // Load categories from UserDefaults
                }

                // Add event Button
                Button(action: {
                    self.newEventTitle = ""
                    self.newEventDate = Date()
                    self.newEventEndDate = Date()
                    self.showEndDate = false
                    self.selectedCategory = self.selectedCategoryFilter ?? (appData.defaultCategory.isEmpty ? "Work" : appData.defaultCategory) // Set the selected category or default category
                    self.showAddEventSheet = true // This will now trigger the bottom sheet
                }) {
                    Image(systemName: "plus")
                        .font(.title)
                        .bold() // Make the icon thicker
                        .foregroundColor(.white) // Always white
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(self.selectedCategoryFilter != nil ? appData.categories.first(where: { $0.name == self.selectedCategoryFilter })?.color ?? Color.black : appData.categories.first(where: { $0.name == appData.defaultCategory })?.color ?? Color.blue) // Change background color based on selected category and color scheme
                        .cornerRadius(40)
                }
                .padding(0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }

        // Add Event Sheet
        .sheet(isPresented: $showAddEventSheet) {
            AddEventView(
                events: $events,
                selectedEvent: $selectedEvent,
                newEventTitle: $newEventTitle,
                newEventDate: $newEventDate,
                newEventEndDate: $newEventEndDate,
                showEndDate: $showEndDate,
                showAddEventSheet: $showAddEventSheet,
                selectedCategory: $selectedCategory,
                selectedColor: $selectedColor,
                notificationsEnabled: $notificationsEnabled,
                appData: _appData // Ensure this is correctly passed
            )
        }

        // Edit Event Sheet
        .sheet(isPresented: $showEditSheet) {
            EditEventView(
                events: $events,
                selectedEvent: $selectedEvent,
                newEventTitle: $newEventTitle,
                newEventDate: $newEventDate,
                newEventEndDate: $newEventEndDate,
                showEndDate: $showEndDate,
                showEditSheet: $showEditSheet,
                selectedCategory: $selectedCategory,
                selectedColor: $selectedColor,
                notificationsEnabled: $notificationsEnabled,
                saveEvent: saveEvent
            )
            .environmentObject(appData)
        }

        // Past events Sheet
        .sheet(isPresented: $showPastEventsSheet) {
            PastEventsView(events: $events, selectedEvent: $selectedEvent, newEventTitle: $newEventTitle, newEventDate: $newEventDate, newEventEndDate: $newEventEndDate, showEndDate: $showEndDate, selectedCategory: $selectedCategory, showPastEventsSheet: $showPastEventsSheet, showEditSheet: $showEditSheet, selectedColor: $selectedColor, categories: appData.categories, itemDateFormatter: itemDateFormatter, saveEvents: saveEvents)
                .environmentObject(appData)
        }

        // Categories Sheet
        .sheet(isPresented: $showCategoryManagementView) {
            CategoriesView()
                .environmentObject(appData)
        }
    }

    func filteredEvents() -> [Event] {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        var allEvents = [Event]()

        for event in events {
            if let filter = selectedCategoryFilter {
                if event.category == filter && (event.date >= startOfToday || (event.endDate != nil && event.endDate! >= startOfToday)) {
                    allEvents.append(event)
                }
            } else {
                if event.date >= startOfToday || (event.endDate != nil && event.endDate! >= startOfToday) {
                    allEvents.append(event)
                }
            }
        }

        return allEvents.sorted { $0.date < $1.date }
    }

    func deleteEvent(at event: Event) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events.remove(at: index)
            saveEvents()  // Save after deleting
            appData.removeNotification(for: event) // Call centralized function
            WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
        }
    }

    // Load events from UserDefaults
    func loadEvents() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier"),
           let data = sharedDefaults.data(forKey: "events"),
           let decoded = try? decoder.decode([Event].self, from: data) {
            events = decoded
            // print("Loaded events: \(events)")
        } else {
            print("No events found in shared UserDefaults.")
        }
    }

    // Save events to UserDefaults
    func saveEvents() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let encoded = try? encoder.encode(events),
           let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier") {
            sharedDefaults.set(encoded, forKey: "events")
            print("Saved events: \(events)")
            WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
        } else {
            print("Failed to encode events.")
        }
    }
    
    func saveEvent() {
        if let selectedEvent = selectedEvent,
           let index = events.firstIndex(where: { $0.id == selectedEvent.id }) {
            events[index].title = newEventTitle
            events[index].date = newEventDate
            events[index].endDate = showEndDate ? newEventEndDate : nil
            events[index].category = selectedCategory
            events[index].color = selectedColor
            events[index].notificationsEnabled = notificationsEnabled
            saveEvents()
            handleNotification(for: events[index])
            WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
        }
        showEditSheet = false
    }
    
    func addNewEvent() {
        let defaultEndDate = showEndDate ? newEventEndDate : nil
        let newEvent = Event(title: newEventTitle, date: newEventDate, endDate: defaultEndDate, color: selectedColor, category: selectedCategory, notificationsEnabled: notificationsEnabled)
        if let index = events.firstIndex(where: { $0.date > newEvent.date }) {
            events.insert(newEvent, at: index)
        } else {
            events.append(newEvent)
        }
        saveEvents()
        handleNotification(for: newEvent)
        newEventTitle = ""
        newEventDate = Date()
        newEventEndDate = Date()
        showEndDate = false
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
    }
    
    func handleNotification(for event: Event) {
        if event.notificationsEnabled {
            appData.scheduleNotification(for: event) // Call centralized function
        } else {
            appData.removeNotification(for: event) // Call centralized function
        }
    }
}

@ViewBuilder
private func categoryPillsView(appData: AppData, events: [Event], selectedCategoryFilter: Binding<String?>, colorScheme: ColorScheme) -> some View {
    let filteredCategories = appData.categories.filter { category in
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return events.contains { event in
            event.category == category.name && event.date >= startOfToday
        }
    }
    
    if filteredCategories.count > 1 {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(filteredCategories, id: \.name) { category in
                    Button(action: {
                        selectedCategoryFilter.wrappedValue = selectedCategoryFilter.wrappedValue == category.name ? nil : category.name
                    }) {
                        Text(category.name)
                            .font(.footnote)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedCategoryFilter.wrappedValue == category.name ? category.color : Color.clear) // Change background color based on selection
                            .foregroundColor(selectedCategoryFilter.wrappedValue == category.name ? .white : (colorScheme == .dark ? .white : .black)) // Adjust foreground color based on color scheme
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(selectedCategoryFilter.wrappedValue == category.name ? Color.clear : Color.gray, lineWidth: 1) // Conditionally apply border
                            )
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// Preview Provider
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppData())
            .preferredColorScheme(.dark) // Preview in dark mode
    }
}
