import UIKit

/// Maps calendar days to a continuous carousel position, including gaps between
/// events. Using calendar-day offsets keeps the two scroll surfaces in sync at DST.
struct TimelineCardPositions {
    var days: [Int]

    func fraction(for day: CGFloat) -> CGFloat {
        guard let first = days.first, let last = days.last, days.count > 1 else { return 0 }
        if day <= CGFloat(first) { return 0 }
        if day >= CGFloat(last) { return CGFloat(days.count - 1) }
        var lower = 0
        var upper = days.count - 1
        while upper - lower > 1 {
            let middle = (lower + upper) / 2
            if CGFloat(days[middle]) <= day { lower = middle } else { upper = middle }
        }
        return CGFloat(lower) + (day - CGFloat(days[lower])) / CGFloat(days[upper] - days[lower])
    }

    func day(for fraction: CGFloat) -> CGFloat? {
        guard !days.isEmpty else { return nil }
        let position = min(CGFloat(days.count - 1), max(0, fraction))
        let lower = Int(floor(position))
        let upper = min(days.count - 1, lower + 1)
        return CGFloat(days[lower]) + (position - CGFloat(lower)) * CGFloat(days[upper] - days[lower])
    }
}

/// The timeline selects a card page; dragging a card page moves the timeline.
/// Synchronizing in UIKit avoids feedback through SwiftUI layout updates.
final class TimelineContainerView: UIView {
    let timeline = TimelineScrollView()
    let cards = TimelineCardsScrollView()
    var onSelectEvent: ((Event) -> Void)?
    var onEditEvent: ((Event) -> Void)?
    private var expanded = false
    private var synchronizing = false
    private var lastLayoutBounds: CGRect = .zero
    private var needsInitialCardSync = true
    private let emptyLabel = UILabel()
    private let monthLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(timeline)
        addSubview(cards)
        monthLabel.font = .preferredFont(forTextStyle: .headline)
        monthLabel.adjustsFontForContentSizeCategory = true
        monthLabel.accessibilityTraits = .header
        addSubview(monthLabel)
        emptyLabel.text = "No events to show"
        emptyLabel.font = .preferredFont(forTextStyle: .body)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        addSubview(emptyLabel)

        timeline.onScrollPositionChange = { [weak self] day in
            guard let self, self.expanded, !self.synchronizing else { return }
            self.updateMonth()
            self.synchronizing = true
            self.cards.setDayPosition(day)
            self.synchronizing = false
        }
        cards.onDayPositionChange = { [weak self] day in
            guard let self, self.expanded, !self.synchronizing else { return }
            self.synchronizing = true
            self.timeline.setDayPosition(day)
            self.updateMonth()
            self.synchronizing = false
        }
        timeline.onBeginDragging = { [weak self] in self?.cards.stopScrolling() }
        cards.onBeginDragging = { [weak self] in
            guard let self else { return }
            self.timeline.setContentOffset(self.timeline.contentOffset, animated: false)
        }
        timeline.onSelectEvent = { [weak self] event in
            guard let self else { return }
            if self.expanded { self.cards.show(event: event) }
            self.onSelectEvent?(event)
        }
        cards.onEditEvent = { [weak self] in self?.onEditEvent?($0) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(events: [Event], expanded: Bool) {
        if self.expanded && !expanded { cards.stopScrolling() }
        if self.expanded != expanded { needsInitialCardSync = true }
        self.expanded = expanded
        monthLabel.isHidden = !expanded
        timeline.setExpanded(expanded)
        timeline.update(events: events)
        cards.update(events: events, anchor: timeline.anchor)
        cards.isHidden = !expanded || events.isEmpty
        emptyLabel.isHidden = !expanded || !events.isEmpty
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let headerHeight = expanded ? ceil(monthLabel.font.lineHeight) + 12 : 0
        monthLabel.frame = CGRect(x: 16, y: 0, width: max(0, bounds.width - 32), height: headerHeight)
        timeline.frame = CGRect(x: 0, y: headerHeight, width: bounds.width, height: max(0, bounds.height - headerHeight))
        updateMonth()
        let cardHeight = min(max(0, bounds.height - 52), TimelineCardStackView.preferredHeight)
        cards.frame = CGRect(x: 0, y: bounds.height - cardHeight, width: bounds.width, height: cardHeight)
        emptyLabel.frame = CGRect(x: 16, y: max(52, bounds.height - 80), width: max(0, bounds.width - 32), height: 44)
        timeline.bottomOverlayHeight = expanded ? cardHeight : 0
        if expanded, needsInitialCardSync || lastLayoutBounds != bounds {
            synchronizing = true
            cards.setDayPosition(timeline.dayPosition, animated: false)
            synchronizing = false
        }
        needsInitialCardSync = false
        lastLayoutBounds = bounds
    }

    private func updateMonth() {
        let calendar = Calendar.current
        if let date = calendar.date(byAdding: .day, value: Int(floor(timeline.dayPosition)), to: timeline.anchor) {
            monthLabel.text = date.formatted(.dateTime.month(.wide).year())
        }
    }
}

final class TimelineCardsScrollView: UIScrollView, UIScrollViewDelegate {
    var onDayPositionChange: ((CGFloat) -> Void)?
    var onEditEvent: ((Event) -> Void)?
    var onBeginDragging: (() -> Void)?
    private(set) var groups: [EventListDay] = []
    private var positions = TimelineCardPositions(days: [])
    private var stacks: [Date: TimelineCardStackView] = [:]
    private var selectedEvents: [Date: UUID] = [:]
    private var eventSnapshot: [Event] = []
    private var groupedToday: Date?
    private var applyingPosition = false
    private var followingTimeline = true
    private var layingOut = false
    private var lastLayoutWidth: CGFloat = 0
    private var needsPageLayout = true
    private var targetPage: Int?
    private var currentDay: CGFloat = 0
    private var cardWidth: CGFloat { min(420, max(0, bounds.width - 32)) }
    private var pitch: CGFloat { max(1, bounds.width) }

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        alwaysBounceVertical = false
        bounces = false
        isPagingEnabled = true
        decelerationRate = .fast
        contentInsetAdjustmentBehavior = .never
        scrollsToTop = false
        backgroundColor = .clear
        accessibilityIdentifier = "timelineEventCards"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(events: [Event], anchor: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let unchanged = eventSnapshot.count == events.count && zip(eventSnapshot, events).allSatisfy {
            $0.id == $1.id && $0.title == $1.title && $0.date == $1.date &&
            $0.endDate == $1.endDate && $0.color.color == $1.color.color
        }
        guard !unchanged || groupedToday != today else { return }
        stopScrolling()
        eventSnapshot = events
        groupedToday = today
        groups = EventListDay.group(events: events, today: today)
        positions = TimelineCardPositions(days: groups.map { calendar.dateComponents([.day], from: anchor, to: $0.date).day ?? 0 })
        selectedEvents = selectedEvents.filter { date, id in groups.contains { $0.date == date && $0.events.contains { $0.id == id } } }
        stacks.values.forEach { $0.removeFromSuperview() }
        stacks.removeAll()
        needsPageLayout = true
        targetPage = nil
        setNeedsLayout()
    }

    func stopScrolling() {
        applyingPosition = true
        setContentOffset(contentOffset, animated: false)
        applyingPosition = false
    }

    func setDayPosition(_ day: CGFloat, animated: Bool = true) {
        currentDay = day
        followingTimeline = true
        let page = Int(round(positions.fraction(for: day)))
        guard page != targetPage else { return }
        targetPage = page
        applyingPosition = true
        setContentOffset(CGPoint(x: CGFloat(page) * pitch, y: 0),
                         animated: animated && window != nil && !UIAccessibility.isReduceMotionEnabled)
        applyingPosition = false
        setNeedsLayout()
    }

    func show(event: Event) {
        guard let index = groups.firstIndex(where: { $0.events.contains { $0.id == event.id } }) else { return }
        selectedEvents[groups[index].date] = event.id
        followingTimeline = false
        targetPage = nil
        // Moving the cards also moves the timeline to this day.
        setContentOffset(CGPoint(x: CGFloat(index) * pitch, y: 0), animated: !UIAccessibility.isReduceMotionEnabled)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0, !layingOut else { return }
        layingOut = true
        defer { layingOut = false }
        applyingPosition = true
        contentSize = CGSize(width: bounds.width + CGFloat(max(0, groups.count - 1)) * pitch, height: bounds.height)
        if lastLayoutWidth != bounds.width || needsPageLayout {
            contentOffset.x = round(positions.fraction(for: currentDay)) * pitch
            lastLayoutWidth = bounds.width
            needsPageLayout = false
        }
        applyingPosition = false
        let first = max(0, Int(floor(contentOffset.x / pitch)) - 1)
        let last = min(groups.count - 1, Int(ceil((contentOffset.x + bounds.width) / pitch)))
        guard first <= last else { return }
        let visibleDates = Set(groups[first...last].map(\.date))
        for date in Array(stacks.keys) where !visibleDates.contains(date) {
            stacks.removeValue(forKey: date)?.removeFromSuperview()
        }
        for index in first...last {
            let group = groups[index]
            let stack = stacks[group.date] ?? TimelineCardStackView()
            if stacks[group.date] == nil {
                stacks[group.date] = stack
                addSubview(stack)
                stack.onEditEvent = { [weak self] in self?.onEditEvent?($0) }
            }
            stack.configure(group: group, selectedID: selectedEvents[group.date])
            stack.frame = CGRect(x: (bounds.width - cardWidth) / 2 + CGFloat(index) * pitch,
                                 y: 0, width: cardWidth, height: bounds.height)
        }
        accessibilityValue = "Page \(min(groups.count, Int(round(contentOffset.x / pitch)) + 1)) of \(groups.count)"
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !applyingPosition, !followingTimeline, let day = positions.day(for: contentOffset.x / pitch) {
            currentDay = day
            onDayPositionChange?(day)
        }
        setNeedsLayout()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        followingTimeline = false
        targetPage = nil
        onBeginDragging?()
    }

}

private final class TimelineCardStackView: UIView {
    static var preferredHeight: CGFloat { UIFontMetrics(forTextStyle: .body).scaledValue(for: 168) + 32 }
    var onEditEvent: ((Event) -> Void)?
    private let backCards = [UIView(), UIView()]
    private let surface = UIView()
    private let editButton = UIButton(type: .custom)
    private let dateLabel = UILabel()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let colorLine = UIView()
    private let countButton = UIButton(type: .system)
    private var event: Event?
    private var groupDate: Date?

    override init(frame: CGRect) {
        super.init(frame: frame)
        for card in backCards + [surface] {
            card.backgroundColor = .secondarySystemGroupedBackground
            card.layer.cornerRadius = 20
            card.layer.borderColor = UIColor.separator.withAlphaComponent(0.15).cgColor
            card.layer.borderWidth = 0.5
            card.layer.shadowColor = UIColor.black.cgColor
            card.layer.shadowOpacity = 0.09
            card.layer.shadowRadius = 10
            card.layer.shadowOffset = CGSize(width: 0, height: 3)
            addSubview(card)
        }
        surface.addSubview(editButton)
        surface.addSubview(countButton)
        for label in [dateLabel, titleLabel, detailLabel] { editButton.addSubview(label) }
        editButton.addSubview(colorLine)
        dateLabel.font = .preferredFont(forTextStyle: .caption1)
        dateLabel.textColor = .secondaryLabel
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 2
        detailLabel.font = .preferredFont(forTextStyle: .footnote)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 2
        for label in [dateLabel, titleLabel, detailLabel] { label.adjustsFontForContentSizeCategory = true }
        colorLine.layer.cornerRadius = 2
        editButton.addTarget(self, action: #selector(editEvent), for: .touchUpInside)
        countButton.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
        countButton.showsMenuAsPrimaryAction = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(group: EventListDay, selectedID: UUID?) {
        guard let front = group.events.first(where: { $0.id == selectedID }) ?? group.events.first else { return }
        guard event?.id != front.id || groupDate != group.date else { return }
        event = front
        groupDate = group.date
        titleLabel.text = front.title
        dateLabel.text = group.date.formatted(.dateTime.month(.abbreviated).day().year())
        detailLabel.text = EventDateText.range(start: front.date, end: front.endDate, reference: Date())
        colorLine.backgroundColor = UIColor(front.color.color)
        for (index, card) in backCards.enumerated() { card.isHidden = group.events.count < (3 - index) }
        countButton.isHidden = group.events.count < 2
        countButton.setTitle("\(group.events.count) events", for: .normal)
        countButton.accessibilityLabel = "Show all \(group.events.count) events on \(dateLabel.text ?? "this day")"
        countButton.accessibilityIdentifier = "timelineStackEvents"
        countButton.menu = UIMenu(children: group.events.map { event in
            UIAction(title: event.title) { [weak self] _ in self?.onEditEvent?(event) }
        })
        editButton.accessibilityLabel = front.title
        editButton.accessibilityValue = "\(dateLabel.text ?? ""), \(detailLabel.text ?? "")"
        editButton.accessibilityHint = "Edit event"
        editButton.accessibilityIdentifier = "timelineCard-\(front.id.uuidString)"
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let frontFrame = bounds.inset(by: UIEdgeInsets(top: 24, left: 0, bottom: 16, right: 0))
        for (index, card) in backCards.enumerated() {
            let inset = CGFloat(2 - index) * 7
            card.frame = frontFrame.insetBy(dx: inset, dy: 0).offsetBy(dx: 0, dy: -inset)
            card.layer.shadowPath = UIBezierPath(roundedRect: card.bounds, cornerRadius: 20).cgPath
        }
        surface.frame = frontFrame
        surface.layer.shadowPath = UIBezierPath(roundedRect: surface.bounds, cornerRadius: 20).cgPath
        editButton.frame = surface.bounds
        let captionHeight = ceil(dateLabel.font.lineHeight)
        countButton.frame = CGRect(x: max(0, surface.bounds.width - 100), y: 2, width: 88, height: 44)
        dateLabel.frame = CGRect(x: 16, y: 16, width: max(0, surface.bounds.width - (countButton.isHidden ? 32 : 116)), height: captionHeight)
        let titleY = 16 + captionHeight + 12
        let titleHeight = min(titleLabel.font.lineHeight * 2, max(0, surface.bounds.height - titleY - detailLabel.font.lineHeight * 2 - 24))
        titleLabel.frame = CGRect(x: 28, y: titleY, width: surface.bounds.width - 44, height: titleHeight)
        detailLabel.frame = CGRect(x: 28, y: titleLabel.frame.maxY + 4, width: surface.bounds.width - 44,
                                  height: max(0, surface.bounds.height - titleLabel.frame.maxY - 20))
        colorLine.frame = CGRect(x: 16, y: titleY, width: 3, height: max(0, surface.bounds.height - titleY - 16))
    }

    @objc private func editEvent() { if let event { onEditEvent?(event) } }
}
