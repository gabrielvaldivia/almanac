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
        cards.onPreferredHeightChange = { [weak self] in
            self?.setNeedsLayout()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(events: [Event], expanded: Bool, highlightedEventID: UUID? = nil) {
        if self.expanded && !expanded { cards.stopScrolling(); cards.collapseStack() }
        if self.expanded != expanded { needsInitialCardSync = true }
        self.expanded = expanded
        monthLabel.isHidden = !expanded
        timeline.setExpanded(expanded)
        timeline.update(events: events)
        timeline.highlightedEventID = highlightedEventID
        cards.update(events: events, anchor: timeline.anchor)
        cards.highlightedEventID = highlightedEventID
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
        let cardHeight = cards.preferredHeight(for: bounds.width, maximumHeight: max(0, bounds.height - 52))
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
    var highlightedEventID: UUID? {
        didSet {
            guard highlightedEventID != oldValue else { return }
            for stack in stacks.values { stack.setHighlighted(eventID: highlightedEventID) }
        }
    }
    var onPreferredHeightChange: (() -> Void)?
    private(set) var expandedDate: Date?

    func preferredHeight(for viewportWidth: CGFloat, maximumHeight: CGFloat) -> CGFloat {
        let width = min(420, max(0, viewportWidth - 32))
        if let group = groups.first(where: { $0.date == expandedDate }) {
            var height: CGFloat = 56
            for event in group.events {
                height += TimelineEventCardLayout(event: event, width: width, traits: traitCollection).height + 12
                // Busy days scroll vertically; only measure enough rows to fill the viewport.
                if height >= maximumHeight { return maximumHeight }
            }
            return height
        }
        guard !groups.isEmpty else { return 0 }
        let position = needsPageLayout ? round(positions.fraction(for: currentDay)) : contentOffset.x / pitch
        let first = min(groups.count - 1, max(0, Int(floor(position))))
        let last = min(groups.count - 1, max(first, Int(ceil(position))))
        // During a swipe, both neighboring cards need room for their full content.
        let height = groups[first...last].map { group in
            let front = group.events.first(where: { $0.id == selectedEvents[group.date] }) ?? group.events[0]
            return TimelineEventCardLayout(event: front, width: width, stackCount: group.events.count,
                                           traits: traitCollection).height + 40
        }.max() ?? 0
        return min(maximumHeight, height)
    }
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
    private var pitch: CGFloat { max(1, bounds.width) }

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        alwaysBounceVertical = false
        bounces = false
        isPagingEnabled = true
        isDirectionalLockEnabled = true
        decelerationRate = .fast
        contentInsetAdjustmentBehavior = .never
        scrollsToTop = false
        backgroundColor = .clear
        accessibilityIdentifier = "timelineEventCards"
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: TimelineCardsScrollView, _) in
            view.onPreferredHeightChange?()
            view.setNeedsLayout()
        }
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
        if let expandedDate, !groups.contains(where: { $0.date == expandedDate && $0.events.count > 1 }) {
            collapseStack()
        }
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
        if let expandedDate, groups.indices.contains(page), groups[page].date != expandedDate { collapseStack() }
        guard page != targetPage else { return }
        targetPage = page
        onPreferredHeightChange?()
        applyingPosition = true
        setContentOffset(CGPoint(x: CGFloat(page) * pitch, y: 0),
                         animated: animated && window != nil && !UIAccessibility.isReduceMotionEnabled)
        applyingPosition = false
        setNeedsLayout()
    }

    func show(event: Event) {
        guard let index = groups.firstIndex(where: { $0.events.contains { $0.id == event.id } }) else { return }
        if let expandedDate, expandedDate != groups[index].date { collapseStack() }
        selectedEvents[groups[index].date] = event.id
        onPreferredHeightChange?()
        followingTimeline = false
        targetPage = nil
        // Moving the cards also moves the timeline to this day.
        setContentOffset(CGPoint(x: CGFloat(index) * pitch, y: 0), animated: !UIAccessibility.isReduceMotionEnabled)
        setNeedsLayout()
        superview?.layoutIfNeeded()
        layoutIfNeeded()
        stacks[groups[index].date]?.show(event: event)
    }

    func toggleStack(for date: Date) {
        guard let group = groups.first(where: { $0.date == date }), group.events.count > 1 else { return }
        stopScrolling()
        expandedDate = expandedDate == date ? nil : date
        setNeedsLayout()
        onPreferredHeightChange?()
        superview?.layoutIfNeeded()
        layoutIfNeeded()
        UISelectionFeedbackGenerator().selectionChanged()
        if expandedDate != nil { stacks[date]?.animateExpansion() }
    }

    func collapseStack() {
        guard expandedDate != nil else { return }
        expandedDate = nil
        setNeedsLayout()
        onPreferredHeightChange?()
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
                stack.onToggleStack = { [weak self] in self?.toggleStack(for: group.date) }
            }
            stack.configure(group: group, selectedID: selectedEvents[group.date], expanded: expandedDate == group.date)
            stack.setHighlighted(eventID: highlightedEventID)
            stack.frame = CGRect(x: CGFloat(index) * pitch, y: 0, width: bounds.width, height: bounds.height)
        }
        accessibilityValue = "Page \(min(groups.count, Int(round(contentOffset.x / pitch)) + 1)) of \(groups.count)"
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !applyingPosition, !followingTimeline, let day = positions.day(for: contentOffset.x / pitch) {
            currentDay = day
            onDayPositionChange?(day)
        }
        if !applyingPosition { onPreferredHeightChange?() }
        setNeedsLayout()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        collapseStack()
        followingTimeline = false
        targetPage = nil
        onBeginDragging?()
    }

}

private final class TimelineCardStackView: UIView, UITableViewDataSource, UITableViewDelegate {
    var onEditEvent: ((Event) -> Void)?
    var onToggleStack: (() -> Void)?
    private let backCards = [UIView(), UIView()]
    private let frontCard = TimelineEventCardView()
    private let table = UITableView(frame: .zero, style: .plain)
    private let collapseButton = UIButton(type: .system)
    private var group: EventListDay?
    private var expanded = false
    private var highlightedEventID: UUID?
    private var rowHeights: [UUID: CGFloat] = [:]
    private var measuredWidth: CGFloat = 0
    private var measuredTextSize: UIContentSizeCategory?

    override init(frame: CGRect) {
        super.init(frame: frame)
        for card in backCards {
            TimelineEventCardView.style(card)
            addSubview(card)
        }
        addSubview(frontCard)
        addSubview(table)
        addSubview(collapseButton)
        frontCard.onTap = { [weak self] event in
            guard let self else { return }
            if (self.group?.events.count ?? 0) > 1 { self.onToggleStack?() }
            else { self.onEditEvent?(event) }
        }
        frontCard.onToggleStack = { [weak self] in self?.onToggleStack?() }
        table.dataSource = self
        table.delegate = self
        table.register(TimelineEventCardCell.self, forCellReuseIdentifier: "event")
        table.estimatedRowHeight = 0
        table.separatorStyle = .none
        table.backgroundColor = .clear
        table.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 4, right: 0)
        table.contentInsetAdjustmentBehavior = .never
        table.showsVerticalScrollIndicator = false
        table.scrollsToTop = false
        table.isDirectionalLockEnabled = true
        table.accessibilityIdentifier = "timelineExpandedStack"
        collapseButton.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
        collapseButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        collapseButton.semanticContentAttribute = .forceRightToLeft
        collapseButton.backgroundColor = .secondarySystemGroupedBackground
        collapseButton.layer.cornerRadius = 22
        collapseButton.addTarget(self, action: #selector(collapse), for: .touchUpInside)
        collapseButton.accessibilityLabel = "Collapse event stack"
        collapseButton.accessibilityIdentifier = "timelineCollapseStack"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(group: EventListDay, selectedID: UUID?, expanded: Bool) {
        let changed = self.group?.events != group.events || self.group?.date != group.date
        self.group = group
        self.expanded = expanded
        guard let front = group.events.first(where: { $0.id == selectedID }) ?? group.events.first else { return }
        frontCard.configure(event: front, date: group.date, stackCount: group.events.count)
        frontCard.isHidden = expanded
        for (index, card) in backCards.enumerated() { card.isHidden = expanded || group.events.count < (3 - index) }
        table.isHidden = !expanded
        collapseButton.isHidden = !expanded
        collapseButton.setTitle("\(group.events.count) events  ", for: .normal)
        if changed { rowHeights.removeAll(); table.reloadData() }
        setNeedsLayout()
    }

    func setHighlighted(eventID: UUID?) {
        highlightedEventID = eventID
        frontCard.setHighlighted(eventID: eventID)
        for case let cell as TimelineEventCardCell in table.visibleCells { cell.card.setHighlighted(eventID: eventID) }
    }

    func show(event: Event) {
        guard expanded, let index = group?.events.firstIndex(where: { $0.id == event.id }) else { return }
        layoutIfNeeded()
        table.scrollToRow(at: IndexPath(row: index, section: 0), at: .none, animated: !UIAccessibility.isReduceMotionEnabled)
    }

    func animateExpansion() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        layoutIfNeeded()
        table.layoutIfNeeded()
        for cell in table.visibleCells {
            cell.transform = CGAffineTransform(translationX: 0, y: min(60, table.bounds.height - cell.frame.minY))
            cell.alpha = 0
        }
        UIView.animate(withDuration: 0.18, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
            for cell in self.table.visibleCells { cell.transform = .identity; cell.alpha = 1 }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = min(420, max(0, bounds.width - 32))
        let height = frontCard.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        let frontFrame = CGRect(x: (bounds.width - width) / 2, y: bounds.height - height - 16,
                                width: width, height: height)
        if measuredWidth != width || measuredTextSize != traitCollection.preferredContentSizeCategory {
            measuredWidth = width
            measuredTextSize = traitCollection.preferredContentSizeCategory
            rowHeights.removeAll()
            table.reloadData()
        }
        for (index, card) in backCards.enumerated() {
            let inset = CGFloat(2 - index) * 7
            card.frame = frontFrame.insetBy(dx: inset, dy: 0).offsetBy(dx: 0, dy: -inset)
            card.layer.shadowPath = UIBezierPath(roundedRect: card.bounds, cornerRadius: 20).cgPath
        }
        frontCard.frame = frontFrame
        let buttonWidth = max(116, collapseButton.sizeThatFits(bounds.size).width + 32)
        collapseButton.frame = CGRect(x: (bounds.width - buttonWidth) / 2, y: 0, width: buttonWidth, height: 44)
        table.frame = CGRect(x: 0, y: 44, width: bounds.width, height: max(0, bounds.height - 44))
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { group?.events.count ?? 0 }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let event = group?.events[indexPath.row] else { return 0 }
        if let height = rowHeights[event.id] { return height }
        let width = min(420, max(0, bounds.width - 32))
        let height = TimelineEventCardLayout(event: event, width: width, traits: traitCollection).height + 12
        rowHeights[event.id] = height
        return height
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "event", for: indexPath) as! TimelineEventCardCell
        if let group {
            cell.card.configure(event: group.events[indexPath.row], date: group.date)
            cell.card.setHighlighted(eventID: highlightedEventID)
            cell.card.onTap = { [weak self] in self?.onEditEvent?($0) }
        }
        return cell
    }

    @objc private func collapse() { onToggleStack?() }
}

private final class TimelineEventCardCell: UITableViewCell {
    let card = TimelineEventCardView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(card)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        transform = .identity
        alpha = 1
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = min(420, max(0, contentView.bounds.width - 32))
        card.frame = CGRect(x: (contentView.bounds.width - width) / 2, y: 0,
                            width: width, height: max(0, contentView.bounds.height - 12))
    }
}

private final class TimelineEventCardView: UIView {
    var onTap: ((Event) -> Void)?
    var onToggleStack: (() -> Void)?
    private let editButton = UIButton(type: .custom)
    private let countdownLabel = UILabel()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let colorLine = UIView()
    private let countButton = UIButton(type: .system)
    private var event: Event?
    private var stackCount = 1

    static func style(_ card: UIView) {
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 20
        card.layer.borderColor = UIColor.separator.withAlphaComponent(0.15).cgColor
        card.layer.borderWidth = 0.5
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.09
        card.layer.shadowRadius = 10
        card.layer.shadowOffset = CGSize(width: 0, height: 3)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        Self.style(self)
        addSubview(editButton)
        addSubview(countButton)
        for label in [countdownLabel, titleLabel, detailLabel] { editButton.addSubview(label) }
        editButton.addSubview(colorLine)
        countdownLabel.font = .preferredFont(forTextStyle: .caption1)
        countdownLabel.textColor = .secondaryLabel
        countdownLabel.numberOfLines = 0
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 0
        detailLabel.font = .preferredFont(forTextStyle: .footnote)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0
        for label in [countdownLabel, titleLabel, detailLabel] { label.adjustsFontForContentSizeCategory = true }
        colorLine.layer.cornerRadius = 2
        editButton.addTarget(self, action: #selector(tapEvent), for: .touchUpInside)
        countButton.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
        countButton.addTarget(self, action: #selector(toggleStack), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setHighlighted(eventID: UUID?) {
        let highlighted = eventID != nil && event?.id == eventID
        layer.borderWidth = highlighted ? 2 : 0.5
        layer.borderColor = highlighted
            ? event.map { UIColor($0.color.color).cgColor }
            : UIColor.separator.withAlphaComponent(0.15).cgColor
        if highlighted { editButton.accessibilityTraits.insert(.selected) }
        else { editButton.accessibilityTraits.remove(.selected) }
    }

    func configure(event: Event, date: Date, stackCount: Int = 1) {
        self.event = event
        self.stackCount = stackCount
        titleLabel.text = event.title
        countdownLabel.text = event.date.relativeDate(to: event.endDate)
        detailLabel.text = EventDateText.range(start: event.date, end: event.endDate, reference: Date())
        colorLine.backgroundColor = UIColor(event.color.color)
        countButton.isHidden = stackCount < 2
        countButton.setTitle("\(stackCount) events", for: .normal)
        countButton.accessibilityLabel = "Show all \(stackCount) events on \(date.formatted(date: .abbreviated, time: .omitted))"
        countButton.accessibilityIdentifier = "timelineStackEvents"
        editButton.accessibilityLabel = event.title
        editButton.accessibilityValue = "\(countdownLabel.text ?? ""), \(detailLabel.text ?? "")"
        editButton.accessibilityHint = stackCount > 1 ? "Expand event stack" : "Edit event"
        editButton.accessibilityIdentifier = "timelineCard-\(event.id.uuidString)"
        setNeedsLayout()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard let event else { return .zero }
        let layout = TimelineEventCardLayout(event: event, width: size.width, stackCount: stackCount, traits: traitCollection)
        return CGSize(width: size.width, height: layout.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let event else { return }
        let layout = TimelineEventCardLayout(event: event, width: bounds.width, stackCount: stackCount, traits: traitCollection)
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 20).cgPath
        editButton.frame = bounds
        countdownLabel.font = layout.countdownFont
        titleLabel.font = layout.titleFont
        detailLabel.font = layout.detailFont
        countButton.titleLabel?.font = layout.countdownFont
        countdownLabel.frame = layout.countdown
        titleLabel.frame = layout.title
        detailLabel.frame = layout.detail
        countButton.frame = layout.countButton
        colorLine.frame = CGRect(x: 16, y: layout.title.minY, width: 3,
                                 height: layout.detail.maxY - layout.title.minY)
    }

    @objc private func tapEvent() { if let event { onTap?(event) } }
    @objc private func toggleStack() { onToggleStack?() }
}

/// Shared text measurements keep carousel cards and vertical rows fitted to the
/// same content, including wrapped titles, date ranges, and Dynamic Type.
struct TimelineEventCardLayout {
    let countdownFont: UIFont
    let titleFont: UIFont
    let detailFont: UIFont
    let countdown: CGRect
    let title: CGRect
    let detail: CGRect
    let countButton: CGRect
    var height: CGFloat { detail.maxY + 12 }

    init(event: Event, width: CGFloat, stackCount: Int = 1, traits: UITraitCollection, now: Date = Date()) {
        countdownFont = .preferredFont(forTextStyle: .caption1, compatibleWith: traits)
        titleFont = UIFontMetrics(forTextStyle: .headline).scaledFont(
            for: .systemFont(ofSize: 17, weight: .medium), compatibleWith: traits)
        detailFont = .preferredFont(forTextStyle: .footnote, compatibleWith: traits)
        let countWidth = stackCount > 1
            ? max(88, ceil(("\(stackCount) events" as NSString).size(withAttributes: [.font: countdownFont]).width) + 16) : 0
        let captionWidth = max(1, width - 32 - countWidth)
        countdown = CGRect(x: 16, y: 12, width: captionWidth,
                           height: Self.textHeight(event.date.relativeDate(to: event.endDate, now: now),
                                                   font: countdownFont, width: captionWidth))
        let textWidth = max(1, width - 44)
        title = CGRect(x: 28, y: countdown.maxY + 8, width: textWidth,
                       height: Self.textHeight(event.title, font: titleFont, width: textWidth))
        detail = CGRect(x: 28, y: title.maxY + 4, width: textWidth,
                        height: Self.textHeight(EventDateText.range(start: event.date, end: event.endDate, reference: now),
                                                font: detailFont, width: textWidth))
        countButton = CGRect(x: max(0, width - countWidth - 4), y: max(0, countdown.midY - 22),
                             width: countWidth, height: 44)
    }

    private static func textHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let bounds = (text as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                   options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                   attributes: [.font: font], context: nil)
        return ceil(max(font.lineHeight, bounds.height))
    }
}
