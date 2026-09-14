import XCTest
import UIKit
@testable import Up_Next

final class TimelineTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private var anchor: Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: 7))!
    }

    private func event(_ title: String, start: Int, end: Int? = nil) -> Event {
        Event(title: title, date: calendar.date(byAdding: .day, value: start, to: anchor)!,
              endDate: end.flatMap { calendar.date(byAdding: .day, value: $0, to: anchor) },
              color: CodableColor(color: .blue))
    }

    func testRecyclingPreservesDatesAndFractionalPositionInBothDirections() {
        for direction: CGFloat in [-1, 1] {
            var window = TimelineScrollWindow()
            var offset = window.initialOffset + 13.5
            for _ in 0..<1000 {
                offset += direction * 70 * TimelineScrollWindow.dayWidth
                let absolutePosition = CGFloat(window.firstDay) + offset / TimelineScrollWindow.dayWidth
                let visibleBefore = window.visibleDays(offset: offset, width: 393)
                offset = window.recenter(offset: offset)
                XCTAssertEqual(CGFloat(window.firstDay) + offset / TimelineScrollWindow.dayWidth,
                               absolutePosition, accuracy: 0.000001)
                XCTAssertEqual(window.visibleDays(offset: offset, width: 393), visibleBefore)
                XCTAssertEqual(window.contentWidth, 181 * 44)
                XCTAssertGreaterThan(offset, 0)
                XCTAssertLessThan(offset + 393, window.contentWidth)
            }
        }
    }

    func testViewportIncludesPartiallyVisibleDays() {
        let window = TimelineScrollWindow()
        XCTAssertEqual(window.visibleDays(offset: window.initialOffset, width: 88), 0...1)
        XCTAssertEqual(window.visibleDays(offset: window.initialOffset + 1, width: 88), 0...2)
        XCTAssertEqual(window.visibleDays(offset: window.initialOffset - 1, width: 88), -1...1)
    }

    func testHandleHasThreeStopsAndRespectsAvailableHeight() {
        let heights = TimelinePanelHeights(compact: 108, expanded: 600)
        XCTAssertEqual(heights.nearest(to: 20), .collapsed)
        XCTAssertEqual(heights.nearest(to: 180), .compact)
        XCTAssertEqual(heights.nearest(to: 450), .expanded)
        XCTAssertEqual(heights.height(for: .expanded), 600)
        XCTAssertEqual(TimelinePanelHeights(compact: 500, expanded: 200).compact, 200)
        XCTAssertEqual(TimelinePanelHeights(compact: 100, expanded: -10).expanded, 0)
    }

    func testCardPositionsInterpolateSparseDaysInBothDirections() {
        let positions = TimelineCardPositions(days: [-20, 0, 1, 30, 365])
        for day: CGFloat in [-20, -10.5, 0, 0.25, 1, 17, 30, 200, 365] {
            XCTAssertEqual(positions.day(for: positions.fraction(for: day))!, day, accuracy: 0.00001)
        }
        XCTAssertEqual(positions.fraction(for: -100), 0)
        XCTAssertEqual(positions.fraction(for: 1000), 4)
        XCTAssertNil(TimelineCardPositions(days: []).day(for: 0))
        XCTAssertEqual(TimelineCardPositions(days: [5]).day(for: 100), 5)
    }

    @MainActor
    func testFloatingCardsGroupSameDayAndStaySynchronizedWithTimeline() {
        let container = TimelineContainerView(frame: CGRect(x: 0, y: 0, width: 393, height: 650))
        let today = Calendar.current.startOfDay(for: Date())
        let events = [
            Event(title: "First", date: today, color: CodableColor(color: .blue)),
            Event(title: "Second", date: today, color: CodableColor(color: .blue)),
            Event(title: "Later", date: Calendar.current.date(byAdding: .day, value: 10, to: today)!, color: CodableColor(color: .blue))
        ]
        container.update(events: events, expanded: true)
        container.layoutIfNeeded()
        container.timeline.layoutIfNeeded()
        container.cards.layoutIfNeeded()
        XCTAssertEqual(container.cards.groups.map { $0.events.count }, [2, 1])
        XCTAssertFalse(container.cards.isHidden)

        container.timeline.setDayPosition(4.25)
        container.cards.layoutIfNeeded()
        XCTAssertEqual(container.cards.contentOffset.x, 0, accuracy: 0.001)
        container.timeline.setDayPosition(5.25)
        container.cards.layoutIfNeeded()
        XCTAssertEqual(container.cards.contentOffset.x, container.cards.bounds.width, accuracy: 0.001)
        XCTAssertEqual(container.timeline.dayPosition, 5.25, accuracy: 0.001, "Selecting a card page must not snap the timeline away from the user's date")

        container.cards.scrollViewWillBeginDragging(container.cards)
        container.cards.contentOffset.x *= 0.5
        // UIScrollView rounds fractional offsets to the screen's pixel grid.
        XCTAssertEqual(container.timeline.dayPosition * TimelineScrollWindow.dayWidth,
                       5 * TimelineScrollWindow.dayWidth, accuracy: 0.5)
        container.timeline.scrollToToday(animated: false)
        container.cards.layoutIfNeeded()
        XCTAssertEqual(container.cards.contentOffset.x, 0, accuracy: 0.001)

        container.update(events: events, expanded: false)
        XCTAssertTrue(container.cards.isHidden)
        XCTAssertTrue(container.timeline.isTodayVisible)
    }

    @MainActor
    func testExpandedStackScrollsManyEventsWithoutMovingTimelineAndCollapsesWhenLeavingDay() {
        let container = TimelineContainerView(frame: CGRect(x: 0, y: 0, width: 393, height: 650))
        let today = Calendar.current.startOfDay(for: Date())
        let events = (0..<1000).map { index in
            Event(title: "Same day \(index)", date: today, color: CodableColor(color: .blue))
        }
        let later = Event(title: "Later", date: Calendar.current.date(byAdding: .day, value: 10, to: today)!,
                          color: CodableColor(color: .blue))
        container.update(events: events + [later], expanded: true)
        container.layoutIfNeeded()
        container.cards.layoutIfNeeded()
        let collapsedHeight = container.cards.bounds.height
        let day = container.timeline.dayPosition
        container.cards.toggleStack(for: today)
        container.layoutIfNeeded()
        container.cards.layoutIfNeeded()
        XCTAssertEqual(container.cards.expandedDate, today)
        XCTAssertGreaterThan(container.cards.bounds.height, collapsedHeight)
        XCTAssertLessThanOrEqual(container.cards.bounds.height, container.bounds.height - 52)
        XCTAssertEqual(container.timeline.dayPosition, day, accuracy: 0.001)

        func descendants(_ view: UIView) -> [UIView] { view.subviews.flatMap { [$0] + descendants($0) } }
        let table = descendants(container.cards).compactMap { $0 as? UITableView }.first { !$0.isHidden }!
        table.superview?.layoutIfNeeded()
        table.layoutIfNeeded()
        XCTAssertEqual(table.numberOfRows(inSection: 0), 1000)
        XCTAssertLessThan(table.visibleCells.count, 10)
        table.scrollToRow(at: IndexPath(row: 999, section: 0), at: .bottom, animated: false)
        table.layoutIfNeeded()
        let lastEvent = container.cards.groups[0].events.last!
        let button = descendants(table).compactMap { $0 as? UIButton }.first {
            $0.accessibilityIdentifier == "timelineCard-\(lastEvent.id.uuidString)"
        }!
        var editedID: UUID?
        container.onEditEvent = { editedID = $0.id }
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(editedID, lastEvent.id)
        XCTAssertEqual(container.timeline.dayPosition, day, accuracy: 0.001)

        container.timeline.setDayPosition(10)
        container.layoutIfNeeded()
        XCTAssertNil(container.cards.expandedDate)
        XCTAssertEqual(container.cards.bounds.height, collapsedHeight)
        container.cards.setDayPosition(0, animated: false)
        container.cards.toggleStack(for: today)
        container.update(events: [later], expanded: true)
        XCTAssertNil(container.cards.expandedDate, "Filtering away a group must clear its expansion")
    }

    @MainActor
    func testCardPagingUsesTheTimelinesOriginalCalendarAnchor() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let cards = TimelineCardsScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: 200))
        cards.update(events: [Event(title: "Today", date: today, color: CodableColor(color: .blue)),
                              Event(title: "Tomorrow", date: tomorrow, color: CodableColor(color: .blue))], anchor: yesterday)
        cards.setDayPosition(1.25, animated: false)
        cards.layoutIfNeeded()
        XCTAssertEqual(cards.contentOffset.x, 0, accuracy: 0.001)
        cards.setDayPosition(2, animated: false)
        cards.layoutIfNeeded()
        XCTAssertEqual(cards.contentOffset.x, 393, accuracy: 0.001)
    }

    @MainActor
    func testFullTimelineResizeAndFilteringKeepCardsBounded() {
        let container = TimelineContainerView(frame: CGRect(x: 0, y: 0, width: 393, height: 650))
        let today = Calendar.current.startOfDay(for: Date())
        let events = (0..<1000).map { day in
            Event(title: "Event \(day)", date: Calendar.current.date(byAdding: .day, value: day, to: today)!, color: CodableColor(color: .blue))
        }
        container.update(events: events, expanded: true)
        container.layoutIfNeeded()
        container.cards.layoutIfNeeded()
        container.timeline.setDayPosition(500.5)
        container.cards.layoutIfNeeded()
        XCTAssertLessThan(container.cards.subviews.count, 12)
        container.frame.size = CGSize(width: 600, height: 400)
        container.layoutIfNeeded()
        container.cards.layoutIfNeeded()
        XCTAssertEqual(container.timeline.dayPosition, 500.5, accuracy: 0.001)
        container.update(events: [], expanded: true)
        container.layoutIfNeeded()
        XCTAssertTrue(container.cards.groups.isEmpty)
        XCTAssertTrue(container.cards.isHidden)
    }

    func testHeightOnlyIncludesOverlapsInViewAndShrinksToEmpty() {
        let events = [event("A", start: 0, end: 2), event("B", start: 1, end: 3),
                      event("C", start: 2, end: 4), event("Distant", start: 500)]
        let crowded = TimelineLayout.make(events: events, visibleDays: 0...2, anchor: anchor, calendar: calendar)
        let quiet = TimelineLayout.make(events: events, visibleDays: 4...6, anchor: anchor, calendar: calendar)
        let empty = TimelineLayout.make(events: events, visibleDays: 10...16, anchor: anchor, calendar: calendar)
        XCTAssertEqual(crowded.laneCount, 3)
        XCTAssertEqual(quiet.laneCount, 1)
        XCTAssertEqual(quiet.placements.first?.lane, 0)
        XCTAssertEqual(empty.laneCount, 0)
        XCTAssertEqual(TimelineLayout.height(for: crowded.laneCount), 132)
        XCTAssertEqual(TimelineLayout.height(for: empty.laneCount), 48)
    }

    func testOverlappingChainsReuseLanesWithoutCollisions() {
        let events = [event("A", start: 0, end: 1), event("B", start: 1, end: 2), event("C", start: 2, end: 3)]
        let layout = TimelineLayout.make(events: events, visibleDays: 0...4, anchor: anchor, calendar: calendar)
        XCTAssertEqual(layout.laneCount, 2)
        XCTAssertEqual(layout.placements.map(\.lane), [0, 1, 0])
    }

    func testEventsSpanningViewportAndDSTAreIncluded() {
        let span = event("Trip", start: -100, end: 100)
        let nextDay = event("After DST", start: 2)
        let layout = TimelineLayout.make(events: [span, nextDay], visibleDays: 0...6, anchor: anchor, calendar: calendar)
        XCTAssertEqual(layout.laneCount, 2)
        XCTAssertEqual(layout.placements.last?.startDay, 2)
        XCTAssertEqual(layout.placements.first?.startDay, -100)
        XCTAssertEqual(layout.placements.first?.endDay, 100)
    }

    func testHistoryAndDistantFutureShareChronologicalListStartingNearToday() {
        let events = [event("Future", start: 1000), event("Old", start: -1000), event("Soon", start: 2),
                      event("Trip", start: -3, end: 3)]
        let days = EventListDay.group(events: events, today: anchor, calendar: calendar)
        XCTAssertEqual(days.flatMap(\.events).map(\.title), ["Old", "Trip", "Soon", "Future"])
        XCTAssertEqual(EventListDay.initialDate(in: days, today: anchor, calendar: calendar), anchor)
        XCTAssertEqual(days.count, 4)
    }

    func testHistoryOnlyOpensAtMostRecentEventAndMonthHeadersIncludeYear() {
        let events = [event("Old", start: -400), event("Recent", start: -1)]
        let days = EventListDay.group(events: events, today: anchor, calendar: calendar)
        XCTAssertEqual(EventListDay.initialDate(in: days, today: anchor, calendar: calendar), days.last?.date)
        XCTAssertTrue(days.allSatisfy(\.startsMonth))
        XCTAssertNil(EventListDay.initialDate(in: [], today: anchor, calendar: calendar))
    }

    @MainActor
    func testReturnToTodayAfterRecyclingInEitherDirection() {
        for direction: CGFloat in [-1, 1] {
            let scrollView = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: 84))
            let todayEvent = Event(title: "Today", date: Date(), color: CodableColor(color: .blue))
            scrollView.update(events: [todayEvent])
            scrollView.layoutIfNeeded()
            XCTAssertTrue(scrollView.isTodayVisible)

            for _ in 0..<100 {
                scrollView.contentOffset.x += direction * 70 * TimelineScrollWindow.dayWidth
                scrollView.setNeedsLayout()
                scrollView.layoutIfNeeded()
            }
            XCTAssertFalse(scrollView.isTodayVisible)

            scrollView.scrollToToday(animated: false)
            scrollView.layoutIfNeeded()
            XCTAssertTrue(scrollView.isTodayVisible)
            XCTAssertTrue(scrollView.subviews.contains {
                $0.accessibilityLabel == "Today" && scrollView.bounds.intersects($0.frame)
            })
            XCTAssertLessThan(scrollView.subviews.filter(\.isAccessibilityElement).count, 16)
        }
    }

    @MainActor
    func testTodayVisibilityReportsLeavingAndReturning() async {
        let scrollView = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: 84))
        let initial = expectation(description: "Today visible initially")
        scrollView.onTodayVisibilityChange = { visible in
            XCTAssertTrue(visible)
            initial.fulfill()
        }
        scrollView.layoutIfNeeded()
        await fulfillment(of: [initial], timeout: 1)

        let away = expectation(description: "Today is offscreen")
        scrollView.onTodayVisibilityChange = { visible in
            XCTAssertFalse(visible)
            away.fulfill()
        }
        scrollView.contentOffset.x += 10 * TimelineScrollWindow.dayWidth
        scrollView.setNeedsLayout()
        scrollView.layoutIfNeeded()
        await fulfillment(of: [away], timeout: 1)

        let returned = expectation(description: "Today visible after return")
        scrollView.onTodayVisibilityChange = { visible in
            XCTAssertTrue(visible)
            returned.fulfill()
        }
        scrollView.scrollToToday(animated: false)
        scrollView.layoutIfNeeded()
        await fulfillment(of: [returned], timeout: 1)
    }

    @MainActor
    func testScrollViewStartsTodayAndKeepsOnlyNearbyDayViews() {
        let scrollView = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: 84))
        scrollView.layoutIfNeeded()
        let todayLabel = Date().formatted(date: .complete, time: .omitted)
        XCTAssertTrue(scrollView.subviews.contains { $0.accessibilityLabel == todayLabel })
        for _ in 0..<10 {
            scrollView.contentOffset.x += 70 * TimelineScrollWindow.dayWidth
            scrollView.setNeedsLayout()
            scrollView.layoutIfNeeded()
        }
        XCTAssertLessThan(scrollView.subviews.filter(\.isAccessibilityElement).count, 15)
    }
}
