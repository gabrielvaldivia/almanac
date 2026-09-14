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
    @State private var attemptedQuickSubmit = false
    @State private var newEventTitle: String = ""
    @State private var newEventDate: Date = Date()
    @State private var newEventEndDate: Date = Date()
    @State private var selectedEvent: Event?
    private var editSheetPresented: Binding<Bool> {
        Binding(get: { selectedEvent != nil }, set: { if !$0 { selectedEvent = nil } })
    }
    @State private var highlightedEventID: UUID?
    @State private var highlightRequestID: UUID?
    @State private var showEndDate: Bool = false
    @State private var showPastEventsView: Bool = false
    @State private var selectedCategoryFilter: String? = nil
    @State private var selectedCategory: String? = nil
    @State private var eventListPosition: Date?
    @State private var timelineShowsToday = true
    @State private var timelineHeight: CGFloat = 100
    @State private var timelineMonth = Calendar.current.dateInterval(of: .month, for: Date())!.start
    @State private var timelineUsesYearHeading = false
    @State private var eventSheetScrollRequest: EventSheetScrollRequest?
    @State private var timelineScrollRequest: EventSheetScrollRequest?
    @State private var scrollSynchronization = EventScrollSynchronization()
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
    let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    private var timelineTitle: String {
        TimelineHeading.text(first: timelineMonth, last: timelineMonth, yearOnly: timelineUsesYearHeading)
    }

    private var compactTimelineTitle: String {
        if timelineUsesYearHeading { return timelineTitle }
        return Calendar.current.isDate(timelineMonth, equalTo: Date(), toGranularity: .year)
            ? timelineMonth.formatted(.dateTime.month(.abbreviated))
            : timelineMonth.formatted(.dateTime.month(.abbreviated).year())
    }

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
                floatingControls
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
        .sheet(item: $selectedEvent) { event in
            EditEventView(events: $appData.events, selectedEvent: $selectedEvent,
                          showEditSheet: editSheetPresented, saveEvents: appData.saveEvents)
                .id(event.id)
        }
        .tint(categoryTint)
    }

    @ViewBuilder
    private var floatingControls: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 16) {
                floatingControlContent
            }
        } else {
            floatingControlContent
        }
    }

    private var floatingControlContent: some View {
        HStack(alignment: .bottom) {
            if showingQuickEntry {
                QuickAddEventField(
                    text: $quickEventInput, isFocused: $isQuickEntryFocused,
                    overrides: $quickEventOverrides, draft: quickEventDraft,
                    categories: simplifiedCategories, onSubmit: submitQuickEntry,
                    validationMessage: attemptedQuickSubmit ? quickEventDraft.scheduleReviewMessage ?? quickEventDraft.dateOptions.validationMessage : nil,
                    onDismiss: dismissQuickEntry
                )
                .disabled(appData.storageError != nil)
                .modifier(FloatingControlSurface(id: "composer", namespace: composerTransition))
                .transition(.opacity)
                .task { isQuickEntryFocused = true }
            } else {
                filterMenu
                    .transition(.opacity)
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
                .disabled(appData.storageError != nil)
                .foregroundStyle(.white)
                .modifier(FloatingControlSurface(id: "composer", namespace: composerTransition, isInteractive: true, tint: categoryTint))
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
                    events: timelineEvents, tint: categoryTint, highlightedEventID: highlightedEventID,
                    scrollToTodayRequest: scrollToTodayRequest, scrollToDateRequest: timelineScrollRequest,
                    animateScrolling: !reduceMotion,
                    onHeightChange: { timelineHeight = $0 },
                    onTodayVisibilityChange: { timelineShowsToday = $0 }, onSelectEvent: selectTimelineEvent,
                    onInteractionBegan: beginTimelineInteraction,
                    onPositionChange: { day, anchor, visibleDayCount in
                        let calendar = Calendar.current
                        guard let focusedDate = calendar.date(byAdding: .day, value: Int(floor(day)), to: anchor),
                              let month = calendar.dateInterval(of: .month, for: focusedDate)?.start else { return }
                        let date = EventSheetSelection.nearestDate(to: day, anchor: anchor, dates: days.map(\.date))
                        let usesYear = TimelineHeading.showsYear(visibleDayCount: visibleDayCount)
                        DispatchQueue.main.async {
                            if timelineMonth != month { timelineMonth = month }
                            // Update SwiftUI only when the heading changes, not on every pinch frame.
                            if timelineUsesYearHeading != usesYear { timelineUsesYearHeading = usesYear }
                            if let date, scrollSynchronization.timelineMoved(to: date) {
                                eventSheetScrollRequest = EventSheetScrollRequest(date: date, animated: true)
                            }
                        }
                    }
                )
                // Keep the list usable on crowded dates and with the keyboard
                // open; overflowing event lanes can scroll inside the timeline.
                .frame(height: min(timelineHeight, max(80, geometry.size.height * 0.5)))

                Divider().accessibilityIdentifier("timelineListDivider")
                eventList(days: days)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .background(Color(uiColor: .systemBackground))
            .frame(height: geometry.size.height, alignment: .top)
            .clipped()
            .transaction { if reduceMotion { $0.animation = nil } }
        }
        .safeAreaInset(edge: .top) {
            if let error = appData.storageError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error).font(.footnote)
                    NavigationLink("Data Recovery") { SettingsView() }
                }.padding().frame(maxWidth: .infinity).background(.regularMaterial)
            }
        }
        .navigationTitle(timelineTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ViewThatFits(in: .horizontal) {
                    Text(timelineTitle).fixedSize()
                    Text(compactTimelineTitle).fixedSize()
                }
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: dismissQuickEntry)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("appTitle")
            }
            ToolbarItem(placement: .topBarLeading) {
                settingsButton
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !timelineShowsToday {
                    todayButton
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
            beginTimelineInteraction()
            dismissQuickEntry()
            highlightRequestID = nil
            highlightedEventID = nil
            if let date = EventListDay.initialDate(in: EventListDay.group(events: timelineEvents)) {
                eventSheetScrollRequest = EventSheetScrollRequest(date: date)
            }
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

    private func eventList(days: [EventListDay]) -> some View {
        VStack(spacing: 0) {
            if days.isEmpty {
                emptyStateView(selectedCategoryFilter: selectedCategoryFilter)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(days) { day in
                                eventRowView(key: day.date.relativeDate(), events: day.events)
                                    .padding(.horizontal)
                                    .background {
                                        GeometryReader { geometry in
                                            let frame = geometry.frame(in: .named("eventList"))
                                            Color.clear.preference(key: EventSheetVisibleDaysKey.self,
                                                value: [EventSheetVisibleDay(date: day.date, minY: frame.minY, maxY: frame.maxY)])
                                        }
                                    }
                                    // The gap between days must not keep an offscreen
                                    // event selected when the next card is visible.
                                    .padding(.bottom, 10)
                                    .id(day.date)
                            }
                            Spacer(minLength: 100)
                        }
                    }
                    .contentMargins(.top, 16, for: .scrollContent)
                    .accessibilityIdentifier("eventList")
                    .coordinateSpace(name: "eventList")
                    .scrollDismissesKeyboard(.interactively)
                    .modifier(EventSheetScrollTracking(onInteraction: beginSheetInteraction))
                    .onPreferenceChange(EventSheetVisibleDaysKey.self) { visibleDays in
                        guard let day = visibleDays.filter({ $0.maxY > 1 }).min(by: { $0.minY < $1.minY }) else { return }
                        if day.date != eventListPosition { eventListPosition = day.date }
                        synchronizeTimeline(to: day.date)
                    }
                    .onChange(of: eventSheetScrollRequest) { _, request in
                        guard let request else { return }
                        withAnimation(request.animated && !reduceMotion ? .easeOut(duration: 0.18) : nil) {
                            proxy.scrollTo(request.date, anchor: .top)
                        }
                    }
                    .onChange(of: days.map(\.date), initial: true) { _, dates in
                        guard !dates.contains(eventListPosition ?? .distantPast),
                              let date = EventListDay.initialDate(in: days) else { return }
                        beginTimelineInteraction()
                        eventListPosition = date
                        proxy.scrollTo(date, anchor: .top)
                    }
                }
            }
        }
    }

    private func beginTimelineInteraction() {
        scrollSynchronization.begin(.timeline)
        timelineScrollRequest = nil
    }

    private func beginSheetInteraction() {
        guard scrollSynchronization.source != .sheet else { return }
        scrollSynchronization.begin(.sheet)
        if let date = eventListPosition { synchronizeTimeline(to: date) }
    }

    private func synchronizeTimeline(to date: Date) {
        guard scrollSynchronization.sheetMoved(to: date) else { return }
        timelineScrollRequest = EventSheetScrollRequest(date: date, animated: true)
    }

    private var settingsButton: some View {
        NavigationLink(destination: SettingsView()) {
            Image(systemName: "gearshape.fill")
                .accessibilityLabel("Settings")
                .foregroundStyle(.tint)
                .imageScale(.large)
        }
        .simultaneousGesture(TapGesture().onEnded { dismissQuickEntry() })
    }

    private var todayButton: some View {
        Button(action: scrollToToday) {
            Image(systemName: "calendar.day.timeline.left")
                .imageScale(.large)
        }
        .foregroundStyle(.tint)
        .accessibilityLabel("Today")
        .accessibilityHint("Return to today in the timeline and event list")
        .accessibilityIdentifier("scrollToToday")
    }

    private func scrollToToday() {
        beginTimelineInteraction()
        dismissQuickEntry()
        highlightedEventID = nil
        highlightRequestID = nil
        scrollToTodayRequest = UUID()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            if let date = EventListDay.initialDate(in: EventListDay.group(events: timelineEvents)) {
                eventSheetScrollRequest = EventSheetScrollRequest(date: date)
            }
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
                .font(.system(size: 22, weight: .medium))
                .frame(width: 56, height: 56)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .modifier(FloatingControlSurface(id: "filter", namespace: composerTransition, isInteractive: true))
        .accessibilityLabel("Filter events")
        .accessibilityValue(selectedCategoryFilter ?? "All Events")
        .accessibilityIdentifier("eventFilter")
    }

    private func submitQuickEntry() {
        let draft = quickEventDraft
        guard appData.storageError == nil, !draft.title.isEmpty else { return }
        attemptedQuickSubmit = true
        guard !draft.requiresScheduleReview, draft.dateOptions.validationMessage == nil else { return }
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
        attemptedQuickSubmit = false
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
        beginTimelineInteraction()
        highlightedEventID = event.id
        highlightRequestID = UUID()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            eventSheetScrollRequest = EventSheetScrollRequest(date: EventListDay.displayDate(for: event), animated: true)
        }
    }

    private var quickEventDefaults: NewEventDraft {
        NewEventDraft(title: "", date: Date(), category: selectedCategoryFilter, appData: appData)
    }

    private var categoryTint: Color {
        quickEventDefaults.categoryOptions.selectedColor.color
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
                    .padding(.vertical, appData.eventStyle == "naked" ? 6 : 14)
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
        dismissQuickEntry()
        selectedEvent = nil
        switch link {
        case .addEvent:
            quickEventInput = ""
            quickEventOverrides = QuickEventOverrides()
            attemptedQuickSubmit = false
            showingQuickEntry = true
            isQuickEntryFocused = true
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
