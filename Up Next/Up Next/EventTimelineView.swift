import SwiftUI
import UIKit

/// A fixed-size canvas that is rebased as the user scrolls. Day offsets and the
/// fractional scroll position survive rebasing, so neither end is reachable.
struct TimelineScrollWindow {
    static let dayWidth: CGFloat = 44
    static let dayCount = 181
    static let centerDay = dayCount / 2
    var firstDay = -centerDay
    var pointsPerDay: CGFloat = dayWidth

    init(pointsPerDay: CGFloat = dayWidth) {
        self.pointsPerDay = pointsPerDay
        firstDay = -centerIndex
    }

    // Keep the canvas bounded in pixels at every scale, with enough room to pan
    // through months without ever reaching a physical edge.
    var canvasDayCount: Int { max(Self.dayCount, Int(ceil(CGFloat(Self.dayCount) * Self.dayWidth / pointsPerDay))) }
    var centerIndex: Int { canvasDayCount / 2 }
    var edgeBuffer: Int { Int(ceil(30 * Self.dayWidth / pointsPerDay)) }
    var contentWidth: CGFloat { CGFloat(canvasDayCount) * pointsPerDay }
    var initialOffset: CGFloat { CGFloat(centerIndex) * pointsPerDay }

    mutating func recenter(offset: CGFloat) -> CGFloat {
        let index = Int(floor(offset / pointsPerDay))
        guard index < edgeBuffer || index > canvasDayCount - edgeBuffer else { return offset }
        let shift = index - centerIndex
        firstDay += shift
        return offset - CGFloat(shift) * pointsPerDay
    }

    func visibleDays(offset: CGFloat, width: CGFloat) -> ClosedRange<Int> {
        let first = firstDay + Int(floor(offset / pointsPerDay))
        let last = firstDay + Int(ceil((offset + max(1, width)) / pointsPerDay)) - 1
        return first...max(first, last)
    }
}

enum TimelineZoomLevel: String, CaseIterable {
    case days = "Days", weeks = "Weeks", months = "Months"

    var pointsPerDay: CGFloat {
        switch self {
        case .days: return TimelineScrollWindow.dayWidth
        case .weeks: return TimelineScrollWindow.dayWidth / 7
        case .months: return TimelineScrollWindow.dayWidth / 30
        }
    }
}

struct TimelineAxisWeights {
    let days: CGFloat
    let weeks: CGFloat
    let months: CGFloat

    init(pointsPerDay: CGFloat) {
        days = min(1, max(0, (pointsPerDay - 22) / 18))
        months = 1 - min(1, max(0, (pointsPerDay - 2.8) / (TimelineZoomLevel.weeks.pointsPerDay - 2.8)))
        weeks = max(0, 1 - days - months)
    }

    var level: TimelineZoomLevel { days >= 0.5 ? .days : (months >= 0.5 ? .months : .weeks) }
}

struct TimelineAxisPeriod {
    let startDay: Int
    let endDay: Int // Exclusive; calendar months retain their real lengths.
    let title: String
    let subtitle: String
    let accessibilityLabel: String

    static func make(level: TimelineZoomLevel, visibleDays: ClosedRange<Int>, anchor: Date,
                     calendar: Calendar = .current) -> [TimelineAxisPeriod] {
        guard level != .days,
              let firstDate = calendar.date(byAdding: .day, value: visibleDays.lowerBound, to: anchor),
              let firstPeriod = calendar.dateInterval(of: level == .weeks ? .weekOfYear : .month, for: firstDate) else { return [] }
        var start = firstPeriod.start
        var periods: [TimelineAxisPeriod] = []
        while let interval = calendar.dateInterval(of: level == .weeks ? .weekOfYear : .month, for: start) {
            let startDay = calendar.dateComponents([.day], from: anchor, to: start).day ?? 0
            if startDay > visibleDays.upperBound { break }
            let endDay = calendar.dateComponents([.day], from: anchor, to: interval.end).day ?? startDay + 1
            let lastDate = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? start
            let title = start.formatted(.dateTime.month(.abbreviated))
            let subtitle = level == .weeks
                ? "\(calendar.component(.day, from: start))–\(calendar.component(.day, from: lastDate))"
                : start.formatted(.dateTime.year())
            periods.append(TimelineAxisPeriod(
                startDay: startDay, endDay: endDay, title: title, subtitle: subtitle,
                accessibilityLabel: level == .weeks
                    ? "Week of \(start.formatted(date: .complete, time: .omitted))"
                    : start.formatted(.dateTime.month(.wide).year())))
            guard interval.end > start else { break }
            start = interval.end
        }
        return periods
    }
}

enum TimelinePresentation: CaseIterable {
    case collapsed, compact, expanded
}

struct TimelinePanelHeights {
    let compact: CGFloat
    let expanded: CGFloat

    init(compact: CGFloat, expanded: CGFloat) {
        self.expanded = max(0, expanded)
        self.compact = min(max(0, compact), self.expanded)
    }

    func height(for presentation: TimelinePresentation) -> CGFloat {
        switch presentation {
        case .collapsed: return 0
        case .compact: return compact
        case .expanded: return expanded
        }
    }

    func nearest(to height: CGFloat) -> TimelinePresentation {
        if height < compact / 2 { return .collapsed }
        if height > (compact + expanded) / 2 { return .expanded }
        return .compact
    }
}

struct EventTimelineView: View {
    var events: [Event]
    var tint: Color
    var highlightedEventID: UUID?
    var scrollToTodayRequest: UUID?
    var onTodayVisibilityChange: (Bool) -> Void
    var onSelectEvent: (Event) -> Void
    var onEditEvent: (Event) -> Void
    var maximumHeight: CGFloat
    @Binding var presentation: TimelinePresentation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var laneCount = 0
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.3, dampingFraction: 0.9)))
    private var handleDrag: TimelineHandleDrag?

    private let topPadding: CGFloat = 4
    private var heights: TimelinePanelHeights {
        TimelinePanelHeights(compact: TimelineLayout.height(for: laneCount) + topPadding,
                             expanded: maximumHeight)
    }
    private var visibleHeight: CGFloat { handleDrag?.height ?? heights.height(for: presentation) }
    private var isCollapsed: Bool { presentation == .collapsed }
    private var isExpanded: Bool { presentation == .expanded }

    var body: some View {
        VStack(spacing: 0) {
            TimelineScroller(
                events: events,
                tint: tint,
                highlightedEventID: highlightedEventID,
                scrollToTodayRequest: scrollToTodayRequest,
                animateScrolling: !reduceMotion,
                onTodayVisibilityChange: onTodayVisibilityChange,
                onSelectEvent: onSelectEvent,
                onEditEvent: onEditEvent,
                onLaneCountChange: { laneCount = $0 },
                onCollapse: { setPresentation($0 ? .collapsed : .compact) },
                isExpanded: isExpanded
            )
            .frame(height: max(0, max(heights.compact, visibleHeight) - topPadding))
            .padding(.top, topPadding)
            .frame(height: visibleHeight, alignment: .top)
            .clipped()
            .allowsHitTesting(!isCollapsed && handleDrag == nil)
            .accessibilityHidden(isCollapsed && handleDrag == nil)

            Button {
                setPresentation(isCollapsed ? .compact : (isExpanded ? .compact : .collapsed))
            } label: {
                Capsule()
                    .fill(.tertiary)
                    .frame(width: 28, height: 4)
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCollapsed ? "Show timeline" : (isExpanded ? "Reduce timeline" : "Hide timeline"))
            .accessibilityHint("Drag down to fill the screen with the timeline. Drag up to show the event list.")
            .accessibilityValue(isExpanded ? "Full timeline" : (isCollapsed ? "Collapsed" : "Compact"))
            .accessibilityAction(named: Text("Expand timeline")) { setPresentation(.expanded) }
            .accessibilityAction(named: Text("Show event list")) { setPresentation(.compact) }
            .accessibilityIdentifier("timelineResizeHandle")
            .highPriorityGesture(handleGesture)
        }
        .background(Color(uiColor: .systemBackground))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: laneCount)
        .transaction { transaction in
            // Resizing tracks the finger directly. Only release/tap transitions animate.
            if handleDrag != nil || reduceMotion { transaction.animation = nil }
        }
        .onChange(of: scrollToTodayRequest) {
            if isCollapsed { setPresentation(.compact) }
        }
    }

    private var handleGesture: some Gesture {
        // Global coordinates keep translation stable as the handle itself moves.
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .updating($handleDrag) { value, state, transaction in
                if state == nil {
                    guard abs(value.translation.height) > abs(value.translation.width) else { return }
                    state = TimelineHandleDrag(heights: heights, startHeight: heights.height(for: presentation))
                }
                state?.translation = value.translation.height
                transaction.animation = nil
            }
            .onEnded { value in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                // GestureState may already have reset when onEnded runs. The
                // settled presentation remains the drag's starting position.
                let stops = handleDrag?.heights ?? heights
                let startHeight = handleDrag?.startHeight ?? stops.height(for: presentation)
                setPresentation(stops.nearest(to: startHeight + value.predictedEndTranslation.height))
            }
    }

    private func setPresentation(_ presentation: TimelinePresentation) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.9)) {
            self.presentation = presentation
        }
    }
}

private struct TimelineHandleDrag {
    let heights: TimelinePanelHeights
    let startHeight: CGFloat
    var translation: CGFloat = 0

    var height: CGFloat { min(heights.expanded, max(0, startHeight + translation)) }
}

private struct TimelineScroller: UIViewRepresentable {
    var events: [Event]
    var tint: Color
    var highlightedEventID: UUID?
    var scrollToTodayRequest: UUID?
    var animateScrolling: Bool
    var onTodayVisibilityChange: (Bool) -> Void
    var onSelectEvent: (Event) -> Void
    var onEditEvent: (Event) -> Void
    var onLaneCountChange: (Int) -> Void
    var onCollapse: (Bool) -> Void
    var isExpanded: Bool

    final class Coordinator {
        var lastScrollToTodayRequest: UUID?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> TimelineContainerView {
        TimelineContainerView()
    }

    func updateUIView(_ container: TimelineContainerView, context: Context) {
        let scrollView = container.timeline
        container.tintColor = UIColor(tint)
        container.onSelectEvent = onSelectEvent
        container.onEditEvent = onEditEvent
        scrollView.onLaneCountChange = onLaneCountChange
        scrollView.onCollapse = onCollapse
        scrollView.onTodayVisibilityChange = onTodayVisibilityChange
        container.update(events: events, expanded: isExpanded, highlightedEventID: highlightedEventID)
        if let scrollToTodayRequest, context.coordinator.lastScrollToTodayRequest != scrollToTodayRequest {
            context.coordinator.lastScrollToTodayRequest = scrollToTodayRequest
            scrollView.scrollToToday(animated: animateScrolling)
        }
    }
}

/// Only visible days and events have views. UIScrollView supplies native
/// momentum and gesture handling while the calendar window stays bounded.
final class TimelineScrollView: UIScrollView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    var onSelectEvent: ((Event) -> Void)?
    var onLaneCountChange: ((Int) -> Void)?
    var onCollapse: ((Bool) -> Void)?
    var onTodayVisibilityChange: ((Bool) -> Void)?
    var onScrollPositionChange: ((CGFloat) -> Void)?
    var onBeginDragging: (() -> Void)?
    var highlightedEventID: UUID? {
        didSet {
            guard highlightedEventID != oldValue else { return }
            for (id, button) in eventButtons { button.isSelected = id == highlightedEventID }
        }
    }
    private let selectionFeedback = UISelectionFeedbackGenerator()

    let anchor = Calendar.current.startOfDay(for: Date())
    private var scrollWindow = TimelineScrollWindow()
    private var events: [Event] = []
    private var indexedEvents: [TimelineEventPlacement] = []
    private var dayViews: [Int: TimelineDayView] = [:]
    private var periodViews: [String: TimelinePeriodView] = [:]
    private let todayLine = UIView()
    private let zoomGesture = UIPinchGestureRecognizer()
    private var pinch: (width: CGFloat, day: CGFloat, cardDay: CGFloat)?
    private var cardReferenceX: CGFloat = 0
    private var changingScale = false
    var pointsPerDay: CGFloat { scrollWindow.pointsPerDay }
    var zoomLevel: TimelineZoomLevel { TimelineAxisWeights(pointsPerDay: pointsPerDay).level }
    var cardDayPosition: CGFloat { dayPosition + cardReferenceX / pointsPerDay }
    private var eventButtons: [UUID: TimelineEventButton] = [:]
    private var renderedDays: ClosedRange<Int>?
    private var reportedLaneCount: Int?
    private var reportedTodayVisibility: Bool?
    private var isLayingOut = false
    private var needsEventLayout = true
    private var renderedSize: CGSize = .zero
    private var expanded = false
    var bottomOverlayHeight: CGFloat = 0 {
        didSet {
            guard bottomOverlayHeight != oldValue else { return }
            needsEventLayout = true
            setNeedsLayout()
        }
    }

    var dayPosition: CGFloat {
        CGFloat(scrollWindow.firstDay) + contentOffset.x / pointsPerDay
    }

    func setDayPosition(_ position: CGFloat) {
        let index = position - CGFloat(scrollWindow.firstDay)
        if index < CGFloat(scrollWindow.edgeBuffer) || index > CGFloat(scrollWindow.canvasDayCount - scrollWindow.edgeBuffer) {
            scrollWindow.firstDay = Int(floor(position)) - scrollWindow.centerIndex
            needsEventLayout = true
        }
        contentOffset.x = (position - CGFloat(scrollWindow.firstDay)) * pointsPerDay
        setNeedsLayout()
    }

    func setExpanded(_ expanded: Bool) {
        guard self.expanded != expanded else { return }
        self.expanded = expanded
        for gesture in gestureRecognizers ?? [] where gesture is UISwipeGestureRecognizer {
            gesture.isEnabled = !expanded
        }
        zoomGesture.isEnabled = expanded
        if !expanded {
            pinch = nil
            let day = cardDayPosition
            applyZoom(pointsPerDay: TimelineZoomLevel.days.pointsPerDay, anchorDay: day, viewportX: 0, cardDay: day)
            contentOffset.y = 0
        }
        showsVerticalScrollIndicator = expanded
        needsEventLayout = true
        setNeedsLayout()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        alwaysBounceVertical = false
        isDirectionalLockEnabled = true
        contentInsetAdjustmentBehavior = .never
        scrollsToTop = false
        backgroundColor = .clear
        accessibilityIdentifier = "eventTimeline"
        contentSize = CGSize(width: scrollWindow.contentWidth, height: 1)
        contentOffset.x = scrollWindow.initialOffset
        panGestureRecognizer.maximumNumberOfTouches = 1
        zoomGesture.addTarget(self, action: #selector(pinched(_:)))
        zoomGesture.delegate = self
        zoomGesture.isEnabled = false
        addGestureRecognizer(zoomGesture)
        todayLine.backgroundColor = tintColor
        todayLine.isUserInteractionEnabled = false
        addSubview(todayLine)

        for direction: UISwipeGestureRecognizer.Direction in [.up, .down] {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swipedVertically(_:)))
            swipe.direction = direction
            swipe.delegate = self
            addGestureRecognizer(swipe)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func receiveZoomGestures(in view: UIView) {
        // One finger can start over a floating card and the other over the axis.
        // Their common container must receive both touches for a natural pinch.
        view.addGestureRecognizer(zoomGesture)
    }

    private var todayDay: Int {
        Calendar.current.dateComponents([.day], from: anchor,
                                        to: Calendar.current.startOfDay(for: Date())).day ?? 0
    }

    var isTodayVisible: Bool {
        scrollWindow.visibleDays(offset: contentOffset.x, width: bounds.width).contains(todayDay)
    }

    func scrollToToday(animated: Bool) {
        // Stop momentum before returning so a fling cannot move us away again.
        setContentOffset(contentOffset, animated: false)
        cardReferenceX = 0
        let targetIndex = todayDay - scrollWindow.firstDay
        if (scrollWindow.edgeBuffer...(scrollWindow.canvasDayCount - scrollWindow.edgeBuffer)).contains(targetIndex) {
            setContentOffset(CGPoint(x: CGFloat(targetIndex) * pointsPerDay, y: 0), animated: animated)
        } else {
            // Today may be outside the recycled canvas after a long scroll.
            scrollWindow.firstDay = todayDay - scrollWindow.centerIndex
            setContentOffset(CGPoint(x: scrollWindow.initialOffset, y: 0), animated: false)
        }
        needsEventLayout = true
        setNeedsLayout()
    }

    func setCardDayPosition(_ day: CGFloat) { setDayPosition(day - cardReferenceX / pointsPerDay) }

    func beginZoom(at viewportX: CGFloat) {
        guard expanded else { return }
        setContentOffset(contentOffset, animated: false)
        onBeginDragging?()
        pinch = (pointsPerDay, dayPosition + viewportX / pointsPerDay, cardDayPosition)
    }

    func changeZoom(scale: CGFloat, at viewportX: CGFloat) {
        guard let pinch else { return }
        applyZoom(pointsPerDay: pinch.width * scale, anchorDay: pinch.day, viewportX: viewportX, cardDay: pinch.cardDay)
    }

    func endZoom() { pinch = nil }

    private func applyZoom(pointsPerDay width: CGFloat, anchorDay: CGFloat, viewportX: CGFloat, cardDay: CGFloat) {
        let width = min(TimelineZoomLevel.days.pointsPerDay, max(TimelineZoomLevel.months.pointsPerDay, width))
        changingScale = true
        let leftDay = anchorDay - viewportX / width
        scrollWindow.pointsPerDay = width
        scrollWindow.firstDay = Int(floor(leftDay)) - scrollWindow.centerIndex
        contentSize.width = scrollWindow.contentWidth
        contentOffset.x = (leftDay - CGFloat(scrollWindow.firstDay)) * width
        // Preserve the selected card's date as its screen position moves with the
        // pinch. Subsequent panning continues from that same reference point.
        cardReferenceX = min(bounds.width, max(0, (cardDay - dayPosition) * width))
        changingScale = false
        needsEventLayout = true
        setNeedsLayout()
        UIView.performWithoutAnimation { layoutIfNeeded() }
        onScrollPositionChange?(cardDayPosition)
    }

    var zoomAccessibilityActions: [UIAccessibilityCustomAction] {
        TimelineZoomLevel.allCases.map { level in
            UIAccessibilityCustomAction(name: "Show \(level.rawValue.lowercased())") { [weak self] _ in
                guard let self, self.expanded else { return false }
                self.beginZoom(at: self.bounds.width / 2)
                self.changeZoom(scale: level.pointsPerDay / self.pointsPerDay, at: self.bounds.width / 2)
                self.endZoom()
                return true
            }
        }
    }

    @objc private func pinched(_ gesture: UIPinchGestureRecognizer) {
        let viewportX = gesture.location(in: self).x - contentOffset.x
        switch gesture.state {
        case .began: beginZoom(at: viewportX)
        case .changed: changeZoom(scale: gesture.scale, at: viewportX)
        case .ended, .cancelled, .failed: endZoom()
        default: break
        }
    }

    func update(events: [Event]) {
        let unchanged = self.events.count == events.count && zip(self.events, events).allSatisfy { old, new in
            old.id == new.id && old.date == new.date && old.endDate == new.endDate &&
            old.title == new.title && old.color.color == new.color.color
        }
        guard !unchanged else { return }
        self.events = events
        indexedEvents = TimelineLayout.index(events: events, anchor: anchor)
        needsEventLayout = true
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0, !isLayingOut else { return }
        isLayingOut = true
        defer { isLayingOut = false }

        let oldFirstDay = scrollWindow.firstDay
        let offset = scrollWindow.recenter(offset: contentOffset.x)
        if oldFirstDay != scrollWindow.firstDay {
            contentOffset = CGPoint(x: offset, y: contentOffset.y)
            needsEventLayout = true
        }

        let visibleDays = scrollWindow.visibleDays(offset: offset, width: bounds.width)
        guard visibleDays != renderedDays || needsEventLayout || renderedSize != bounds.size else { return }
        renderedDays = visibleDays
        renderedSize = bounds.size
        needsEventLayout = false
        render(visibleDays: visibleDays)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !changingScale else { return }
        onScrollPositionChange?(cardDayPosition)
        setNeedsLayout()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { onBeginDragging?() }

    private func render(visibleDays: ClosedRange<Int>) {
        let calendar = Calendar.current
        let weights = TimelineAxisWeights(pointsPerDay: pointsPerDay)
        let markerSize = max(6, 24 * sqrt(pointsPerDay / TimelineScrollWindow.dayWidth))
        let markerPitch = markerSize + 4
        let minimumDaySpan = max(1, (markerSize + 2) / pointsPerDay)
        let buffer = max(1, Int(ceil(minimumDaySpan / 2)))
        let bufferedDays = (visibleDays.lowerBound - buffer)...(visibleDays.upperBound + buffer)
        let layout = TimelineLayout.make(indexedEvents: indexedEvents,
                                         visibleDays: minimumDaySpan > 1 ? bufferedDays : visibleDays,
                                         minimumDaySpan: minimumDaySpan)
        let markerHeight = max(0, CGFloat(layout.laneCount) * markerPitch - 4)
        // Center the whole group of lanes between the day labels and the cards.
        // Crowded days retain their spacing and can still scroll vertically.
        let markerTop: CGFloat = expanded
            ? max(48, (44 + bounds.height - bottomOverlayHeight - markerHeight) / 2)
            : 48
        contentSize = CGSize(width: scrollWindow.contentWidth,
                             height: expanded ? max(bounds.height, markerTop + markerHeight + 4 + bottomOverlayHeight) : bounds.height)
        for day in Array(dayViews.keys) where weights.days == 0 || !bufferedDays.contains(day) {
            dayViews.removeValue(forKey: day)?.removeFromSuperview()
        }
        for day in bufferedDays where weights.days > 0 {
            guard let date = calendar.date(byAdding: .day, value: day, to: anchor) else { continue }
            let dayView = dayViews[day] ?? TimelineDayView()
            if dayViews[day] == nil {
                dayViews[day] = dayView
                addSubview(dayView)
            }
            dayView.configure(date: date, expanded: expanded)
            dayView.alpha = weights.days
            dayView.accessibilityElementsHidden = weights.level != .days
            dayView.frame = CGRect(x: CGFloat(day - scrollWindow.firstDay) * pointsPerDay,
                                   y: 0, width: pointsPerDay, height: expanded ? contentSize.height : 44)
        }
        var periodKeys = Set<String>()
        for (level, alpha) in [(TimelineZoomLevel.weeks, weights.weeks), (.months, weights.months)] where alpha > 0 {
            for period in TimelineAxisPeriod.make(level: level, visibleDays: bufferedDays, anchor: anchor) {
                let key = "\(level.rawValue)-\(period.startDay)"
                periodKeys.insert(key)
                let view = periodViews[key] ?? TimelinePeriodView()
                if periodViews[key] == nil { periodViews[key] = view; insertSubview(view, at: 0) }
                view.configure(period: period, containsToday: (period.startDay..<period.endDay).contains(todayDay))
                view.alpha = alpha
                view.accessibilityElementsHidden = level != weights.level
                view.frame = CGRect(x: CGFloat(period.startDay - scrollWindow.firstDay) * pointsPerDay, y: 0,
                                    width: CGFloat(period.endDay - period.startDay) * pointsPerDay, height: contentSize.height)
            }
        }
        for key in Array(periodViews.keys) where !periodKeys.contains(key) { periodViews.removeValue(forKey: key)?.removeFromSuperview() }
        todayLine.backgroundColor = tintColor
        todayLine.alpha = (1 - weights.days) * 0.25
        todayLine.frame = CGRect(x: (CGFloat(todayDay - scrollWindow.firstDay) + 0.5) * pointsPerDay - 0.5,
                                 y: 44, width: 1, height: max(0, bounds.height - bottomOverlayHeight - 44))

        let visibleIDs = Set(layout.placements.map { $0.event.id })
        for id in Array(eventButtons.keys) where !visibleIDs.contains(id) {
            eventButtons.removeValue(forKey: id)?.removeFromSuperview()
        }
        for placement in layout.placements {
            let button = eventButtons[placement.event.id] ?? TimelineEventButton(type: .custom)
            if eventButtons[placement.event.id] == nil {
                eventButtons[placement.event.id] = button
                button.addTarget(self, action: #selector(prepareSelectionFeedback), for: .touchDown)
                button.addTarget(self, action: #selector(selectedEvent(_:)), for: .touchUpInside)
                addSubview(button)
            }
            let start = max(placement.startDay, bufferedDays.lowerBound)
            let end = min(placement.endDay, bufferedDays.upperBound)
            let isSingleDay = placement.startDay == placement.endDay
            let x = CGFloat(start - scrollWindow.firstDay) * pointsPerDay
            let width = CGFloat(end - start + 1) * pointsPerDay
            let inset = min(2, pointsPerDay / 4)
            let markerWidth = isSingleDay ? markerSize : max(markerSize, width - inset * 2)
            button.placement = placement
            button.isSelected = placement.event.id == highlightedEventID
            button.layer.cornerRadius = markerSize / 2
            button.frame = CGRect(x: x + (isSingleDay ? (pointsPerDay - markerSize) / 2 : (width - markerWidth) / 2),
                                  y: markerTop + CGFloat(placement.lane) * markerPitch,
                                  width: markerWidth, height: markerSize)
            button.accessibilityLabel = placement.event.title
            button.accessibilityValue = placement.event.date.formatted(date: .abbreviated, time: .omitted)
            button.accessibilityHint = "Show event"
        }

        if let first = calendar.date(byAdding: .day, value: visibleDays.lowerBound, to: anchor),
           let last = calendar.date(byAdding: .day, value: visibleDays.upperBound, to: anchor) {
            accessibilityValue = "\(weights.level.rawValue) view, \(first.formatted(date: .abbreviated, time: .omitted)) – \(last.formatted(date: .abbreviated, time: .omitted))"
            accessibilityHint = expanded ? "Pinch to zoom between days, weeks, and months. Swipe to move through dates." : "Swipe to move through dates."
        }
        if reportedLaneCount != layout.laneCount {
            reportedLaneCount = layout.laneCount
            // Layout can run inside a SwiftUI update; report the new height on
            // the next main-loop turn instead of mutating view state inline.
            DispatchQueue.main.async { [weak self] in
                guard let self, let count = self.reportedLaneCount else { return }
                self.onLaneCountChange?(count)
            }
        }
        let showsToday = visibleDays.contains(todayDay)
        if reportedTodayVisibility != showsToday {
            reportedTodayVisibility = showsToday
            DispatchQueue.main.async { [weak self] in
                guard let self, let visible = self.reportedTodayVisibility else { return }
                self.onTodayVisibilityChange?(visible)
            }
        }
    }

    @objc private func prepareSelectionFeedback() {
        selectionFeedback.prepare()
    }

    @objc private func selectedEvent(_ button: TimelineEventButton) {
        guard let event = button.placement?.event else { return }
        highlightedEventID = event.id
        selectionFeedback.selectionChanged()
        onSelectEvent?(event)
    }

    @objc private func swipedVertically(_ gesture: UISwipeGestureRecognizer) {
        onCollapse?(gesture.direction == .up)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        gestureRecognizer is UISwipeGestureRecognizer || otherGestureRecognizer is UISwipeGestureRecognizer
    }
}

private final class TimelineEventButton: UIButton {
    var placement: TimelineEventPlacement? {
        didSet { updateSelectionAppearance() }
    }

    override var isSelected: Bool {
        didSet { updateSelectionAppearance() }
    }

    private func updateSelectionAppearance() {
        guard let event = placement?.event else { return }
        let color = UIColor(event.color.color)
        backgroundColor = color.withAlphaComponent(isSelected ? 0.6 : 0.2)
        if isSelected { accessibilityTraits.insert(.selected) }
        else { accessibilityTraits.remove(.selected) }
    }
}

private final class TimelineDayView: UIView {
    private let weekday = UILabel()
    private let number = UILabel()
    private var isToday = false
    private let dayLine = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        weekday.font = .preferredFont(forTextStyle: .caption1)
        weekday.textColor = .secondaryLabel
        weekday.textAlignment = .center
        number.font = .preferredFont(forTextStyle: .caption1)
        number.textAlignment = .center
        number.layer.cornerRadius = 12
        number.clipsToBounds = true
        addSubview(weekday)
        addSubview(number)
        dayLine.backgroundColor = .separator
        dayLine.alpha = 0.25
        addSubview(dayLine)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(date: Date, expanded: Bool) {
        weekday.text = date.formatted(.dateTime.weekday(.abbreviated))
        number.text = date.formatted(.dateTime.day())
        isToday = Calendar.current.isDateInToday(date)
        number.backgroundColor = isToday ? tintColor : .clear
        number.textColor = isToday ? .white : .label
        accessibilityLabel = date.formatted(date: .complete, time: .omitted)
        dayLine.isHidden = !expanded
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        number.backgroundColor = isToday ? tintColor : .clear
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        weekday.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 16)
        number.frame = CGRect(x: (bounds.width - 24) / 2, y: 20, width: 24, height: 24)
        dayLine.frame = CGRect(x: bounds.width - 0.5, y: 52, width: 0.5, height: max(0, bounds.height - 52))
    }
}

private final class TimelinePeriodView: UIView {
    private let title = UILabel()
    private let subtitle = UILabel()
    private let line = UIView()
    private var containsToday = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        for label in [title, subtitle] {
            label.font = .preferredFont(forTextStyle: .caption1)
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.8
            addSubview(label)
        }
        subtitle.textColor = .label
        line.backgroundColor = .separator
        line.alpha = 0.25
        addSubview(line)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(period: TimelineAxisPeriod, containsToday: Bool) {
        title.text = period.title
        subtitle.text = period.subtitle
        self.containsToday = containsToday
        title.textColor = containsToday ? tintColor : .secondaryLabel
        accessibilityLabel = period.accessibilityLabel
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        title.textColor = containsToday ? tintColor : .secondaryLabel
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        title.frame = CGRect(x: 2, y: 0, width: max(0, bounds.width - 4), height: 16)
        subtitle.frame = CGRect(x: 2, y: 20, width: max(0, bounds.width - 4), height: 24)
        line.frame = CGRect(x: bounds.width - 0.5, y: 52, width: 0.5, height: max(0, bounds.height - 52))
    }
}
