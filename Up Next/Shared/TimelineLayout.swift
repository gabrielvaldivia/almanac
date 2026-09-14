import Foundation

struct TimelineEventPlacement {
    var event: Event
    var startDay: Int
    var endDay: Int
    var lane: Int
}

struct TimelineLayout {
    var placements: [TimelineEventPlacement]
    var laneCount: Int

    static func make(events: [Event], visibleDays: ClosedRange<Int>, anchor: Date,
                     calendar: Calendar = .current) -> TimelineLayout {
        make(indexedEvents: index(events: events, anchor: anchor, calendar: calendar), visibleDays: visibleDays)
    }

    static func index(events: [Event], anchor: Date, calendar: Calendar = .current) -> [TimelineEventPlacement] {
        let anchor = calendar.startOfDay(for: anchor)
        return events.map { event in
            let start = calendar.dateComponents([.day], from: anchor,
                                               to: calendar.startOfDay(for: event.date)).day ?? 0
            let end = max(start, calendar.dateComponents([.day], from: anchor,
                                                         to: calendar.startOfDay(for: event.endDate ?? event.date)).day ?? start)
            return TimelineEventPlacement(event: event, startDay: start, endDay: end, lane: 0)
        }.sorted {
            if $0.startDay != $1.startDay { return $0.startDay < $1.startDay }
            if $0.endDay != $1.endDay { return $0.endDay > $1.endDay }
            return $0.event.id.uuidString < $1.event.id.uuidString
        }

    }

    static func make(indexedEvents: [TimelineEventPlacement], visibleDays: ClosedRange<Int>,
                     minimumDaySpan: CGFloat = 1) -> TimelineLayout {
        let candidates = indexedEvents.filter { $0.startDay <= visibleDays.upperBound && $0.endDay >= visibleDays.lowerBound }
        // Reuse the first free lane. Counting earlier overlapping events can
        // leave gaps for chains of events that don't all overlap one another.
        var laneEnds: [CGFloat] = []
        let placements = candidates.map { candidate in
            var placement = candidate
            let center = CGFloat(placement.startDay + placement.endDay + 1) / 2
            let start = min(CGFloat(placement.startDay), center - minimumDaySpan / 2)
            let end = max(CGFloat(placement.endDay + 1), center + minimumDaySpan / 2)
            let lane = laneEnds.firstIndex { $0 <= start } ?? laneEnds.count
            if lane == laneEnds.count {
                laneEnds.append(end)
            } else {
                laneEnds[lane] = end
            }
            placement.lane = lane
            return placement
        }
        return TimelineLayout(placements: placements, laneCount: laneEnds.count)
    }

    static func height(for laneCount: Int) -> CGFloat {
        48 + CGFloat(laneCount) * 28
    }
}
