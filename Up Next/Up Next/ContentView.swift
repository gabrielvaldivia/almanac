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
        formatter.dateFormat = "EEE, MMMM d" // Updated format to include day of the week
        return formatter
    }()

    var body: some View {
         NavigationView {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) { // Remove vertical padding by setting spacing to 0
                    // List of events
                    let groupedEvents = Dictionary(grouping: filteredEvents().sorted(by: { $0.date < $1.date }), by: { event in
                        if event.date <= Date() && (event.endDate ?? event.date) >= Calendar.current.startOfDay(for: Date()) {
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
                                .roundedFont(.headline)
                            Text("Add something you're looking forward to")
                                .roundedFont(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack {
                                Section(header: CategoryPillsView(appData: appData, events: events, selectedCategoryFilter: $selectedCategoryFilter, colorScheme: colorScheme)
                                            .padding(.vertical, 10)
                                ) {
                                    ForEach(sortedKeys, id: \.self) { key in
                                        HStack(alignment: .top) {
                                            Text(key.uppercased())
                                                .font(.system(.caption, design: .monospaced, weight: .medium))
                                                // .font(.system(.footnote, design: .rounded, weight: .medium))
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
                                                             showEditSheet: $showEditSheet,
                                                             categories: appData.categories)
                                                        .onTapGesture {
                                                            self.selectedEvent = event
                                                            self.newEventTitle = event.title
                                                            self.newEventDate = event.date
                                                            self.newEventEndDate = event.endDate ?? Date()
                                                            self.showEndDate = event.endDate != nil
                                                            self.selectedCategory = event.category
                                                            self.showEditSheet = true
                                                        }
                                                        .listRowSeparator(.hidden)
                                                }
                                            }
                                        } 
                                        
                                    } 
                                    .listRowSeparator(.hidden)
                                    .padding(.horizontal)
                                    .padding(.bottom, 10)
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                        .listRowSeparator(.hidden)
                        .background(Color.clear)
                    } 
                }
                .navigationTitle("Up Next")
                .roundedFont(.title)
                .navigationBarItems(
                    leading: HStack {
                        CircleButton(
                            iconName: "clock.arrow.circlepath",
                            action: {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                self.showPastEventsSheet = true
                            }
                        )
                    },
                    trailing: CircleButton(
                        iconName: "gearshape.fill",
                        action: {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            self.showCategoryManagementView = true
                        }
                    )
                )
                .onAppear {
                    print("ContentView appeared")
                    loadEvents()
                    appData.loadCategories() // Load categories from UserDefaults
                }

                .onOpenURL { url in
                    if url.scheme == "upnext" && url.host == "addEvent" {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Add a 0.5 second delay
                            self.newEventTitle = ""
                            self.newEventDate = Date()
                            self.newEventEndDate = Date()
                            self.showEndDate = false
                            self.selectedCategory = self.selectedCategoryFilter ?? (appData.defaultCategory.isEmpty ? "Work" : appData.defaultCategory)
                            self.showAddEventSheet = true
                        }
                    }
                }

                // Custom Add Event Button
                AddEventButton(
                    selectedCategoryFilter: $selectedCategoryFilter,
                    showAddEventSheet: $showAddEventSheet,
                    newEventTitle: $newEventTitle,
                    newEventDate: $newEventDate,
                    newEventEndDate: $newEventEndDate,
                    showEndDate: $showEndDate,
                    selectedCategory: $selectedCategory
                )
                .padding(0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .environmentObject(appData) // Pass appData as an environment object
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

    // Filtered events
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
            WidgetCenter.shared.reloadTimelines(ofKind: "NextEventWidget") // Reload NextEventWidget timelines
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
            WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
            WidgetCenter.shared.reloadTimelines(ofKind: "NextEventWidget") // Reload NextEventWidget timelines
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
            WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
            WidgetCenter.shared.reloadTimelines(ofKind: "NextEventWidget") // Reload NextEventWidget timelines
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
        newEventTitle = ""
        newEventDate = Date()
        newEventEndDate = Date()
        showEndDate = false
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
        WidgetCenter.shared.reloadTimelines(ofKind: "NextEventWidget") // Reload NextEventWidget timelines
    }
    
    func handleNotification(for event: Event) {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)!

        if event.notificationsEnabled {
            if event.date <= endOfToday && (event.endDate ?? event.date) >= startOfToday {
                appData.scheduleNotification(for: event) // Call centralized function
            } else {
                appData.removeNotification(for: event) // Call centralized function
            }
        } else {
            appData.removeNotification(for: event) // Call centralized function
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
