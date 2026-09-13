import Foundation

struct TimelineItem: Identifiable {
    let event: Event
    let start: Int
    let end: Int
    let lane: Int
    var id: UUID { event.id }
    var dayCount: Int { end - start + 1 }
}

enum TimelineLayout {
    static func items(events: [Event], from start: Date, days: Int, calendar: Calendar = .current) -> [TimelineItem] {
        guard days > 0 else { return [] }
        let start = calendar.startOfDay(for: start)
        let spans = events.compactMap { event -> (Event, Int, Int)? in
            let first = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: event.date)).day ?? 0
            let last = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: event.endDate ?? event.date)).day ?? first
            guard last >= 0, first < days else { return nil }
            return (event, max(0, first), min(days - 1, max(first, last)))
        }.sorted {
            if $0.1 != $1.1 { return $0.1 < $1.1 }
            if $0.2 != $1.2 { return $0.2 > $1.2 }
            return $0.0.id.uuidString < $1.0.id.uuidString
        }
        var laneEnds: [Int] = []
        return spans.map { event, first, last in
            let lane = laneEnds.firstIndex { $0 < first } ?? laneEnds.count
            if lane == laneEnds.count { laneEnds.append(last) } else { laneEnds[lane] = last }
            return TimelineItem(event: event, start: first, end: last, lane: lane)
        }
    }
}
