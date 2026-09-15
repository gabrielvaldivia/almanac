import XCTest
import SwiftUI
@testable import Up_Next

final class RegressionTests: XCTestCase {
    func makeEvent(_ title: String = "Event", day: Int = 1, seriesID: UUID? = nil) -> Event {
        let date = Calendar.current.date(from: DateComponents(year: 2030, month: 1, day: day))!
        return Event(title: title, date: date, color: CodableColor(color: .blue),
                     repeatOption: seriesID == nil ? .never : .daily, seriesID: seriesID)
    }

    func testEventTextHasReadableContrastAcrossStylesColorsAndHighlights() {
        let colors: [Color] = [.blue, .red, .yellow, .orange, .pink, .purple, .green, .cyan,
                               .white, .black, .gray, Color(red: 0.97, green: 0.93, blue: 0.81),
                               Color(red: 0.12, green: 0.05, blue: 0.2).opacity(0.3)]
        for color in colors {
            for style in ["bubbly", "classic", "naked"] {
                for dark in [false, true] {
                    for highlighted in [false, true] {
                        let palette = EventRowColors(category: CodableColor(color: color), style: style,
                                                     dark: dark, highlighted: highlighted)
                        XCTAssertGreaterThanOrEqual(EventRowColors.contrast(palette.title, palette.background), 4.5)
                        XCTAssertGreaterThanOrEqual(EventRowColors.contrast(palette.date, palette.background), 4.5)
                    }
                }
            }
        }
        XCTAssertEqual(EventRowColors.contrast(CodableColor(color: .white), CodableColor(color: .black)), 21, accuracy: 0.0001)
        let blue = CodableColor(color: Color(red: 0, green: 0.2, blue: 0.5))
        XCTAssertEqual(EventRowColors(category: blue, style: "bubbly", dark: false, highlighted: false).title, blue,
                       "Already readable category text retains its color")
    }

    func testWidgetKeepsEventsThroughTheirLastCalendarDay() {
        var event = makeEvent(day: 1); event.endDate = makeEvent(day: 2).date
        let midday = makeEvent(day: 2).date.addingTimeInterval(12 * 3600)
        XCTAssertEqual(WidgetEvents.upcoming([event], at: midday).count, 1)
        XCTAssertTrue(WidgetEvents.upcoming([event], at: makeEvent(day: 3).date).isEmpty)
        XCTAssertEqual(Calendar.current.component(.hour, from: WidgetEvents.entryDates(now: midday)[1]), 0)
    }

    func testTimelineReusesOnlyNonoverlappingLanesAndIncludesOngoingEvents() {
        var a = makeEvent("A", day: 1); a.endDate = makeEvent(day: 3).date
        var b = makeEvent("B", day: 2); b.endDate = makeEvent(day: 4).date
        var c = makeEvent("C", day: 4); c.endDate = makeEvent(day: 5).date
        let layout = TimelineLayout.make(events: [c, a, b], visibleDays: 0...6, anchor: makeEvent(day: 2).date).placements
        let laneA = layout.first { $0.event.id == a.id }!, laneB = layout.first { $0.event.id == b.id }!, laneC = layout.first { $0.event.id == c.id }!
        XCTAssertEqual(laneA.startDay, -1)
        XCTAssertNotEqual(laneB.lane, laneC.lane)
        XCTAssertEqual(laneA.lane, laneC.lane)
        XCTAssertEqual(laneA.endDay, 1)
    }

    func testSpanningEventsIntersectWindowEvenWhenBothEndpointsAreOutside() {
        var event = makeEvent(day: 1)
        event.endDate = makeEvent(day: 30).date
        XCTAssertTrue(EventWindow.intersects(event, start: makeEvent(day: 5).date, end: makeEvent(day: 10).date))
        XCTAssertFalse(EventWindow.intersects(makeEvent(day: 1), start: makeEvent(day: 5).date, end: makeEvent(day: 10).date))
    }

    func testInvalidRepeatIntervalsCannotCreateDuplicates() {
        var event = makeEvent()
        event.repeatOption = .custom
        event.repeatUnit = "Days"
        event.useCustomRepeatOptions = true
        for interval in [0, -1, Int.max] {
            event.customRepeatCount = interval
            XCTAssertTrue(generateRepeatingEvents(for: event, repeatUntilOption: .indefinitely).isEmpty)
        }
    }

    func testWidgetGroupsKeepVisibleLimitsOrderAndOngoingEvents() {
        let calendar = Calendar.current
        let today = makeEvent(day: 2).date
        var ongoing = makeEvent("Ongoing", day: 1); ongoing.endDate = makeEvent(day: 3).date
        let sameDay = makeEvent("Same day", day: 2)
        let tomorrow = makeEvent("Tomorrow", day: 3)
        let later = makeEvent("Later", day: 16)
        let snapshot = WidgetEvents.upcoming([later, tomorrow, makeEvent("Past", day: 1), sameDay, ongoing], at: today)
        XCTAssertEqual(snapshot.map(\.id), [ongoing.id, sameDay.id, tomorrow.id, later.id])
        let medium = WidgetEvents.grouped(snapshot, limit: 2, at: today)
        XCTAssertEqual(medium.map(\.date), [today])
        XCTAssertEqual(medium.flatMap(\.events).map(\.id), [ongoing.id, sameDay.id])
        let large = WidgetEvents.grouped(snapshot, limit: 5, at: today)
        XCTAssertEqual(large.map(\.date), [today, tomorrow.date, later.date])
        XCTAssertEqual(large.flatMap(\.events), snapshot)
        XCTAssertTrue(WidgetEvents.grouped(snapshot, limit: 0, at: today).isEmpty)
        let afterMidnight = calendar.date(byAdding: .day, value: 1, to: today)!
        let refreshed = WidgetEvents.upcoming(snapshot, at: afterMidnight)
        XCTAssertEqual(WidgetEvents.grouped(refreshed, limit: 2, at: afterMidnight).flatMap(\.events).map(\.id), [ongoing.id, tomorrow.id])
    }

    func testWidgetLinksHaveValidatedRoutes() {
        let id = UUID()
        XCTAssertEqual(DeepLink(url: DeepLink.eventURL(id)), .event(id))
        XCTAssertEqual(DeepLink(url: URL(string: "upnext://addEvent")!), .addEvent)
        XCTAssertNil(DeepLink(url: URL(string: "https://event/\(id)")!))
        XCTAssertNil(DeepLink(url: URL(string: "upnext://event/bad-id")!))
    }

    func testPreferencesMigrationPreservesLatestSettingsAndNone() {
        let oldName = "test.legacy.\(UUID())", newName = "test.shared.\(UUID())"
        let old = UserDefaults(suiteName: oldName)!, shared = UserDefaults(suiteName: newName)!
        defer { old.removePersistentDomain(forName: oldName); shared.removePersistentDomain(forName: newName) }
        shared.set("Work", forKey: "defaultCategory")
        old.set("", forKey: "defaultCategory")
        old.set(true, forKey: "dailyNotificationEnabled")
        AppPreferences.migrate(from: old, to: shared)
        XCTAssertEqual(shared.string(forKey: "defaultCategory"), "")
        XCTAssertTrue(shared.bool(forKey: "dailyNotificationEnabled"))
        AppPreferences.migrate(from: old, to: shared)
        XCTAssertEqual(shared.string(forKey: "defaultCategory"), "")
        XCTAssertNil(old.object(forKey: "defaultCategory"))
    }

    func testCategoryNamesCannotMergeOrBeEmpty() {
        XCTAssertFalse(CategoryName.isValid("  ", existing: []))
        XCTAssertFalse(CategoryName.isValid(" work ", existing: ["Work", "Home"]))
        XCTAssertTrue(CategoryName.isValid("Work", existing: ["Work", "Home"], excluding: "Work"))
        XCTAssertFalse(CategoryName.isValid("Home", existing: ["Work", "Home"], excluding: "Work"))
    }

    func testMissingSeriesDoesNotSelectOrDeleteOtherEvents() {
        var converted = makeEvent("Converted")
        converted.repeatOption = .daily
        let unrelated = makeEvent("Unrelated")
        let events = [converted, unrelated]
        XCTAssertTrue(EventSeries.members(of: converted, in: events).isEmpty)
        XCTAssertEqual(EventSeries.removing(converted, from: events).map(\.id), events.map(\.id))
    }

    func testSeriesDeletionPreservesOtherSeriesAndStandaloneEvents() {
        let id = UUID()
        let first = makeEvent(seriesID: id)
        let second = makeEvent(day: 2, seriesID: id)
        let unrelated = makeEvent("Unrelated")
        let otherSeries = makeEvent(seriesID: UUID())
        XCTAssertEqual(EventSeries.removing(first, from: [first, unrelated, second, otherSeries]).map(\.id),
                       [unrelated.id, otherSeries.id])
    }
    func testLongSeriesTitleEditsPreserveEveryOccurrence() {
        let id = UUID()
        let start = makeEvent(seriesID: id).date
        let events = (0..<365).map { offset -> Event in
            var event = makeEvent(seriesID: id)
            event.date = Calendar.current.date(byAdding: .day, value: offset, to: start)!
            return event
        }
        for index in [0, 180, 364] {
            var replacement = events[index]
            replacement.title = "Renamed"
            let updated = EventSeries.updating(events[index], with: replacement, in: events)
            XCTAssertEqual(updated.map(\.id), events.map(\.id))
            XCTAssertEqual(updated.map(\.date), events.map(\.date))
            XCTAssertTrue(updated.allSatisfy { $0.title == "Renamed" })
        }
    }

    func testInterleavedSeriesDoesNotUseUnrelatedNeighborDate() {
        let id = UUID()
        let first = makeEvent(seriesID: id)
        let second = makeEvent(day: 2, seriesID: id)
        let unrelated = makeEvent("Other", day: 20)
        var replacement = first
        replacement.repeatOption = .weekly
        let result = EventSeries.updating(first, with: replacement, in: [first, unrelated, second])
        XCTAssertEqual(result[1].date, unrelated.date)
        XCTAssertEqual(result[2].date, Calendar.current.date(byAdding: .day, value: 7, to: first.date))
    }
}
