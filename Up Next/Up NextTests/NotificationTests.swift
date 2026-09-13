import XCTest
@testable import Up_Next

final class NotificationTests: XCTestCase {
    func testRemindersUseFutureEventDaysEvenWhenTodayIsEmpty() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        func date(_ day: Int, _ hour: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2030, month: 3, day: day, hour: hour))!
        }
        let events = [11, 10, 9].map { Event(title: "Day \($0)", date: date($0), color: CodableColor(color: .blue)) }
        let plan = NotificationPlan.make(events: events, hour: 8, minute: 30, now: date(8, 10), calendar: calendar)
        XCTAssertEqual(plan.map { calendar.component(.day, from: $0.date) }, [9, 10, 11])
        XCTAssertEqual(plan.map { calendar.component(.hour, from: $0.date) }, [8, 8, 8])
        XCTAssertEqual(plan.map(\.titles), [["Day 9"], ["Day 10"], ["Day 11"]])
        XCTAssertEqual(plan[1].date.timeIntervalSince(plan[0].date), 23 * 3600) // spring DST
    }

    func testCapacitySortingEditsDeletionAndDisabledEvents() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var events = (1...80).reversed().map { Event(title: "Day \($0)", date: calendar.date(byAdding: .day, value: $0, to: today)!, color: CodableColor(color: .blue)) }
        events[79].notificationsEnabled = false
        let plan = NotificationPlan.make(events: events, hour: 8, minute: 0, now: today)
        XCTAssertEqual(plan.count, 64)
        XCTAssertEqual(plan.first?.titles, ["Day 2"])
        events[78].title = "Renamed"
        XCTAssertEqual(NotificationPlan.make(events: events, hour: 8, minute: 0, now: today).first?.titles, ["Renamed"])
        XCTAssertTrue(NotificationPlan.make(events: [], hour: 8, minute: 0, now: today).isEmpty)
    }

    func testSummaryIncludesOngoingEventsAndDoesNotMovePastReminderToTomorrow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2030, month: 1, day: 2))!
        let event = Event(title: "Trip", date: today.addingTimeInterval(-86400), endDate: today.addingTimeInterval(86400), color: CodableColor(color: .blue))
        let plan = NotificationPlan.make(events: [event], hour: 8, minute: 0, now: today.addingTimeInterval(9 * 3600), calendar: calendar)
        XCTAssertEqual(plan.count, 1)
        XCTAssertEqual(calendar.component(.day, from: plan[0].date), 3)
    }
}
