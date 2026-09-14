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

struct ContentView: View {

    // State variables to manage the view's state
    @State private var quickEventInput: String = ""
    @State private var showingQuickEntry = false
    @Namespace private var composerTransition
    @State private var quickEventOverrides = QuickEventOverrides()
    @State private var manualDraft: NewEventDraft?
    @State private var newEventTitle: String = ""
    @State private var newEventDate: Date = Date()
    @State private var newEventEndDate: Date = Date()
    @State private var newEventRecurrence: ParsedEventRecurrence?
    @State private var showAddEventSheet: Bool = false
    @State private var selectedEvent: Event?
    private var editSheetPresented: Binding<Bool> {
        Binding(get: { selectedEvent != nil }, set: { if !$0 { selectedEvent = nil } })
    }
    @State private var highlightedEventID: UUID?
    @State private var highlightRequestID: UUID?
    @State private var showEndDate: Bool = false
    @State private var showPastEventsView: Bool = false
    @State private var selectedCategoryFilter: String? = nil
    @State private var selectedColor: CodableColor = CodableColor(color: .blue)
    @State private var selectedCategory: String? = nil
    @State private var eventListPosition: Date?
    @State private var timelineShowsToday = true
    @State private var timelinePresentation: TimelinePresentation = .compact
    @State private var scrollToTodayRequest: UUID?
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @FocusState private var isQuickEntryFocused: Bool

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
                    .ignoresSafeArea(.container, edges: .bottom)
                if showingQuickEntry {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: dismissQuickEntry)
                        .accessibilityLabel("Dismiss event entry")
                        .accessibilityIdentifier("dismissQuickEntry")
                        .accessibilityAddTraits(.isButton)
                }
                quickEntryControl
                    .disabled(appData.storageError != nil)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
        .sheet(isPresented: $showAddEventSheet) {
            addEventSheet
        }
        .sheet(item: $selectedEvent) { event in
            EditEventView(events: $appData.events, selectedEvent: $selectedEvent,
                          showEditSheet: editSheetPresented, saveEvents: appData.saveEvents)
                .id(event.id)
        }
        .tint(categoryTint)
    }

    private var quickEntryControl: some View {
        HStack(alignment: .bottom) {
            if showingQuickEntry {
                QuickAddEventField(
                    text: $quickEventInput, isFocused: $isQuickEntryFocused,
                    overrides: $quickEventOverrides, draft: quickEventDraft,
                    categories: simplifiedCategories, onSubmit: submitQuickEntry, onEdit: openEventDetails,
                    onDismiss: dismissQuickEntry
                )
                .modifier(FloatingControlSurface())
                .matchedGeometryEffect(id: "composer", in: composerTransition, anchor: .bottomTrailing)
                .transition(.opacity)
                .task { isQuickEntryFocused = true }
            } else {
                Spacer()
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showingQuickEntry = true }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .frame(width: 56, height: 56)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .modifier(FloatingControlSurface())
                .matchedGeometryEffect(id: "composer", in: composerTransition, anchor: .bottomTrailing)
                .transition(.opacity)
                .accessibilityLabel("Add event")
                .accessibilityIdentifier("quickAddButton")
            }
        }
    }

    private var mainContent: some View {
        let days = EventListDay.group(events: timelineEvents)

        return GeometryReader { geometry in
            VStack(spacing: 0) {
                EventTimelineView(
                    events: timelineEvents,
                    tint: categoryTint,
                    highlightedEventID: highlightedEventID,
                    scrollToTodayRequest: scrollToTodayRequest,
                    onTodayVisibilityChange: { timelineShowsToday = $0 },
                    onSelectEvent: selectTimelineEvent,
                    onEditEvent: { selectedEvent = $0 },
                    maximumHeight: max(0, geometry.size.height - 24),
                    presentation: $timelinePresentation
                )
                if timelinePresentation != .expanded {
                    Divider()

                    if days.isEmpty {
                        emptyStateView(selectedCategoryFilter: selectedCategoryFilter)
                    } else {
                        if let visibleDate = eventListPosition ?? EventListDay.initialDate(in: days) {
                            Text(itemDateFormatter.string(from: visibleDate))
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                                .background(Color(uiColor: .systemBackground))
                                .accessibilityAddTraits(.isHeader)
                        }
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(days) { day in
                                    eventRowView(key: day.date.relativeDate(), events: day.events)
                                        .padding(.horizontal)
                                        .padding(.bottom, 10)
                                        .id(day.date)
                                }
                                // Content scrolls behind the floating composer; this
                                // inset lets the last event clear it when scrolled.
                                Spacer(minLength: 100)
                            }
                            .scrollTargetLayout()
                        }
                        .accessibilityIdentifier("eventList")
                        .scrollPosition(id: $eventListPosition, anchor: .top)
                        .coordinateSpace(name: "eventList")
                        .scrollDismissesKeyboard(.interactively)
                        .background(Color.clear)
                        .onChange(of: days.map(\.date), initial: true) {
                            guard !days.contains(where: { $0.date == eventListPosition }) else { return }
                            eventListPosition = EventListDay.initialDate(in: days)
                        }
                    }
                }
            }
            .frame(height: geometry.size.height, alignment: .top)
            .clipped()
        }
        .safeAreaInset(edge: .top) {
            if let error = appData.storageError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error).font(.footnote)
                    NavigationLink("Data Recovery") { SettingsView() }
                }.padding().frame(maxWidth: .infinity).background(.regularMaterial)
            }
        }
        .navigationTitle("Almanac")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                settingsButton
            }
            ToolbarItem(placement: .topBarTrailing) { filterMenu }
            if !timelineShowsToday || isListAwayFromToday(in: days) {
                if #available(iOS 26, *) {
                    ToolbarItem(placement: .topBarTrailing) {
                        todayButton
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarTrailing) { todayButton }
                }
            }
        }
        .onAppear {
            appData.loadEvents()
            appData.loadCategories()
        }
        .onChange(of: appData.categories.map(\.name)) { _, names in
            if let selectedCategoryFilter, !names.contains(selectedCategoryFilter) { self.selectedCategoryFilter = nil }
            if let name = quickEventOverrides.categoryName, !name.isEmpty, !names.contains(name) {
                quickEventOverrides.categoryName = nil
            }
        }
        .onOpenURL { url in
            handleOpenURL(url)
        }
        .onChange(of: selectedCategoryFilter) {
            highlightRequestID = nil
            highlightedEventID = nil
            eventListPosition = EventListDay.initialDate(in: EventListDay.group(events: timelineEvents))
        }
        .task(id: highlightRequestID) {
            guard highlightRequestID != nil else { return }
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.5)) {
                highlightedEventID = nil
            }
        }
    }

    private var settingsButton: some View {
        NavigationLink(destination: SettingsView()) {
            Image(systemName: "gearshape.fill")
                .accessibilityLabel("Settings")
                .foregroundStyle(.tint)
                .imageScale(.large)
        }
    }

    @ViewBuilder private var todayButton: some View {
        let button = Button(action: scrollToToday) {
            Text(Date().formatted(.dateTime.day()))
                .font(.body)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Today")
        .accessibilityHint("Return to today in the timeline and event list")
        .accessibilityIdentifier("scrollToToday")

        if #available(iOS 26, *) {
            button.glassEffect(.regular.interactive(), in: Circle())
        } else {
            button.background(.regularMaterial, in: Circle())
        }
    }

    private func isListAwayFromToday(in days: [EventListDay]) -> Bool {
        guard let eventListPosition, let todayPosition = EventListDay.initialDate(in: days) else { return false }
        return eventListPosition != todayPosition
    }

    private func scrollToToday() {
        highlightedEventID = nil
        highlightRequestID = nil
        scrollToTodayRequest = UUID()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            eventListPosition = EventListDay.initialDate(in: EventListDay.group(events: timelineEvents))
        }
    }

    private var filterMenu: some View {
        Menu {
            Button {
                selectedCategoryFilter = nil
            } label: {
                HStack {
                    Text("All Events")
                    if selectedCategoryFilter == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            ForEach(appData.categories, id: \.name) { category in
                Button {
                    selectedCategoryFilter = category.name
                } label: {
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
            Image(systemName: "line.horizontal.3.decrease")
                .foregroundStyle(.tint)
                .imageScale(.large)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .accessibilityLabel("Filter events")
        .accessibilityValue(selectedCategoryFilter ?? "All Events")
        .accessibilityIdentifier("eventFilter")
    }

    private func submitQuickEntry() {
        let draft = quickEventDraft
        guard appData.storageError == nil, !draft.title.isEmpty else { return }
        guard !draft.requiresScheduleReview, draft.dateOptions.validationMessage == nil else {
            openEventDetails()
            return
        }
        appData.events.append(contentsOf: NewEventDraft.events(
            title: draft.title, dates: draft.dateOptions, category: draft.categoryOptions))
        appData.saveEvents()
        isQuickEntryFocused = false
        resetQuickEntry()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func resetQuickEntry() {
        isQuickEntryFocused = false
        quickEventInput = ""
        quickEventOverrides = QuickEventOverrides()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showingQuickEntry = false }
    }

    private func dismissQuickEntry() {
        isQuickEntryFocused = false
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showingQuickEntry = false }
    }

    private var quickEventDraft: NewEventDraft {
        quickEventOverrides.resolve(quickEventInput, category: selectedCategoryFilter, appData: appData)
    }

    private var timelineEvents: [Event] {
        appData.events.filter { selectedCategoryFilter == nil || $0.category == selectedCategoryFilter }
    }

    private func selectTimelineEvent(_ event: Event) {
        highlightedEventID = event.id
        highlightRequestID = UUID()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            eventListPosition = EventListDay.displayDate(for: event)
        }
    }

    private var quickEventDefaults: NewEventDraft {
        NewEventDraft(title: "", date: Date(), category: selectedCategoryFilter, appData: appData)
    }

    private var categoryTint: Color {
        quickEventDefaults.categoryOptions.selectedColor.color
    }

    private func openEventDetails() {
        isQuickEntryFocused = false
        let draft = quickEventDraft
        manualDraft = draft
        newEventTitle = draft.title
        newEventDate = draft.dateOptions.date
        newEventEndDate = draft.dateOptions.endDate
        newEventRecurrence = nil
        showEndDate = draft.dateOptions.showEndDate
        selectedCategory = draft.categoryOptions.selectedCategory
        selectedColor = draft.categoryOptions.selectedColor
        showAddEventSheet = true
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
            initialDraft: manualDraft,
            initialRecurrence: newEventRecurrence,
            onSave: resetQuickEntry,
            appData: _appData
        )
    }

    // View for each event row
    func eventRowView(key: String, events: [Event]) -> some View {
        HStack(alignment: .top) {
            GeometryReader { dayGeometry in
                let dayFrame = dayGeometry.frame(in: .named("eventList"))
                Text(key.uppercased())
                    .font(.system(.caption, design: .monospaced, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
                    .visualEffect { content, labelGeometry in
                        // Keep the day beside its events, then let the next day
                        // push it away at the bottom of this group.
                        content.offset(y: min(max(0, -dayFrame.minY),
                                              max(0, dayFrame.height - labelGeometry.size.height)))
                    }
            }
            .frame(width: 100)
            VStack(alignment: .leading) {
                ForEach(events, id: \.id) { event in
                    EventRow(
                        event: event,
                        isHighlighted: highlightedEventID == event.id,
                        selectedEvent: $selectedEvent,
                        newEventTitle: $newEventTitle,
                        newEventDate: $newEventDate,
                        newEventEndDate: $newEventEndDate,
                        showEndDate: $showEndDate,
                        selectedCategory: $selectedCategory,
                        showEditSheet: editSheetPresented,
                        categories: simplifiedCategories
                    )
                    .accessibilityAddTraits(highlightedEventID == event.id ? .isSelected : [])
                    .id(event.id)
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
                Text("No events yet")
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
        guard let link = DeepLink(url: url) else { return }
        showAddEventSheet = false
        selectedEvent = nil
        switch link {
        case .addEvent:
            manualDraft = nil
            newEventRecurrence = nil
            newEventTitle = ""
            newEventDate = Date()
            newEventEndDate = Date()
            showEndDate = false
            selectedCategory = selectedCategoryFilter ?? (appData.defaultCategory.isEmpty ? nil : appData.defaultCategory)
            showAddEventSheet = true
        case .event(let id):
            if let event = appData.events.first(where: { $0.id == id }) {
                selectedEvent = event
            }
        case .home: selectedCategoryFilter = nil
        }
    }

}

/// Group by calendar dates, including history, without parsing relative labels.
struct EventListDay: Identifiable {
    var date: Date
    var events: [Event]
    var startsMonth: Bool
    var id: Date { date }

    static func displayDate(for event: Event, today: Date = Date(), calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: today)
        let start = calendar.startOfDay(for: event.date)
        let end = calendar.startOfDay(for: event.endDate ?? event.date)
        return start <= today && end >= today ? today : start
    }

    static func group(events: [Event], today: Date = Date(), calendar: Calendar = .current) -> [EventListDay] {
        let grouped = Dictionary(grouping: events) { displayDate(for: $0, today: today, calendar: calendar) }
        let dates = grouped.keys.sorted()
        return dates.enumerated().map { index, date in
            EventListDay(
                date: date,
                events: grouped[date]!.sorted {
                    if $0.date != $1.date { return $0.date < $1.date }
                    return $0.id.uuidString < $1.id.uuidString
                },
                startsMonth: index == 0 || !calendar.isDate(date, equalTo: dates[index - 1], toGranularity: .month)
            )
        }
    }

    static func initialDate(in days: [EventListDay], today: Date = Date(), calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: today)
        return days.first { $0.date >= today }?.date ?? days.last?.date
    }
}
