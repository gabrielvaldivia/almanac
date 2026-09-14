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

struct EventTimelineView: UIViewRepresentable, Animatable {
    var events: [Event]
    var tint: Color
    var highlightedEventID: UUID?
    var scrollToTodayRequest: UUID?
    var animateScrolling: Bool
    var expanded: Bool
    var expansionProgress: CGFloat
    var onTodayVisibilityChange: (Bool) -> Void
    var onSelectEvent: (Event) -> Void
    var onPositionChange: (CGFloat, Date) -> Void

    var animatableData: CGFloat {
        get { expansionProgress }
        set { expansionProgress = newValue }
    }

    final class Coordinator { var lastScrollToTodayRequest: UUID? }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> TimelineCanvasView { TimelineCanvasView() }

    func updateUIView(_ canvas: TimelineCanvasView, context: Context) {
        canvas.tintColor = UIColor(tint)
        canvas.timeline.onSelectEvent = onSelectEvent
        canvas.onPositionChange = onPositionChange
        canvas.timeline.onTodayVisibilityChange = onTodayVisibilityChange
        canvas.update(events: events, expanded: expanded, progress: expansionProgress, highlightedEventID: highlightedEventID)
        if let request = scrollToTodayRequest, context.coordinator.lastScrollToTodayRequest != request {
            context.coordinator.lastScrollToTodayRequest = request
            canvas.timeline.scrollToToday(animated: animateScrolling)
        }
    }
}

final class TimelineCanvasView: UIView {
    let timeline = TimelineScrollView()
    private let monthLabel = UILabel()
    private var progress: CGFloat = 0
    var onPositionChange: ((CGFloat, Date) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(timeline)
        timeline.receiveZoomGestures(in: self)
        monthLabel.font = .preferredFont(forTextStyle: .headline)
        monthLabel.adjustsFontForContentSizeCategory = true
        monthLabel.accessibilityTraits = .header
        monthLabel.accessibilityIdentifier = "timelineScaleHeader"
        monthLabel.accessibilityCustomActions = timeline.zoomAccessibilityActions
        monthLabel.accessibilityHint = "Use Actions to show days, weeks, or months."
        addSubview(monthLabel)
        timeline.onScrollPositionChange = { [weak self] day in
            guard let self else { return }
            self.updateMonth()
            self.onPositionChange?(day, self.timeline.anchor)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(events: [Event], expanded: Bool, progress: CGFloat, highlightedEventID: UUID?) {
        self.progress = progress
        monthLabel.isHidden = progress == 0
        monthLabel.alpha = progress
        timeline.setExpanded(expanded)
        timeline.expansionProgress = progress
        timeline.update(events: events)
        timeline.highlightedEventID = highlightedEventID
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let header = (ceil(monthLabel.font.lineHeight) + 12) * progress
        monthLabel.frame = CGRect(x: 16, y: 0, width: max(0, bounds.width - 32), height: header)
        timeline.frame = CGRect(x: 0, y: header, width: bounds.width, height: max(0, bounds.height - header))
        updateMonth()
    }

    private func updateMonth() {
        let calendar = Calendar.current
        guard let first = calendar.date(byAdding: .day, value: Int(floor(timeline.dayPosition)), to: timeline.anchor) else { return }
        let lastDay = Int(ceil(timeline.dayPosition + timeline.bounds.width / timeline.pointsPerDay)) - 1
        let last = calendar.date(byAdding: .day, value: lastDay, to: timeline.anchor) ?? first
        if timeline.zoomLevel == .days || calendar.isDate(first, equalTo: last, toGranularity: .month) {
            monthLabel.text = first.formatted(.dateTime.month(.wide).year())
        } else if calendar.isDate(first, equalTo: last, toGranularity: .year) {
            monthLabel.text = "\(first.formatted(.dateTime.month(.abbreviated))) – \(last.formatted(.dateTime.month(.abbreviated).year()))"
        } else {
            monthLabel.text = "\(first.formatted(.dateTime.month(.abbreviated).year())) – \(last.formatted(.dateTime.month(.abbreviated).year()))"
        }
    }
}

final class TimelineScrollView: UIScrollView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    var onSelectEvent: ((Event) -> Void)?
    var onTodayVisibilityChange: ((Bool) -> Void)?
    var onScrollPositionChange: ((CGFloat) -> Void)?
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
    private var pinch: (width: CGFloat, day: CGFloat, focusedDay: CGFloat)?
    private var focusReferenceX: CGFloat = 0
    private var changingScale = false
    var pointsPerDay: CGFloat { scrollWindow.pointsPerDay }
    var zoomLevel: TimelineZoomLevel { TimelineAxisWeights(pointsPerDay: pointsPerDay).level }
    var focusedDayPosition: CGFloat { dayPosition + focusReferenceX / pointsPerDay }
    private var eventButtons: [UUID: TimelineEventButton] = [:]
    private var renderedDays: ClosedRange<Int>?
    private var reportedTodayVisibility: Bool?
    private var isLayingOut = false
    private var needsEventLayout = true
    private var renderedSize: CGSize = .zero
    private var expanded = false
    var expansionProgress: CGFloat = 0 {
        didSet {
            guard expansionProgress != oldValue else { return }
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
        expansionProgress = expanded ? 1 : 0
        zoomGesture.isEnabled = expanded
        if !expanded {
            pinch = nil
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


    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func receiveZoomGestures(in view: UIView) {
        // Recognize pinches across the month heading and the calendar axis.
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
        focusReferenceX = 0
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


    func beginZoom(at viewportX: CGFloat) {
        guard expanded else { return }
        setContentOffset(contentOffset, animated: false)
        pinch = (pointsPerDay, dayPosition + viewportX / pointsPerDay, focusedDayPosition)
    }

    func changeZoom(scale: CGFloat, at viewportX: CGFloat) {
        guard let pinch else { return }
        applyZoom(pointsPerDay: pinch.width * scale, anchorDay: pinch.day, viewportX: viewportX, focusedDay: pinch.focusedDay)
    }

    func endZoom() { pinch = nil }

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
        onScrollPositionChange?(focusedDayPosition)
        setNeedsLayout()
    }


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
        // Center the whole group of lanes between the day labels and the event sheet.
        // Crowded days retain their spacing and can still scroll vertically.
        let centeredTop = max(48, (44 + bounds.height - markerHeight) / 2)
        let markerTop = 48 + (centeredTop - 48) * expansionProgress
        contentSize = CGSize(width: scrollWindow.contentWidth,
                             height: max(bounds.height, markerTop + markerHeight + 4))
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
            dayView.configure(date: date, expansionProgress: expansionProgress)
            dayView.alpha = weights.days
            dayView.accessibilityElementsHidden = weights.level != .days
            dayView.frame = CGRect(x: CGFloat(day - scrollWindow.firstDay) * pointsPerDay,
                                   y: 0, width: pointsPerDay, height: expansionProgress > 0 ? contentSize.height : 44)
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
        todayLine.alpha = max(0, weights.months * 2 - 1) * 0.25
        todayLine.frame = CGRect(x: (CGFloat(todayDay - scrollWindow.firstDay) + 0.5) * pointsPerDay - 0.5,
                                 y: 44, width: 1, height: max(0, bounds.height - 44))

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
        dayLine.alpha = 0.85
        addSubview(dayLine)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(date: Date, expansionProgress: CGFloat) {
        weekday.text = date.formatted(.dateTime.weekday(.abbreviated))
        number.text = date.formatted(.dateTime.day())
        isToday = Calendar.current.isDateInToday(date)
        number.backgroundColor = isToday ? tintColor : .clear
        number.textColor = isToday ? .white : .label
        accessibilityLabel = date.formatted(date: .complete, time: .omitted)
        dayLine.alpha = expansionProgress * 0.85
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        number.backgroundColor = isToday ? tintColor : .clear
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        weekday.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 16)
        number.frame = CGRect(x: (bounds.width - 24) / 2, y: 20, width: 24, height: 24)
        dayLine.frame = CGRect(x: bounds.width - 0.75, y: 52, width: 0.75, height: max(0, bounds.height - 52))
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
        line.alpha = 0.85
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
        line.frame = CGRect(x: bounds.width - 0.75, y: 52, width: 0.75, height: max(0, bounds.height - 52))
    }
}
