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

    func testPagingMaterializesExact365DayWindowsAndPreservesExistingOccurrences() {
        let event = seed(.daily, date(2027, 1, 1))
        var window = EventListWindow(today: event.date, calendar: calendar)
        var events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .indefinitely), now: event.date, calendar: calendar)
        XCTAssertEqual(events.filter { window.contains($0.date) }.count, 365)
        let original = events
        for expected in [730, 1095] {
            window.loadMore()
            events = Recurrence.replenishing(events, now: event.date, calendar: calendar, before: window.end)
            XCTAssertEqual(events.count, expected)
            XCTAssertEqual(Array(events.prefix(original.count)), original)
            XCTAssertTrue(events.allSatisfy { $0.date < window.end })
            XCTAssertTrue(Recurrence.hasEvents(onOrAfter: window.end, in: events, calendar: calendar))
            XCTAssertEqual(Recurrence.replenishing(events, now: event.date, calendar: calendar, before: window.end), events)
        }
        XCTAssertEqual(Set(events.map(\.id)).count, events.count)
    }

    func testSparseRecurrenceCanPageAcrossEmptyYearsAndStopsAtItsEnding() {
        var event = seed(.custom, date(2027, 1, 1))
        event.customRepeatCount = 2; event.repeatUnit = "Years"; event.repeatUntil = date(2029, 1, 1)
        var events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .onDate), now: event.date, calendar: calendar)
        var window = EventListWindow(today: event.date, calendar: calendar)
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(Recurrence.hasEvents(onOrAfter: window.end, in: events, calendar: calendar))
        window.loadMore()
        events = Recurrence.replenishing(events, now: event.date, calendar: calendar, before: window.end)
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(Recurrence.hasEvents(onOrAfter: window.end, in: events, calendar: calendar))
        window.loadMore()
        events = Recurrence.replenishing(events, now: event.date, calendar: calendar, before: window.end)
        XCTAssertEqual(events.map(\.date), [date(2027, 1, 1), date(2029, 1, 1)])
        XCTAssertFalse(Recurrence.hasEvents(onOrAfter: window.end, in: events, calendar: calendar))
    }

    func testFutureOccurrenceLookupRespectsExclusionsCountsAndClampedMonths() {
        let event = seed(.monthly, date(2030, 1, 31))
        var rule = RecurrenceRule(event: event, end: .after)
        XCTAssertEqual(rule.nextIndex(onOrAfter: date(2030, 2, 1), calendar: calendar), 1)
        XCTAssertEqual(rule.nextIndex(onOrAfter: date(2030, 3, 1), calendar: calendar), 2)
        rule.excludedIndices = [1, 2]
        XCTAssertNil(rule.nextIndex(onOrAfter: date(2030, 2, 1), calendar: calendar))
        rule.end = .indefinitely
        XCTAssertEqual(rule.nextIndex(onOrAfter: date(2030, 2, 1), calendar: calendar), 3)
        rule.end = .onDate; rule.until = date(2030, 3, 31)
        XCTAssertNil(rule.nextIndex(onOrAfter: date(2030, 2, 1), calendar: calendar))
    }

    func testPagingAvailabilityUsesTheSeriesCategoryInsteadOfAnExceptionCategory() {
        var event = seed(.yearly, date(2030, 1, 1)); event.category = "Social"
        var events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .indefinitely), now: event.date, calendar: calendar)
        events[0].category = "Work"; events[0].isRecurrenceException = true
        let boundary = date(2032, 1, 1)
        XCTAssertFalse(Recurrence.hasEvents(onOrAfter: boundary, in: events, category: "Work", calendar: calendar))
        XCTAssertTrue(Recurrence.hasEvents(onOrAfter: boundary, in: events, category: "Social", calendar: calendar))
        let filled = Recurrence.replenishing(events, now: event.date, calendar: calendar, before: date(2033, 1, 1))
        XCTAssertEqual(filled.last?.category, "Social")
        XCTAssertEqual(filled.first?.category, "Work")
    }

    func testEditingEndCountChangesSeriesWithoutChangingSurvivingIDs() {
        let event = seed(.daily, date(2030, 1, 1))
        let events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .after), calendar: calendar)
        var updated = events[1]
        updated.recurrence!.count = 2
        let edited = EventSeries.updating(events[1], with: updated, in: events, calendar: calendar)
        XCTAssertEqual(edited.map(\.id), Array(events.prefix(2)).map(\.id))
    }

    func testMaximumSizeSeriesMetadataEditPreservesOccurrenceIdentityAndExceptions() {
        var event = seed(.daily, date(2030, 1, 1))
        event.repeatUntilCount = 10000
        event.endDate = date(2030, 1, 3)
        var events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .after), calendar: calendar)
        events[100].isRecurrenceException = true
        events[100].date = date(2029, 12, 1)
        let unrelated = Event(title: "Unrelated", date: event.date, color: CodableColor(color: .orange))
        events.insert(unrelated, at: 5000)
        var replacement = events[9000]
        replacement.title = "Renamed"
        let start = ProcessInfo.processInfo.systemUptime
        let updated = EventSeries.updating(events[9000], with: replacement, in: events, calendar: calendar)
        print("Series metadata edit, 10000 occurrences: \(ProcessInfo.processInfo.systemUptime - start) seconds")
        XCTAssertEqual(updated.map(\.id), events.map(\.id))
        XCTAssertEqual(updated.map(\.date), events.map(\.date))
        XCTAssertEqual(updated.map(\.occurrenceIndex), events.map(\.occurrenceIndex))
        XCTAssertEqual(updated.map(\.isRecurrenceException), events.map(\.isRecurrenceException))
        XCTAssertEqual(updated[5000], unrelated)
        XCTAssertTrue(updated.filter { $0.seriesID == event.seriesID }.allSatisfy { $0.title == "Renamed" })
    }

    func testChangingEndingPreservesStoredHistoryWithoutBackfillingMissingYears() throws {
        let event = seed(.daily, date(2030, 1, 1))
        var events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .indefinitely), now: event.date, calendar: calendar)
        events = Recurrence.removingOccurrence(events[10], from: events)
        events[5].isRecurrenceException = true
        events[5].date = date(2029, 12, 20)
        events[5].endDate = date(2029, 12, 22)
        let exception = events[5]
        var replacement = events[20]
        replacement.recurrence!.end = .onDate
        replacement.recurrence!.until = date(2033, 1, 1)
        let updated = Recurrence.updatingSeries(events[20], with: replacement, in: events,
                                               calendar: calendar, now: date(2032, 1, 1))
        XCTAssertTrue(Set(events.map(\.id)).isSubset(of: Set(updated.map(\.id))))
        XCTAssertEqual(Set(updated.map(\.id)).count, updated.count)
        XCTAssertFalse(updated.contains { $0.occurrenceIndex == 10 })
        XCTAssertFalse(updated.contains { $0.date == date(2031, 6, 1) }, "Changing the ending must not invent unstored history")
        for original in events {
            XCTAssertEqual(updated.first { $0.id == original.id }?.date, original.date)
        }
        XCTAssertEqual(updated.first { $0.id == exception.id }?.endDate, exception.endDate)
        XCTAssertEqual(updated.last?.date, date(2033, 1, 1))
        XCTAssertEqual(updated.first?.recurrence?.anchorDay, CalendarDay(event.date, calendar: calendar))
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        decoder.userInfo[.eventCalendar] = calendar
        let savedRule = try decoder.decode(RecurrenceRule.self, from: encoder.encode(XCTUnwrap(updated.first?.recurrence)))
        XCTAssertEqual(savedRule.anchor, event.date)
        XCTAssertEqual(savedRule.until, date(2033, 1, 1))
    }

    func testEndingInThePastKeepsExactlyTheSurvivingHistoricalOccurrences() {
        let event = seed(.daily, date(2030, 1, 1))
        let events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .indefinitely), now: event.date, calendar: calendar)
        var replacement = events[0]
        replacement.recurrence!.end = .onDate
        replacement.recurrence!.until = date(2030, 1, 3)
        let updated = Recurrence.updatingSeries(events[0], with: replacement, in: events,
                                               calendar: calendar, now: date(2032, 1, 1))
        XCTAssertEqual(updated.map(\.id), Array(events.prefix(3)).map(\.id))
        XCTAssertEqual(updated.map(\.date), [date(2030, 1, 1), date(2030, 1, 2), date(2030, 1, 3)])
    }

    func testMovingMonthlySeriesFromAnyOccurrenceKeepsCalendarDatesConsistent() {
        let event = seed(.monthly, date(2030, 1, 31))
        let events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .after), calendar: calendar)
        let cases = [
            (0, date(2030, 1, 30), [date(2030, 1, 30), date(2030, 2, 28), date(2030, 3, 30)]),
            (1, date(2030, 2, 27), [date(2030, 1, 27), date(2030, 2, 27), date(2030, 3, 27)]),
            (2, date(2030, 4, 30), [date(2030, 2, 28), date(2030, 3, 30), date(2030, 4, 30)])
        ]
        for (index, movedDate, expected) in cases {
            var replacement = events[index]; replacement.date = movedDate
            let updated = EventSeries.updating(events[index], with: replacement, in: events, calendar: calendar)
            XCTAssertEqual(updated.map(\.id), events.map(\.id))
            XCTAssertEqual(updated.map(\.date), expected)
            for (index, member) in updated.enumerated() {
                XCTAssertEqual(member.date, member.recurrence?.date(at: index, calendar: calendar))
            }
        }
    }

    func testMovingYearlySeriesToLeapDayPersistsItsIntendedDay() throws {
        var event = seed(.yearly, date(2029, 2, 28)); event.repeatUntilCount = 4
        let events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .after), calendar: calendar)
        var replacement = events[3]; replacement.date = date(2032, 2, 29)
        let updated = EventSeries.updating(events[3], with: replacement, in: events, calendar: calendar)
        XCTAssertEqual(updated.map(\.date), [date(2029, 2, 28), date(2030, 2, 28), date(2031, 2, 28), date(2032, 2, 29)])
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        decoder.userInfo[.eventCalendar] = calendar
        let rule = try decoder.decode(RecurrenceRule.self, from: encoder.encode(XCTUnwrap(updated[0].recurrence)))
        XCTAssertEqual(rule.date(at: 7, calendar: calendar), date(2036, 2, 29))
        var metadata = updated[3]; metadata.title = "Renamed"
        let renamed = EventSeries.updating(updated[3], with: metadata, in: updated, calendar: calendar)
        XCTAssertEqual(renamed.map(\.date), updated.map(\.date))
        XCTAssertEqual(renamed.map(\.id), updated.map(\.id))
    }

    func testMonthlyMovesPreserveDateExceptionsWithoutTreatingMetadataAsADateException() {
        let event = seed(.monthly, date(2030, 1, 31))
        var events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .after), calendar: calendar)
        events[1].title = "Title exception"; events[1].isRecurrenceException = true
        events[2].date = date(2030, 3, 15); events[2].isRecurrenceException = true
        var replacement = events[0]; replacement.date = date(2030, 1, 30)
        let updated = EventSeries.updating(events[0], with: replacement, in: events, calendar: calendar)
        XCTAssertEqual(updated.map(\.date), [date(2030, 1, 30), date(2030, 2, 28), date(2030, 3, 14)])
        XCTAssertEqual(updated.map(\.isRecurrenceException), events.map(\.isRecurrenceException))
    }

    func testEquivalentCustomMonthlyPatternKeepsTheOriginalMonthEndAnchor() {
        let event = seed(.monthly, date(2030, 1, 31))
        let events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .after), calendar: calendar)
        var replacement = events[1]
        replacement.repeatOption = .custom; replacement.repeatUnit = "Months"
        replacement.recurrence!.frequency = .custom; replacement.recurrence!.unit = "Months"
        let updated = EventSeries.updating(events[1], with: replacement, in: events, calendar: calendar)
        XCTAssertEqual(updated.map(\.date), events.map(\.date))
        XCTAssertEqual(updated.first?.recurrence?.anchor, event.date)
    }

    func testMovingFromADateExceptionKeepsAShortMonthAnchorConsistent() {
        let event = seed(.monthly, date(2030, 1, 31))
        let initial = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .after), calendar: calendar)
        var firstMove = initial[2]; firstMove.date = date(2030, 4, 30)
        var events = EventSeries.updating(initial[2], with: firstMove, in: initial, calendar: calendar)
        events[2].date = date(2030, 4, 15); events[2].isRecurrenceException = true
        var replacement = events[2]; replacement.date = date(2030, 4, 16)
        let updated = EventSeries.updating(events[2], with: replacement, in: events, calendar: calendar)
        XCTAssertEqual(updated.map(\.date), [date(2030, 3, 1), date(2030, 4, 1), date(2030, 4, 16)])
        XCTAssertEqual(updated[0].recurrence?.date(at: 0, calendar: calendar), updated[0].date)
        XCTAssertEqual(updated[1].recurrence?.date(at: 1, calendar: calendar), updated[1].date)
        XCTAssertEqual(updated.map(\.id), events.map(\.id))
    }
}
