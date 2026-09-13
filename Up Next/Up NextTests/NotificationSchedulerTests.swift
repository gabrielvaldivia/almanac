import XCTest
import UserNotifications
@testable import Up_Next

@MainActor
private final class TestNotificationCenter: NotificationCenterClient {
    var requests: [String: UNNotificationRequest] = [:]
    var failureID: String?
    var started: XCTestExpectation?
    func pendingRequests() async -> [UNNotificationRequest] {
        started?.fulfill(); started = nil
        await Task.yield()
        return Array(requests.values)
    }
    func add(_ request: UNNotificationRequest) async throws {
        await Task.yield()
        if request.identifier == failureID { throw NSError(domain: "TestNotification", code: 1) }
        requests[request.identifier] = request
    }
    func remove(identifiers: [String]) { for id in identifiers { requests.removeValue(forKey: id) } }
}

final class NotificationSchedulerTests: XCTestCase {
    @MainActor
    func testLatestScheduleWinsAndLegacyRequestsAreRemoved() async {
        let center = TestNotificationCenter(), started = expectation(description: "First reconciliation started")
        center.started = started
        center.requests["dailyNotification"] = UNNotificationRequest(identifier: "dailyNotification", content: UNMutableNotificationContent(), trigger: nil)
        let scheduler = NotificationScheduler(center: center)
        let first = Task { await scheduler.replace(with: [DailyReminder(id: "almanac.day.old", date: Date().addingTimeInterval(86400), titles: ["Old"])]) }
        await fulfillment(of: [started], timeout: 5)
        let second = Task { await scheduler.replace(with: [DailyReminder(id: "almanac.day.new", date: Date().addingTimeInterval(172800), titles: ["Updated"])]) }
        _ = await first.value; _ = await second.value
        XCTAssertEqual(Set(center.requests.keys), ["almanac.day.new"])
        XCTAssertEqual(center.requests["almanac.day.new"]?.content.body, "Updated")
        let trigger = center.requests["almanac.day.new"]?.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.repeats, false)
        XCTAssertNotNil(trigger?.dateComponents.year)
    }

    @MainActor
    func testOneRejectedRequestDoesNotPreventOtherReminders() async {
        let center = TestNotificationCenter(); center.failureID = "almanac.day.bad"
        let scheduler = NotificationScheduler(center: center)
        let error = await scheduler.replace(with: [
            DailyReminder(id: "almanac.day.bad", date: Date().addingTimeInterval(86400), titles: ["Bad"]),
            DailyReminder(id: "almanac.day.good", date: Date().addingTimeInterval(172800), titles: ["Good"])
        ])
        XCTAssertNotNil(error)
        XCTAssertNotNil(center.requests["almanac.day.good"])
    }
}
