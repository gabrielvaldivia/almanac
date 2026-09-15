import XCTest
@testable import Up_Next

final class CalendarDayTests: XCTestCase {
    func calendar(_ zone: String) -> Calendar {
        var result = Calendar(identifier: .gregorian); result.timeZone = TimeZone(identifier: zone)!; return result
    }
    func testEventCalendarDateSurvivesTravelAcrossDateLine() throws {
        let origin = calendar("America/New_York")
        let date = origin.date(from: DateComponents(year: 2030, month: 6, day: 18, hour: 12))!
        var event = Event(title: "Birthday", date: date, endDate: date, color: CodableColor(color: .blue))
        event.calendarDay = CalendarDay(date, calendar: origin)
        event.calendarEndDay = CalendarDay(date, calendar: origin)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        for zone in ["America/Los_Angeles", "Asia/Tokyo", "Pacific/Kiritimati", "Pacific/Pago_Pago"] {
            let destination = calendar(zone)
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
            decoder.userInfo[.eventCalendar] = destination
            let decoded = try decoder.decode(Event.self, from: data)
            XCTAssertEqual(destination.component(.day, from: decoded.date), 18)
            XCTAssertEqual(destination.component(.day, from: decoded.endDate!), 18)
        }
    }

    func testDateRangesIncludeBothYearsWhenTheyCrossTheYearBoundary() {
        let calendar = calendar("America/New_York")
        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day))!
        }
        let reference = date(2026, 9, 14)
        let crossYear = EventDateText.range(start: date(2026, 12, 31), end: date(2027, 1, 2), reference: reference, calendar: calendar)
        XCTAssertTrue(crossYear.contains("2026")); XCTAssertTrue(crossYear.contains("2027"))
        XCTAssertTrue(crossYear.hasSuffix("(3 days)"))
        let ongoing = EventDateText.range(start: date(2026, 12, 31), end: date(2027, 1, 2), reference: date(2027, 1, 1), calendar: calendar)
        XCTAssertTrue(ongoing.contains("2026")); XCTAssertTrue(ongoing.contains("2027"))
        XCTAssertTrue(ongoing.hasSuffix("(2 days left)"))
        for year in [2025, 2026, 2027] {
            let text = EventDateText.range(start: date(year, 10, 1), end: date(year, 10, 2), reference: reference, calendar: calendar)
            XCTAssertEqual(text.contains(String(year)), year != 2026)
        }
        XCTAssertFalse(EventDateText.range(start: reference, end: nil, reference: reference, calendar: calendar).contains("2026"))
    }

    func testReminderKeepsItsClockTimeAcrossTimeZones() {
        let name = "test.clock.\(UUID())", origin = calendar("America/New_York")
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let time = origin.date(from: DateComponents(year: 2030, month: 6, day: 18, hour: 8, minute: 30))!
        AppPreferences.saveReminderTime(time, calendar: origin, defaults: defaults)
        for zone in ["America/Los_Angeles", "Asia/Tokyo"] {
            let destination = calendar(zone)
            let local = AppPreferences.reminderTime(now: time, calendar: destination, defaults: defaults)
            XCTAssertEqual(destination.component(.hour, from: local), 8)
            XCTAssertEqual(destination.component(.minute, from: local), 30)
        }
    }
}
