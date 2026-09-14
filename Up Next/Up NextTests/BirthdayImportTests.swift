import XCTest
@testable import Up_Next

final class BirthdayImportTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
    private func birthday(_ id: String = "alex", name: String = "Alex", month: Int = 9, day: Int = 15) -> ContactBirthday {
        ContactBirthday(id: id, name: name, birthday: DateComponents(month: month, day: day))!
    }
    private func apply(_ birthdays: [ContactBirthday], selected: Set<String>, events: [Event] = []) -> [Event] {
        BirthdayImport.applying(birthdays, selectedIDs: selected, to: events, category: "Birthdays",
                                color: CodableColor(color: .red), now: date(2026, 9, 13), calendar: calendar)
    }

    func testReviewImportsOnlySelectedBirthdaysWithIndefiniteRecurrence() {
        let events = apply([birthday(), birthday("sam", name: "Sam")], selected: ["alex"])
        XCTAssertEqual(Set(events.compactMap { $0.contactBirthday?.id }), ["alex"])
        XCTAssertEqual(events.first?.title, "Alex’s birthday")
        XCTAssertEqual(events.first?.date, date(2026, 9, 15))
        XCTAssertTrue(events.allSatisfy { $0.category == "Birthdays" && $0.recurrence?.end == .indefinitely && $0.endDate == nil })
        XCTAssertTrue(events.allSatisfy { $0.notificationsEnabled && $0.recurrence?.calendarIdentifier == .gregorian })
    }

    func testRepeatedImportPreservesIDsAndManualChanges() {
        var events = apply([birthday()], selected: ["alex"])
        events[0].title = "Birthday dinner"
        events[0].isRecurrenceException = true
        XCTAssertEqual(apply([birthday(), birthday()], selected: ["alex"], events: events), events)
    }

    func testReviewRemembersDeselectedAndDeletedBirthdaysButSelectsNewContacts() {
        let contacts = [birthday(), birthday("sam"), birthday("new")]
        let events = apply([birthday()], selected: ["alex"])
        XCTAssertEqual(BirthdayImport.selection(birthdays: contacts, events: events, reviewedIDs: ["alex", "sam"]), ["alex", "new"])
        XCTAssertEqual(BirthdayImport.selection(birthdays: contacts, events: [], reviewedIDs: ["alex", "sam"]), ["new"])
    }

    func testTurningOffBirthdayPreservesUnrelatedAndUnavailableContacts() {
        let manual = Event(title: "Meeting", date: date(2026, 9, 15), color: CodableColor(color: .blue))
        let original = apply([birthday(), birthday("unavailable")], selected: ["alex", "unavailable"]) + [manual]
        let updated = apply([birthday()], selected: [], events: original)
        XCTAssertEqual(updated, original.filter { $0.contactBirthday?.id != "alex" })
    }

    func testContactNameAndDateChangesUpdateExistingSeriesWithoutDuplicatingIt() {
        let original = apply([birthday()], selected: ["alex"])
        let updated = apply([birthday(name: "Alex Smith", month: 10, day: 2)], selected: ["alex"], events: original)
        XCTAssertEqual(updated.count, original.count)
        XCTAssertEqual(updated.map(\.id), original.map(\.id))
        XCTAssertEqual(updated.map(\.seriesID), original.map(\.seriesID))
        XCTAssertEqual(updated.first?.date, date(2026, 10, 2))
        XCTAssertTrue(updated.allSatisfy { $0.title == "Alex Smith’s birthday" })
    }

    func testLeapBirthdayWithoutBirthYearReturnsToFebruary29() {
        let leap = birthday(month: 2, day: 29)
        let events = apply([leap], selected: ["alex"])
        XCTAssertEqual(events.first?.date, date(2027, 2, 28))
        let filled = Recurrence.replenishing(events, now: date(2027, 9, 13), calendar: calendar)
        XCTAssertTrue(filled.contains { $0.date == date(2028, 2, 29) })
        XCTAssertEqual(filled.first?.recurrence?.anchorDay?.day, 29)
    }

    func testPastAndTodayBirthdaysDoNotImportHistoricalEvents() {
        XCTAssertEqual(apply([birthday(day: 12)], selected: ["alex"]).first?.date, date(2027, 9, 12))
        XCTAssertEqual(apply([birthday(day: 13)], selected: ["alex"]).first?.date, date(2026, 9, 13))
    }

    func testDeletedOccurrenceIsNotRecreatedWhenContactsChange() {
        let original = apply([birthday()], selected: ["alex"])
        let filled = Recurrence.replenishing(original, now: date(2027, 10, 1), calendar: calendar)
        let removed = filled[1]
        let remaining = Recurrence.removingOccurrence(removed, from: filled)
        let updated = apply([birthday(name: "Alex Smith")], selected: ["alex"], events: remaining)
        XCTAssertFalse(updated.contains { $0.occurrenceIndex == removed.occurrenceIndex })
        XCTAssertEqual(Set(updated.map(\.id)), Set(remaining.map(\.id)))
    }

    func testBirthdayIdentityAndCalendarSurviveStorageAndTimeZoneChanges() throws {
        let original = apply([birthday()], selected: ["alex"])
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        var destination = Calendar(identifier: .hebrew)
        destination.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        decoder.userInfo[.eventCalendar] = destination
        let decoded = try decoder.decode([Event].self, from: data)
        XCTAssertEqual(decoded.first?.contactBirthday, birthday())
        let filled = Recurrence.replenishing(decoded, now: date(2028, 10, 1), calendar: destination)
        XCTAssertTrue(filled.allSatisfy { $0.calendarDay?.month == 9 && $0.calendarDay?.day == 15 })
        XCTAssertEqual(Set(filled.map(\.id)).count, filled.count)
    }

    func testNonGregorianBirthdaysFollowTheirSourceCalendar() throws {
        let source = try XCTUnwrap(ContactBirthday(id: "lunar", name: "Lunar Birthday",
            birthday: DateComponents(month: 1, day: 1), calendarIdentifier: .hebrew))
        var hebrew = Calendar(identifier: .hebrew); hebrew.timeZone = calendar.timeZone
        let events = apply([source], selected: ["lunar"])
        let filled = Recurrence.replenishing(events, now: date(2029, 10, 1), calendar: calendar)
        XCTAssertGreaterThan(filled.count, 2)
        for event in filled {
            XCTAssertEqual(hebrew.component(.month, from: event.date), 1)
            XCTAssertEqual(hebrew.component(.day, from: event.date), 1)
        }
    }

    func testInvalidDatesAndEmptyNamesAreRejected() {
        XCTAssertNil(ContactBirthday(id: "1", name: "Alex", birthday: DateComponents(month: 2, day: 30)))
        XCTAssertNil(ContactBirthday(id: "1", name: "Alex", birthday: DateComponents(month: 13, day: 1)))
        XCTAssertNil(ContactBirthday(id: "1", name: "Alex", birthday: DateComponents(month: 1)))
        XCTAssertNil(ContactBirthday(id: "1", name: "  ", birthday: DateComponents(month: 1, day: 1)))
    }
}
