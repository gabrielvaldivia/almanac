import Foundation

enum EventWindow {
    static func intersects(_ event: Event, start: Date, end: Date, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: event.date) <= calendar.startOfDay(for: end) &&
        calendar.startOfDay(for: event.endDate ?? event.date) >= calendar.startOfDay(for: start)
    }
}
