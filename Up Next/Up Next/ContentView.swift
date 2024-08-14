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

    // State variables to manage the view's state
    @State private var events: [Event] = []
    @State private var newEventTitle: String = ""
    @State private var newEventDate: Date = Date()
    @State private var newEventEndDate: Date = Date()
    @State private var showAddEventSheet: Bool = false
    @State private var showEditSheet: Bool = false
    @State private var selectedEvent: Event?
    @State private var showEndDate: Bool = false
    @State private var showPastEventsView: Bool = false
    @State private var selectedCategoryFilter: String? = nil
    @State private var selectedColor: CodableColor = CodableColor(color: .blue)
    @State private var selectedCategory: String? = nil
    @State private var monthsToLoad: Int = 12

    // Environment objects and properties
    @EnvironmentObject var appData: AppData
    @Environment(\.colorScheme) var colorScheme

    @FocusState private var isFocused: Bool

    // Date formatters
    let itemDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    var body: some View {
    NavigationView {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Sorting and grouping events
                let sortedEvents = filteredEvents().sorted(by: { $0.date < $1.date })
                let groupedEventsByMonth = groupEventsByMonth(events: sortedEvents)
                let sortedMonths = groupedEventsByMonth.keys.sorted()

                if sortedEvents.isEmpty {
                    // Empty state view when no events are available for the current filter
                    emptyStateView(selectedCategoryFilter: selectedCategoryFilter)
                } else {
                    ScrollView {
                        LazyVStack {
                            // Category filter view
                            Section(header: CategoryPillsView(appData: appData, events: events, selectedCategoryFilter: $selectedCategoryFilter, colorScheme: colorScheme)
                                        .padding(.vertical, 10)
                            ) {
                                // Displaying events grouped by month
                                ForEach(sortedMonths, id: \.self) { month in
                                    VStack(alignment: .leading) {
                                        Text(itemDateFormatter.string(from: month))
                                            .roundedFont(.headline)
                                            .padding(.horizontal)
                                            .padding(.top, 10)
                                        
                                        let eventsInMonth = groupedEventsByMonth[month]!
                                        let groupedEventsByDate = groupEventsByDate(events: eventsInMonth)
                                        let sortedKeys = sortKeys(Array(groupedEventsByDate.keys))

                                        // Displaying events grouped by date
                                        ForEach(sortedKeys, id: \.self) { key in
                                            eventRowView(key: key, events: groupedEventsByDate[key]!)
                                        }
                                        .listRowSeparator(.hidden)
                                        .padding(.horizontal)
                                        .padding(.bottom, 10)
                                    }
                                }
                            }
                        }
                        
                        // "View More" button to load more events
                        if selectedCategoryFilter == nil || hasMoreEventsToLoad() {
                            if hasMoreEventsToLoad() {
                                Button(action: {
                                    self.monthsToLoad += 12
                                    loadEvents()
                                }) {
                                    Text("View More")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(Color.gray.opacity(0.2))
                                        .foregroundColor(.gray)
                                        .cornerRadius(20)
                                }
                                .padding(.vertical, 10)
                            }
                        }
                        
                        Spacer(minLength: 80)
                    }
                    .listStyle(PlainListStyle())
                    .listRowSeparator(.hidden)
                    .background(Color.clear)
                    .refreshable {
                        // Pull-to-refresh action
                        loadEvents()
                    }
                } 
            }
            .navigationTitle("Up Next")
            .navigationBarItems(
                leading: NavigationLink(destination: PastEventsView(
                    events: $events,
                    selectedEvent: $selectedEvent,
                    newEventTitle: $newEventTitle,
                    newEventDate: $newEventDate,
                    newEventEndDate: $newEventEndDate,
                    showEndDate: $showEndDate,
                    selectedCategory: $selectedCategory,
                    showEditSheet: $showEditSheet,
                    selectedColor: $selectedColor,
                    categories: appData.categories,
                    itemDateFormatter: itemDateFormatter,
                    saveEvents: saveEvents
                ).environmentObject(appData), isActive: $showPastEventsView) {
                    Image(systemName: "clock.arrow.circlepath")
                        .imageScale(.large)
                        .fontWeight(.bold)
                },
                trailing: NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape.fill")
                        .imageScale(.large)
                }
            )
            .onAppear {
                print("ContentView appeared")
                loadEvents()
                appData.loadCategories()
            }
            .onOpenURL { url in
                handleOpenURL(url)
            }

            // Add Event Button
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
            .environmentObject(appData)
        }
    }
    .focused($isFocused)
    .sheet(isPresented: $showAddEventSheet) {
        // Add Event Sheet
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
            appData: _appData
        )
        .focused($isFocused)
    }
    .sheet(isPresented: $showEditSheet) {
        // Edit Event Sheet
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
            saveEvent: saveEvent
        )
        .environmentObject(appData)
        .focused($isFocused)
    }
}

func groupEventsByMonth(events: [Event]) -> [Date: [Event]] {
    return Dictionary(grouping: events, by: { event in
        let components = Calendar.current.dateComponents([.year, .month], from: event.date)
        return Calendar.current.date(from: components)!
    })
}

// Group events by date
func groupEventsByDate(events: [Event]) -> [String: [Event]] {
    return Dictionary(grouping: events, by: { event in
        if event.date <= Date() && (event.endDate ?? event.date) >= Calendar.current.startOfDay(for: Date()) {
            return "Today"
        } else {
            return event.date.relativeDate()
        }
    })
}

// Sort keys for grouped events
func sortKeys(_ keys: [String]) -> [String] {
    return keys.sorted { key1, key2 in
        let date1 = Date().addingTimeInterval(TimeInterval(daysFromRelativeDate(key1)))
        let date2 = Date().addingTimeInterval(TimeInterval(daysFromRelativeDate(key2)))
        return date1 < date2
    }
}

// View for each event row
func eventRowView(key: String, events: [Event]) -> some View {
    HStack(alignment: .top) {
        Text(key.uppercased())
            .font(.system(.caption, design: .monospaced, weight: .medium))
            .foregroundColor(.gray)
            .frame(width: 100, alignment: .leading)
            .padding(.vertical, 14)
        VStack(alignment: .leading) {
            ForEach(events, id: \.id) { event in
                EventRow(event: event,
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
                        self.newEventEndDate = event.endDate ?? Calendar.current.date(byAdding: .day, value: 1, to: event.date) ?? event.date
                        self.showEndDate = event.endDate != nil
                        self.selectedCategory = event.category
                        self.showEditSheet = true
                    }
                    .listRowSeparator(.hidden)
            }
        }
    }
}

// Empty state view when no events are available or when a category with no events is selected
func emptyStateView(selectedCategoryFilter: String?) -> some View {
    VStack {
        // Category filter view
        CategoryPillsView(appData: appData, events: events, selectedCategoryFilter: $selectedCategoryFilter, colorScheme: colorScheme)
            .padding(.vertical, 10)
        
        Spacer()
        if let category = selectedCategoryFilter {
            Text("No events in \(category)")
                .roundedFont(.headline)
            Text("Add an event to this category")
                .roundedFont(.subheadline)
                .foregroundColor(.gray)
        } else {
            Text("No upcoming events")
                .roundedFont(.headline)
            Text("Add something you're looking forward to")
                .roundedFont(.subheadline)
                .foregroundColor(.gray)
        }
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}

// Handle URL scheme for adding events
func handleOpenURL(_ url: URL) {
    if url.scheme == "upnext" && url.host == "addEvent" {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.newEventTitle = ""
            self.newEventDate = Date()
            self.newEventEndDate = Date()
            self.showEndDate = false
            self.selectedCategory = self.selectedCategoryFilter ?? (appData.defaultCategory.isEmpty ? nil : appData.defaultCategory)
            self.showAddEventSheet = true
        }
    }
}
    // Filter events based on selected category and date range
    func filteredEvents() -> [Event] {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let endDate = Calendar.current.date(byAdding: .month, value: monthsToLoad, to: startOfToday)!
        var allEvents = [Event]()

        for event in events {
            if let filter = selectedCategoryFilter {
                if event.category == filter && (event.date >= startOfToday && event.date <= endDate || (event.endDate != nil && event.endDate! >= startOfToday && event.endDate! <= endDate)) {
                    allEvents.append(event)
                }
            } else {
                if event.date >= startOfToday && event.date <= endDate || (event.endDate != nil && event.endDate! >= startOfToday && event.endDate! <= endDate) {
                    allEvents.append(event)
                }
            }
        }

        return allEvents.sorted { $0.date < $1.date }
    }

    // Delete an event
    func deleteEvent(at event: Event) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events.remove(at: index)
            saveEvents()
            WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "NextEventWidget")
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
            WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "NextEventWidget")
        } else {
            print("Failed to encode events.")
        }
    }
    
    // Save the currently edited event
    func saveEvent() {
        if let selectedEvent = selectedEvent,
           let index = events.firstIndex(where: { $0.id == selectedEvent.id }) {
            events[index].title = newEventTitle
            events[index].date = newEventDate
            events[index].endDate = showEndDate ? newEventEndDate : nil
            events[index].category = selectedCategory
            events[index].color = selectedColor
            saveEvents()
            WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "NextEventWidget")
        }
        showEditSheet = false
    }
    
    // Add a new event
    func addNewEvent() {
        let defaultEndDate = showEndDate ? newEventEndDate : nil
        let newEvent = Event(title: newEventTitle, date: newEventDate, endDate: defaultEndDate, color: selectedColor, category: nil)
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
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "NextEventWidget")
    }
    
     // Check if there are more events to load
    func hasMoreEventsToLoad() -> Bool {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let endDate = Calendar.current.date(byAdding: .month, value: monthsToLoad, to: startOfToday)!
        return events.contains { event in
            let eventDate = event.endDate ?? event.date
            if let filter = selectedCategoryFilter {
                return event.category == filter && eventDate > endDate
            } else {
                return eventDate > endDate
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppData())
            .preferredColorScheme(.dark)
    }
}