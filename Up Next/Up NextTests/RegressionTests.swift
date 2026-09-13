import XCTest
@testable import Up_Next

final class RegressionTests: XCTestCase {
    func makeEvent(_ title: String = "Event", day: Int = 1, seriesID: UUID? = nil) -> Event {
        let date = Calendar.current.date(from: DateComponents(year: 2030, month: 1, day: day))!
        return Event(title: title, date: date, color: CodableColor(color: .blue),
                     repeatOption: seriesID == nil ? .never : .daily, seriesID: seriesID)
    }

    func testTimelineReusesOnlyNonoverlappingLanesAndClipsOngoingEvents() {
        var a = makeEvent("A", day: 1); a.endDate = makeEvent(day: 3).date
        var b = makeEvent("B", day: 2); b.endDate = makeEvent(day: 4).date
        var c = makeEvent("C", day: 4); c.endDate = makeEvent(day: 5).date
        let layout = TimelineLayout.items(events: [c, a, b], from: makeEvent(day: 2).date, days: 7)
        let laneA = layout.first { $0.id == a.id }!, laneB = layout.first { $0.id == b.id }!, laneC = layout.first { $0.id == c.id }!
        XCTAssertEqual(laneA.start, 0)
        XCTAssertNotEqual(laneB.lane, laneC.lane)
        XCTAssertEqual(laneA.lane, laneC.lane)
        XCTAssertEqual(laneA.dayCount, 2)
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
            XCTAssertTrue(generateRepeatingEvents(for: event, repeatUntilOption: .indefinitely, showEndDate: false).isEmpty)
        }
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
