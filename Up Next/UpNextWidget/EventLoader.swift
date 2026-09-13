import Foundation

struct EventLoader {
    static func loadEvents(for category: String? = nil, at date: Date = Date()) -> [Event] {
        guard let data = AppPreferences.shared.data(forKey: "events"),
              let events = try? EventStore.decode(data) else { return [] }
        return WidgetEvents.upcoming(Recurrence.replenishing(events, now: date), category: category, at: date)
    }
}
