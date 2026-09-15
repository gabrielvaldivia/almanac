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

    @MainActor
    private func visibleAxisLabels(in timeline: TimelineScrollView) -> [UILabel] {
        let header = timeline.subviews.first { $0.accessibilityIdentifier == "timelineAxis" }
        return (header?.subviews ?? []).flatMap(\.subviews).compactMap { $0 as? UILabel }
            .filter { !$0.isHidden && $0.alpha > 0 }
    }

    @MainActor
    func testTappingTimelineDotHighlightsItsEvent() throws {
        let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: 124))
        let event = Event(title: "Birthday", date: timeline.anchor, color: CodableColor(color: .red))
        timeline.update(events: [event])
        timeline.layoutIfNeeded()
        var selected: UUID?
        timeline.onSelectEvent = { selected = $0.id }
        let dot = try XCTUnwrap(timeline.subviews.compactMap { $0 as? UIButton }.first)
        dot.sendActions(for: .touchUpInside)
        XCTAssertEqual(selected, event.id)
        XCTAssertEqual(timeline.highlightedEventID, event.id)
        XCTAssertTrue(dot.isSelected)
    }

    @MainActor
    func testSmallTimelineMarkersHaveExpandedTargetsWithNearestMarkerSelection() throws {
        let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: 300))
        let events = (0..<4).map {
            Event(title: "Target \($0)", date: timeline.anchor, color: CodableColor(color: .blue))
        }
        timeline.update(events: events)
        timeline.layoutIfNeeded()
        for level in TimelineZoomLevel.allCases {
            timeline.beginZoom(at: 0)
            timeline.changeZoom(scale: level.pointsPerDay / timeline.pointsPerDay, at: 0)
            timeline.endZoom()
            timeline.layoutIfNeeded()
            let markers = timeline.subviews.compactMap { $0 as? UIButton }.sorted { $0.frame.minY < $1.frame.minY }
            XCTAssertEqual(markers.count, 4)
            for marker in markers {
                XCTAssertLessThanOrEqual(marker.bounds.height, 20, "The visual marker stays small")
                XCTAssertTrue(marker.point(inside: CGPoint(x: marker.bounds.midX + 21, y: marker.bounds.midY), with: nil))
                let center = CGPoint(x: marker.frame.midX, y: marker.frame.midY)
                XCTAssertTrue(timeline.hitTest(center, with: nil) === marker, "Actual marks win over neighboring expanded targets")
                let outside = CGPoint(x: marker.frame.maxX + 1, y: marker.frame.midY)
                XCTAssertFalse(marker.frame.contains(outside))
                XCTAssertTrue(timeline.hitTest(outside, with: nil) === marker)
                marker.sendActions(for: .touchUpInside)
                XCTAssertEqual(timeline.highlightedEventID, events.first { $0.title == marker.accessibilityLabel }?.id)
            }
            let first = try XCTUnwrap(markers.first)
            let second = markers[1]
            let nearSecond = CGPoint(x: second.frame.midX, y: (first.frame.maxY + second.frame.minY) / 2 + 0.5)
            XCTAssertTrue(timeline.hitTest(nearSecond, with: nil) === second)
        }
    }

    @MainActor
    func testTimeZoneChangesPreserveVisibleDatesAndKeepTodayCorrect() throws {
        let originalZone = NSTimeZone.default
        defer { NSTimeZone.default = originalZone }
        NSTimeZone.default = TimeZone(identifier: "America/New_York")!
        let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: 200))
        let anchorDay = CalendarDay(timeline.anchor)
        let originalEvent = Event(title: "Travel event", date: Calendar.current.date(byAdding: .day, value: 3, to: timeline.anchor)!, color: CodableColor(color: .blue))
        timeline.update(events: [originalEvent]); timeline.layoutIfNeeded()
        timeline.setDayPosition(0.25); timeline.layoutIfNeeded()
        let originalPosition = timeline.dayPosition
        let originalButtonFrame = try XCTUnwrap(timeline.subviews.compactMap { $0 as? UIButton }.first).frame
        for zone in ["America/Los_Angeles", "Asia/Tokyo", "Pacific/Kiritimati", "Pacific/Pago_Pago"] {
            NSTimeZone.default = TimeZone(identifier: zone)!
            var event = originalEvent
            event.date = try XCTUnwrap(originalEvent.calendarDay?.date())
            timeline.update(events: [event]); timeline.layoutIfNeeded()
            XCTAssertEqual(CalendarDay(timeline.anchor), anchorDay, zone)
            XCTAssertEqual(timeline.dayPosition, originalPosition, accuracy: 0.0001, zone)
            let frame = try XCTUnwrap(timeline.subviews.compactMap { $0 as? UIButton }.first).frame
            XCTAssertEqual(frame.minX, originalButtonFrame.minX, accuracy: 0.5, zone)
        }
        // Also exercise the unchanged-array cache and direct Today action.
        timeline.update(events: [])
        NSTimeZone.default = TimeZone(identifier: "America/Los_Angeles")!
        timeline.update(events: [])
        timeline.scrollToToday(animated: false); timeline.layoutIfNeeded()
        let focused = Calendar.current.date(byAdding: .day, value: Int(timeline.focusedDayPosition), to: timeline.anchor)!
        XCTAssertEqual(focused, Calendar.current.startOfDay(for: Date()))
        XCTAssertTrue(timeline.isTodayVisible)
        NSTimeZone.default = TimeZone(identifier: "Asia/Tokyo")!
        timeline.scrollToToday(animated: false)
        XCTAssertEqual(Calendar.current.date(byAdding: .day, value: Int(timeline.focusedDayPosition), to: timeline.anchor),
                       Calendar.current.startOfDay(for: Date()))
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
    func testPinchContinuouslyAnchorsTheDateAndPreservesZoomAcrossHeightChanges() {
        let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: 600))
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
        for height: CGFloat in [100, 250, 150] {
            timeline.frame.size.height = height
            timeline.layoutIfNeeded()
            XCTAssertEqual(timeline.pointsPerDay, 6.6, accuracy: 0.00001)
            XCTAssertEqual(timeline.dayPosition, leftDay, accuracy: 0.00001)
            XCTAssertEqual(timeline.focusedDayPosition, focusedDay, accuracy: 0.00001)
        }
        timeline.beginZoom(at: 180)
        timeline.changeZoom(scale: 0.1, at: 180)
        timeline.endZoom()
        XCTAssertEqual(timeline.zoomLevel, .months, "The timeline can zoom out above the event list")
        timeline.beginZoom(at: 180)
        timeline.changeZoom(scale: 30, at: 180)
        timeline.endZoom()
        XCTAssertEqual(timeline.zoomLevel, .days, "The timeline can zoom back in above the event list")
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
        for visibleDays: CGFloat in [14, 21, 31, 42, 43, 49, 56] {
            XCTAssertEqual(TimelineHeading.text(first: first, last: first, today: anchor, calendar: calendar,
                                               yearOnly: TimelineHeading.showsYear(visibleDayCount: visibleDays)), "July")
        }
        for visibleDays: CGFloat in [57, 90, 270] {
            let yearOnly = TimelineHeading.showsYear(visibleDayCount: visibleDays)
            XCTAssertEqual(TimelineHeading.text(first: first, last: last, yearOnly: yearOnly), "2026")
            XCTAssertEqual(TimelineHeading.text(first: nextYear, last: nextYear, yearOnly: yearOnly), "2027")
        }
        let months = TimelineAxisPeriod.make(level: .months, visibleDays: 0...150, anchor: first, calendar: calendar)
        XCTAssertTrue(months.allSatisfy { $0.subtitle.isEmpty && !$0.title.contains("2026") })
        XCTAssertTrue(months.allSatisfy { $0.accessibilityLabel.contains("2026") })
        let weeks = TimelineAxisPeriod.make(level: .weeks, visibleDays: 0...150, anchor: first, calendar: calendar)
        XCTAssertTrue(weeks.allSatisfy { $0.subtitle.contains("–") && !$0.subtitle.contains("2026") })
        XCTAssertTrue(weeks.allSatisfy { $0.compactSubtitle.contains("/") }, "Dense weekly ticks retain the month and day")
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
            XCTAssertEqual(week.compactSubtitle, "\(month)/\(day)")
            XCTAssertEqual(week.endDay - week.startDay, 7)
            XCTAssertTrue(week.accessibilityLabel.contains("through"))
        }
        calendar.firstWeekday = 2
        let september = calendar.date(from: DateComponents(year: 2026, month: 9, day: 14))!
        XCTAssertEqual(TimelineAxisPeriod.make(level: .weeks, visibleDays: 0...0, anchor: september,
                                              calendar: calendar).first?.subtitle, "14–20")
    }

    func testNumericAxisDatesUseTheLocalMonthAndDayWithoutLeadingZeros() {
        let cases = [(2026, 9, 13, "9/13"), (2026, 12, 31, "12/31"), (2027, 1, 1, "1/1")]
        for (year, month, day, expected) in cases {
            let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 23, minute: 30))!
            XCTAssertEqual(TimelineAxisDate.text(date, calendar: calendar), expected,
                           "The axis must use the local date even after midnight in UTC")
            XCTAssertEqual(TimelineAxisDate.text(date, includesMonth: false, calendar: calendar), String(day),
                           "Individual days omit the month, including beneath weekday labels")
        }
    }

    @MainActor
    func testTimelineKeepsEveryDayNumberUntilDatesWouldOverlapAtDifferentHeights() {
        for height: CGFloat in [100, 600] {
            let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: height))
            timeline.layoutIfNeeded()
            for spacing: CGFloat in [44, 40, 26.4, 22, 20, 10] {
                timeline.beginZoom(at: 196)
                timeline.changeZoom(scale: spacing / timeline.pointsPerDay, at: 196)
                timeline.endZoom()
                // Keep individual dates even across month/year boundaries, then
                // switch to weekly ticks only when day numbers no longer fit.
                for month in [9, 12] {
                    let calendar = Calendar.current
                    let start = calendar.date(from: DateComponents(year: 2026, month: month, day: 28))!
                    let position = calendar.dateComponents([.day], from: timeline.anchor, to: start).day!
                    timeline.setDayPosition(CGFloat(position))
                    timeline.layoutIfNeeded()
                    let labels = visibleAxisLabels(in: timeline)
                    XCTAssertFalse(labels.isEmpty)
                    if spacing >= 20 {
                        for day in 0..<Int(floor(timeline.bounds.width / spacing)) {
                            let date = calendar.date(byAdding: .day, value: day, to: start)!
                            let expected = "\(calendar.component(.day, from: date))"
                            XCTAssertTrue(labels.contains { $0.text == expected },
                                          "Every fully visible day must show its number: \(expected) at \(spacing) pt/day")
                        }
                        XCTAssertFalse(labels.contains { $0.text?.contains("/") == true || $0.text?.contains("–") == true })
                    } else {
                        XCTAssertTrue(labels.allSatisfy { $0.text?.contains("–") == true || $0.text?.contains("/") == true },
                                      "Use weekly dates once individual day numbers would overlap")
                    }
                }
            }
        }
    }

    @MainActor
    func testMonthNamesStayFullUntilTheTimelineIsTooCrowded() throws {
        let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: 100))
        let calendar = Calendar.current
        let september = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))
        let position = try XCTUnwrap(calendar.dateComponents([.day], from: timeline.anchor, to: september).day)
        let fullName = september.formatted(.dateTime.month(.wide))
        let shortName = september.formatted(.dateTime.month(.abbreviated))
        timeline.layoutIfNeeded()
        // Zoom out and back in: full names should return as soon as they fit.
        for (spacing, expected): (CGFloat, String) in [(3.5, fullName), (44.0 / 30, shortName), (3.5, fullName)] {
            timeline.beginZoom(at: 0)
            timeline.changeZoom(scale: spacing / timeline.pointsPerDay, at: 0)
            timeline.endZoom()
            timeline.setDayPosition(CGFloat(position))
            timeline.layoutIfNeeded()
            let labels = visibleAxisLabels(in: timeline).compactMap(\.text)
            XCTAssertTrue(labels.contains(expected), "Expected \(expected) at \(spacing) pt/day, got \(labels)")
        }
    }

    @MainActor
    func testAxisLabelsFitWithoutOverlapAtEveryZoomAndFractionalScrollOffset() {
        continueAfterFailure = false
        for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
            UITraitCollection(preferredContentSizeCategory: category).performAsCurrent {
                for width: CGFloat in [320, 393, 600] {
                    let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: width, height: 600))
                    timeline.layoutIfNeeded()
                    // Include the exact week/month blend that previously drew both
                    // month names on top of one another, and densely spaced weekdays.
                    for spacing: CGFloat in [44, 39, 34, 31, 29, 26.4, 24, 23, 22, 21, 20, 18, 10, 6.6, 5.3, 4.5, 3.6, 2.8, 44.0 / 30] {
                        timeline.beginZoom(at: width / 2)
                        timeline.changeZoom(scale: spacing / timeline.pointsPerDay, at: width / 2)
                        timeline.endZoom()
                        for position: CGFloat in [-90.33, 0, 0.07, 0.51, 18.91, 95.2] {
                            timeline.setDayPosition(position)
                            timeline.layoutIfNeeded()
                            let labels = visibleAxisLabels(in: timeline)
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
    func testTimelineShowsNoDividersAtEveryZoom() throws {
        let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 800, height: 500))
        timeline.layoutIfNeeded()
        for spacing: CGFloat in [44, 39, 29, 18, 6.6, 5.3, 4.6, 2.8, 44.0 / 30] {
            timeline.beginZoom(at: 400)
            timeline.changeZoom(scale: spacing / timeline.pointsPerDay, at: 400)
            timeline.endZoom()
            timeline.setDayPosition(0.37)
            timeline.layoutIfNeeded()
            let lines = timeline.subviews.filter {
                $0.alpha > 0 && !$0.isHidden && $0.frame.width > 0 && $0.frame.width <= 1 && $0.frame.height > 1
            }
            XCTAssertTrue(lines.isEmpty, "No vertical lines should appear at \(spacing) pt/day")
            let header = try XCTUnwrap(timeline.subviews.first { $0.accessibilityIdentifier == "timelineAxis" })
            XCTAssertFalse(header.subviews.contains {
                $0.alpha > 0 && !$0.isHidden && $0.frame.height > 0 && $0.frame.height <= 1 && $0.frame.width > 1
            }, "No horizontal line should appear below the date labels")
        }
    }

    @MainActor
    func testTimelineDotsStayInsideDateSectionsAndAvoidEachOtherAtEveryZoom() throws {
        let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: 200))
        let calendar = Calendar.current
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 27)))
        let position = try XCTUnwrap(calendar.dateComponents([.day], from: timeline.anchor, to: start).day)
        let events = (-10...300).map {
            Event(title: "Day \($0)", date: calendar.date(byAdding: .day, value: $0, to: start)!,
                  color: CodableColor(color: $0.isMultiple(of: 2) ? .red : .blue))
        }
        timeline.update(events: events)
        let datesByTitle = Dictionary(uniqueKeysWithValues: events.map { ($0.title, $0.date) })
        timeline.layoutIfNeeded()
        for spacing: CGFloat in [44, 39, 31, 26.4, 20, 10, 6.6, 4.6, 4.5, 3.6, 2.8, 44.0 / 30] {
            timeline.beginZoom(at: 0)
            timeline.changeZoom(scale: spacing / timeline.pointsPerDay, at: 0)
            timeline.endZoom()
            for offset: CGFloat in [0, 0.37, 6.8, 85.2] {
                timeline.setDayPosition(CGFloat(position) + offset)
                timeline.layoutIfNeeded()
                let markers = timeline.subviews.compactMap { $0 as? UIButton }
                XCTAssertFalse(markers.isEmpty)
                for (index, marker) in markers.enumerated() {
                    let date = try XCTUnwrap(datesByTitle[marker.accessibilityLabel ?? ""])
                    let component: Calendar.Component = timeline.zoomLevel == .days ? .day
                        : (timeline.zoomLevel == .weeks ? .weekOfYear : .month)
                    let interval = try XCTUnwrap(calendar.dateInterval(of: component, for: date))
                    let startDay = calendar.dateComponents([.day], from: timeline.anchor, to: interval.start).day!
                    let endDay = calendar.dateComponents([.day], from: timeline.anchor, to: interval.end).day!
                    let sectionLeft = (CGFloat(startDay) - timeline.dayPosition) * timeline.pointsPerDay
                    let sectionRight = (CGFloat(endDay) - timeline.dayPosition) * timeline.pointsPerDay
                    XCTAssertGreaterThanOrEqual(marker.frame.minX - timeline.bounds.minX - sectionLeft, 3.99)
                    XCTAssertGreaterThanOrEqual(sectionRight - (marker.frame.maxX - timeline.bounds.minX), 3.99)
                    for other in markers.dropFirst(index + 1) {
                        XCTAssertFalse(marker.frame.insetBy(dx: -0.9, dy: -0.9).intersects(other.frame),
                                       "Padding must not push neighboring dates into one another")
                    }
                }
            }
        }
    }

    @MainActor
    func testDateHeaderStaysPinnedWhileEventsScrollAtEveryScale() throws {
        for height: CGFloat in [108, 600] {
            let container = UIView(frame: CGRect(x: 0, y: 0, width: 393, height: height))
            container.backgroundColor = .systemBackground
            let timeline = TimelineScrollView(frame: container.bounds)
            container.addSubview(timeline)
            timeline.update(events: (0..<80).map {
                Event(title: "Stacked event \($0)", date: timeline.anchor, color: CodableColor(color: .blue))
            })
            timeline.layoutIfNeeded()
            let header = try XCTUnwrap(timeline.subviews.first { $0.accessibilityIdentifier == "timelineAxis" })
            func viewportFrame(_ view: UIView) -> CGRect {
                view.convert(view.bounds, to: timeline).offsetBy(dx: -timeline.bounds.minX, dy: -timeline.bounds.minY)
            }
            for spacing: CGFloat in [44, 26.4, 18, TimelineZoomLevel.months.pointsPerDay] {
                timeline.beginZoom(at: 196)
                timeline.changeZoom(scale: spacing / timeline.pointsPerDay, at: 196)
                timeline.endZoom()
                timeline.setDayPosition(0)
                timeline.contentOffset.y = 0
                timeline.layoutIfNeeded()
                XCTAssertGreaterThan(timeline.contentSize.height, height + 175)
                let labels = visibleAxisLabels(in: timeline)
                XCTAssertFalse(labels.isEmpty)
                let originalFrames = labels.map(viewportFrame)
                let marker = try XCTUnwrap(timeline.subviews.compactMap { $0 as? UIButton }.first)
                let markerTop = viewportFrame(marker).minY
                for offset: CGFloat in [80, 175, -20] {
                    timeline.contentOffset.y = offset
                    timeline.layoutIfNeeded()
                    XCTAssertEqual(viewportFrame(header).minY, 0, accuracy: 0.01)
                    XCTAssertEqual(viewportFrame(header).width, timeline.bounds.width, accuracy: 0.01)
                    for (label, original) in zip(labels, originalFrames) {
                        XCTAssertFalse(label.isHidden)
                        let frame = viewportFrame(label)
                        XCTAssertEqual(frame.minX, original.minX, accuracy: 0.01)
                        XCTAssertEqual(frame.minY, original.minY, accuracy: 0.01,
                                       "Date labels must stay fixed during vertical scrolling")
                        XCTAssertEqual(frame.width, original.width, accuracy: 0.01)
                        XCTAssertEqual(frame.height, original.height, accuracy: 0.01)
                    }
                    XCTAssertEqual(viewportFrame(marker).minY, markerTop - offset, accuracy: 0.01,
                                   "Events must still scroll underneath the pinned header")
                    let hit = try XCTUnwrap(timeline.hitTest(CGPoint(x: timeline.bounds.midX,
                                                                   y: timeline.bounds.minY + header.bounds.height / 2), with: nil))
                    XCTAssertTrue(hit === header || hit.isDescendant(of: header), "Covered event controls must not receive header taps")
                    if height == 600 && spacing == 18 && offset == 175 {
                        container.layoutIfNeeded()
                        let image = UIGraphicsImageRenderer(bounds: container.bounds).image { container.layer.render(in: $0.cgContext) }
                        let screenshot = XCTAttachment(image: image)
                        screenshot.name = "Pinned weekly axis above vertically scrolled events"
                        screenshot.lifetime = .keepAlways
                        add(screenshot)
                    }
                }
                timeline.setDayPosition(0.4)
                timeline.layoutIfNeeded()
                XCTAssertEqual(header.bounds.minX, timeline.contentOffset.x, accuracy: 0.01)
                XCTAssertEqual(viewportFrame(header).minY, 0, accuracy: 0.01)
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

    func testEventListLoadsExact365DayPagesAcrossLeapYearAndDaylightSaving() {
        let start = calendar.date(from: DateComponents(year: 2027, month: 3, day: 7, hour: 15))!
        let today = calendar.startOfDay(for: start)
        func date(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today)! }
        var window = EventListWindow(today: start, calendar: calendar)
        XCTAssertEqual(window.end, calendar.date(from: DateComponents(year: 2028, month: 3, day: 6)))
        XCTAssertTrue(window.contains(date(-1)), "History remains reachable above today")
        XCTAssertTrue(window.contains(date(364)))
        XCTAssertFalse(window.contains(date(365)))
        window.loadMore()
        XCTAssertEqual(window.dayCount, 730)
        XCTAssertTrue(window.contains(date(365)))
        XCTAssertTrue(window.contains(date(729)))
        XCTAssertFalse(window.contains(date(730)))
        window.include(date(730))
        XCTAssertEqual(window.dayCount, 1095, "Selecting a distant timeline event reveals its page")
        XCTAssertTrue(window.contains(date(730)))
        window.include(today)
        XCTAssertEqual(window.dayCount, 1095, "Revealing a loaded event does not collapse earlier pages")
    }

    func testListWindowRefreshKeepsLoadedPagesAndReanchorsAfterMidnightOrTravel() {
        let start = calendar.date(from: DateComponents(year: 2027, month: 3, day: 7, hour: 23, minute: 59))!
        var window = EventListWindow(today: start, calendar: calendar)
        window.loadMore()
        let nextMorning = start.addingTimeInterval(120)
        XCTAssertTrue(window.refresh(today: nextMorning, calendar: calendar))
        XCTAssertEqual(window.dayCount, 730)
        XCTAssertEqual(window.end, calendar.date(byAdding: .day, value: 730, to: calendar.startOfDay(for: nextMorning)))
        XCTAssertTrue(window.contains(calendar.startOfDay(for: start)), "Refreshing must retain accessible history")
        XCTAssertFalse(window.refresh(today: nextMorning.addingTimeInterval(60), calendar: calendar))
        var destination = calendar; destination.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertTrue(window.refresh(today: nextMorning, calendar: destination))
        XCTAssertEqual(window.dayCount, 730)
        XCTAssertEqual(window.end, destination.date(byAdding: .day, value: 730, to: destination.startOfDay(for: nextMorning)))
        let afterDST = destination.date(from: DateComponents(year: 2027, month: 3, day: 15))!
        XCTAssertTrue(window.refresh(today: afterDST, calendar: destination))
        XCTAssertEqual(window.end, destination.date(byAdding: .day, value: 730, to: afterDST))
    }

    @MainActor
    func testFollowingSheetDatesPreservesZoomAndCalendarFocusAcrossRecycledWindows() {
        let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: 550))
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
        canvas.update(events: [], highlightedEventID: nil)
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
        for height: CGFloat in [100, 250] {
            timeline.frame.size.height = height
            timeline.beginZoom(at: 180)
            XCTAssertFalse(timeline.panGestureRecognizer.isEnabled, "Scrolling cannot move dates under an active pinch")
            timeline.changeZoom(scale: 0.6, at: 180)
            timeline.frame.size.height = height + 24
            timeline.changeZoom(scale: 0.8, at: 180)
            timeline.endZoom()
            XCTAssertTrue(timeline.panGestureRecognizer.isEnabled)
        }
    }

    @MainActor
    func testTimelineFitsVisibleLanesWithEqualPaddingAtEveryZoom() {
        for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
            UITraitCollection(preferredContentSizeCategory: category).performAsCurrent {
                let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: 100))
                for level in TimelineZoomLevel.allCases {
                    timeline.beginZoom(at: 0)
                    timeline.changeZoom(scale: level.pointsPerDay / timeline.pointsPerDay, at: 0)
                    timeline.endZoom()
                    timeline.setDayPosition(0)
                    var lastHeight: CGFloat = 0
                    for count in [0, 1, 2, 5] {
                        timeline.update(events: (0..<count).map {
                            Event(title: "Event \($0)", date: timeline.anchor, color: CodableColor(color: .blue))
                        })
                        timeline.layoutIfNeeded()
                        timeline.frame.size.height = timeline.preferredHeight
                        timeline.layoutIfNeeded()
                        guard let header = timeline.subviews.first(where: { $0.accessibilityIdentifier == "timelineAxis" }) else {
                            XCTFail("Missing timeline date header"); return
                        }
                        if level != .days {
                            for label in visibleAxisLabels(in: timeline) {
                                let frame = header.convert(label.bounds, from: label)
                                XCTAssertEqual(frame.midY, header.bounds.midY, accuracy: 1,
                                               "Single-row week and month labels need equal top/bottom padding")
                            }
                        }
                        let markers = timeline.subviews.compactMap { $0 as? UIButton }
                        XCTAssertEqual(markers.count, count)
                        XCTAssertGreaterThan(timeline.preferredHeight, lastHeight)
                        lastHeight = timeline.preferredHeight
                        XCTAssertEqual(timeline.contentSize.height, timeline.bounds.height, accuracy: 1)
                        if let top = markers.map(\.frame.minY).min(), let bottom = markers.map(\.frame.maxY).max() {
                            let above = top - header.bounds.height
                            let below = timeline.bounds.height - bottom
                            XCTAssertEqual(above, below, accuracy: 1, "The marker group must be centered below the date header")
                            XCTAssertEqual(above, 16, accuracy: 1)
                        }
                    }
                    timeline.setDayPosition(500)
                    timeline.layoutIfNeeded()
                    XCTAssertLessThan(timeline.preferredHeight, lastHeight, "Quiet dates shrink the timeline")
                    timeline.frame.size.height = timeline.preferredHeight
                    timeline.layoutIfNeeded()
                    XCTAssertTrue(timeline.subviews.compactMap { $0 as? UIButton }.isEmpty)
                    XCTAssertEqual(timeline.contentOffset.y, 0)
                }
            }
        }
    }

    @MainActor
    func testHeightReportsFollowHeaderZoomAndVisibleEventChanges() async {
        let canvas = TimelineCanvasView(frame: CGRect(x: 0, y: 0, width: 393, height: 100))
        let events = (0..<3).map {
            Event(title: "Event \($0)", date: canvas.timeline.anchor, color: CodableColor(color: .blue))
        }
        let dayHeight = expectation(description: "Day header and three lanes reported")
        canvas.timeline.onHeightChange = { height in
            XCTAssertEqual(height, 152, accuracy: 1)
            dayHeight.fulfill()
        }
        canvas.update(events: events, highlightedEventID: nil)
        canvas.layoutIfNeeded()
        canvas.timeline.layoutIfNeeded()
        await fulfillment(of: [dayHeight], timeout: 1)
        let weekHeight = expectation(description: "Single-row week header and smaller dots reported")
        canvas.timeline.onHeightChange = { height in
            XCTAssertLessThan(height, 152)
            weekHeight.fulfill()
        }
        canvas.timeline.beginZoom(at: 0)
        canvas.timeline.changeZoom(scale: 0.15, at: 0)
        // Live height changes must arrive before the gesture ends.
        await fulfillment(of: [weekHeight], timeout: 1)
        canvas.timeline.endZoom()

        let beforeDrag = canvas.timeline.preferredHeight
        let quietHeight = expectation(description: "Quiet dates resize during the drag")
        canvas.timeline.onHeightChange = { height in
            XCTAssertLessThan(height, beforeDrag)
            quietHeight.fulfill()
        }
        canvas.timeline.scrollViewWillBeginDragging(canvas.timeline)
        canvas.timeline.setDayPosition(500)
        canvas.timeline.layoutIfNeeded()
        await fulfillment(of: [quietHeight], timeout: 1)
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
        let header = scrollView.subviews.first { $0.accessibilityIdentifier == "timelineAxis" }!
        XCTAssertTrue(header.subviews.contains { $0.accessibilityLabel == todayLabel })
        for _ in 0..<10 {
            scrollView.contentOffset.x += 70 * TimelineScrollWindow.dayWidth
            scrollView.setNeedsLayout()
            scrollView.layoutIfNeeded()
        }
        XCTAssertLessThan(header.subviews.filter(\.isAccessibilityElement).count, 15)
    }
}
