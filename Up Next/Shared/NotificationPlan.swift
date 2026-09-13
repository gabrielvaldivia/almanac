import Foundation
import UserNotifications

struct DailyReminder {
    let id: String
    let date: Date
    let titles: [String]
}

/// One non-repeating summary per calendar day, ordered before applying the system queue limit.
enum NotificationPlan {
    static func make(events: [Event], hour: Int, minute: Int, now: Date = Date(),
                     calendar: Calendar = .current, limit: Int = 64) -> [DailyReminder] {
        guard limit > 0 else { return [] }
        let today = calendar.startOfDay(for: now)
        var days: [Date: [Event]] = [:]
        for event in events where event.notificationsEnabled {
            var day = max(today, calendar.startOfDay(for: event.date))
            let end = calendar.startOfDay(for: event.endDate ?? event.date)
            // A single long event cannot occupy more than the entire queue.
            for _ in 0...limit {
                guard day <= end else { break }
                days[day, default: []].append(event)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
                day = next
            }
        }
        return days.keys.sorted().compactMap { day -> DailyReminder? in
            guard let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  calendar.isDate(fire, inSameDayAs: day), fire > now else { return nil }
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            let id = "almanac.day.\(parts.year!)-\(parts.month!)-\(parts.day!)"
            let titles = days[day]!.sorted {
                $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date
            }.map(\.title)
            return DailyReminder(id: id, date: fire, titles: titles)
        }.prefix(limit).map { $0 }
    }
}

@MainActor
protocol NotificationCenterClient {
    func pendingRequests() async -> [UNNotificationRequest]
    func add(_ request: UNNotificationRequest) async throws
    func remove(identifiers: [String])
}

@MainActor
private struct SystemNotificationCenter: NotificationCenterClient {
    func pendingRequests() async -> [UNNotificationRequest] { await UNUserNotificationCenter.current().pendingNotificationRequests() }
    func add(_ request: UNNotificationRequest) async throws { try await UNUserNotificationCenter.current().add(request) }
    func remove(identifiers: [String]) { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers) }
}

/// Chaining tasks prevents older saves from overwriting a newer schedule across suspension points.
@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler(center: SystemNotificationCenter())
    private let center: any NotificationCenterClient
    init(center: any NotificationCenterClient) { self.center = center }
    private var tail: Task<String?, Never>?

    func replace(with plan: [DailyReminder], calendar: Calendar = .current) async -> String? {
        let previous = tail
        let work = Task { () -> String? in
            _ = await previous?.value
            let pending = await center.pendingRequests()
            let desired = Set(plan.map(\.id))
            let obsolete = pending.filter {
                ($0.identifier.hasPrefix("almanac.day.") && !desired.contains($0.identifier)) ||
                $0.identifier == "dailyNotification" || UUID(uuidString: $0.identifier) != nil
            }.map(\.identifier)
            center.remove(identifiers: obsolete)
            var failure: String?
            for reminder in plan {
                let content = UNMutableNotificationContent()
                content.title = "You have \(reminder.titles.count) event\(reminder.titles.count == 1 ? "" : "s") today"
                content.body = reminder.titles.joined(separator: ", ")
                content.sound = .default
                var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
                // Calendar components follow the device's local time zone.
                components.second = 0
                let request = UNNotificationRequest(identifier: reminder.id, content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
                do { try await center.add(request) }
                catch { failure = error.localizedDescription }
            }
            return failure
        }
        tail = work
        return await work.value
    }
}
