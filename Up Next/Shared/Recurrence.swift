import Foundation
import CryptoKit

struct RecurrenceRule: Codable, Equatable {
    var anchor: Date { didSet { anchorDay = CalendarDay(anchor) } }
    var anchorDay: CalendarDay?
    // Retain the requested day if deriving an earlier anchor lands in a
    // shorter month (for example, April 30 minus two months is February 28).
    var preferredDayOfMonth: Int?
    var frequency: RepeatOption
    var interval: Int
    var unit: String
    var end: RepeatUntilOption
    var until: Date? { didSet { untilDay = until.map { CalendarDay($0) } } }
    var untilDay: CalendarDay?
    var count: Int
    var excludedIndices: [Int] = []
    // Contact birthdays follow their source calendar, even if the device uses another calendar.
    var calendarIdentifier: Calendar.Identifier?

    init(event: Event, end: RepeatUntilOption, calendar: Calendar = .current) {
        anchor = event.date
        anchorDay = CalendarDay(event.date, calendar: calendar)
        preferredDayOfMonth = event.recurrence?.preferredDayOfMonth
        frequency = event.repeatOption
        interval = frequency == .custom ? (event.customRepeatCount ?? 1) : 1
        unit = event.repeatUnit ?? "Days"
        self.end = end
        until = end == .onDate ? event.repeatUntil : nil
        untilDay = until.map { CalendarDay($0, calendar: calendar) }
        count = event.repeatUntilCount ?? 1
        calendarIdentifier = event.recurrence?.calendarIdentifier
    }

    enum CodingKeys: String, CodingKey { case anchor, anchorDay, preferredDayOfMonth, frequency, interval, unit, end, until, untilDay, count, excludedIndices, calendarIdentifier }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let calendar = decoder.userInfo[.eventCalendar] as? Calendar ?? .current
        let legacyAnchor = try values.decode(Date.self, forKey: .anchor)
        anchorDay = try values.decodeIfPresent(CalendarDay.self, forKey: .anchorDay) ?? CalendarDay(legacyAnchor, calendar: calendar)
        anchor = anchorDay?.date(in: calendar) ?? legacyAnchor
        preferredDayOfMonth = try values.decodeIfPresent(Int.self, forKey: .preferredDayOfMonth)
        frequency = try values.decode(RepeatOption.self, forKey: .frequency)
        interval = try values.decode(Int.self, forKey: .interval)
        unit = try values.decode(String.self, forKey: .unit)
        end = try values.decode(RepeatUntilOption.self, forKey: .end)
        let legacyUntil = try values.decodeIfPresent(Date.self, forKey: .until)
        untilDay = try values.decodeIfPresent(CalendarDay.self, forKey: .untilDay) ?? legacyUntil.map { CalendarDay($0, calendar: calendar) }
        until = untilDay?.date(in: calendar)
        count = try values.decode(Int.self, forKey: .count)
        excludedIndices = try values.decodeIfPresent([Int].self, forKey: .excludedIndices) ?? []
        calendarIdentifier = try values.decodeIfPresent(Calendar.Identifier.self, forKey: .calendarIdentifier)
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
        let calendar = resolvedCalendar(calendar)
        guard let date = calendar.date(byAdding: component, value: offset, to: anchor) else { return nil }
        guard let preferredDayOfMonth, component == .month || component == .year else { return date }
        guard let days = calendar.range(of: .day, in: .month, for: date) else { return nil }
        return calendar.date(bySetting: .day, value: min(max(days.lowerBound, preferredDayOfMonth), days.upperBound - 1), of: date)
    }

    func resolvedCalendar(_ calendar: Calendar) -> Calendar {
        guard let calendarIdentifier else { return calendar }
        var result = Calendar(identifier: calendarIdentifier)
        result.timeZone = calendar.timeZone
        return result
    }

    func nextIndex(onOrAfter boundary: Date, fromIndex: Int = 0, calendar: Calendar = .current) -> Int? {
        guard frequency != .never, (1...1000).contains(interval),
              end != .after || (1...10000).contains(count) else { return nil }
        let calendar = resolvedCalendar(calendar)
        let elapsed = calendar.dateComponents([component], from: anchor, to: boundary).value(for: component) ?? 0
        // Start just before the estimate to account for month-end clamping.
        var index = max(0, fromIndex, elapsed / interval - 1)
        let exclusions = Set(excludedIndices)
        while let date = date(at: index, calendar: calendar) {
            if end == .after && index >= count { return nil }
            if end == .onDate, let until, calendar.startOfDay(for: date) > calendar.startOfDay(for: until) { return nil }
            if date >= boundary && !exclusions.contains(index) { return index }
            guard index < Int.max else { return nil }
            index += 1
        }
        return nil
    }
}

enum Recurrence {
    static func generate(_ seed: Event, rule: RecurrenceRule, fromIndex: Int = 0,
                         now: Date = Date(), calendar: Calendar = .current, before end: Date? = nil) -> [Event] {
        let calendar = rule.resolvedCalendar(calendar)
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
            if let end {
                if date >= end { break }
            } else if rule.end != .after && date > horizon { break }
            if !exclusions.contains(index) {
                result.append(occurrence(seed, rule: rule, seriesID: seriesID, index: index,
                                         date: date, duration: duration, calendar: calendar))
            }
            index += 1
        }
        return result
    }

    private static func occurrence(_ seed: Event, rule: RecurrenceRule, seriesID: UUID, index: Int,
                                   date: Date, duration: Int, calendar: Calendar) -> Event {
        var event = seed
        event.id = index == 0 ? seed.id : occurrenceID(seriesID: seriesID, index: index)
        event.date = date
        event.endDate = seed.endDate == nil ? nil : calendar.date(byAdding: .day, value: duration, to: date)
        event.calendarDay = CalendarDay(date, calendar: calendar)
        event.calendarEndDay = event.endDate.map { CalendarDay($0, calendar: calendar) }
        event.seriesID = seriesID
        event.recurrence = rule
        event.occurrenceIndex = index
        event.isRecurrenceException = false
        event.repeatOption = rule.frequency
        event.repeatUntil = rule.until
        event.repeatUntilCount = rule.count
        return event
    }

    static func occurrenceID(seriesID: UUID, index: Int) -> UUID {
        // UUID v5: the stored series ID is the namespace, and the occurrence
        // index is the name. This identifies records; it is not a security hash.
        var namespace = seriesID.uuid
        var data = withUnsafeBytes(of: &namespace) { Data($0) }
        data.append(contentsOf: "almanac.occurrence.\(index)".utf8)
        var bytes = Array(Insecure.SHA1.hash(data: data).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }

    static func replenishing(_ events: [Event], now: Date = Date(), calendar: Calendar = .current,
                             before end: Date? = nil) -> [Event] {
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
            result.append(contentsOf: generate(seed, rule: rule, fromIndex: nextIndex, now: now, calendar: calendar, before: end))
        }
        return result
    }

    static func hasEvents(onOrAfter boundary: Date, in events: [Event], category: String? = nil,
                          calendar: Calendar = .current) -> Bool {
        if events.contains(where: { $0.date >= boundary && (category == nil || $0.category == category) }) { return true }
        let groups = Dictionary(grouping: events.filter { $0.seriesID != nil }, by: { $0.seriesID! })
        return groups.values.contains { group in
            let ordered = group.sorted { $0.date < $1.date }
            // Choose the series seed before filtering: a differently categorized
            // exception does not change the category of future occurrences.
            guard let seed = ordered.first(where: { !$0.isRecurrenceException }) ?? ordered.first,
                  seed.repeatOption != .never, category == nil || seed.category == category,
                  let rule = seed.recurrence else { return false }
            let next = (group.compactMap(\.occurrenceIndex).max() ?? -1) + 1
            return rule.nextIndex(onOrAfter: boundary, fromIndex: next, calendar: calendar) != nil
        }
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
                               calendar: Calendar = .current, now: Date = Date()) -> [Event] {
        guard let id = selected.seriesID, let oldRule = selected.recurrence else { return events }
        let calendar = oldRule.resolvedCalendar(calendar)
        if replacement.repeatOption == .never {
            var single = replacement
            single.seriesID = nil; single.recurrence = nil; single.occurrenceIndex = nil
            return events.compactMap { $0.id == selected.id ? single : ($0.seriesID == id ? nil : $0) }
        }
        var newRule = replacement.recurrence ?? oldRule
        newRule.excludedIndices = oldRule.excludedIndices
        let samePattern = oldRule.component == newRule.component && oldRule.interval == newRule.interval
        let sameEnding = oldRule.end == newRule.end && oldRule.until == newRule.until && oldRule.count == newRule.count
        let shift = calendar.dateComponents([.day], from: calendar.startOfDay(for: selected.date), to: calendar.startOfDay(for: replacement.date)).day ?? 0
        func hasDateException(_ event: Event) -> Bool {
            guard event.isRecurrenceException, let index = event.occurrenceIndex,
                  let scheduled = oldRule.date(at: index, calendar: calendar) else { return false }
            return !calendar.isDate(event.date, inSameDayAs: scheduled)
        }
        if samePattern && shift == 0 {
            newRule.anchor = oldRule.anchor
            newRule.preferredDayOfMonth = oldRule.preferredDayOfMonth
        } else {
            var targetDate = replacement.date
            if samePattern, hasDateException(selected), let index = selected.occurrenceIndex,
               let scheduled = oldRule.date(at: index, calendar: calendar) {
                targetDate = calendar.date(byAdding: .day, value: shift, to: scheduled) ?? targetDate
            }
            newRule.anchor = calendar.date(byAdding: newRule.component,
                value: -(selected.occurrenceIndex ?? 0) * newRule.interval, to: targetDate) ?? targetDate
            let requestedDay = calendar.component(.day, from: targetDate)
            newRule.preferredDayOfMonth = (newRule.component == .month || newRule.component == .year) &&
                calendar.component(.day, from: newRule.anchor) != requestedDay ? requestedDay : nil
        }
        newRule.anchorDay = CalendarDay(newRule.anchor, calendar: calendar)
        newRule.untilDay = newRule.until.map { CalendarDay($0, calendar: calendar) }
        if samePattern && sameEnding {
            // Metadata and date shifts preserve every stored occurrence, including older long series.
            let duration = replacement.endDate.map {
                calendar.dateComponents([.day], from: calendar.startOfDay(for: replacement.date),
                                        to: calendar.startOfDay(for: $0)).day ?? 0
            }
            return events.map { original in
                guard original.seriesID == id else { return original }
                var updated = replacement
                updated.id = original.id
                updated.seriesID = id
                let shifted = calendar.date(byAdding: .day, value: shift, to: original.date) ?? original.date
                if shift != 0, !hasDateException(original), let index = original.occurrenceIndex {
                    updated.date = newRule.date(at: index, calendar: calendar) ?? shifted
                } else {
                    updated.date = shifted
                }
                updated.endDate = duration.flatMap { calendar.date(byAdding: .day, value: $0, to: updated.date) }
                updated.calendarDay = CalendarDay(updated.date, calendar: calendar)
                updated.calendarEndDay = updated.endDate.map { CalendarDay($0, calendar: calendar) }
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
        var materialized = generate(seed, rule: newRule, now: now, calendar: calendar)
        let generatedIndices = Set(materialized.compactMap(\.occurrenceIndex))
        let exclusions = Set(newRule.excludedIndices)
        let duration = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: seed.date),
                                                     to: calendar.startOfDay(for: seed.endDate ?? seed.date)).day ?? 0)
        // A generation horizon limits new occurrences, not records already
        // saved by the user. Keep each surviving index without filling gaps
        // in unmaterialized history or restoring explicitly deleted dates.
        for index in byIndex.keys where !generatedIndices.contains(index) && !exclusions.contains(index) {
            guard newRule.end != .after || index < newRule.count,
                  let date = newRule.date(at: index, calendar: calendar) else { continue }
            if newRule.end == .onDate, let until = newRule.until,
               calendar.startOfDay(for: date) > calendar.startOfDay(for: until) { continue }
            materialized.append(occurrence(seed, rule: newRule, seriesID: id, index: index,
                                           date: date, duration: duration, calendar: calendar))
        }
        let generated = materialized.sorted { ($0.occurrenceIndex ?? 0) < ($1.occurrenceIndex ?? 0) }.map { member -> Event in
            var updated = member
            if let index = member.occurrenceIndex, let original = byIndex[index] {
                updated.id = original.id
                if original.isRecurrenceException {
                    updated.date = original.date; updated.endDate = original.endDate
                    updated.calendarDay = original.calendarDay; updated.calendarEndDay = original.calendarEndDay
                    updated.isRecurrenceException = true
                }
            }
            return updated
        }
        return events.filter { $0.seriesID != id } + generated
    }
}
