import XCTest
@testable import Up_Next

final class RecurrenceTests: XCTestCase {
    var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ year: Int, _ month: Int, _ day: Int) -> Date { calendar.date(from: DateComponents(year: year, month: month, day: day))! }
    func seed(_ frequency: RepeatOption, _ start: Date) -> Event {
        Event(title: "Series", date: start, color: CodableColor(color: .blue), repeatOption: frequency,
              seriesID: UUID(), customRepeatCount: 1, repeatUnit: "Days", repeatUntilCount: 3, useCustomRepeatOptions: true)
    }

    func testMonthlyAndYearlyRecurrencesRemainAnchored() {
        let monthly = seed(.monthly, date(2030, 1, 31))
        let result = Recurrence.generate(monthly, rule: RecurrenceRule(event: monthly, end: .after), calendar: calendar)
        XCTAssertEqual(result.map(\.date), [date(2030, 1, 31), date(2030, 2, 28), date(2030, 3, 31)])
        var yearly = seed(.yearly, date(2028, 2, 29)); yearly.repeatUntilCount = 5
        let leap = Recurrence.generate(yearly, rule: RecurrenceRule(event: yearly, end: .after), calendar: calendar)
        XCTAssertEqual(leap.last?.date, date(2032, 2, 29))
    }

    func testExplicitEndModesAndIntervalsSurviveRoundTrip() throws {
        var event = seed(.custom, date(2030, 1, 1)); event.customRepeatCount = 2; event.repeatUnit = "Weeks"
        let events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .after), calendar: calendar)
        XCTAssertEqual(events.map(\.date), [date(2030, 1, 1), date(2030, 1, 15), date(2030, 1, 29)])
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        XCTAssertEqual(try EventStore.decode(encoder.encode(events))[1].recurrence?.end, .after)
        event.repeatUntil = date(2030, 1, 15)
        XCTAssertEqual(Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .onDate), calendar: calendar).count, 2)
    }

    func testRefillPreservesDeletedAndEditedOccurrences() {
        let event = seed(.daily, date(2030, 1, 1))
        var events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .indefinitely), now: date(2030, 1, 1), calendar: calendar)
        let removedIndex = events[10].occurrenceIndex!
        events = Recurrence.removingOccurrence(events[10], from: events)
        events[0].title = "Exception"; events[0].isRecurrenceException = true
        let oldIDs = Set(events.map(\.id))
        let filled = Recurrence.replenishing(events, now: date(2031, 1, 1), calendar: calendar)
        XCTAssertTrue(oldIDs.isSubset(of: Set(filled.map(\.id))))
        XCTAssertFalse(filled.contains { $0.occurrenceIndex == removedIndex })
        XCTAssertEqual(filled.first?.title, "Exception")
        XCTAssertTrue(filled.contains { $0.date == date(2032, 1, 1) })
    }

    func testEditingEndCountChangesSeriesWithoutChangingSurvivingIDs() {
        let event = seed(.daily, date(2030, 1, 1))
        let events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .after), calendar: calendar)
        var updated = events[1]
        updated.recurrence!.count = 2
        let edited = EventSeries.updating(events[1], with: updated, in: events, calendar: calendar)
        XCTAssertEqual(edited.map(\.id), Array(events.prefix(2)).map(\.id))
    }
}
