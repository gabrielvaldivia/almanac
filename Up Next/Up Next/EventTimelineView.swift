import SwiftUI
import UIKit

/// A fixed-size canvas that is rebased as the user scrolls. Day offsets and the
/// fractional scroll position survive rebasing, so neither end is reachable.
struct TimelineScrollWindow {
    static let dayWidth: CGFloat = 44
    static let dayCount = 181
    static let centerDay = dayCount / 2
    var firstDay = -centerDay

    var contentWidth: CGFloat { CGFloat(Self.dayCount) * Self.dayWidth }
    var initialOffset: CGFloat { CGFloat(Self.centerDay) * Self.dayWidth }

    mutating func recenter(offset: CGFloat) -> CGFloat {
        let index = Int(floor(offset / Self.dayWidth))
        guard index < 30 || index > Self.dayCount - 30 else { return offset }
        let shift = index - Self.centerDay
        firstDay += shift
        return offset - CGFloat(shift) * Self.dayWidth
    }

    func visibleDays(offset: CGFloat, width: CGFloat) -> ClosedRange<Int> {
        let first = firstDay + Int(floor(offset / Self.dayWidth))
        let last = firstDay + Int(ceil((offset + max(1, width)) / Self.dayWidth)) - 1
        return first...max(first, last)
    }
}

struct EventTimelineView: View {
    var events: [Event]
    var tint: Color
    var scrollToTodayRequest: UUID?
    var onTodayVisibilityChange: (Bool) -> Void
    var onSelectEvent: (Event) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var laneCount = 0
    @State private var isCollapsed = false

    var body: some View {
        VStack(spacing: 0) {
            TimelineScroller(
                events: events,
                tint: tint,
                scrollToTodayRequest: scrollToTodayRequest,
                animateScrolling: !reduceMotion,
                onTodayVisibilityChange: onTodayVisibilityChange,
                onSelectEvent: onSelectEvent,
                onLaneCountChange: { laneCount = $0 },
                onCollapse: setCollapsed
            )
            .frame(height: isCollapsed ? 0 : TimelineLayout.height(for: laneCount))
            .padding(.top, isCollapsed ? 0 : 16)
            .clipped()
            .opacity(isCollapsed ? 0 : 1)
            .allowsHitTesting(!isCollapsed)
            .accessibilityHidden(isCollapsed)

            Button {
                setCollapsed(!isCollapsed)
            } label: {
                Capsule()
                    .fill(.tertiary)
                    .frame(width: 28, height: 4)
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCollapsed ? "Show timeline" : "Hide timeline")
            .accessibilityHint(isCollapsed ? "Swipe down to reveal the timeline" : "Swipe up to hide the timeline")
            .simultaneousGesture(
                DragGesture(minimumDistance: 20).onEnded { value in
                    guard abs(value.translation.height) > abs(value.translation.width) else { return }
                    setCollapsed(value.translation.height < 0)
                }
            )
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: laneCount)
        .onChange(of: scrollToTodayRequest) {
            setCollapsed(false)
        }
    }

    private func setCollapsed(_ collapsed: Bool) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            isCollapsed = collapsed
        }
    }
}

private struct TimelineScroller: UIViewRepresentable {
    var events: [Event]
    var tint: Color
    var scrollToTodayRequest: UUID?
    var animateScrolling: Bool
    var onTodayVisibilityChange: (Bool) -> Void
    var onSelectEvent: (Event) -> Void
    var onLaneCountChange: (Int) -> Void
    var onCollapse: (Bool) -> Void

    final class Coordinator {
        var lastScrollToTodayRequest: UUID?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> TimelineScrollView {
        TimelineScrollView()
    }

    func updateUIView(_ scrollView: TimelineScrollView, context: Context) {
        scrollView.tintColor = UIColor(tint)
        scrollView.onSelectEvent = onSelectEvent
        scrollView.onLaneCountChange = onLaneCountChange
        scrollView.onCollapse = onCollapse
        scrollView.onTodayVisibilityChange = onTodayVisibilityChange
        scrollView.update(events: events)
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

    private let anchor = Calendar.current.startOfDay(for: Date())
    private var scrollWindow = TimelineScrollWindow()
    private var events: [Event] = []
    private var indexedEvents: [TimelineEventPlacement] = []
    private var dayViews: [Int: TimelineDayView] = [:]
    private var eventButtons: [UUID: TimelineEventButton] = [:]
    private var renderedDays: ClosedRange<Int>?
    private var reportedLaneCount: Int?
    private var reportedTodayVisibility: Bool?
    private var isLayingOut = false
    private var needsEventLayout = true

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

        for direction: UISwipeGestureRecognizer.Direction in [.up, .down] {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swipedVertically(_:)))
            swipe.direction = direction
            swipe.delegate = self
            addGestureRecognizer(swipe)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

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
        let targetIndex = todayDay - scrollWindow.firstDay
        if (30...(TimelineScrollWindow.dayCount - 30)).contains(targetIndex) {
            setContentOffset(CGPoint(x: CGFloat(targetIndex) * TimelineScrollWindow.dayWidth, y: 0), animated: animated)
        } else {
            // Today may be outside the recycled canvas after a long scroll.
            scrollWindow.firstDay = todayDay - TimelineScrollWindow.centerDay
            setContentOffset(CGPoint(x: scrollWindow.initialOffset, y: 0), animated: false)
        }
        needsEventLayout = true
        setNeedsLayout()
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

        contentSize = CGSize(width: scrollWindow.contentWidth, height: bounds.height)
        let oldFirstDay = scrollWindow.firstDay
        let offset = scrollWindow.recenter(offset: contentOffset.x)
        if oldFirstDay != scrollWindow.firstDay {
            contentOffset = CGPoint(x: offset, y: 0)
            needsEventLayout = true
        }

        let visibleDays = scrollWindow.visibleDays(offset: offset, width: bounds.width)
        guard visibleDays != renderedDays || needsEventLayout else { return }
        renderedDays = visibleDays
        needsEventLayout = false
        render(visibleDays: visibleDays)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        setNeedsLayout()
    }

    private func render(visibleDays: ClosedRange<Int>) {
        let calendar = Calendar.current
        let bufferedDays = (visibleDays.lowerBound - 1)...(visibleDays.upperBound + 1)
        for day in Array(dayViews.keys) where !bufferedDays.contains(day) {
            dayViews.removeValue(forKey: day)?.removeFromSuperview()
        }
        for day in bufferedDays {
            guard let date = calendar.date(byAdding: .day, value: day, to: anchor) else { continue }
            let dayView = dayViews[day] ?? TimelineDayView()
            if dayViews[day] == nil {
                dayViews[day] = dayView
                addSubview(dayView)
            }
            dayView.configure(date: date)
            dayView.frame = CGRect(x: CGFloat(day - scrollWindow.firstDay) * TimelineScrollWindow.dayWidth,
                                   y: 0, width: TimelineScrollWindow.dayWidth, height: 44)
        }

        let layout = TimelineLayout.make(indexedEvents: indexedEvents, visibleDays: visibleDays)
        let visibleIDs = Set(layout.placements.map { $0.event.id })
        for id in Array(eventButtons.keys) where !visibleIDs.contains(id) {
            eventButtons.removeValue(forKey: id)?.removeFromSuperview()
        }
        for placement in layout.placements {
            let button = eventButtons[placement.event.id] ?? TimelineEventButton(type: .custom)
            if eventButtons[placement.event.id] == nil {
                eventButtons[placement.event.id] = button
                button.addTarget(self, action: #selector(selectedEvent(_:)), for: .touchUpInside)
                addSubview(button)
            }
            let start = max(placement.startDay, bufferedDays.lowerBound)
            let end = min(placement.endDay, bufferedDays.upperBound)
            let isSingleDay = placement.startDay == placement.endDay
            let x = CGFloat(start - scrollWindow.firstDay) * TimelineScrollWindow.dayWidth
            let width = CGFloat(end - start + 1) * TimelineScrollWindow.dayWidth
            button.placement = placement
            button.backgroundColor = UIColor(placement.event.color.color).withAlphaComponent(0.2)
            button.layer.cornerRadius = 12
            button.frame = CGRect(x: x + (isSingleDay ? 10 : 2), y: 48 + CGFloat(placement.lane) * 28,
                                  width: isSingleDay ? 24 : width - 4, height: 24)
            button.accessibilityLabel = placement.event.title
            button.accessibilityValue = placement.event.date.formatted(date: .abbreviated, time: .omitted)
            button.accessibilityHint = "Show event"
        }

        if let first = calendar.date(byAdding: .day, value: visibleDays.lowerBound, to: anchor),
           let last = calendar.date(byAdding: .day, value: visibleDays.upperBound, to: anchor) {
            accessibilityValue = "\(first.formatted(date: .abbreviated, time: .omitted)) – \(last.formatted(date: .abbreviated, time: .omitted))"
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

    @objc private func selectedEvent(_ button: TimelineEventButton) {
        if let event = button.placement?.event { onSelectEvent?(event) }
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
    var placement: TimelineEventPlacement?
}

private final class TimelineDayView: UIView {
    private let weekday = UILabel()
    private let number = UILabel()
    private var isToday = false

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
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(date: Date) {
        weekday.text = date.formatted(.dateTime.weekday(.abbreviated))
        number.text = date.formatted(.dateTime.day())
        isToday = Calendar.current.isDateInToday(date)
        number.backgroundColor = isToday ? tintColor : .clear
        number.textColor = isToday ? .white : .label
        accessibilityLabel = date.formatted(date: .complete, time: .omitted)
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        number.backgroundColor = isToday ? tintColor : .clear
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        weekday.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 16)
        number.frame = CGRect(x: (bounds.width - 24) / 2, y: 20, width: 24, height: 24)
    }
}
