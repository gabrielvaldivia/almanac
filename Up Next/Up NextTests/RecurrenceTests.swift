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

    func testLongInactivityRefillsTheFutureWithoutDiscardingStoredHistory() {
        var event = seed(.daily, date(2030, 1, 1))
        event.endDate = date(2030, 1, 4)
        var rule = RecurrenceRule(event: event, end: .indefinitely, calendar: calendar)
        let now = date(2065, 1, 1)
        let todayIndex = calendar.dateComponents([.day], from: event.date, to: now).day!
        rule.excludedIndices = [20, todayIndex + 2]
        let original = Recurrence.generate(event, rule: rule, now: event.date, calendar: calendar)
        let refilled = Recurrence.replenishing(original, now: now, calendar: calendar)
        XCTAssertEqual(Array(refilled.prefix(original.count)), original)
        XCTAssertTrue(refilled.contains { $0.date == now })
        XCTAssertTrue(refilled.contains { $0.date == date(2066, 1, 1) })
        XCTAssertTrue(refilled.contains { $0.date < now && ($0.endDate ?? $0.date) >= now })
        XCTAssertFalse(refilled.contains { rule.excludedIndices.contains($0.occurrenceIndex ?? -1) })
        XCTAssertLessThan(refilled.count - original.count, 400)
        XCTAssertEqual(Recurrence.replenishing(refilled, now: now, calendar: calendar), refilled)

        event.repeatUntilCount = 10000
        let finite = RecurrenceRule(event: event, end: .after, calendar: calendar)
        XCTAssertEqual(Recurrence.generate(event, rule: finite, fromIndex: 9998, now: now, calendar: calendar).map(\.occurrenceIndex), [9998, 9999])
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

    func testWidgetAndAppReplenishmentAgreeOnFutureIDsWithoutRewritingStoredIDs() throws {
        let event = seed(.yearly, date(2030, 1, 1))
        var stored = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .indefinitely), now: event.date, calendar: calendar)
        stored[1].id = UUID() // A previously saved occurrence may have a legacy random ID.
        stored[0].isRecurrenceException = true; stored[0].title = "Exception"
        let widget = Recurrence.replenishing(stored, now: date(2032, 6, 1), calendar: calendar)
        let app = Recurrence.replenishing(stored, now: date(2032, 6, 2), calendar: calendar)
        XCTAssertEqual(Array(widget.prefix(stored.count)), stored)
        XCTAssertEqual(Array(app.prefix(stored.count)), stored)
        let linkedEvent = try XCTUnwrap(widget.first { $0.date == date(2033, 1, 1) })
        XCTAssertEqual(DeepLink(url: DeepLink.eventURL(linkedEvent.id)), .event(linkedEvent.id))
        XCTAssertEqual(app.first { $0.id == linkedEvent.id }?.date, linkedEvent.date)
        XCTAssertEqual(widget.map(\.id), app.map(\.id))
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let saved = try EventStore.decode(encoder.encode(app))
        let later = Recurrence.replenishing(saved, now: date(2034, 6, 1), calendar: calendar)
        XCTAssertEqual(Array(later.prefix(saved.count)), saved)
        XCTAssertEqual(Set(later.map(\.id)).count, later.count)
    }

    func testOccurrenceIDsUseStableNamespacedVersionFiveIdentifiers() {
        let namespace = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        // Independently calculated with Python's standard-library uuid.uuid5.
        XCTAssertEqual(Recurrence.occurrenceID(seriesID: namespace, index: 7).uuidString.lowercased(),
                       "5e857776-9c1d-502c-a927-07949f122170")
        XCTAssertNotEqual(Recurrence.occurrenceID(seriesID: namespace, index: 7), Recurrence.occurrenceID(seriesID: namespace, index: 8))
        XCTAssertNotEqual(Recurrence.occurrenceID(seriesID: namespace, index: 7), Recurrence.occurrenceID(seriesID: UUID(), index: 7))
    }

    func testDeletingTheOnlyLoadedOccurrencePreservesASparseFutureSchedule() throws {
        var event = seed(.custom, date(2030, 1, 1)); event.customRepeatCount = 2; event.repeatUnit = "Years"
        var events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .indefinitely, calendar: calendar), now: event.date, calendar: calendar)
        XCTAssertEqual(events.count, 1)
        let unrelated = Event(title: "Keep", date: event.date, color: CodableColor(color: .red))
        events.append(unrelated)
        for (index, expectedDate) in [(0, date(2032, 1, 1)), (1, date(2034, 1, 1))] {
            let selected = try XCTUnwrap(events.first { $0.seriesID == event.seriesID })
            events = Recurrence.removingOccurrence(selected, from: events, calendar: calendar)
            XCTAssertEqual(events.first { $0.id == unrelated.id }, unrelated)
            let next = try XCTUnwrap(events.first { $0.seriesID == event.seriesID })
            XCTAssertEqual(next.date, expectedDate)
            XCTAssertEqual(next.occurrenceIndex, index + 1)
            XCTAssertEqual(next.recurrence?.excludedIndices, Array(0...index))
            XCTAssertNotEqual(next.id, selected.id)
        }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        decoder.userInfo[.eventCalendar] = calendar
        let restored = try decoder.decode([Event].self, from: encoder.encode(events))
        XCTAssertEqual(restored.first { $0.seriesID == event.seriesID }?.recurrence?.anchor, event.date)
        let filled = Recurrence.replenishing(restored, now: date(2036, 1, 1), calendar: calendar)
        XCTAssertTrue(filled.contains { $0.date == date(2036, 1, 1) })
        XCTAssertFalse(filled.contains { $0.seriesID == event.seriesID && ($0.occurrenceIndex ?? 0) < 2 })
    }

    func testDeletingSparseOccurrencesRespectsFiniteEndingsAndExclusions() throws {
        var event = seed(.custom, date(2030, 1, 1)); event.customRepeatCount = 2; event.repeatUnit = "Years"
        event.repeatUntil = date(2034, 1, 1)
        var rule = RecurrenceRule(event: event, end: .onDate); rule.excludedIndices = [1]
        let original = Recurrence.generate(event, rule: rule, now: event.date, calendar: calendar)
        let remaining = Recurrence.removingOccurrence(original[0], from: original, calendar: calendar)
        XCTAssertEqual(remaining.map(\.date), [date(2034, 1, 1)])
        XCTAssertTrue(Recurrence.removingOccurrence(remaining[0], from: remaining, calendar: calendar).isEmpty)
        event.repeatUntilCount = 1
        let counted = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .after), calendar: calendar)
        XCTAssertTrue(Recurrence.removingOccurrence(counted[0], from: counted, calendar: calendar).isEmpty)
        let single = Event(title: "Single", date: event.date, color: CodableColor(color: .blue))
        XCTAssertTrue(Recurrence.removingOccurrence(single, from: [single], calendar: calendar).isEmpty)
    }

    func testSingleSparseOccurrenceEditsDoNotChangeFutureMetadataOrDisableTheSchedule() throws {
        var event = seed(.custom, date(2030, 1, 1)); event.customRepeatCount = 2; event.repeatUnit = "Years"
        event.category = "Social"; event.endDate = date(2030, 1, 2)
        let original = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .indefinitely, calendar: calendar), now: event.date, calendar: calendar)
        var replacement = original[0]
        replacement.title = "Exception"; replacement.endDate = date(2030, 1, 5)
        replacement.color = CodableColor(color: .orange); replacement.category = "Work"
        replacement.notificationsEnabled = false; replacement.repeatOption = .never
        let updated = Recurrence.updatingOccurrence(original[0], with: replacement, in: original, calendar: calendar)
        XCTAssertEqual(updated[0].id, original[0].id)
        XCTAssertEqual(updated[0].title, "Exception")
        XCTAssertEqual(updated[0].endDate, date(2030, 1, 5))
        XCTAssertEqual(updated[0].repeatOption, .never)
        XCTAssertTrue(updated[0].isRecurrenceException)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; decoder.userInfo[.eventCalendar] = calendar
        let restored = try decoder.decode([Event].self, from: encoder.encode(updated))
        let filled = Recurrence.replenishing(restored, now: date(2034, 1, 1), calendar: calendar)
        for offset in [2, 4] {
            let future = try XCTUnwrap(filled.first { $0.date == date(2030 + offset, 1, 1) })
            XCTAssertEqual(future.title, event.title); XCTAssertEqual(future.color, event.color)
            XCTAssertEqual(future.category, event.category); XCTAssertEqual(future.notificationsEnabled, event.notificationsEnabled)
            XCTAssertEqual(future.endDate, date(2030 + offset, 1, 2))
            XCTAssertEqual(future.repeatOption, .custom); XCTAssertEqual(future.customRepeatCount, 2)
            XCTAssertEqual(future.repeatUnit, "Years"); XCTAssertFalse(future.isRecurrenceException)
        }
        XCTAssertEqual(Set(filled.map(\.id)).count, filled.count)
    }

    func testEditingOrDeletingTheLastNormalOccurrenceKeepsTheOriginalSeriesSource() throws {
        let event = seed(.yearly, date(2030, 1, 1))
        let original = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .indefinitely, calendar: calendar), now: event.date, calendar: calendar)
        var firstEdit = original[0]; firstEdit.title = "First exception"
        let first = Recurrence.updatingOccurrence(original[0], with: firstEdit, in: original, calendar: calendar)
        XCTAssertEqual(first.count, original.count, "No extra occurrence is needed while another normal one survives")
        var secondEdit = original[1]; secondEdit.title = "Second exception"
        let edited = Recurrence.updatingOccurrence(original[1], with: secondEdit, in: first, calendar: calendar)
        XCTAssertEqual(edited.map(\.title), ["First exception", "Second exception", event.title])
        let deleted = Recurrence.removingOccurrence(original[1], from: first, calendar: calendar)
        XCTAssertEqual(deleted.map(\.title), ["First exception", event.title])
        XCTAssertEqual(deleted.last?.date, date(2032, 1, 1))
        XCTAssertEqual(deleted.last?.recurrence?.excludedIndices, [1])
        let later = Recurrence.replenishing(deleted, now: date(2033, 1, 1), calendar: calendar)
        XCTAssertTrue(later.filter { !$0.isRecurrenceException }.allSatisfy { $0.title == event.title })
        XCTAssertFalse(later.contains { $0.occurrenceIndex == 1 })
        var finite = event; finite.repeatUntilCount = 1
        let last = Recurrence.generate(finite, rule: RecurrenceRule(event: finite, end: .after, calendar: calendar), calendar: calendar)
        XCTAssertEqual(Recurrence.updatingOccurrence(last[0], with: secondEdit, in: last, calendar: calendar).count, 1,
                       "An exhausted finite series does not gain a future occurrence")
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
