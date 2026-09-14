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

    func testRecyclingAtEveryZoomKeepsTheCalendarPositionAndCanvasBounded() {
        for level in TimelineZoomLevel.allCases {
            for direction: CGFloat in [-1, 1] {
                var window = TimelineScrollWindow(pointsPerDay: level.pointsPerDay)
                var offset = window.initialOffset + 13.5
                for _ in 0..<100 {
                    offset += direction * 3000
                    let day = CGFloat(window.firstDay) + offset / window.pointsPerDay
                    offset = window.recenter(offset: offset)
                    XCTAssertEqual(CGFloat(window.firstDay) + offset / window.pointsPerDay, day, accuracy: 0.000001)
                    XCTAssertGreaterThan(offset, 0)
                    XCTAssertLessThan(offset + 393, window.contentWidth)
                    XCTAssertLessThanOrEqual(window.contentWidth, 181 * 44 + 44)
                }
            }
        }
    }

    @MainActor
    func testPinchContinuouslyAnchorsTheDateUnderMovingFingersAndResetsForCompact() {
        let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: 600))
        timeline.setExpanded(true)
        timeline.layoutIfNeeded()
        timeline.setDayPosition(20.25)
        let focusedDay = timeline.focusedDayPosition
        let anchorDay = timeline.dayPosition + 180 / timeline.pointsPerDay
        timeline.beginZoom(at: 180)
        for scale: CGFloat in [0.7, 0.4, 0.15, 0.06, 0.01] {
            timeline.changeZoom(scale: scale, at: 200)
            XCTAssertEqual((timeline.dayPosition - anchorDay) * timeline.pointsPerDay + 200, 0, accuracy: 0.5)
            XCTAssertEqual(timeline.focusedDayPosition, focusedDay, accuracy: 0.00001)
        }
        XCTAssertEqual(timeline.pointsPerDay, TimelineZoomLevel.months.pointsPerDay)
        timeline.changeZoom(scale: 0.15, at: 200)
        XCTAssertEqual(timeline.pointsPerDay, 6.6, accuracy: 0.00001, "Pinch scale must stay continuous, without snapping to a preset")
        XCTAssertEqual(timeline.zoomLevel, .weeks)
        timeline.endZoom()
        timeline.setExpanded(false)
        XCTAssertEqual(timeline.pointsPerDay, 44)
        XCTAssertEqual(timeline.dayPosition * 44, focusedDay * 44, accuracy: 0.5)
        timeline.beginZoom(at: 180)
        timeline.changeZoom(scale: 0.1, at: 180)
        XCTAssertEqual(timeline.pointsPerDay, 44, "Only the full-screen timeline should zoom")
    }

    func testZoomPeriodsUseRealMonthLengthsAndCalendarWeeksAcrossDST() {
        for year in [2024, 2026] {
            let february = calendar.date(from: DateComponents(year: year, month: 2, day: 1))!
            let periods = TimelineAxisPeriod.make(level: .months, visibleDays: 0...70, anchor: february, calendar: calendar)
            XCTAssertEqual(periods.map { $0.endDay - $0.startDay }, [year == 2024 ? 29 : 28, 31, 30])
            XCTAssertEqual(periods[0].startDay, 0)
            XCTAssertEqual(periods[1].startDay, periods[0].endDay)
        }
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        let weeks = TimelineAxisPeriod.make(level: .weeks, visibleDays: 0...20, anchor: anchor, calendar: mondayCalendar)
        XCTAssertEqual(weeks.first?.startDay, -5)
        XCTAssertTrue(weeks.allSatisfy { $0.endDay - $0.startDay == 7 })
        for (first, second) in zip(weeks, weeks.dropFirst()) { XCTAssertEqual(first.endDay, second.startDay) }
    }

    @MainActor
    func testMonthZoomSeparatesNearbyMarkersAndOnlyBuildsVisibleViews() {
        let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: 600))
        let events = (0..<1000).map { day in
            Event(title: "Day \(day)", date: Calendar.current.date(byAdding: .day, value: day, to: timeline.anchor)!,
                  color: CodableColor(color: .blue))
        }
        timeline.update(events: events)
        timeline.setExpanded(true)
        timeline.layoutIfNeeded()
        timeline.beginZoom(at: 196)
        timeline.changeZoom(scale: 1.0 / 30, at: 196)
        timeline.endZoom()
        for day: CGFloat in [0, 400, 800, 0] {
            timeline.setDayPosition(day)
            timeline.layoutIfNeeded()
            let markers = timeline.subviews.compactMap { $0 as? UIButton }
            XCTAssertLessThan(markers.count, 280)
            XCTAssertLessThan(timeline.subviews.count, 300)
            for (index, marker) in markers.enumerated() {
                for other in markers.dropFirst(index + 1) { XCTAssertFalse(marker.frame.intersects(other.frame)) }
            }
        }
    }

    func testEventSheetHasTwoStopsAndTracksTheHandleWithinItsBounds() {
        let heights = EventSheetHeights(available: 750, compactTimeline: 108)
        XCTAssertEqual(heights.large, 642)
        XCTAssertEqual(heights.small, 240)
        XCTAssertEqual(heights.nearest(to: 100), .small)
        XCTAssertEqual(heights.nearest(to: 700), .large)
        var drag = EventSheetDrag(heights: heights, startHeight: heights.large)
        drag.translation = 150
        XCTAssertEqual(drag.height, 492)
        XCTAssertGreaterThan(heights.timelineExpansion(at: drag.height), 0)
        XCTAssertLessThan(heights.timelineExpansion(at: drag.height), 1)
        drag.translation = 1000
        XCTAssertEqual(drag.height, heights.small)
        drag.translation = -1000
        XCTAssertEqual(drag.height, heights.large)
        XCTAssertEqual(EventSheetHeights(available: 100, compactTimeline: 500).large, 100)
        XCTAssertEqual(EventSheetHeights(available: -10, compactTimeline: 100).small, 0)
    }

    func testSheetSelectionFindsTheNearestCalendarDayAcrossDSTAndLargeGaps() {
        let dates = [-20, 0, 2, 30, 365].map { calendar.date(byAdding: .day, value: $0, to: anchor)! }
        func selected(_ day: CGFloat) -> Date? {
            EventSheetSelection.nearestDate(to: day, anchor: anchor, dates: dates, calendar: calendar)
        }
        XCTAssertEqual(selected(-100), dates.first)
        XCTAssertEqual(selected(0.9), dates[1])
        XCTAssertEqual(selected(1.1), dates[2])
        XCTAssertEqual(selected(20), dates[3])
        XCTAssertEqual(selected(1000), dates.last)
        XCTAssertNil(EventSheetSelection.nearestDate(to: 0, anchor: anchor, dates: [], calendar: calendar))
    }

    @MainActor
    func testTimelineReportsTheFocusedDayWhileZoomingAndReturningToToday() {
        let canvas = TimelineCanvasView(frame: CGRect(x: 0, y: 0, width: 393, height: 550))
        canvas.update(events: [], expanded: true, progress: 1, highlightedEventID: nil)
        canvas.layoutIfNeeded()
        canvas.timeline.layoutIfNeeded()
        var reportedDay: CGFloat?
        canvas.onPositionChange = { day, anchor in
            reportedDay = day
            XCTAssertEqual(anchor, canvas.timeline.anchor)
        }
        canvas.timeline.setDayPosition(60)
        XCTAssertEqual(reportedDay, 60)
        canvas.timeline.beginZoom(at: 196)
        canvas.timeline.changeZoom(scale: 1.0 / 30, at: 196)
        canvas.timeline.endZoom()
        XCTAssertEqual(reportedDay!, 60, accuracy: 0.001)
        XCTAssertEqual(canvas.timeline.zoomLevel, .months)
        canvas.timeline.scrollToToday(animated: false)
        XCTAssertEqual(reportedDay!, 0, accuracy: 0.001)
        XCTAssertTrue(canvas.timeline.isTodayVisible)
        XCTAssertEqual(canvas.timeline.zoomLevel, .months)
    }

    @MainActor
    func testDotsMoveContinuouslyAsTheEventSheetShrinks() {
        let canvas = TimelineCanvasView(frame: CGRect(x: 0, y: 0, width: 393, height: 80))
        let events = [Event(title: "Today", date: canvas.timeline.anchor, color: CodableColor(color: .blue))]
        func layoutTree(_ view: UIView) { view.layoutIfNeeded(); view.subviews.forEach(layoutTree) }
        var previousTop: CGFloat = 48
        for step in 0...10 {
            let progress = CGFloat(step) / 10
            canvas.frame.size.height = 80 + 470 * progress
            canvas.update(events: events, expanded: false, progress: progress, highlightedEventID: nil)
            layoutTree(canvas)
            let marker = canvas.timeline.subviews.compactMap { $0 as? UIButton }.first { $0.accessibilityLabel == "Today" }!
            XCTAssertGreaterThanOrEqual(marker.frame.minY, previousTop)
            if step == 5 { XCTAssertGreaterThan(marker.frame.minY, 80) }
            previousTop = marker.frame.minY
        }
        canvas.update(events: events, expanded: true, progress: 1, highlightedEventID: nil)
        layoutTree(canvas)
        let marker = canvas.timeline.subviews.compactMap { $0 as? UIButton }.first { $0.accessibilityLabel == "Today" }!
        XCTAssertEqual(marker.frame.minY, previousTop, accuracy: 0.5)
        XCTAssertEqual(marker.frame.minY - 44, canvas.timeline.bounds.height - marker.frame.maxY, accuracy: 1)
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
