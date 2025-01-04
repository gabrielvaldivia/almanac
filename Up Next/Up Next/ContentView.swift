//
//  ContentView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/19/24.
//

import Foundation
import SwiftUI
import UserNotifications
import WidgetKit

struct EventTimelineView: View {
    @EnvironmentObject var appData: AppData
    var events: [Event]
    let numberOfDays: Int = 365  // Show a full year
    @Environment(\.colorScheme) var colorScheme

    private let dayWidth: CGFloat = 120
    private let eventHeight: CGFloat = 24

    private var startDate: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var dateRange: [Date] {
        (0..<numberOfDays).map { dayOffset in
            Calendar.current.date(byAdding: .day, value: dayOffset, to: startDate) ?? startDate
        }
    }

    private func eventsForDate(_ date: Date) -> [(event: Event, level: Int)] {
        let eventsOnDate = events.filter { event in
            let eventStart = Calendar.current.startOfDay(for: event.date)
            let eventEnd = event.endDate.map { Calendar.current.startOfDay(for: $0) } ?? eventStart
            let targetDate = Calendar.current.startOfDay(for: date)
            return targetDate >= eventStart && targetDate <= eventEnd
        }

        // Sort events by start date and duration
        let sortedEvents = eventsOnDate.sorted { e1, e2 in
            if e1.date == e2.date {
                let d1 =
                    e1.endDate.map {
                        Calendar.current.dateComponents([.day], from: e1.date, to: $0).day ?? 0
                    } ?? 0
                let d2 =
                    e2.endDate.map {
                        Calendar.current.dateComponents([.day], from: e2.date, to: $0).day ?? 0
                    } ?? 0
                return d1 > d2
            }
            return e1.date < e2.date
        }

        // Assign levels to events based on overlap
        var eventLevels: [(event: Event, level: Int)] = []
        var usedLevels: Set<Int> = []

        for event in sortedEvents {
            var level = 0
            while usedLevels.contains(level) {
                level += 1
            }
            eventLevels.append((event: event, level: level))
            usedLevels.insert(level)
        }

        return eventLevels
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                // Days row
                LazyHStack(alignment: .top, spacing: 4) {
                    ForEach(dateRange, id: \.self) { date in
                        VStack(alignment: .center, spacing: 4) {
                            // Day and number
                            HStack(spacing: 4) {
                                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.gray)
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(
                                        Calendar.current.isDateInToday(date)
                                            ? .accentColor : .primary)
                            }
                        }
                        .frame(width: dayWidth)
                    }
                }
                .padding(.horizontal, 16)

                // Events layer
                ForEach(events) { event in
                    if let startIndex = dateRange.firstIndex(where: {
                        Calendar.current.startOfDay(for: $0)
                            == Calendar.current.startOfDay(for: event.date)
                    }) {
                        let xOffset = CGFloat(startIndex) * (dayWidth + 4) + 16  // Account for day spacing
                        let width = calculateEventWidth(event)
                        let level = eventLevel(for: event)
                        EventPill(event: event)
                            .frame(width: width)
                            .offset(x: xOffset, y: 24 + CGFloat(level) * (eventHeight + 4))
                    }
                }
            }
        }
        .frame(height: calculateTimelineHeight())
    }

    private func calculateTimelineHeight() -> CGFloat {
        let headerHeight: CGFloat = 20  // Height for day header (changed from 32)
        let spacing: CGFloat = 4  // Spacing between events
        let levels = maxEventLevels + 1  // Add 1 to account for 0-based index
        let eventsHeight = CGFloat(levels) * (eventHeight + spacing)
        let bottomPadding: CGFloat = 8  // Padding at the bottom

        return headerHeight + eventsHeight + bottomPadding
    }

    private func eventLevel(for event: Event) -> Int {
        let eventStart = Calendar.current.startOfDay(for: event.date)
        let eventEnd = event.endDate.map { Calendar.current.startOfDay(for: $0) } ?? eventStart

        var level = 0
        for otherEvent in events {
            if otherEvent.id == event.id { continue }

            let otherStart = Calendar.current.startOfDay(for: otherEvent.date)
            let otherEnd =
                otherEvent.endDate.map { Calendar.current.startOfDay(for: $0) } ?? otherStart

            // Check if events overlap
            if max(eventStart, otherStart) <= min(eventEnd, otherEnd) {
                if otherEvent.date < event.date
                    || (otherEvent.date == event.date && otherEvent.id < event.id)
                {
                    level += 1
                }
            }
        }

        return level
    }

    private var maxEventLevels: Int {
        dateRange.map { date in
            eventsForDate(date).map(\.level).max() ?? 0
        }.max() ?? 0 + 1
    }

    private func calculateEventWidth(_ event: Event) -> CGFloat {
        let eventStart = Calendar.current.startOfDay(for: event.date)
        let eventEnd = event.endDate.map { Calendar.current.startOfDay(for: $0) } ?? eventStart
        let days = Calendar.current.dateComponents([.day], from: eventStart, to: eventEnd).day ?? 0
        return CGFloat(days + 1) * dayWidth + CGFloat(days) * 4  // Add spacing for gaps between days
    }
}

struct EventPill: View {
    var event: Event

    var body: some View {
        HStack {
            Text(event.title)
                .lineLimit(1)
                .font(.system(size: 11))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(event.color.color.opacity(0.2))
        .foregroundColor(event.color.color)
        .cornerRadius(12)
    }
}

struct ContentView: View {

    // State variables to manage the view's state
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
    @State private var eventDetails = EventDetails(
        title: "", selectedEvent: Event(title: "", date: Date(), color: CodableColor(color: .blue)))
    @State private var dateOptions = DateOptions(
        date: Date(), endDate: Date(), showEndDate: false, repeatOption: .never,
        repeatUntil: Date(), repeatUntilOption: .indefinitely, repeatUntilCount: 1,
        showRepeatOptions: false, repeatUnit: "Days", customRepeatCount: 1)
    @State private var categoryOptions = CategoryOptions(
        selectedCategory: nil, selectedColor: CodableColor(color: .blue))
    @State private var viewState = ViewState(
        showCategoryManagementView: false, showDeleteActionSheet: false, showDeleteButtons: true)

    // Environment objects and properties
    @EnvironmentObject var appData: AppData
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) private var scenePhase

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

    private var simplifiedCategories: [(name: String, color: Color)] {
        return appData.categories.map { category in
            (name: category.name, color: category.color)
        }
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                mainContent
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
            addEventSheet
        }
        .sheet(isPresented: $showEditSheet) {
            editEventSheet
        }
        .onChange(of: appData.events) { _ in
            // Force view update
            appData.objectWillChange.send()
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            let sortedEvents = filteredEvents().sorted(by: { $0.date < $1.date })
            let groupedEventsByMonth = groupEventsByMonth(events: sortedEvents)
            let sortedMonths = groupedEventsByMonth.keys.sorted()

            if sortedEvents.isEmpty {
                emptyStateView(selectedCategoryFilter: selectedCategoryFilter)
            } else {
                // Timeline view fixed at the top
                EventTimelineView(events: sortedEvents)
                    .padding(.top, 16)  // Changed from [.top, .bottom] to just .top
                    .background(Color(uiColor: .secondarySystemGroupedBackground))

                Divider()

                // Scrollable content below
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(sortedMonths, id: \.self) { month in
                            monthSection(month: month, events: groupedEventsByMonth[month]!)
                        }
                        .padding(.top, 8)  // Reduced from 16 to 8

                        viewMoreButton

                        Spacer(minLength: 80)
                    }
                }
                .listStyle(PlainListStyle())
                .listRowSeparator(.hidden)
                .background(Color.clear)
                .refreshable {
                    appData.loadEvents()
                }
            }
        }
        .navigationTitle("Almanac")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(
            leading: settingsButton,
            trailing: Menu {
                Button(action: {
                    selectedCategoryFilter = nil
                }) {
                    HStack {
                        Text("All Events")
                        if selectedCategoryFilter == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                ForEach(appData.categories, id: \.name) { category in
                    Button(action: {
                        selectedCategoryFilter = category.name
                    }) {
                        HStack {
                            Circle()
                                .fill(category.color)
                                .frame(width: 8, height: 8)
                            Text(category.name)
                            if selectedCategoryFilter == category.name {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(
                    systemName: selectedCategoryFilter == nil
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill"
                )
                .imageScale(.large)
            }
        )
        .onAppear {
            print("ContentView appeared")
            appData.loadEvents()
            appData.loadCategories()
        }
        .onOpenURL { url in
            handleOpenURL(url)
        }
    }

    private var settingsButton: some View {
        NavigationLink(destination: SettingsView()) {
            Image(systemName: "gearshape.fill")
                .imageScale(.large)
        }
    }

    private var addEventSheet: some View {
        AddEventView(
            events: $appData.events,
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

    private var editEventSheet: some View {
        EditEventView(
            events: $appData.events,
            selectedEvent: $selectedEvent,
            showEditSheet: $showEditSheet,
            saveEvents: appData.saveEvents
        )
        .environmentObject(appData)
        .focused($isFocused)
    }

    private func monthSection(month: Date, events: [Event]) -> some View {
        VStack(alignment: .leading) {
            Text(itemDateFormatter.string(from: month))
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 10)

            let groupedEventsByDate = groupEventsByDate(events: events)
            let sortedKeys = sortKeys(Array(groupedEventsByDate.keys))

            ForEach(sortedKeys, id: \.self) { key in
                eventRowView(key: key, events: groupedEventsByDate[key]!)
            }
            .listRowSeparator(.hidden)
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }

    private var viewMoreButton: some View {
        Group {
            if selectedCategoryFilter == nil || hasMoreEventsToLoad() {
                if hasMoreEventsToLoad() {
                    Button(action: {
                        self.monthsToLoad += 12
                        appData.loadEvents()
                    }) {
                        Text("View More")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.gray)
                            .cornerRadius(20)
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }

    // Group events by month
    func groupEventsByMonth(events: [Event]) -> [Date: [Event]] {
        return Dictionary(
            grouping: events,
            by: { event in
                let components = Calendar.current.dateComponents([.year, .month], from: event.date)
                return Calendar.current.date(from: components)!
            })
    }

    // Group events by date
    func groupEventsByDate(events: [Event]) -> [String: [Event]] {
        return Dictionary(
            grouping: events,
            by: { event in
                if event.date <= Date()
                    && (event.endDate ?? event.date) >= Calendar.current.startOfDay(for: Date())
                {
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
                    EventRow(
                        event: event,
                        selectedEvent: $selectedEvent,
                        newEventTitle: $newEventTitle,
                        newEventDate: $newEventDate,
                        newEventEndDate: $newEventEndDate,
                        showEndDate: $showEndDate,
                        selectedCategory: $selectedCategory,
                        showEditSheet: $showEditSheet,
                        categories: simplifiedCategories
                    )
                    .onTapGesture {
                        selectEvent(event)
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
            CategoryPillsView(
                appData: appData, events: appData.events,
                selectedCategoryFilter: $selectedCategoryFilter, colorScheme: colorScheme
            )
            .padding(.vertical, 10)

            Spacer()
            if let category = selectedCategoryFilter {
                Text("No events in \(category)")
                    .font(.headline)
                Text("Add an event to this category")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                Text("No upcoming events")
                    .font(.headline)
                Text("Add something you're looking forward to")
                    .font(.subheadline)
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
                self.selectedCategory =
                    self.selectedCategoryFilter
                    ?? (appData.defaultCategory.isEmpty ? nil : appData.defaultCategory)
                self.showAddEventSheet = true
            }
        }
    }

    // Filter events based on selected category and date range
    func filteredEvents() -> [Event] {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let endDate = Calendar.current.date(
            byAdding: .month, value: monthsToLoad, to: startOfToday)!
        var allEvents = [Event]()

        for event in appData.events {
            if let filter = selectedCategoryFilter {
                if event.category == filter
                    && (event.date >= startOfToday && event.date <= endDate
                        || (event.endDate != nil && event.endDate! >= startOfToday
                            && event.endDate! <= endDate))
                {
                    allEvents.append(event)
                }
            } else {
                if event.date >= startOfToday && event.date <= endDate
                    || (event.endDate != nil && event.endDate! >= startOfToday
                        && event.endDate! <= endDate)
                {
                    allEvents.append(event)
                }
            }
        }

        return allEvents.sorted { $0.date < $1.date }
    }

    // Delete an event
    func deleteEvent(_ event: Event) {
        appData.deleteEvent(event)
        appData.objectWillChange.send()
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "NextEventWidget")
    }

    // Check if there are more events to load
    func hasMoreEventsToLoad() -> Bool {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let endDate = Calendar.current.date(
            byAdding: .month, value: monthsToLoad, to: startOfToday)!
        return appData.events.contains { event in
            let eventDate = event.endDate ?? event.date
            if let filter = selectedCategoryFilter {
                return event.category == filter && eventDate > endDate
            } else {
                return eventDate > endDate
            }
        }
    }

    private func selectEvent(_ event: Event) {
        selectedEvent = event
    }
}
