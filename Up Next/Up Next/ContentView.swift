//
//  ContentView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/19/24.
//

import Foundation
import SwiftUI

struct ContentView: View {

    // State variables to manage the view's state
    @State private var quickEventInput: String = ""
    @State private var showingQuickEntry = false
    @State private var quickEntryDragOffset: CGFloat = 0
    @Namespace private var composerTransition
    @State private var quickEventOverrides = QuickEventOverrides()
    @State private var attemptedQuickSubmit = false
    @State private var selectedEvent: Event?
    private var editSheetPresented: Binding<Bool> {
        Binding(get: { selectedEvent != nil }, set: { if !$0 { selectedEvent = nil } })
    }
    @State private var highlightedEventID: UUID?
    @State private var highlightRequestID: UUID?
    @State private var selectedCategoryFilter: String? = nil
    @State private var eventListPosition: Date?
    @State private var eventListWindow = EventListWindow()
    @State private var timelineShowsToday = true
    @State private var timelineHeight: CGFloat = 100
    @State private var requestedTimelineHeight: CGFloat = 100
    @State private var timelineInsetHeight: CGFloat = 100
    @State private var timelineMonth = Calendar.current.dateInterval(of: .month, for: Date())!.start
    @State private var timelineUsesYearHeading = false
    @State private var eventSheetScrollRequest: EventSheetScrollRequest?
    @State private var timelineScrollRequest: EventSheetScrollRequest?
    @State private var scrollSynchronization = EventScrollSynchronization()
    @State private var scrollToTodayRequest: UUID?
    @State private var showingSettings = false
    @State private var windowFrame: CGRect = .zero
    @State private var floatingControlsSpan: ClosedRange<CGFloat> = 0...0
    /// The side where iPhone Duo places bars vertically, or nil while bars are
    /// horizontal. Filter and Add then move into that bar below Settings.
    @State private var toolbarVerticalEdge: HorizontalEdge?
    /// Locates Add in the vertical bar, so the composer can grow out of it.
    @State private var barAddButtonProbe = WindowFrameProbe()
    /// Where the composer grows from and shrinks back into, in window
    /// coordinates, while Add sits in the vertical bar.
    @State private var composerMorphSource: CGRect?
    /// The vertical fold of iPhone Duo's inner display opened like a book, in
    /// global coordinates, or nil. The month grid and the list then sit on
    /// either side of it.
    @State private var foldDivision: CGRect?
    @State private var contentFrame: CGRect = .zero
    @State private var monthGridScrollRequest: EventSheetScrollRequest?
    /// The months column's share of the content width after dragging its edge,
    /// or 0 to keep the edge at the fold.
    @AppStorage("monthColumnFraction", store: AppPreferences.shared) private var monthColumnFraction = 0.0
    @State private var monthColumnDragStart: CGFloat?
    /// The months were scrolled by hand, so the list follows the top month.
    @State private var monthGridDrivesList = false
    // Environment objects and properties
    @EnvironmentObject var appData: AppData
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale

    @FocusState private var isQuickEntryFocused: Bool

    private var timelineTitle: String {
        TimelineHeading.text(first: timelineMonth, last: timelineMonth,
                             yearOnly: timelineUsesYearHeading && !showsMonthGrid)
    }

    private var compactTimelineTitle: String {
        if timelineUsesYearHeading && !showsMonthGrid { return timelineTitle }
        return Calendar.current.isDate(timelineMonth, equalTo: Date(), toGranularity: .year)
            ? timelineMonth.formatted(.dateTime.month(.abbreviated))
            : timelineMonth.formatted(.dateTime.month(.abbreviated).year())
    }

    private var simplifiedCategories: [(name: String, color: Color)] {
        return appData.categories.map { category in
            (name: category.name, color: category.color)
        }
    }

    private var foldColumns: FoldColumns? {
        FoldColumns(content: contentFrame, division: foldDivision)
    }

    /// iPhone Duo's inner display in landscape shows a month grid on one side
    /// of the fold and the event list on the other, in place of the timeline.
    private var showsMonthGrid: Bool { foldColumns != nil }

    private var eventListBackground: Color {
        Color(uiColor: .systemBackground)
    }

    private var timelineBackground: Color {
        Color(uiColor: TimelineAppearance.background)
    }

    var body: some View {
        // NavigationView turns into a sidebar with an empty detail column in
        // regular widths, such as the open inner display of iPhone Duo or a large
        // iPhone in landscape. A stack keeps one screen at every size.
        NavigationStack {
            ZStack(alignment: .bottom) {
                mainContent
                    // Keep the list underneath the keyboard throughout its
                    // animation; only the floating composer moves above it.
                    // The month grid stays above the Home indicator, so its
                    // column extends the list itself to the bottom edge.
                    .ignoresSafeArea(showsMonthGrid ? .keyboard : .all, edges: .bottom)
                if showingQuickEntry {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: dismissQuickEntry)
                        .accessibilityLabel("Dismiss event entry")
                        .accessibilityIdentifier("dismissQuickEntry")
                        .accessibilityAddTraits(.isButton)
                }
                floatingControls
                    .onGeometryChange(for: ClosedRange<CGFloat>.self) { proxy in
                        let frame = proxy.frame(in: .global)
                        return frame.minX...frame.maxX
                    } action: { span in
                        floatingControlsSpan = span
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .background {
                eventListBackground
                    .ignoresSafeArea()
                    // Measure the whole window, including bars and the camera
                    // area, so the composer can stay clear of its center.
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .global)
                    } action: { frame in
                        windowFrame = frame
                    }
                    .modifier(FoldDivisionReader(division: $foldDivision))
            }
            .modifier(ToolbarVerticalEdgeReader(edge: $toolbarVerticalEdge))
        }
        .sheet(item: $selectedEvent) { event in
            EditEventView(events: $appData.events, selectedEvent: $selectedEvent,
                          showEditSheet: editSheetPresented, saveEvents: appData.saveEvents)
                .id(event.id)
        }
        .tint(categoryTint)
    }

    private var floatingControls: some View {
        ZStack(alignment: .bottomTrailing) {
            if !showingQuickEntry && toolbarVerticalEdge == nil {
                filterMenu
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
            // Keep the filter outside the morphing glass container. The plus
            // and composer share one surface: the plus at the trailing edge,
            // the composer centered on the window. With a vertical bar, the
            // plus lives in the bar and the composer grows out of it.
            if showingQuickEntry || toolbarVerticalEdge == nil {
                let shift = showingQuickEntry ? composerCenterShift : 0
                composerControls
                    .frame(maxWidth: .infinity, alignment: showingQuickEntry ? .center : .trailing)
                    .padding(.leading, max(0, shift * 2))
                    .padding(.trailing, max(0, -shift * 2))
                    .transition(composerBarTransition)
            }
        }
        // Span the full width even while empty, so the composer's width and
        // centering are measured before it first appears.
        .frame(maxWidth: .infinity)
    }

    /// Grows the composer out of Add in the vertical bar and back into it.
    private var composerBarTransition: AnyTransition {
        guard let source = composerMorphSource, !reduceMotion else { return .opacity }
        return .composerMorph(from: source, tint: categoryTint)
    }

    @ViewBuilder
    private var composerControls: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 16) {
                composerControlContent
            }
        } else {
            composerControlContent
        }
    }

    private var composerControlContent: some View {
        ZStack(alignment: .bottomTrailing) {
            if showingQuickEntry {
                QuickAddEventField(
                    text: $quickEventInput, isFocused: $isQuickEntryFocused,
                    overrides: $quickEventOverrides, draft: quickEventDraft,
                    categories: simplifiedCategories, onSubmit: submitQuickEntry,
                    validationMessage: attemptedQuickSubmit ? quickEventDraft.scheduleReviewMessage ?? quickEventDraft.dateOptions.validationMessage : nil,
                    onDismiss: dismissQuickEntry
                )
                .frame(maxWidth: composerMaxWidth)
                .disabled(appData.storageError != nil)
                .simultaneousGesture(quickEntryDismissGesture)
                .transition(.opacity)
                .task { isQuickEntryFocused = true }
            } else {
                Button(action: showQuickEntry) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .frame(width: 56, height: 56)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(appData.storageError != nil)
                .foregroundStyle(.white)
                .transition(.opacity)
                .accessibilityLabel("Add event")
                .accessibilityIdentifier("quickAddButton")
            }
        }
        // Resize one surface in place. Replacing two matched glass surfaces
        // during a drag and keyboard dismissal can replay the outgoing view
        // from its old, un-dragged position.
        .modifier(FloatingControlSurface(
            id: "composer", namespace: composerTransition,
            isInteractive: !showingQuickEntry,
            tint: showingQuickEntry ? nil : categoryTint
        ))
        .offset(y: quickEntryDragOffset)
    }

    private var quickEntryDismissGesture: some Gesture {
        // Measure outside the translated composer so moving the view cannot
        // change the gesture's origin and feed back into the next drag update.
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
                guard value.translation.height > abs(value.translation.width) else { return }
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    quickEntryDragOffset = max(0, value.translation.height)
                }
            }
            .onEnded { value in
                let isDownward = value.translation.height > abs(value.translation.width)
                if isDownward && (value.translation.height > 40 || value.predictedEndTranslation.height > 100) {
                    dismissQuickEntry()
                } else {
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { quickEntryDragOffset = 0 }
                }
            }
    }

    private var mainContent: some View {
        let days = eventListDays

        return GeometryReader { geometry in
            let columns = foldColumns
            let headerHeight = min(timelineHeight, max(80, geometry.size.height * 0.5))
            let insetHeight = columns == nil ? min(timelineInsetHeight, max(80, geometry.size.height * 0.5)) : 0
            let proposedHeight = min(requestedTimelineHeight, max(80, geometry.size.height * 0.5))
            // One list serves both layouts, so it keeps its scroll position when
            // the month grid appears beside it or gives way to the timeline.
            HStack(spacing: 0) {
                if let columns {
                    let width = monthColumnWidth(columns)
                    monthGrid(width: width)
                    monthColumnEdge(width: width, columns: columns)
                        .frame(width: monthColumnLane(columns))
                        .zIndex(1)
                }
                eventList(days: days, insetHeight: insetHeight,
                          headerOffset: columns == nil ? headerHeight - insetHeight : 0,
                          proposedHeaderOffset: columns == nil ? proposedHeight - insetHeight : 0,
                          // The months follow the first day fully in view.
                          visibilityInset: columns == nil ? 0 : eventListTopMargin) {
                    if columns == nil {
                        EventTimelineView(
                            events: timelineEvents, tint: categoryTint, highlightedEventID: highlightedEventID,
                            scrollToTodayRequest: scrollToTodayRequest, scrollToDateRequest: timelineScrollRequest,
                            animateScrolling: !reduceMotion,
                            onHeightChange: updateTimelineHeight,
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
                        // Keep the list usable on crowded dates; overflowing event
                        // lanes can scroll inside the timeline.
                        .frame(height: headerHeight)
                        // The band is background content: it reaches under side bars and
                        // beside the camera, while dates and markers stay in the safe area.
                        .background(timelineBackground.ignoresSafeArea(edges: .horizontal))
                        .overlay(alignment: .bottom) {
                            Divider().ignoresSafeArea(edges: .horizontal).allowsHitTesting(false)
                        }
                    }
                }
                .background(eventListBackground)
                // Beside the month grid, the list reaches under the Home
                // indicator while the grid stays above it.
                .frame(height: columns == nil ? geometry.size.height : nil, alignment: .top)
                .clipShape(VerticalClip())
                .ignoresSafeArea(.container, edges: .bottom)
            }
            .transaction { if reduceMotion { $0.animation = nil } }
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            contentFrame = frame
        }
        .safeAreaInset(edge: .top) {
            if let error = appData.storageError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error).font(.footnote)
                    NavigationLink("Data Recovery") { SettingsView() }
                }.padding().frame(maxWidth: .infinity).background(.regularMaterial)
            }
        }
        // The month grid shows its own month heading. An empty principal item
        // would show this title in the bar instead.
        .navigationTitle(showsMonthGrid ? "" : timelineTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(timelineBackground, for: .navigationBar)
        // Beside the month grid, each column's color reaches the top edge.
        .toolbarBackground(showsMonthGrid ? .hidden : .visible, for: .navigationBar)
        .toolbarColorScheme(colorScheme, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if !showsMonthGrid {
                    ViewThatFits(in: .horizontal) {
                        Text(timelineTitle).fixedSize()
                        Text(compactTimelineTitle).fixedSize()
                    }
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: dismissQuickEntry)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("appTitle")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                settingsButton
            }
            ToolbarItem(placement: .topBarTrailing) {
                if showsMonthGrid ? !monthGridShowsToday : !timelineShowsToday {
                    todayButton
                }
            }
            // On iPhone Duo, the system stacks top and bottom bar items in one
            // vertical bar. Bottom items follow Settings and Today after a gap.
            if toolbarVerticalEdge != nil {
                ToolbarItem(placement: .bottomBar) {
                    barFilterMenu
                }
                // Vertical bars need iOS 27.1. Add leaves the bar while the
                // composer, which grows out of it, is open. It comes last, so
                // the filter keeps its place.
                if #available(iOS 26.4, *) {
                    ToolbarItem(placement: .bottomBar) {
                        barAddButton
                    }
                    .hidden(showingQuickEntry)
                }
            }
        }
        .navigationDestination(isPresented: $showingSettings) { SettingsView() }
        .onAppear {
            appData.loadEvents()
            appData.loadCategories()
            refreshListWindow()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshListWindow() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshListWindow()
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
        .onChange(of: showsMonthGrid) { _, showsGrid in
            guard let date = eventListPosition else { return }
            if showsGrid {
                if let month = Calendar.current.dateInterval(of: .month, for: date)?.start { timelineMonth = month }
                monthGridScrollRequest = EventSheetScrollRequest(date: date)
            } else {
                // The timeline starts over at today. Move it to the list's
                // date without letting it move the list.
                scrollSynchronization.begin(.sheet)
                timelineScrollRequest = EventSheetScrollRequest(date: date)
            }
        }
        .onChange(of: selectedCategoryFilter) {
            eventListWindow = EventListWindow()
            beginTimelineInteraction()
            dismissQuickEntry()
            highlightRequestID = nil
            highlightedEventID = nil
            if let date = EventListDay.initialDate(in: eventListDays) {
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

    /// Space above the first row. Naked rows have no inset card background to
    /// hide behind. Keep their scroll inset within the 10-point interday gap so
    /// returning to Today fully clears the preceding row.
    private var eventListTopMargin: CGFloat { appData.eventStyle == "naked" ? 10 : 16 }

    /// `visibilityInset` ignores rows that only show in that much space at the
    /// top, such as the end of the previous group above the first one.
    private func eventList<Header: View>(days: [EventListDay], insetHeight: CGFloat, headerOffset: CGFloat,
                                      proposedHeaderOffset: CGFloat, visibilityInset: CGFloat = 0,
                                      @ViewBuilder header: @escaping () -> Header) -> some View {
        VStack(spacing: 0) {
            if days.isEmpty && !hasMoreListEvents {
                emptyStateView(selectedCategoryFilter: selectedCategoryFilter)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        Color.clear.frame(height: insetHeight).allowsHitTesting(false)
                    }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            if days.isEmpty {
                                Text("No events in the next \(eventListWindow.dayCount) days")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                            ForEach(days) { day in
                                VStack(alignment: .leading, spacing: 0) {
                                    if day.startsMonth {
                                        Text(day.date.formatted(.dateTime.month(.wide).year()))
                                            .font(.headline)
                                            .padding(.top, 16)
                                            .padding(.bottom, 10)
                                            .accessibilityAddTraits(.isHeader)
                                    }
                                    eventRowView(key: day.date.relativeDate(), events: day.events, pinnedTop: headerOffset)
                                }
                                    .padding(.horizontal)
                                    .background {
                                        GeometryReader { geometry in
                                            let frame = geometry.frame(in: .named("eventList"))
                                            Color.clear.preference(key: EventListTopDatesKey.self,
                                                value: EventListTopDates(
                                                    visible: frame.maxY > headerOffset + visibilityInset + 1 ? day.date : nil,
                                                    afterResize: frame.maxY > proposedHeaderOffset + visibilityInset + 1
                                                        ? day.date : nil,
                                                    requestedHeight: requestedTimelineHeight))
                                        }
                                    }
                                    // The gap between days must not keep an offscreen
                                    // event selected when the next card is visible.
                                    .padding(.bottom, 10)
                                    .id(day.date)
                            }
                            if hasMoreListEvents {
                                Button("Show more") {
                                    // Appending a page must keep the current row
                                    // and scroll ownership, without reloading storage.
                                    var expanded = eventListWindow
                                    expanded.loadMore()
                                    if appData.extendRecurrences(before: expanded.end) {
                                        eventListWindow = expanded
                                    }
                                }
                                .disabled(appData.storageError != nil)
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding(.vertical, 10)
                                .accessibilityHint("Load the next 365 days of events")
                                .accessibilityIdentifier("showMoreEvents")
                            }
                            Spacer(minLength: 100)
                        }
                    }
                    .contentMargins(.top, eventListTopMargin, for: .scrollContent)
                    .accessibilityIdentifier("eventList")
                    .coordinateSpace(name: "eventList")
                    .scrollDismissesKeyboard(.interactively)
                    .modifier(EventSheetScrollTracking(onInteraction: beginSheetInteraction))
                    // Keep the native drag baseline stable. The visible timeline
                    // resizes independently in the overlay above this scroll view.
                    .safeAreaInset(edge: .top, spacing: 0) {
                        Color.clear.frame(height: insetHeight).allowsHitTesting(false)
                    }
                    .onPreferenceChange(EventListTopDatesKey.self) { dates in
                        if let date = dates.visible, date != eventListPosition {
                            eventListPosition = date
                            synchronizeTimeline(to: date)
                        }
                        if dates.requestedHeight == requestedTimelineHeight, dates.visible == dates.afterResize {
                            applyTimelineHeight(requestedTimelineHeight)
                        }
                    }
                    .onChange(of: eventSheetScrollRequest) { _, request in
                        guard let request, scrollSynchronization.source == .timeline else { return }
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
        .overlay(alignment: .top, content: header)
    }

    private func monthGrid(width: CGFloat) -> some View {
        MonthGridView(
            months: monthGridMonths, initialMonth: timelineMonth, events: timelineEvents,
            scrollRequest: monthGridScrollRequest,
            bottomInset: toolbarVerticalEdge == nil ? 80 : 16,
            onInteraction: beginMonthGridScroll, onTopMonthChange: monthGridTopChanged,
            onReachEnd: loadMoreMonths, onTapDate: showGridDate
        )
        .frame(width: width)
        .frame(maxHeight: .infinity)
        // The grid shares the timeline's band color, reaching under side bars
        // and beside the camera.
        .background(timelineBackground.ignoresSafeArea(edges: [.top, .bottom, .leading]))
        .overlay(alignment: .trailing) {
            Color(uiColor: .separator)
                .frame(width: 1 / displayScale)
                .ignoresSafeArea(edges: .vertical)
                .allowsHitTesting(false)
        }
    }

    /// The months column's width: at the fold, or where its edge was dragged.
    private func monthColumnWidth(_ columns: FoldColumns) -> CGFloat {
        guard monthColumnFraction > 0 else { return columns.leading }
        return MonthColumnResize.width(proposed: monthColumnFraction * contentFrame.width,
                                       contentWidth: contentFrame.width - monthColumnLane(columns),
                                       fold: columns.leading)
    }

    /// The space between the months and the list that holds the resize handle:
    /// the hinge at the fold, and the same wherever the edge is dragged, so the
    /// handle keeps the same room around it.
    private func monthColumnLane(_ columns: FoldColumns) -> CGFloat {
        max(columns.gap, 16)
    }

    /// A handle centered in the lane between the months and the list. Drag it
    /// to resize the months; near the fold it snaps back.
    private func monthColumnEdge(width: CGFloat, columns: FoldColumns) -> some View {
        Color.clear
            .overlay {
                Capsule()
                    .fill(Color(uiColor: .tertiaryLabel))
                    .frame(width: 4, height: 36)
                    .frame(width: 24)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 2, coordinateSpace: .global)
                            .onChanged { value in
                                let start = monthColumnDragStart ?? width
                                if monthColumnDragStart == nil { monthColumnDragStart = width }
                                resizeMonthColumn(to: start + value.translation.width, columns: columns)
                            }
                            .onEnded { _ in monthColumnDragStart = nil }
                    )
                    .accessibilityElement()
                    .accessibilityLabel("Months width")
                    .accessibilityValue("\(Int(width.rounded())) points")
                    .accessibilityHint("Swipe up or down to resize the months beside the event list")
                    .accessibilityAdjustableAction { direction in
                        let step: CGFloat = direction == .increment ? 40 : -40
                        resizeMonthColumn(to: width + step, columns: columns)
                    }
                    .accessibilityIdentifier("monthColumnEdge")
            }
    }

    private func resizeMonthColumn(to proposed: CGFloat, columns: FoldColumns) {
        let contentWidth = contentFrame.width
        guard contentWidth > 0 else { return }
        let width = MonthColumnResize.width(proposed: proposed, contentWidth: contentWidth - monthColumnLane(columns),
                                            fold: columns.leading)
        let fraction = width == columns.leading ? 0 : Double(width / contentWidth)
        guard fraction != monthColumnFraction else { return }
        // A tick when the edge settles on the fold.
        if fraction == 0 { UISelectionFeedbackGenerator().selectionChanged() }
        monthColumnFraction = fraction
    }

    private var monthGridShowsToday: Bool {
        Calendar.current.isDate(timelineMonth, equalTo: Date(), toGranularity: .month)
    }

    /// Every month from the earliest listed day, or this month, through the
    /// end of the loaded list.
    private var monthGridMonths: [Date] {
        let calendar = Calendar.current
        let today = Date()
        let first = min(eventListDays.first?.date ?? today, today)
        let last = calendar.date(byAdding: .day, value: -1, to: eventListWindow.end) ?? today
        return MonthGrid.months(from: first, through: last, calendar: calendar)
    }

    private func beginMonthGridScroll() {
        guard !monthGridDrivesList || scrollSynchronization.source != .timeline else { return }
        beginTimelineInteraction()
        monthGridDrivesList = true
    }

    private func monthGridTopChanged(_ month: Date) {
        if timelineMonth != month { timelineMonth = month }
        // Only scrolling the months by hand moves the list. Following the list
        // or returning to today scrolls the months without moving it back.
        guard monthGridDrivesList, scrollSynchronization.source == .timeline else { return }
        loadListEvents(showing: month)
        scrollList(toFirstDayOnOrAfter: month)
    }

    /// Adds a year of months when the last one comes into view, as Show More
    /// does for the list.
    private func loadMoreMonths() {
        guard hasMoreListEvents else { return }
        var expanded = eventListWindow
        expanded.loadMore()
        if appData.extendRecurrences(before: expanded.end) {
            eventListWindow = expanded
        }
    }

    private func showGridDate(_ date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        beginTimelineInteraction()
        dismissQuickEntry()
        monthGridDrivesList = false
        loadListEvents(showing: day)
        scrollList(toFirstDayOnOrAfter: day)
    }

    /// Shows the first listed day on or after `date`, or the last one when
    /// nothing follows it.
    private func scrollList(toFirstDayOnOrAfter date: Date) {
        let days = eventListDays
        guard let target = days.first(where: { $0.date >= date })?.date ?? days.last?.date else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            eventSheetScrollRequest = EventSheetScrollRequest(date: target, animated: true)
        }
    }

    /// Pages the list, and the occurrences of repeating events, through the
    /// last day the grid shows for `date`'s month.
    private func loadListEvents(showing date: Date) {
        guard let lastDay = MonthGrid.weeks(for: date).last?.last, !eventListWindow.contains(lastDay) else { return }
        var expanded = eventListWindow
        expanded.include(lastDay)
        if appData.extendRecurrences(before: expanded.end) {
            eventListWindow = expanded
        }
    }

    private func beginTimelineInteraction() {
        scrollSynchronization.begin(.timeline)
        timelineScrollRequest = nil
        updateTimelineHeight(requestedTimelineHeight)
    }

    private func updateTimelineHeight(_ height: CGFloat) {
        requestedTimelineHeight = height
        if scrollSynchronization.source == .timeline || height >= timelineHeight || eventListDays.isEmpty {
            applyTimelineHeight(height)
        }
        // While browsing the list, the row preferences approve a smaller
        // overlay only after it no longer reveals an earlier event group.
    }

    private func applyTimelineHeight(_ height: CGFloat) {
        let updatesInset = scrollSynchronization.source == .timeline
        guard timelineHeight != height || (updatesInset && timelineInsetHeight != height) else { return }
        withAnimation(reduceMotion ? nil : .interactiveSpring(response: 0.2, dampingFraction: 1, blendDuration: 0)) {
            timelineHeight = height
            if updatesInset { timelineInsetHeight = height }
        }
    }

    private func beginSheetInteraction() {
        guard scrollSynchronization.source != .sheet else { return }
        scrollSynchronization.begin(.sheet)
        monthGridDrivesList = false
        eventSheetScrollRequest = nil
        if let date = eventListPosition { synchronizeTimeline(to: date) }
    }

    private func synchronizeTimeline(to date: Date) {
        guard scrollSynchronization.sheetMoved(to: date) else { return }
        timelineScrollRequest = EventSheetScrollRequest(date: date, animated: true)
        // The months follow the list, bringing the month at its top to the top.
        if showsMonthGrid {
            monthGridScrollRequest = EventSheetScrollRequest(date: date, animated: !reduceMotion)
        }
    }

    // Bar items carry both a title and a symbol. On iPhone Duo the system can
    // move them into a vertical bar, which shows symbols, or the overflow
    // menu, which shows titles. Other iPhones keep showing the symbol.
    private var settingsButton: some View {
        Button {
            dismissQuickEntry()
            showingSettings = true
        } label: {
            Label("Settings", systemImage: "gearshape.fill")
                .imageScale(.large)
        }
        .foregroundStyle(.primary)
    }

    private var todayButton: some View {
        Button(action: scrollToToday) {
            Label("Today", systemImage: "calendar.day.timeline.left")
                .imageScale(.large)
        }
        .foregroundStyle(.primary)
        .accessibilityHint("Return to today in the timeline and event list")
        .accessibilityIdentifier("scrollToToday")
    }

    private func scrollToToday() {
        beginTimelineInteraction()
        dismissQuickEntry()
        highlightedEventID = nil
        highlightRequestID = nil
        monthGridDrivesList = false
        scrollToTodayRequest = UUID()
        if showsMonthGrid {
            monthGridScrollRequest = EventSheetScrollRequest(date: Date(), animated: !reduceMotion)
        }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            if let date = EventListDay.initialDate(in: eventListDays) {
                eventSheetScrollRequest = EventSheetScrollRequest(date: date)
            }
        }
    }

    @ViewBuilder private var filterMenuItems: some View {
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
    }

    private var barFilterMenu: some View {
        Menu {
            filterMenuItems
        } label: {
            Label("Filter", systemImage: "line.horizontal.3.decrease")
        }
        .accessibilityLabel("Filter events")
        .accessibilityValue(selectedCategoryFilter ?? "All Events")
        .accessibilityIdentifier("eventFilter")
    }

    private var barAddButton: some View {
        Button(action: showQuickEntry) {
            Label("Add Event", systemImage: "plus")
        }
        .buttonStyle(.borderedProminent)
        .background(WindowFrameProbeView(probe: barAddButtonProbe))
        .disabled(appData.storageError != nil)
        .accessibilityIdentifier("quickAddButton")
    }

    private var filterMenu: some View {
        Menu {
            filterMenuItems
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
        dismissQuickEntry()
    }

    private func showQuickEntry() {
        composerMorphSource = toolbarVerticalEdge == nil ? nil : barAddButtonProbe.frame
        withAnimation(composerAnimation) { showingQuickEntry = true }
    }

    private func dismissQuickEntry() {
        isQuickEntryFocused = false
        // Shrink back to where Add returns. It is out of the bar while the
        // composer is open, so keep its last frame unless bars turned horizontal.
        if showingQuickEntry, toolbarVerticalEdge == nil { composerMorphSource = nil }
        withAnimation(composerAnimation) {
            showingQuickEntry = false
            quickEntryDragOffset = 0
        }
    }

    private var composerAnimation: Animation? {
        if reduceMotion { return nil }
        // Growing out of the bar covers more ground than the floating plus.
        return composerMorphSource == nil ? .easeInOut(duration: 0.2) : .snappy(duration: 0.32)
    }

    private var quickEventDraft: NewEventDraft {
        quickEventOverrides.resolve(quickEventInput, category: selectedCategoryFilter, appData: appData)
    }

    private var composerMaxWidth: CGFloat {
        FloatingComposerLayout.maxWidth(controls: floatingControlsSpan, window: windowFrame,
                                        isRegularWidth: horizontalSizeClass == .regular)
    }

    private var composerCenterShift: CGFloat {
        FloatingComposerLayout.centerShift(composerWidth: composerMaxWidth, controls: floatingControlsSpan,
                                           window: windowFrame)
    }

    private var timelineEvents: [Event] {
        appData.events.filter { selectedCategoryFilter == nil || $0.category == selectedCategoryFilter }
    }

    private var eventListDays: [EventListDay] {
        let end = eventListWindow.end
        return EventListDay.group(events: timelineEvents.filter { $0.date < end })
    }

    private func refreshListWindow() {
        var refreshed = eventListWindow
        if refreshed.refresh(), appData.extendRecurrences(before: refreshed.end) {
            eventListWindow = refreshed
        }
    }

    private var hasMoreListEvents: Bool {
        Recurrence.hasEvents(onOrAfter: eventListWindow.end, in: appData.events, category: selectedCategoryFilter)
    }

    private func selectTimelineEvent(_ event: Event) {
        beginTimelineInteraction()
        eventListWindow.include(EventListDay.displayDate(for: event))
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
    func eventRowView(key: String, events: [Event], pinnedTop: CGFloat = 0) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top))
        return layout {
            if dynamicTypeSize.isAccessibilitySize {
                relativeDayLabel(key)
                    .padding(.top, 8)
            } else {
                GeometryReader { dayGeometry in
                    relativeDayLabel(key)
                        .padding(.vertical, appData.eventStyle == "naked" ? 6 : 14)
                        .visualEffect { content, labelGeometry in
                            // Keep the day beside its events, then let the next day
                            // push it away at the bottom of this group.
                            content.offset(y: min(max(0, pinnedTop - labelGeometry.frame(in: .named("eventList")).minY),
                                                  max(0, dayGeometry.size.height - labelGeometry.size.height)))
                        }
                }
                .frame(width: 100)
            }
            VStack(alignment: .leading) {
                ForEach(events, id: \.id) { event in
                    EventRow(
                        event: event,
                        isHighlighted: highlightedEventID == event.id,
                        selectedEvent: $selectedEvent
                    )
                    .accessibilityAddTraits(highlightedEventID == event.id ? .isSelected : [])
                    .id(event.id)
                }
            }
        }
    }

    private func relativeDayLabel(_ key: String) -> some View {
        Text(key.uppercased())
            .font(.system(.caption, design: .monospaced, weight: .medium))
            .foregroundStyle(EventRowColors.secondaryLabel(dark: colorScheme == .dark))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("relativeEventDate")
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

/// Reports the edge where the system places vertical bars, or nil wherever bars
/// stay horizontal, including every iPhone other than iPhone Duo.
/// `toolbarVerticalEdge` needs the iOS 27.1 SDK in Xcode 27.1 (Swift 6.4). With
/// older Xcode versions the edge stays nil and the controls keep floating.
#if compiler(>=6.4)
private struct ToolbarVerticalEdgeReader: ViewModifier {
    @Binding var edge: HorizontalEdge?

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.modifier(VerticalEdgeObserver(edge: $edge))
        } else {
            content
        }
    }
}

@available(iOS 27.1, *)
private struct VerticalEdgeObserver: ViewModifier {
    @Binding var edge: HorizontalEdge?
    @Environment(\.toolbarVerticalEdge) private var verticalEdge

    func body(content: Content) -> some View {
        content.onChange(of: verticalEdge, initial: true) { _, newEdge in
            edge = newEdge
        }
    }
}
#else
private struct ToolbarVerticalEdgeReader: ViewModifier {
    @Binding var edge: HorizontalEdge?

    func body(content: Content) -> some View { content }
}
#endif

/// Reports iPhone Duo's fold while the inner display is open like a book, as a
/// vertical division in global coordinates, including while the display is
/// flat. Elsewhere, including with Xcode versions before 27.1, it stays nil.
#if compiler(>=6.4)
private struct FoldDivisionReader: ViewModifier {
    @Binding var division: CGRect?

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onGeometryChange(for: CGRect?.self) { proxy in
                let origin = proxy.frame(in: .global).origin
                return proxy.reservedRegions(kind: .division, options: .includeInactive)
                    .map(\.frame)
                    .first { $0.height > $0.width }
                    .map { $0.offsetBy(dx: origin.x, dy: origin.y) }
            } action: { newDivision in
                division = newDivision
            }
        } else {
            content
        }
    }
}
#else
private struct FoldDivisionReader: ViewModifier {
    @Binding var division: CGRect?

    func body(content: Content) -> some View { content }
}
#endif

/// Clips above and below a frame only, so background content can still extend
/// sideways into the safe area beside vertical bars and the camera.
private struct VerticalClip: Shape {
    func path(in rect: CGRect) -> Path {
        Path(rect.insetBy(dx: -rect.width, dy: 0))
    }
}
