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

enum TimelineAxisDate {
    static func text(_ date: Date, includesMonth: Bool = true, calendar: Calendar = .current) -> String {
        let day = "\(calendar.component(.day, from: date))"
        return includesMonth ? "\(calendar.component(.month, from: date))/\(day)" : day
    }
}

/// Keep marker edges inside their calendar section. Coordinates are relative
/// to the anchor, so padding is stable while panning and recycling the canvas.
private struct TimelineMarkerGeometry {
    static let padding: CGFloat = 4
    let anchor: Date
    let calendar: Calendar
    let level: TimelineZoomLevel
    let pointsPerDay: CGFloat
    let markerSize: CGFloat

    private func section(containing day: Int) -> ClosedRange<CGFloat> {
        let date = calendar.date(byAdding: .day, value: day, to: anchor) ?? anchor
        let component: Calendar.Component = level == .days ? .day : (level == .weeks ? .weekOfYear : .month)
        guard let interval = calendar.dateInterval(of: component, for: date) else {
            return CGFloat(day) * pointsPerDay...CGFloat(day + 1) * pointsPerDay
        }
        let start = calendar.dateComponents([.day], from: anchor, to: interval.start).day ?? day
        let end = calendar.dateComponents([.day], from: anchor, to: interval.end).day ?? day + 1
        return CGFloat(start) * pointsPerDay...CGFloat(end) * pointsPerDay
    }

    func horizontalRange(for placement: TimelineEventPlacement, clippedTo days: ClosedRange<Int>) -> ClosedRange<CGFloat> {
        let start = max(placement.startDay, days.lowerBound)
        let end = min(placement.endDay, days.upperBound)
        let lower = section(containing: start).lowerBound + Self.padding
        // Dividers occupy the trailing 0.75 points of each section.
        let upper = section(containing: end).upperBound - Self.padding - 0.75
        let singleDay = placement.startDay == placement.endDay
        let inset = min(2, pointsPerDay / 4)
        let rawStart = CGFloat(start) * pointsPerDay + inset
        let rawEnd = CGFloat(end + 1) * pointsPerDay - inset
        let width = singleDay ? markerSize : max(markerSize, min(rawEnd, upper) - max(rawStart, lower))
        let preferredCenter = singleDay ? (CGFloat(start) + 0.5) * pointsPerDay
            : (max(rawStart, lower) + min(rawEnd, upper)) / 2
        let center = min(max(preferredCenter, lower + width / 2), upper - width / 2)
        return (center - width / 2)...(center + width / 2)
    }
}

struct TimelineAxisPeriod {
    let startDay: Int
    let endDay: Int // Exclusive; calendar months retain their real lengths.
    let title: String
    let subtitle: String
    let compactSubtitle: String
    let accessibilityLabel: String

    static func make(level: TimelineZoomLevel, visibleDays: ClosedRange<Int>, anchor: Date,
                     calendar: Calendar = .current) -> [TimelineAxisPeriod] {
        guard level != .days,
              let firstDate = calendar.date(byAdding: .day, value: visibleDays.lowerBound, to: anchor),
              let firstPeriod = calendar.dateInterval(of: level == .weeks ? .weekOfYear : .month, for: firstDate) else { return [] }
        var start = firstPeriod.start
        var periods: [TimelineAxisPeriod] = []
        let dayFormat = Date.FormatStyle(locale: calendar.locale ?? .current,
                                         calendar: calendar, timeZone: calendar.timeZone).day()
        let monthDayFormat = dayFormat.month(.abbreviated)
        let accessibleFormat = Date.FormatStyle(date: .complete, time: .omitted,
                                                locale: calendar.locale ?? .current,
                                                calendar: calendar, timeZone: calendar.timeZone)
        while let interval = calendar.dateInterval(of: level == .weeks ? .weekOfYear : .month, for: start) {
            let startDay = calendar.dateComponents([.day], from: anchor, to: start).day ?? 0
            if startDay > visibleDays.upperBound { break }
            let endDay = calendar.dateComponents([.day], from: anchor, to: interval.end).day ?? startDay + 1
            let title = start.formatted(.dateTime.month(.abbreviated))
            // Calendar intervals end at the next period's midnight. Display the
            // last included date, using calendar arithmetic across DST changes.
            let lastDate = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? start
            let rangeFormat = calendar.isDate(start, equalTo: lastDate, toGranularity: .month)
                ? dayFormat : monthDayFormat
            let subtitle = level == .weeks ? "\(start.formatted(rangeFormat))–\(lastDate.formatted(rangeFormat))" : ""
            periods.append(TimelineAxisPeriod(
                startDay: startDay, endDay: endDay, title: title, subtitle: subtitle,
                compactSubtitle: level == .weeks ? TimelineAxisDate.text(start, calendar: calendar) : "",
                accessibilityLabel: level == .weeks
                    ? "\(start.formatted(accessibleFormat)) through \(lastDate.formatted(accessibleFormat))"
                    : start.formatted(.dateTime.month(.wide).year())))
            guard interval.end > start else { break }
            start = interval.end
        }
        return periods
    }
}

/// Keep month context while roughly a month fits, even after ticks switch to weeks.
enum TimelineHeading {
    static func showsYear(visibleDayCount: CGFloat) -> Bool { visibleDayCount > 42 }

    static func text(first: Date, last: Date, today: Date = Date(), calendar: Calendar = .current,
                     yearOnly: Bool = false) -> String {
        if yearOnly { return first.formatted(.dateTime.year()) }
        let sameMonth = calendar.isDate(first, equalTo: last, toGranularity: .month)
        let sameYear = calendar.isDate(first, equalTo: last, toGranularity: .year)
        let currentYear = calendar.isDate(first, equalTo: today, toGranularity: .year)
        if sameMonth {
            return currentYear ? first.formatted(.dateTime.month(.wide)) : first.formatted(.dateTime.month(.wide).year())
        }
        let start = first.formatted(.dateTime.month(.abbreviated))
        let end = last.formatted(.dateTime.month(.abbreviated))
        if sameYear {
            return currentYear ? "\(start) – \(end)" : "\(start) – \(last.formatted(.dateTime.month(.abbreviated).year()))"
        }
        return "\(first.formatted(.dateTime.month(.abbreviated).year())) – \(last.formatted(.dateTime.month(.abbreviated).year()))"
    }
}

/// Size labels at their native font size; never compress or ellipsize a calendar label.
private enum TimelineAxisTypography {
    static var font: UIFont { .preferredFont(forTextStyle: .caption1) }
    static var firstRowHeight: CGFloat { max(16, ceil(font.lineHeight)) }
    static var secondRowHeight: CGFloat { max(24, ceil(font.lineHeight) + 4) }
    static var height: CGFloat { firstRowHeight + 4 + secondRowHeight }

    static func place(_ label: UILabel, in available: CGRect, y: CGFloat, height: CGFloat,
                      alpha: CGFloat, centeredAt center: CGFloat? = nil, horizontalPadding: CGFloat = 4) {
        guard !available.isNull, !available.isEmpty else { label.isHidden = true; return }
        label.font = font
        let width = ceil(label.intrinsicContentSize.width)
        let usable = available.insetBy(dx: horizontalPadding, dy: 0)
        guard !usable.isNull, !usable.isEmpty else { label.isHidden = true; return }
        let x = center.map { $0 - width / 2 } ?? usable.midX - width / 2
        let frame = CGRect(x: x, y: y, width: width, height: height)
        // Partial cells at either screen edge disappear as a whole, never as clipped text.
        label.isHidden = alpha <= 0 || width <= 0 || frame.minX < usable.minX || frame.maxX > usable.maxX
        label.alpha = alpha
        label.frame = frame
    }
}

struct EventTimelineView: UIViewRepresentable {
    var events: [Event]
    var tint: Color
    var highlightedEventID: UUID?
    var scrollToTodayRequest: UUID?
    var scrollToDateRequest: EventSheetScrollRequest?
    var animateScrolling: Bool
    var onHeightChange: (CGFloat) -> Void
    var onTodayVisibilityChange: (Bool) -> Void
    var onSelectEvent: (Event) -> Void
    var onInteractionBegan: () -> Void
    var onPositionChange: (CGFloat, Date, CGFloat) -> Void

    final class Coordinator {
        var lastScrollToTodayRequest: UUID?
        var lastScrollToDateRequest: UUID?
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> TimelineCanvasView { TimelineCanvasView() }

    func updateUIView(_ canvas: TimelineCanvasView, context: Context) {
        canvas.overrideUserInterfaceStyle = context.environment.colorScheme == .dark ? .dark : .light
        canvas.tintColor = UIColor(tint)
        canvas.timeline.onSelectEvent = onSelectEvent
        canvas.timeline.onInteractionBegan = onInteractionBegan
        canvas.onPositionChange = onPositionChange
        canvas.timeline.onTodayVisibilityChange = onTodayVisibilityChange
        canvas.timeline.onHeightChange = onHeightChange
        canvas.update(events: events, highlightedEventID: highlightedEventID)
        if let request = scrollToTodayRequest, context.coordinator.lastScrollToTodayRequest != request {
            context.coordinator.lastScrollToTodayRequest = request
            canvas.timeline.scrollToToday(animated: animateScrolling)
        }
        if let request = scrollToDateRequest, context.coordinator.lastScrollToDateRequest != request.id {
            context.coordinator.lastScrollToDateRequest = request.id
            canvas.timeline.scrollToDate(request.date, animated: request.animated && animateScrolling)
        }
    }
}

final class TimelineCanvasView: UIView {
    let timeline = TimelineScrollView()
    var onPositionChange: ((CGFloat, Date, CGFloat) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(timeline)
        timeline.receiveZoomGestures(in: self)
        timeline.onScrollPositionChange = { [weak self] _ in
            guard let self else { return }
            self.reportPosition()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(events: [Event], highlightedEventID: UUID?) {
        timeline.update(events: events)
        timeline.highlightedEventID = highlightedEventID
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let widthChanged = timeline.bounds.width != bounds.width
        if timeline.frame != bounds { timeline.frame = bounds }
        if widthChanged { reportPosition() }
    }

    private func reportPosition() {
        onPositionChange?(timeline.focusedDayPosition, timeline.anchor, timeline.bounds.width / timeline.pointsPerDay)
    }
}

final class TimelineScrollView: UIScrollView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    var onSelectEvent: ((Event) -> Void)?
    var onInteractionBegan: (() -> Void)?
    var onTodayVisibilityChange: ((Bool) -> Void)?
    var onScrollPositionChange: ((CGFloat) -> Void)?
    var onHeightChange: ((CGFloat) -> Void)?
    private(set) var preferredHeight: CGFloat = 100
    private let eventVerticalPadding: CGFloat = 24
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
    private let axisHeader = UIView()
    private let axisDivider = UIView()
    private var axisHeight: CGFloat = TimelineAxisTypography.height
    private let zoomGesture = UIPinchGestureRecognizer()
    private var pinch: (width: CGFloat, day: CGFloat, focusedDay: CGFloat)?
    private var focusReferenceX: CGFloat = 0
    private var changingScale = false
    private var scrollTargetDay: CGFloat?
    var pointsPerDay: CGFloat { scrollWindow.pointsPerDay }
    var zoomLevel: TimelineZoomLevel { TimelineAxisWeights(pointsPerDay: pointsPerDay).level }
    var focusedDayPosition: CGFloat { dayPosition + focusReferenceX / pointsPerDay }
    private var eventButtons: [UUID: TimelineEventButton] = [:]
    private var renderedDays: ClosedRange<Int>?
    private var reportedTodayVisibility: Bool?
    private var isLayingOut = false
    private var needsEventLayout = true
    private var renderedSize: CGSize = .zero

    override var accessibilityValue: String? {
        get {
            // Describe the actual viewport, including during UIKit scroll
            // animations between SwiftUI updates.
            let calendar = Calendar.current
            let days = scrollWindow.visibleDays(offset: contentOffset.x, width: bounds.width)
            guard let first = calendar.date(byAdding: .day, value: days.lowerBound, to: anchor),
                  let last = calendar.date(byAdding: .day, value: days.upperBound, to: anchor) else { return nil }
            return "\(zoomLevel.rawValue) view, \(first.formatted(date: .abbreviated, time: .omitted)) – \(last.formatted(date: .abbreviated, time: .omitted))"
        }
        set { super.accessibilityValue = newValue }
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
        accessibilityCustomActions = zoomAccessibilityActions
        contentSize = CGSize(width: scrollWindow.contentWidth, height: 1)
        contentOffset.x = scrollWindow.initialOffset
        panGestureRecognizer.maximumNumberOfTouches = 1
        zoomGesture.addTarget(self, action: #selector(pinched(_:)))
        zoomGesture.delegate = self
        addGestureRecognizer(zoomGesture)
        axisHeader.backgroundColor = .systemBackground
        axisHeader.clipsToBounds = true
        axisHeader.accessibilityIdentifier = "timelineAxis"
        axisDivider.backgroundColor = .separator
        axisDivider.alpha = 0.85
        axisDivider.isUserInteractionEnabled = false
        axisDivider.accessibilityIdentifier = "timelineAxisDivider"
        axisHeader.addSubview(axisDivider)
        addSubview(axisHeader)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: TimelineScrollView, _: UITraitCollection) in
            view.needsEventLayout = true
            view.setNeedsLayout()
        }

    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func receiveZoomGestures(in view: UIView) {
        // Recognize pinches across the full timeline surface.
        view.addGestureRecognizer(zoomGesture)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // A one-finger pan can begin before the second finger lands. Let the
        // pinch recognize anyway; beginZoom then cancels the pan's movement.
        gestureRecognizer === zoomGesture && otherGestureRecognizer === panGestureRecognizer
    }

    private var todayDay: Int {
        Calendar.current.dateComponents([.day], from: anchor,
                                        to: Calendar.current.startOfDay(for: Date())).day ?? 0
    }

    var isTodayVisible: Bool {
        scrollWindow.visibleDays(offset: contentOffset.x, width: bounds.width).contains(todayDay)
    }

    func scrollToToday(animated: Bool) {
        focusReferenceX = 0
        scroll(toFocusedDay: CGFloat(todayDay), animated: animated)
    }

    func scrollToDate(_ date: Date, animated: Bool) {
        let calendar = Calendar.current
        let day = calendar.dateComponents([.day], from: anchor, to: calendar.startOfDay(for: date)).day ?? 0
        scroll(toFocusedDay: CGFloat(day), animated: animated)
    }

    private func scroll(toFocusedDay day: CGFloat, animated: Bool) {
        // Cancel existing momentum before following a new event. Keep both the
        // zoom and the date's reference position established by the last pinch.
        scrollTargetDay = nil
        setContentOffset(contentOffset, animated: false)
        scrollTargetDay = day
        let leftDay = day - focusReferenceX / pointsPerDay
        let targetIndex = leftDay - CGFloat(scrollWindow.firstDay)
        if (CGFloat(scrollWindow.edgeBuffer)...CGFloat(scrollWindow.canvasDayCount - scrollWindow.edgeBuffer)).contains(targetIndex) {
            let target = CGPoint(x: targetIndex * pointsPerDay, y: 0)
            let animate = animated && abs(target.x - contentOffset.x) > 1
            setContentOffset(target, animated: animate)
            if !animate { finishProgrammaticScroll() }
        } else {
            // Rebase distant dates rather than animating beyond the recycled canvas.
            scrollWindow.firstDay = Int(floor(leftDay)) - scrollWindow.centerIndex
            setContentOffset(CGPoint(x: (leftDay - CGFloat(scrollWindow.firstDay)) * pointsPerDay, y: 0), animated: false)
            finishProgrammaticScroll()
        }
        needsEventLayout = true
        setNeedsLayout()
    }

    private func finishProgrammaticScroll() {
        guard let day = scrollTargetDay else { return }
        scrollTargetDay = nil
        // A layout update can end UIKit's animation before its target. Settle at
        // the requested position before compensating for physical-pixel rounding.
        setDayPosition(day - focusReferenceX / pointsPerDay)
        // UIKit rounds offsets to physical pixels. Keep an exact calendar focus
        // so landing on the first of a month cannot report the previous month.
        focusReferenceX = (day - dayPosition) * pointsPerDay
        onScrollPositionChange?(focusedDayPosition)
    }

    func beginZoom(at viewportX: CGFloat) {
        scrollTargetDay = nil
        panGestureRecognizer.isEnabled = false
        onInteractionBegan?()
        setContentOffset(contentOffset, animated: false)
        pinch = (pointsPerDay, dayPosition + viewportX / pointsPerDay, focusedDayPosition)
    }

    func changeZoom(scale: CGFloat, at viewportX: CGFloat) {
        guard let pinch else { return }
        applyZoom(pointsPerDay: pinch.width * scale, anchorDay: pinch.day, viewportX: viewportX, focusedDay: pinch.focusedDay)
    }

    func endZoom() {
        pinch = nil
        panGestureRecognizer.isEnabled = true
    }

    private func applyZoom(pointsPerDay width: CGFloat, anchorDay: CGFloat, viewportX: CGFloat, focusedDay: CGFloat) {
        let width = min(TimelineZoomLevel.days.pointsPerDay, max(TimelineZoomLevel.months.pointsPerDay, width))
        changingScale = true
        let leftDay = anchorDay - viewportX / width
        scrollWindow.pointsPerDay = width
        scrollWindow.firstDay = Int(floor(leftDay)) - scrollWindow.centerIndex
        contentSize.width = scrollWindow.contentWidth
        contentOffset.x = (leftDay - CGFloat(scrollWindow.firstDay)) * width
        // Preserve the focused event day as its screen position moves with the
        // pinch. Subsequent panning continues from that same reference point.
        focusReferenceX = min(bounds.width, max(0, (focusedDay - dayPosition) * width))
        changingScale = false
        needsEventLayout = true
        setNeedsLayout()
        UIView.performWithoutAnimation { layoutIfNeeded() }
        onScrollPositionChange?(focusedDayPosition)
    }

    var zoomAccessibilityActions: [UIAccessibilityCustomAction] {
        TimelineZoomLevel.allCases.map { level in
            UIAccessibilityCustomAction(name: "Show \(level.rawValue.lowercased())") { [weak self] _ in
                guard let self else { return false }
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
        case .began:
            beginZoom(at: viewportX)
            changeZoom(scale: gesture.scale, at: viewportX)
        case .changed: changeZoom(scale: gesture.scale, at: viewportX)
        case .ended:
            changeZoom(scale: gesture.scale, at: viewportX)
            endZoom()
        case .cancelled, .failed: endZoom()
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
        if visibleDays != renderedDays || needsEventLayout || renderedSize != bounds.size {
            renderedDays = visibleDays
            renderedSize = bounds.size
            needsEventLayout = false
            render(visibleDays: visibleDays)
        }
        // Pin only the date header vertically. Its horizontal coordinate space
        // follows the timeline, including fractional pans and recycled windows.
        let headerHeight = axisHeight + 8
        axisHeader.frame = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: headerHeight)
        axisHeader.bounds = CGRect(x: bounds.minX, y: 0, width: bounds.width, height: headerHeight)
        axisDivider.frame = CGRect(x: bounds.minX, y: headerHeight - 0.75, width: bounds.width, height: 0.75)
        let grid = CGRect(x: bounds.minX, y: bounds.minY + axisDivider.frame.minY,
                          width: bounds.width, height: max(0, bounds.height - axisDivider.frame.minY))
        for view in dayViews.values { view.layoutLabels(in: axisHeader.bounds, grid: grid) }
        for view in periodViews.values { view.layoutLabels(in: axisHeader.bounds, grid: grid) }
        let eventViewport = CGRect(x: bounds.minX, y: bounds.minY + headerHeight,
                                   width: bounds.width, height: max(0, bounds.height - headerHeight))
        for button in eventButtons.values {
            button.isAccessibilityElement = button.frame.intersects(eventViewport)
        }
        axisHeader.bringSubviewToFront(axisDivider)
        bringSubviewToFront(axisHeader)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollTargetDay = nil
        onInteractionBegan?()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        finishProgrammaticScroll()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !changingScale else { return }
        onScrollPositionChange?(focusedDayPosition)
        setNeedsLayout()
    }


    private func render(visibleDays: ClosedRange<Int>) {
        let calendar = Calendar.current
        let weights = TimelineAxisWeights(pointsPerDay: pointsPerDay)
        let markerSize = max(6, 20 * sqrt(pointsPerDay / TimelineScrollWindow.dayWidth))
        let markerPitch = markerSize + 4
        let geometry = TimelineMarkerGeometry(anchor: anchor, calendar: calendar, level: weights.level,
                                              pointsPerDay: pointsPerDay, markerSize: markerSize)
        let buffer = max(1, Int(ceil((markerSize + 2 * TimelineMarkerGeometry.padding + 1) / pointsPerDay)))
        let bufferedDays = (visibleDays.lowerBound - buffer)...(visibleDays.upperBound + buffer)
        let candidates = indexedEvents.filter { $0.startDay <= bufferedDays.upperBound && $0.endDay >= bufferedDays.lowerBound }
        let markerRanges = Dictionary(uniqueKeysWithValues: candidates.map {
            ($0.event.id, geometry.horizontalRange(for: $0, clippedTo: bufferedDays))
        })
        // Include entire edge days so fractional pans reveal their markers
        // without waiting for the next calendar day to trigger a render.
        let visibleRange = (CGFloat(visibleDays.lowerBound) * pointsPerDay)...(CGFloat(visibleDays.upperBound + 1) * pointsPerDay)
        let visibleEvents = candidates.filter { markerRanges[$0.event.id]?.overlaps(visibleRange) == true }
        let layout = TimelineLayout.make(indexedEvents: visibleEvents, visibleDays: bufferedDays, horizontalRange: {
            let range = markerRanges[$0.event.id]!
            return (range.lowerBound - 1)...(range.upperBound + 1)
        })
        let markerHeight = max(0, CGFloat(layout.laneCount) * markerPitch - 4)
        // The date header and all visible event lanes determine the timeline's
        // natural height. Give the marker group identical top/bottom padding.
        axisHeight = TimelineAxisTypography.height -
            (TimelineAxisTypography.firstRowHeight + 4) * weights.weeks
        let headerHeight = axisHeight + 8
        let height = ceil(headerHeight + markerHeight + 2 * eventVerticalPadding)
        if preferredHeight != height {
            preferredHeight = height
            // Report after UIKit layout finishes, avoiding SwiftUI state changes
            // during updateUIView. Read the latest height if another pinch arrives.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onHeightChange?(self.preferredHeight)
            }
        }
        let markerTop = headerHeight + max(eventVerticalPadding, (bounds.height - headerHeight - markerHeight) / 2)
        // Only one hierarchy occupies the text rows. Keep labels visible even
        // when a pinch stops exactly between scales; the grid remains continuous.
        let axisFont = TimelineAxisTypography.font
        let dayWidth = (1...31).map {
            (String($0) as NSString).size(withAttributes: [.font: axisFont]).width
        }.max() ?? 0
        let compactWeekWidth = bufferedDays.compactMap {
            calendar.date(byAdding: .day, value: $0, to: anchor)
        }.map {
            (TimelineAxisDate.text($0, calendar: calendar) as NSString).size(withAttributes: [.font: axisFont]).width
        }.max() ?? 0
        let showsDayLabels = pointsPerDay >= ceil(dayWidth) + 4
        let weekdayWidth = (DateFormatter().shortWeekdaySymbols ?? []).map {
            ($0 as NSString).size(withAttributes: [.font: axisFont]).width
        }.max() ?? 0
        let showsWeekdays = showsDayLabels && pointsPerDay >= ceil(weekdayWidth) + 8 &&
            axisHeight >= TimelineAxisTypography.height
        let dayLabelAlpha: CGFloat = showsDayLabels ? 1 : 0
        let periodLabelAlpha: CGFloat = showsDayLabels ? 0 : 1
        let needsDayViews = showsDayLabels || weights.days > 0
        contentSize = CGSize(width: scrollWindow.contentWidth,
                             height: max(bounds.height, markerTop + markerHeight + eventVerticalPadding))
        showsVerticalScrollIndicator = preferredHeight > bounds.height + 1
        if !isDragging && !isDecelerating {
            contentOffset.y = min(max(0, contentOffset.y), max(0, contentSize.height - bounds.height))
        }
        for day in Array(dayViews.keys) where !needsDayViews || !bufferedDays.contains(day) {
            let view = dayViews.removeValue(forKey: day)
            view?.divider.removeFromSuperview()
            view?.removeFromSuperview()
        }
        for day in bufferedDays where needsDayViews {
            guard let date = calendar.date(byAdding: .day, value: day, to: anchor) else { continue }
            let dayView = dayViews[day] ?? TimelineDayView()
            if dayViews[day] == nil {
                dayViews[day] = dayView
                axisHeader.addSubview(dayView)
                insertSubview(dayView.divider, at: 0)
            }
            dayView.configure(date: date, labelAlpha: dayLabelAlpha, showsWeekday: showsWeekdays,
                              dividerAlpha: max(0, weights.days * 2 - 1), axisHeight: axisHeight)
            dayView.frame = CGRect(x: CGFloat(day - scrollWindow.firstDay) * pointsPerDay,
                                   y: 0, width: pointsPerDay, height: headerHeight)
        }
        var periodKeys = Set<String>()
        let monthNameWidth = (DateFormatter().shortMonthSymbols ?? []).map {
            ($0 as NSString).size(withAttributes: [.font: TimelineAxisTypography.font]).width
        }.max() ?? 0
        let monthStride = max(1, Int(ceil((monthNameWidth + 8) / (28 * pointsPerDay))))
        let weekStride = max(1, Int(ceil((ceil(compactWeekWidth) + 8) / (7 * pointsPerDay))))
        for level in [TimelineZoomLevel.weeks, .months] where (!showsDayLabels || weights.days < 1) && (level == .months || weights.months < 1) {
            for period in TimelineAxisPeriod.make(level: level, visibleDays: bufferedDays, anchor: anchor) {
                let key = "\(level.rawValue)-\(period.startDay)"
                periodKeys.insert(key)
                let view = periodViews[key] ?? TimelinePeriodView()
                if periodViews[key] == nil {
                    periodViews[key] = view
                    axisHeader.addSubview(view)
                    insertSubview(view.divider, at: 0)
                }
                let date = calendar.date(byAdding: .day, value: period.startDay, to: anchor) ?? anchor
                let monthIndex = calendar.component(.year, from: date) * 12 + calendar.component(.month, from: date) - 1
                let weekIndex = Int(floor(CGFloat(period.startDay) / 7))
                let labelLevel: TimelineZoomLevel = weights.level == .months ? .months : .weeks
                let showLabel = level == labelLevel && (level == .months
                    ? monthIndex.isMultiple(of: monthStride) : weekIndex.isMultiple(of: weekStride))
                view.configure(period: period, level: level,
                               containsToday: (period.startDay..<period.endDay).contains(todayDay),
                               labelAlpha: showLabel ? periodLabelAlpha : 0,
                               labelColumnWidth: level == .months ? 28 * pointsPerDay * CGFloat(monthStride)
                                   : 7 * pointsPerDay * CGFloat(weekStride),
                               // Once months take over, their sections replace
                               // the week grid instead of cutting through it.
                               dividerAlpha: level == .weeks ? (weights.level == .months ? 0 : weights.weeks)
                                   : max(0, weights.months * 2 - 1),
                               axisHeight: axisHeight)
                view.frame = CGRect(x: CGFloat(period.startDay - scrollWindow.firstDay) * pointsPerDay, y: 0,
                                    width: CGFloat(period.endDay - period.startDay) * pointsPerDay, height: headerHeight)
            }
        }
        for key in Array(periodViews.keys) where !periodKeys.contains(key) {
            let view = periodViews.removeValue(forKey: key)
            view?.divider.removeFromSuperview()
            view?.removeFromSuperview()
        }
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
            guard let range = markerRanges[placement.event.id] else { continue }
            button.placement = placement
            button.isSelected = placement.event.id == highlightedEventID
            button.layer.cornerRadius = markerSize / 2
            button.frame = CGRect(x: range.lowerBound - CGFloat(scrollWindow.firstDay) * pointsPerDay,
                                  y: markerTop + CGFloat(placement.lane) * markerPitch,
                                  width: range.upperBound - range.lowerBound, height: markerSize)
            button.accessibilityLabel = placement.event.title
            button.accessibilityValue = placement.event.date.formatted(date: .abbreviated, time: .omitted)
            button.accessibilityHint = "Show event"
        }

        accessibilityHint = "Pinch to zoom between days, weeks, and months. Swipe to move through dates."
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
        backgroundColor = color.withAlphaComponent(1)
        if isSelected { accessibilityTraits.insert(.selected) }
        else { accessibilityTraits.remove(.selected) }
    }
}

private final class TimelineDayView: UIView {
    private let weekday = UILabel()
    private let number = UILabel()
    let divider = UIView()
    private var isToday = false
    private var showsWeekday = true
    private var showsTodayHighlight = false
    private var labelAlpha: CGFloat = 1
    private var axisHeight: CGFloat = TimelineAxisTypography.height

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        weekday.textColor = .secondaryLabel
        for label in [weekday, number] {
            label.font = TimelineAxisTypography.font
            label.textAlignment = .center
            addSubview(label)
        }
        number.clipsToBounds = true
        divider.backgroundColor = .separator
        divider.isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(date: Date, labelAlpha: CGFloat, showsWeekday: Bool, dividerAlpha: CGFloat, axisHeight: CGFloat) {
        weekday.text = date.formatted(.dateTime.weekday(.abbreviated))
        number.text = TimelineAxisDate.text(date, includesMonth: false)
        self.labelAlpha = labelAlpha
        self.showsWeekday = showsWeekday
        self.axisHeight = axisHeight
        isToday = Calendar.current.isDateInToday(date)
        updateTodayAppearance()
        accessibilityLabel = date.formatted(date: .complete, time: .omitted)
        divider.alpha = dividerAlpha * 0.85
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        updateTodayAppearance()
    }

    private func updateTodayAppearance() {
        number.backgroundColor = isToday && showsTodayHighlight ? tintColor : .clear
        number.textColor = isToday ? (showsTodayHighlight ? .white : tintColor) : .label
    }

    func layoutLabels(in viewport: CGRect, grid: CGRect) {
        let visible = frame.intersection(viewport).offsetBy(dx: -frame.minX, dy: 0)
        TimelineAxisTypography.place(weekday, in: visible, y: 0, height: TimelineAxisTypography.firstRowHeight,
                                     alpha: showsWeekday ? labelAlpha : 0, centeredAt: bounds.midX)
        TimelineAxisTypography.place(number, in: visible, y: axisHeight - TimelineAxisTypography.secondRowHeight,
                                     height: TimelineAxisTypography.secondRowHeight, alpha: labelAlpha, centeredAt: bounds.midX,
                                     horizontalPadding: 2)
        let highlightWidth = max(TimelineAxisTypography.secondRowHeight, ceil(number.intrinsicContentSize.width) + 4)
        showsTodayHighlight = isToday && highlightWidth + 4 <= bounds.width
        if showsTodayHighlight {
            number.frame = CGRect(x: bounds.midX - highlightWidth / 2, y: number.frame.minY,
                                  width: highlightWidth, height: TimelineAxisTypography.secondRowHeight)
            number.isHidden = number.isHidden || number.frame.minX < visible.minX + 2 || number.frame.maxX > visible.maxX - 2
        }
        number.layer.cornerRadius = showsTodayHighlight ? TimelineAxisTypography.secondRowHeight / 2 : 0
        updateTodayAppearance()
        accessibilityElementsHidden = weekday.isHidden && number.isHidden
        divider.frame = CGRect(x: frame.maxX - 0.75, y: grid.minY, width: 0.75, height: grid.height)
    }
}

private final class TimelinePeriodView: UIView {
    private let label = UILabel()
    let divider = UIView()
    private var level = TimelineZoomLevel.months
    private var labelColumnWidth: CGFloat = 0
    private var containsToday = false
    private var labelAlpha: CGFloat = 1
    private var axisHeight: CGFloat = TimelineAxisTypography.height
    private var rangeText = ""
    private var compactText = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        label.font = TimelineAxisTypography.font
        label.textAlignment = .center
        addSubview(label)
        divider.backgroundColor = .separator
        divider.isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(period: TimelineAxisPeriod, level: TimelineZoomLevel, containsToday: Bool,
                   labelAlpha: CGFloat, labelColumnWidth: CGFloat, dividerAlpha: CGFloat, axisHeight: CGFloat) {
        self.level = level
        self.labelColumnWidth = labelColumnWidth
        self.labelAlpha = labelAlpha
        self.axisHeight = axisHeight
        label.text = level == .months ? period.title : period.subtitle
        rangeText = period.subtitle
        compactText = period.compactSubtitle
        self.containsToday = containsToday
        label.textColor = containsToday ? tintColor : .secondaryLabel
        accessibilityLabel = period.accessibilityLabel
        divider.alpha = dividerAlpha * 0.85
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        label.textColor = containsToday ? tintColor : .secondaryLabel
    }

    func layoutLabels(in viewport: CGRect, grid: CGRect) {
        // Large text shows fewer dates or month names with more space, retaining the grid.
        let labelWidth = max(frame.width, labelColumnWidth)
        let labelColumn = CGRect(x: frame.midX - labelWidth / 2, y: frame.minY, width: labelWidth, height: frame.height)
        let visible = labelColumn.intersection(viewport).offsetBy(dx: -frame.minX, dy: 0)
        if level == .weeks {
            let font = TimelineAxisTypography.font
            let rangeWidth = max((rangeText as NSString).size(withAttributes: [.font: font]).width,
                                 ("88–88" as NSString).size(withAttributes: [.font: font]).width)
            // Keep complete ranges at close weekly zoom, including month names
            // for boundary weeks. Fall back to the numeric start date before text crowds.
            label.text = bounds.width >= ceil(rangeWidth) + 16 ? rangeText : compactText
        }
        TimelineAxisTypography.place(label, in: visible,
                                     y: level == .months ? 0 : axisHeight - TimelineAxisTypography.secondRowHeight,
                                     height: level == .months ? TimelineAxisTypography.firstRowHeight : TimelineAxisTypography.secondRowHeight,
                                     alpha: labelAlpha)
        accessibilityElementsHidden = label.isHidden
        divider.frame = CGRect(x: frame.maxX - 0.75, y: grid.minY, width: 0.75, height: grid.height)
    }
}
