import Foundation

struct RecurrenceRule: Codable, Equatable {
    var anchor: Date { didSet { anchorDay = CalendarDay(anchor) } }
    var anchorDay: CalendarDay?
    var frequency: RepeatOption
    var interval: Int
    var unit: String
    var end: RepeatUntilOption
    var until: Date? { didSet { untilDay = until.map { CalendarDay($0) } } }
    var untilDay: CalendarDay?
    var count: Int
    var excludedIndices: [Int] = []

    init(event: Event, end: RepeatUntilOption, calendar: Calendar = .current) {
        anchor = event.date
        anchorDay = CalendarDay(event.date, calendar: calendar)
        frequency = event.repeatOption
        interval = frequency == .custom ? (event.customRepeatCount ?? 1) : 1
        unit = event.repeatUnit ?? "Days"
        self.end = end
        until = end == .onDate ? event.repeatUntil : nil
        untilDay = until.map { CalendarDay($0, calendar: calendar) }
        count = event.repeatUntilCount ?? 1
    }

    enum CodingKeys: String, CodingKey { case anchor, anchorDay, frequency, interval, unit, end, until, untilDay, count, excludedIndices }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let calendar = decoder.userInfo[.eventCalendar] as? Calendar ?? .current
        let legacyAnchor = try values.decode(Date.self, forKey: .anchor)
        anchorDay = try values.decodeIfPresent(CalendarDay.self, forKey: .anchorDay) ?? CalendarDay(legacyAnchor, calendar: calendar)
        anchor = anchorDay?.date(in: calendar) ?? legacyAnchor
        frequency = try values.decode(RepeatOption.self, forKey: .frequency)
        interval = try values.decode(Int.self, forKey: .interval)
        unit = try values.decode(String.self, forKey: .unit)
        end = try values.decode(RepeatUntilOption.self, forKey: .end)
        let legacyUntil = try values.decodeIfPresent(Date.self, forKey: .until)
        untilDay = try values.decodeIfPresent(CalendarDay.self, forKey: .untilDay) ?? legacyUntil.map { CalendarDay($0, calendar: calendar) }
        until = untilDay?.date(in: calendar)
        count = try values.decode(Int.self, forKey: .count)
        excludedIndices = try values.decodeIfPresent([Int].self, forKey: .excludedIndices) ?? []
    }

    var component: Calendar.Component {
        switch frequency {
        case .daily, .never: return .day
        case .weekly: return .weekOfYear
        case .monthly: return .month
        case .yearly: return .year
        case .custom:
            switch unit.lowercased() {
            case "weeks": return .weekOfYear
            case "months": return .month
            case "years": return .year
            default: return .day
            }
        }
    }

    func date(at index: Int, calendar: Calendar = .current) -> Date? {
        guard index >= 0, (1...1000).contains(interval) else { return nil }
        let (offset, overflow) = index.multipliedReportingOverflow(by: interval)
        guard !overflow else { return nil }
        return calendar.date(byAdding: component, value: offset, to: anchor)
    }
}

enum Recurrence {
    static func generate(_ seed: Event, rule: RecurrenceRule, fromIndex: Int = 0,
                         now: Date = Date(), calendar: Calendar = .current) -> [Event] {
        guard rule.frequency != .never, (1...1000).contains(rule.interval),
              rule.end != .after || (1...10000).contains(rule.count) else { return [] }
        let horizon = calendar.date(byAdding: .year, value: 1, to: max(now, rule.anchor))!
        let duration = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: seed.date),
                                 to: calendar.startOfDay(for: seed.endDate ?? seed.date)).day ?? 0)
        let exclusions = Set(rule.excludedIndices)
        let seriesID = seed.seriesID ?? UUID()
        var result: [Event] = []
        var index = fromIndex
        // Avoid materializing decades of history for a newly created indefinite event.
        if rule.end != .after && fromIndex == 0 && rule.anchor < now {
            let elapsed = calendar.dateComponents([rule.component], from: rule.anchor, to: now).value(for: rule.component) ?? 0
            index = max(0, elapsed / rule.interval - duration - 1)
        }
        for _ in 0..<10000 {
            guard rule.end != .after || index < rule.count,
                  let date = rule.date(at: index, calendar: calendar) else { break }
            if rule.end == .onDate, let until = rule.until,
               calendar.startOfDay(for: date) > calendar.startOfDay(for: until) { break }
            if rule.end != .after && date > horizon { break }
            if !exclusions.contains(index) {
                var event = seed
                event.id = index == 0 ? seed.id : UUID()
                event.date = date
                event.endDate = seed.endDate == nil ? nil : calendar.date(byAdding: .day, value: duration, to: date)
                event.seriesID = seriesID
                event.recurrence = rule
                event.occurrenceIndex = index
                event.isRecurrenceException = false
                event.repeatOption = rule.frequency
                event.repeatUntil = rule.until
                event.repeatUntilCount = rule.count
                result.append(event)
            }
            index += 1
        }
        return result
    }

    static func replenishing(_ events: [Event], now: Date = Date(), calendar: Calendar = .current) -> [Event] {
        var result = events
        let groups = Dictionary(grouping: events.filter { $0.seriesID != nil }, by: { $0.seriesID! })
        for (id, group) in groups {
            let ordered = group.sorted { $0.date < $1.date }
            guard var seed = ordered.first(where: { !$0.isRecurrenceException }) ?? ordered.first,
                  seed.repeatOption != .never else { continue }
            var rule: RecurrenceRule
            if let existing = seed.recurrence { rule = existing }
            else {
                // Legacy files did not record the end mode. Preserve explicit end dates conservatively.
                let exceededLegacyEnd = seed.repeatUntil.map { until in ordered.contains { $0.date > until } } ?? false
                let mode: RepeatUntilOption = seed.repeatUntil == nil || exceededLegacyEnd ? .indefinitely : .onDate
                rule = RecurrenceRule(event: seed, end: mode)
                let indexed = ordered.enumerated().map { offset, member -> (Event, Int) in
                    let elapsed = calendar.dateComponents([rule.component], from: rule.anchor, to: member.date).value(for: rule.component) ?? offset
                    return (member, max(offset, elapsed / max(1, rule.interval)))
                }
                let present = Set(indexed.map { $0.1 })
                if let last = present.max(), last <= 10000 {
                    rule.excludedIndices = (0...last).filter { !present.contains($0) }
                }
                for (member, index) in indexed {
                    if let position = result.firstIndex(where: { $0.id == member.id }) {
                        result[position].recurrence = rule
                        result[position].occurrenceIndex = index
                    }
                }
                seed.recurrence = rule
            }
            let members = result.filter { $0.seriesID == id }
            let nextIndex = (members.compactMap(\.occurrenceIndex).max() ?? -1) + 1
            result.append(contentsOf: generate(seed, rule: rule, fromIndex: nextIndex, now: now, calendar: calendar))
        }
        return result
    }

    static func removingOccurrence(_ event: Event, from events: [Event]) -> [Event] {
        events.compactMap { member in
            if member.id == event.id { return nil }
            var updated = member
            if let id = event.seriesID, member.seriesID == id, let index = event.occurrenceIndex,
               updated.recurrence != nil, !updated.recurrence!.excludedIndices.contains(index) {
                updated.recurrence!.excludedIndices.append(index)
            }
            return updated
        }
    }

    static func updatingSeries(_ selected: Event, with replacement: Event, in events: [Event],
                               calendar: Calendar = .current) -> [Event] {
        guard let id = selected.seriesID, let oldRule = selected.recurrence else { return events }
        if replacement.repeatOption == .never {
            var single = replacement
            single.seriesID = nil; single.recurrence = nil; single.occurrenceIndex = nil
            return events.compactMap { $0.id == selected.id ? single : ($0.seriesID == id ? nil : $0) }
        }
        var newRule = replacement.recurrence ?? oldRule
        newRule.excludedIndices = oldRule.excludedIndices
        let samePattern = oldRule.frequency == newRule.frequency && oldRule.interval == newRule.interval && oldRule.unit == newRule.unit
        let sameEnding = oldRule.end == newRule.end && oldRule.until == newRule.until && oldRule.count == newRule.count
        let shift = calendar.dateComponents([.day], from: calendar.startOfDay(for: selected.date), to: calendar.startOfDay(for: replacement.date)).day ?? 0
        if samePattern {
            newRule.anchor = calendar.date(byAdding: .day, value: shift, to: oldRule.anchor) ?? oldRule.anchor
        } else {
            newRule.anchor = calendar.date(byAdding: newRule.component,
                value: -(selected.occurrenceIndex ?? 0) * newRule.interval, to: replacement.date) ?? replacement.date
        }
        if samePattern && sameEnding {
            // Metadata and date shifts preserve every stored occurrence, including older long series.
            return EventSeries.updatingLegacy(selected, with: replacement, in: events, calendar: calendar).map { member in
                guard member.seriesID == id else { return member }
                var updated = member
                let original = events.first { $0.id == member.id }!
                updated.recurrence = newRule
                updated.occurrenceIndex = original.occurrenceIndex
                updated.isRecurrenceException = original.isRecurrenceException
                return updated
            }
        }
        let oldMembers = events.filter { $0.seriesID == id }
        let byIndex = Dictionary(oldMembers.compactMap { member -> (Int, Event)? in
            guard let index = member.occurrenceIndex else { return nil }; return (index, member)
        }, uniquingKeysWith: { first, _ in first })
        var seed = replacement
        seed.date = newRule.anchor
        if let end = replacement.endDate {
            let days = calendar.dateComponents([.day], from: replacement.date, to: end).day ?? 0
            seed.endDate = calendar.date(byAdding: .day, value: days, to: newRule.anchor)
        }
        let generated = generate(seed, rule: newRule, calendar: calendar).map { member -> Event in
            var updated = member
            if let index = member.occurrenceIndex, let original = byIndex[index] {
                updated.id = original.id
                if original.isRecurrenceException {
                    updated.date = original.date; updated.endDate = original.endDate
                    updated.isRecurrenceException = true
                }
            }
            return updated
        }
        return events.filter { $0.seriesID != id } + generated
    }
}
