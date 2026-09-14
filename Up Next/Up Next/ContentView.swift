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
            mainContent
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    HStack(spacing: 8) {
                        Group {
                            if isQuickEntryFocused {
                                closeQuickEntryButton
                                    .transition(.blurReplace)
                            } else {
                                filterMenu
                                    .transition(.blurReplace)
                            }
                        }
                        .modifier(FloatingControlSurface())
                        QuickAddEventField(
                            text: $quickEventInput,
                            isFocused: $isQuickEntryFocused,
                            onSubmit: submitQuickEntry
                        )
                        .disabled(appData.storageError != nil)
                        quickEntryActionButton
                    }
                    .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: isQuickEntryFocused)
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

    private var mainContent: some View {
        let days = EventListDay.group(events: timelineEvents)

        return VStack(spacing: 0) {
            EventTimelineView(
                events: timelineEvents,
                tint: categoryTint,
                scrollToTodayRequest: scrollToTodayRequest,
                onTodayVisibilityChange: { timelineShowsToday = $0 },
                onSelectEvent: selectTimelineEvent
            )
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
                        Spacer(minLength: 16)
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $eventListPosition, anchor: .top)
                .scrollDismissesKeyboard(.interactively)
                .background(Color.clear)
                .onChange(of: days.map(\.date), initial: true) {
                    guard !days.contains(where: { $0.date == eventListPosition }) else { return }
                    eventListPosition = EventListDay.initialDate(in: days)
                }
            }
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

    private var closeQuickEntryButton: some View {
        Button {
            isQuickEntryFocused = false
        } label: {
            Image(systemName: "xmark")
                .foregroundStyle(.tint)
                .imageScale(.large)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close event input")
        .accessibilityHint("Dismisses the keyboard")
        .accessibilityIdentifier("closeQuickEntry")
    }

    private var quickEntryActionButton: some View {
        let isDisabled = appData.storageError != nil || (isQuickEntryFocused && quickEventInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        return Button {
            if isQuickEntryFocused {
                submitQuickEntry()
            } else {
                openEventDetails(QuickEventParser.parse(quickEventInput))
            }
        } label: {
            Image(systemName: isQuickEntryFocused ? "arrow.up" : "calendar.badge.plus")
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(isQuickEntryFocused ? .white : categoryTint)
                .font(.system(size: 20, weight: isQuickEntryFocused ? .semibold : .regular))
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .background {
            if isQuickEntryFocused {
                Circle().fill(categoryTint)
            }
        }
        .modifier(FloatingControlSurface())
        .opacity(isDisabled ? 0.45 : 1)
        .accessibilityLabel(isQuickEntryFocused ? "Submit event" : "Add event")
        .accessibilityHint(isQuickEntryFocused ? "Adds a recognized event or opens event details." : "Opens the full event form.")
        .accessibilityIdentifier(isQuickEntryFocused ? "quickAddSubmit" : "manualEventInput")
    }

    private func submitQuickEntry() {
        guard !quickEventInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isQuickEntryFocused = false
        if let parsed = QuickEventParser.parse(quickEventInput) {
            addQuickEvent(parsed)
        } else {
            openEventDetails(nil)
        }
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

    private func addQuickEvent(_ input: ParsedEventInput) {
        guard appData.storageError == nil else { return }
        let draft = NewEventDraft(title: input.title, date: input.date,
                                  category: selectedCategoryFilter, appData: appData,
                                  recurrence: input.recurrence)
        guard draft.dateOptions.validationMessage == nil else {
            openEventDetails(input)
            return
        }
        appData.events.append(contentsOf: NewEventDraft.events(
            title: draft.title, dates: draft.dateOptions, category: draft.categoryOptions))
        appData.saveEvents()
        quickEventInput = ""
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func openEventDetails(_ input: ParsedEventInput?) {
        isQuickEntryFocused = false
        newEventTitle = input?.title ?? quickEventInput.trimmingCharacters(in: .whitespacesAndNewlines)
        newEventDate = input?.date ?? Calendar.current.startOfDay(for: Date())
        newEventEndDate = newEventDate
        newEventRecurrence = input?.recurrence ?? QuickEventParser.inferredRecurrence(for: newEventTitle)
        showEndDate = false
        selectedCategory = quickEventDefaults.categoryOptions.selectedCategory
        selectedColor = quickEventDefaults.categoryOptions.selectedColor
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
            initialRecurrence: newEventRecurrence,
            onSave: { quickEventInput = "" },
            appData: _appData
        )
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
                        showEditSheet: editSheetPresented,
                        categories: simplifiedCategories
                    )
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(event.color.color.opacity(highlightedEventID == event.id ? 0.18 : 0))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(event.color.color, lineWidth: 2)
                            .opacity(highlightedEventID == event.id ? 1 : 0)
                            .allowsHitTesting(false)
                    }
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
