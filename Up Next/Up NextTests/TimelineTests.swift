import XCTest
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
