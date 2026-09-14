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

    func testExpandedTitlePrefersRightAndMovesAboveWhenAnotherDotBlocksIt() {
        let first = TimelineLabelItem(id: UUID(), marker: CGRect(x: 20, y: 100, width: 20, height: 20),
                                      size: CGSize(width: 90, height: 20))
        let alone = TimelineEventLabelLayout.make(items: [first], horizontalBounds: 8...385)
        XCTAssertEqual(alone[0].frame.minX, first.marker.maxX + 6)
        XCTAssertEqual(alone[0].frame.midY, first.marker.midY)
        let neighbor = TimelineLabelItem(id: UUID(), marker: CGRect(x: 64, y: 100, width: 20, height: 20),
                                         size: CGSize(width: 120, height: 38))
        let crowded = TimelineEventLabelLayout.make(items: [first, neighbor], horizontalBounds: 8...385)
        let displaced = crowded.first { $0.id == first.id }!
        XCTAssertLessThanOrEqual(displaced.frame.maxY, first.marker.minY - TimelineEventLabelLayout.gap)
        XCTAssertEqual(displaced.connector.first, CGPoint(x: first.marker.midX, y: first.marker.minY - 2))
        XCTAssertEqual(displaced.connector.last!.y, displaced.frame.maxY + 2)
        XCTAssertFalse(displaced.frame.intersects(neighbor.marker))
    }

    func testExpandedTitlesAvoidDotsAndEachOtherForStacksLongNamesAndNarrowViewports() {
        for width: CGFloat in [320, 393, 600] {
            let items = (0..<45).map { index in
                TimelineLabelItem(id: UUID(), marker: CGRect(x: CGFloat(index / 5) * 32 + 8,
                    y: 150 + CGFloat(index % 5) * 24, width: 20, height: 20),
                    size: CGSize(width: min(150, width * 0.46), height: index.isMultiple(of: 3) ? 58 : 20))
            }
            let placements = TimelineEventLabelLayout.make(items: items, horizontalBounds: 8...(width - 8))
            XCTAssertEqual(placements.count, items.count)
            for (index, label) in placements.enumerated() {
                XCTAssertGreaterThanOrEqual(label.frame.minX, 8)
                XCTAssertLessThanOrEqual(label.frame.maxX, width - 8)
                XCTAssertEqual(label.marker.minX, items.first { $0.id == label.id }!.marker.minX, "An event must keep its calendar position")
                for other in placements {
                    XCTAssertFalse(label.frame.intersects(other.marker))
                    if label.id != other.id { XCTAssertFalse(label.frame.intersects(other.frame)) }
                    if let start = label.connector.first, let end = label.connector.last {
                        XCTAssertEqual(label.connector.count, 2, "Connections must be direct")
                        XCTAssertFalse(TimelineEventLabelLayout.segment(start, end, intersects: other.frame))
                        if label.id != other.id {
                            XCTAssertFalse(TimelineEventLabelLayout.segment(start, end, intersects: other.marker))
                        }
                    }
                }
                for other in placements.dropFirst(index + 1) {
                    XCTAssertFalse(label.marker.intersects(other.marker))
                    if let a = label.connector.first, let b = label.connector.last,
                       let c = other.connector.first, let d = other.connector.last {
                        XCTAssertFalse(TimelineEventLabelLayout.segmentsCross(a, b, c, d))
                    }
                }
            }
        }
    }

    @MainActor
    func testBirthdayAndReleaseLabelsUseBothSidesWithDirectConnections() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 393, height: 360))
        container.backgroundColor = .systemBackground
        let titles = TimelineEventLabelsView(frame: container.bounds)
        container.addSubview(titles)
        let names = ["Bryan Lewis’s birthday", "Zelda: Ocarina of Time", "GTA 6"]
        let centers: [CGFloat] = [112, 132, 264]
        let entries = names.enumerated().map { index, name in
            (event: Event(title: name, date: Date(), color: CodableColor(color: index == 0 ? .red : .blue)),
             frame: CGRect(x: centers[index] - 4.5, y: 175, width: 9, height: 9))
        }
        _ = titles.update(events: entries, viewport: container.bounds, opacity: 1, minimumY: 40)
        let placements = titles.placements
        XCTAssertEqual(placements.count, 3)
        XCTAssertTrue(placements.contains { $0.frame.maxY < $0.marker.minY })
        XCTAssertTrue(placements.contains { $0.frame.minY > $0.marker.maxY })
        for placement in placements {
            XCTAssertEqual(placement.marker.minY, 175, "This small cluster has room without moving its dots")
            let entry = entries.first { $0.event.id == placement.id }!
            let dot = UIView(frame: placement.marker)
            dot.backgroundColor = UIColor(entry.event.color.color)
            dot.layer.cornerRadius = 4.5
            container.addSubview(dot)
            XCTAssertLessThanOrEqual(placement.connector.count, 2)
        }
        func layoutTree(_ view: UIView) { view.layoutIfNeeded(); view.subviews.forEach(layoutTree) }
        layoutTree(container)
        let image = UIGraphicsImageRenderer(bounds: container.bounds).image { container.layer.render(in: $0.cgContext) }
        let screenshot = XCTAttachment(image: image)
        screenshot.name = "Birthday and releases with balanced direct labels"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testExpandedTitlesRetainAFreePositionDuringSmallPansAndAvoidTheAxis() {
        let item = TimelineLabelItem(id: UUID(), marker: CGRect(x: 80, y: 100, width: 20, height: 20),
                                     size: CGSize(width: 150, height: 120))
        let initial = TimelineEventLabelLayout.make(items: [item], horizontalBounds: 8...385, minimumY: 60)[0]
        XCTAssertGreaterThanOrEqual(initial.frame.minY, item.marker.maxY + 6, "A tall title must not cover the calendar axis")
        let moved = TimelineEventLabelLayout.make(items: [item], horizontalBounds: 12...389, minimumY: 60,
                                                  previous: [item.id: initial.frame])[0]
        XCTAssertEqual(moved.frame, initial.frame, "A small pan must not make labels jump to another column")
    }

    @MainActor
    func testExpandedTitlesFollowPanZoomAndSelectionAndDisappearWhenCollapsed() {
        let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: 550))
        let events = (0..<8).map { day in
            Event(title: "Event \(day) with a longer title", date: Calendar.current.date(byAdding: .day, value: day / 2, to: timeline.anchor)!,
                  color: CodableColor(color: .blue))
        }
        timeline.update(events: events)
        timeline.setExpanded(true)
        timeline.layoutIfNeeded()
        let overlay = timeline.subviews.compactMap { $0 as? TimelineEventLabelsView }.first!
        XCTAssertFalse(overlay.placements.isEmpty)
        for scale: CGFloat in [1, 0.15, 0.03] {
            timeline.beginZoom(at: 0)
            timeline.changeZoom(scale: scale, at: 0)
            timeline.endZoom()
            for day: CGFloat in [0, 0.25, 1.7] {
                timeline.setDayPosition(day)
                timeline.layoutIfNeeded()
                let markers = timeline.subviews.compactMap { $0 as? UIButton }
                for (index, placement) in overlay.placements.enumerated() {
                    for marker in markers { XCTAssertFalse(placement.frame.intersects(marker.frame)) }
                    for other in overlay.placements.dropFirst(index + 1) {
                        XCTAssertFalse(placement.frame.intersects(other.frame))
                    }
                    XCTAssertGreaterThanOrEqual(placement.frame.minX, timeline.bounds.minX)
                    XCTAssertLessThanOrEqual(placement.frame.maxX, timeline.bounds.maxX)
                    XCTAssertLessThanOrEqual(placement.frame.maxY, timeline.contentSize.height)
                }
            }
        }
        var selected: UUID?
        timeline.onSelectEvent = { selected = $0.id }
        let title = overlay.subviews.compactMap { $0 as? UIButton }.first!
        title.sendActions(for: .touchUpInside)
        XCTAssertNotNil(selected)
        XCTAssertEqual(timeline.highlightedEventID, selected)
        timeline.setExpanded(false)
        timeline.layoutIfNeeded()
        XCTAssertTrue(overlay.placements.isEmpty)
        XCTAssertEqual(overlay.alpha, 0)
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
        XCTAssertTrue(weeks.allSatisfy { $0.subtitle.contains("–") && !$0.subtitle.contains("2026") })
        XCTAssertTrue(weeks.allSatisfy { Int($0.compactSubtitle) != nil }, "Dense weekly ticks retain a compact fallback")
    }

    func testWeeklyRangesIncludeTheLastDayAcrossMonthYearAndDSTBoundaries() {
        var calendar = calendar
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = 1
        let cases = [
            (2026, 9, 13, "13–19"),
            (2026, 9, 27, "Sep 27–Oct 3"),
            (2026, 12, 27, "Dec 27–Jan 2"),
            (2026, 3, 8, "8–14"),
            (2026, 11, 1, "1–7")
        ]
        for (year, month, day, expected) in cases {
            let start = calendar.date(from: DateComponents(year: year, month: month, day: day))!
            let week = TimelineAxisPeriod.make(level: .weeks, visibleDays: 0...0, anchor: start, calendar: calendar).first!
            XCTAssertEqual(week.subtitle, expected)
            XCTAssertEqual(week.endDay - week.startDay, 7)
            XCTAssertTrue(week.accessibilityLabel.contains("through"))
        }
        calendar.firstWeekday = 2
        let september = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14))!
        XCTAssertEqual(TimelineAxisPeriod.make(level: .weeks, visibleDays: 0...0, anchor: september,
                                              calendar: calendar).first?.subtitle, "14–20")
    }

    @MainActor
    func testCloseWeeklyZoomShowsDateRangesAboveBothSheetSizes() {
        for height: CGFloat in [100, 600] {
            let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: height))
            timeline.setExpanded(height > 100)
            timeline.layoutIfNeeded()
            timeline.beginZoom(at: 196)
            timeline.changeZoom(scale: 0.6, at: 196)
            timeline.endZoom()
            timeline.layoutIfNeeded()
            let labels = timeline.subviews.flatMap(\.subviews).compactMap { $0 as? UILabel }
                .filter { !$0.isHidden && $0.alpha > 0 }
            XCTAssertFalse(labels.isEmpty)
            XCTAssertTrue(labels.allSatisfy { $0.text?.contains("–") == true },
                          "Close weekly ticks should display the whole week above either sheet size")
        }
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
            let titles = timeline.subviews.compactMap { $0 as? TimelineEventLabelsView }.first!
            XCTAssertLessThan(titles.subviews.count, markers.count)
            for title in titles.subviews {
                XCTAssertTrue(title.frame.intersects(timeline.bounds.insetBy(dx: 0, dy: -80)),
                              "Titles outside the vertical viewport must be recycled")
            }
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
