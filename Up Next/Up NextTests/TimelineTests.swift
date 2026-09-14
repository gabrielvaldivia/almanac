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
    func testPinchContinuouslyAnchorsTheDateAndPreservesZoomAcrossSheetSizes() {
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
        let leftDay = timeline.dayPosition
        for expanded in [false, true, false] {
            timeline.setExpanded(expanded)
            timeline.layoutIfNeeded()
            XCTAssertEqual(timeline.pointsPerDay, 6.6, accuracy: 0.00001)
            XCTAssertEqual(timeline.dayPosition, leftDay, accuracy: 0.00001)
            XCTAssertEqual(timeline.focusedDayPosition, focusedDay, accuracy: 0.00001)
        }
        timeline.beginZoom(at: 180)
        timeline.changeZoom(scale: 0.1, at: 180)
        timeline.endZoom()
        XCTAssertEqual(timeline.zoomLevel, .months, "The timeline can zoom out above the large sheet")
        timeline.beginZoom(at: 180)
        timeline.changeZoom(scale: 30, at: 180)
        timeline.endZoom()
        XCTAssertEqual(timeline.zoomLevel, .days, "The timeline can zoom back in above the large sheet")
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

    func testTimelineLabelsOmitRepeatedYearsAndKeepYearContextWhenNeeded() {
        let first = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let last = calendar.date(from: DateComponents(year: 2026, month: 11, day: 30))!
        XCTAssertEqual(TimelineHeading.text(first: first, last: last, today: anchor, calendar: calendar), "Jul – Nov")
        XCTAssertEqual(TimelineHeading.text(first: first, last: first, today: anchor, calendar: calendar), "July")
        let nextYear = calendar.date(byAdding: .year, value: 1, to: first)!
        XCTAssertTrue(TimelineHeading.text(first: nextYear, last: nextYear, today: anchor, calendar: calendar).contains("2027"))
        let crossYear = TimelineHeading.text(first: first, last: nextYear, today: anchor, calendar: calendar)
        XCTAssertTrue(crossYear.contains("2026"))
        XCTAssertTrue(crossYear.contains("2027"))
        for visibleDays: CGFloat in [14, 21, 31, 42] {
            XCTAssertEqual(TimelineHeading.text(first: first, last: first, today: anchor, calendar: calendar,
                                               yearOnly: TimelineHeading.showsYear(visibleDayCount: visibleDays)), "July")
        }
        for visibleDays: CGFloat in [43, 90, 270] {
            let yearOnly = TimelineHeading.showsYear(visibleDayCount: visibleDays)
            XCTAssertEqual(TimelineHeading.text(first: first, last: last, yearOnly: yearOnly), "2026")
            XCTAssertEqual(TimelineHeading.text(first: nextYear, last: nextYear, yearOnly: yearOnly), "2027")
        }
        let months = TimelineAxisPeriod.make(level: .months, visibleDays: 0...150, anchor: first, calendar: calendar)
        XCTAssertTrue(months.allSatisfy { $0.subtitle.isEmpty && !$0.title.contains("2026") })
        XCTAssertTrue(months.allSatisfy { $0.accessibilityLabel.contains("2026") })
        let weeks = TimelineAxisPeriod.make(level: .weeks, visibleDays: 0...150, anchor: first, calendar: calendar)
        XCTAssertTrue(weeks.allSatisfy { Int($0.subtitle) != nil }, "Weekly ticks identify the start day without squeezed date ranges")
    }

    @MainActor
    func testAxisLabelsFitWithoutOverlapAtEveryZoomAndFractionalScrollOffset() {
        continueAfterFailure = false
        for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
            UITraitCollection(preferredContentSizeCategory: category).performAsCurrent {
                for width: CGFloat in [320, 393, 600] {
                    let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: width, height: 600))
                    timeline.setExpanded(true)
                    timeline.layoutIfNeeded()
                    // Include the exact week/month blend that previously drew both
                    // month names on top of one another, and densely spaced weekdays.
                    for spacing: CGFloat in [44, 39, 34, 31, 29, 24, 18, 10, 6.6, 5.3, 4.5, 3.6, 2.8, 44.0 / 30] {
                        timeline.beginZoom(at: width / 2)
                        timeline.changeZoom(scale: spacing / timeline.pointsPerDay, at: width / 2)
                        timeline.endZoom()
                        for position: CGFloat in [-90.33, 0, 0.07, 0.51, 18.91, 95.2] {
                            timeline.setDayPosition(position)
                            timeline.layoutIfNeeded()
                            let labels = timeline.subviews.flatMap(\.subviews).compactMap { $0 as? UILabel }
                                .filter { !$0.isHidden && $0.alpha > 0 }
                            let frames = labels.map { $0.convert($0.bounds, to: timeline) }
                            for (index, label) in labels.enumerated() {
                                XCTAssertGreaterThanOrEqual(label.bounds.width + 0.01, ceil(label.intrinsicContentSize.width))
                                XCTAssertGreaterThanOrEqual(label.bounds.height, ceil(label.font.lineHeight))
                                XCTAssertGreaterThanOrEqual(frames[index].minX, timeline.bounds.minX)
                                XCTAssertLessThanOrEqual(frames[index].maxX, timeline.bounds.maxX)
                                for other in frames.dropFirst(index + 1) {
                                    XCTAssertFalse(frames[index].intersects(other), "Overlapping labels at \(spacing) pt/day")
                                }
                            }
                            XCTAssertFalse(labels.isEmpty, "Every zoom position must retain readable date context")
                        }
                    }
                }
            }
        }
    }

    @MainActor
    func testWeekGridKeepsEvenSpacingAcrossMonthBoundariesAndZoomBlends() {
        let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 800, height: 500))
        timeline.setExpanded(true)
        timeline.layoutIfNeeded()
        for spacing: CGFloat in [29, 18, 6.6, 5.3, 4.6] {
            timeline.beginZoom(at: 400)
            timeline.changeZoom(scale: spacing / timeline.pointsPerDay, at: 400)
            timeline.endZoom()
            timeline.setDayPosition(0.37)
            timeline.layoutIfNeeded()
            let lines = timeline.subviews.flatMap(\.subviews).filter {
                $0.backgroundColor == .separator && $0.alpha > 0 && !$0.isHidden
            }.map { $0.convert($0.bounds, to: timeline).minX }.sorted()
            XCTAssertGreaterThan(lines.count, 2)
            for (first, next) in zip(lines, lines.dropFirst()) {
                XCTAssertEqual(next - first, spacing * 7, accuracy: 0.01)
            }
        }
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

    func testScrollSynchronizationFollowsTheUserWithoutEchoingProgrammaticMoves() {
        let first = anchor
        let second = calendar.date(byAdding: .day, value: 40, to: first)!
        var synchronization = EventScrollSynchronization()
        XCTAssertTrue(synchronization.timelineMoved(to: first))
        XCTAssertFalse(synchronization.sheetMoved(to: first), "Scrolling the sheet to a timeline date must not echo")
        XCTAssertFalse(synchronization.timelineMoved(to: first), "Repeated geometry reports do not restart animations")

        synchronization.begin(.sheet)
        for date in [first, second, first] {
            XCTAssertTrue(synchronization.sheetMoved(to: date))
            XCTAssertFalse(synchronization.timelineMoved(to: date), "Following the sheet must not snap it back")
            XCTAssertFalse(synchronization.sheetMoved(to: date))
        }
        synchronization.begin(.timeline)
        XCTAssertTrue(synchronization.timelineMoved(to: second), "A new timeline drag takes control immediately")
        XCTAssertFalse(synchronization.sheetMoved(to: first), "Old sheet geometry cannot interrupt that drag")
        synchronization.begin(.sheet)
        XCTAssertTrue(synchronization.sheetMoved(to: first), "Returning to the same event after panning still moves the timeline")
    }

    @MainActor
    func testFollowingSheetDatesPreservesZoomAndCalendarFocusAcrossRecycledWindows() {
        let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: 550))
        timeline.setExpanded(true)
        timeline.layoutIfNeeded()
        for level in TimelineZoomLevel.allCases {
            timeline.beginZoom(at: 196)
            timeline.changeZoom(scale: level.pointsPerDay / timeline.pointsPerDay, at: 196)
            timeline.endZoom()
            let referenceX = (timeline.focusedDayPosition - timeline.dayPosition) * timeline.pointsPerDay
            var interactions = 0
            timeline.onInteractionBegan = { interactions += 1 }
            for offset in [1, 17, 90, 10_000, -10_000, 0] {
                let date = Calendar.current.date(byAdding: .day, value: offset, to: timeline.anchor)!
                timeline.scrollToDate(date.addingTimeInterval(12 * 60 * 60), animated: false)
                timeline.layoutIfNeeded()
                XCTAssertEqual(timeline.pointsPerDay, level.pointsPerDay)
                XCTAssertEqual(timeline.focusedDayPosition, CGFloat(offset), accuracy: 0.000001)
                XCTAssertEqual((timeline.focusedDayPosition - timeline.dayPosition) * timeline.pointsPerDay, referenceX, accuracy: 0.5)
                XCTAssertLessThanOrEqual(timeline.contentSize.width, 181 * 44 + 44)
            }
            XCTAssertEqual(interactions, 0, "Following the sheet must not take ownership away from it")
        }
    }

    @MainActor
    func testTimelineReportsTheFocusedDayWhileZoomingAndReturningToToday() {
        let canvas = TimelineCanvasView(frame: CGRect(x: 0, y: 0, width: 393, height: 550))
        canvas.update(events: [], expanded: true, progress: 1, highlightedEventID: nil)
        canvas.layoutIfNeeded()
        canvas.timeline.layoutIfNeeded()
        var reportedDay: CGFloat?
        var reportedVisibleDays: CGFloat?
        canvas.onPositionChange = { day, anchor, visibleDays in
            reportedDay = day
            reportedVisibleDays = visibleDays
            XCTAssertEqual(anchor, canvas.timeline.anchor)
            XCTAssertEqual(visibleDays, canvas.timeline.bounds.width / canvas.timeline.pointsPerDay)
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
        canvas.frame.size.width = 600
        canvas.layoutIfNeeded()
        XCTAssertEqual(reportedVisibleDays!, 600 / canvas.timeline.pointsPerDay, accuracy: 0.001,
                       "Resizing the viewport must update the heading's date span")
    }

    @MainActor
    func testPinchCanTakeOverAnExistingPanAndRestoresScrollingAfterward() throws {
        let canvas = TimelineCanvasView(frame: CGRect(x: 0, y: 0, width: 393, height: 108))
        canvas.layoutIfNeeded()
        let timeline = canvas.timeline
        let zoom = try XCTUnwrap(canvas.gestureRecognizers?.first { $0 is UIPinchGestureRecognizer })
        XCTAssertTrue(timeline.gestureRecognizer(zoom, shouldRecognizeSimultaneouslyWith: timeline.panGestureRecognizer))
        XCTAssertFalse(timeline.gestureRecognizer(zoom, shouldRecognizeSimultaneouslyWith: UITapGestureRecognizer()))
        for expanded in [false, true] {
            timeline.setExpanded(expanded)
            timeline.beginZoom(at: 180)
            XCTAssertFalse(timeline.panGestureRecognizer.isEnabled, "Scrolling cannot move dates under an active pinch")
            timeline.changeZoom(scale: 0.6, at: 180)
            timeline.setExpanded(!expanded)
            timeline.changeZoom(scale: 0.8, at: 180)
            timeline.endZoom()
            XCTAssertTrue(timeline.panGestureRecognizer.isEnabled)
        }
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
