import Foundation

enum WidgetEvents {
    static func upcoming(_ events: [Event], category: String? = nil, at date: Date,
                         calendar: Calendar = .current, defaults: UserDefaults = AppPreferences.shared) -> [Event] {
        let showsAll = category == nil || category == "All Categories"
        let categoryName = showsAll ? nil : category.flatMap { CategoryStorage.name(forWidgetSelection: $0, defaults: defaults) }
        guard showsAll || categoryName != nil else { return [] }
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .month, value: 12, to: start)!
        return events.filter {
            (showsAll || $0.category == categoryName) &&
            EventWindow.intersects($0, start: start, end: end, calendar: calendar)
        }.sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date }
    }

    struct DayGroup: Identifiable {
        let date: Date
        let events: [Event]
        var id: Date { date }
    }

    /// Group an already sorted upcoming snapshot without parsing display labels.
    static func grouped(_ events: [Event], limit: Int, at date: Date,
                        calendar: Calendar = .current) -> [DayGroup] {
        let today = calendar.startOfDay(for: date)
        let groups = Dictionary(grouping: events.prefix(max(0, limit))) {
            max(today, calendar.startOfDay(for: $0.date))
        }
        return groups.keys.sorted().map { DayGroup(date: $0, events: groups[$0]!) }
    }

    static func entryDates(now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        [now] + (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: now)) }
    }
}
