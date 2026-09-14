import Foundation

/// Only the name and birthday needed for an imported event are retained.
struct ContactBirthday: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let anchorDay: CalendarDay
    let calendarIdentifier: Calendar.Identifier

    init?(id: String, name: String, birthday: DateComponents,
          calendarIdentifier: Calendar.Identifier = .gregorian) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !name.isEmpty, let month = birthday.month, let day = birthday.day,
              (1...13).contains(month), (1...31).contains(day) else { return nil }
        var calendar = Calendar(identifier: calendarIdentifier)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        // A stable reference year also preserves February 29 when no birth year is available.
        let reference = Date(timeIntervalSince1970: 946684800) // January 1, 2000
        let base = calendar.dateComponents([.era, .year], from: reference)
        var anchor: Date?
        for offset in 0..<20 {
            var components = DateComponents(era: base.era, year: (base.year ?? 2000) + offset,
                                            month: month, day: day)
            components.isLeapMonth = birthday.isLeapMonth
            guard let date = calendar.date(from: components) else { continue }
            let resolved = calendar.dateComponents([.month, .day, .isLeapMonth], from: date)
            guard resolved.month == month, resolved.day == day,
                  birthday.isLeapMonth != true || resolved.isLeapMonth == true else { continue }
            anchor = date
            break
        }
        guard let anchor else { return nil }
        self.id = id
        self.name = name
        self.anchorDay = CalendarDay(anchor, calendar: calendar)
        self.calendarIdentifier = calendarIdentifier
    }

    var title: String { "\(name)’s birthday" }

    var dateLabel: String {
        var calendar = Calendar(identifier: calendarIdentifier)
        calendar.timeZone = .current
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMMMd")
        return anchorDay.date(in: calendar).map { formatter.string(from: $0) } ?? ""
    }
}

enum BirthdayImport {
    static func selection(birthdays: [ContactBirthday], events: [Event], reviewedIDs: Set<String>) -> Set<String> {
        let imported = Set(events.compactMap { $0.contactBirthday?.id })
        return Set(birthdays.map(\.id).filter { imported.contains($0) || !reviewedIDs.contains($0) })
    }

    /// Apply only contacts actually reviewed. Unavailable contacts and unrelated events are preserved.
    static func applying(_ birthdays: [ContactBirthday], selectedIDs: Set<String>, to events: [Event],
                         category: String, color: CodableColor, now: Date = Date(),
                         calendar: Calendar = .current) -> [Event] {
        let reviewed = Set(birthdays.map(\.id))
        let imported = Dictionary(grouping: events.filter { $0.contactBirthday != nil }, by: { $0.contactBirthday!.id })
        var result = events.filter { event in
            guard let id = event.contactBirthday?.id else { return true }
            return !reviewed.contains(id)
        }
        var visited = Set<String>()
        for birthday in birthdays where visited.insert(birthday.id).inserted {
            let existing = imported[birthday.id] ?? []
            guard selectedIDs.contains(birthday.id) else {
                continue
            }
            // Reopening and saving an unchanged contact must preserve edits, exclusions, and IDs.
            if !existing.isEmpty, existing.allSatisfy({ $0.contactBirthday == birthday }) {
                result.append(contentsOf: existing)
                continue
            }
            guard let anchor = birthday.anchorDay.date(in: calendar) else {
                result.append(contentsOf: existing)
                continue
            }
            var seed = existing.first(where: { !$0.isRecurrenceException }) ?? existing.first
                ?? Event(title: birthday.title, date: anchor, color: color, category: category)
            let previousSource = seed.contactBirthday
            seed.date = anchor
            seed.calendarDay = birthday.anchorDay
            seed.endDate = nil
            if previousSource == nil || seed.title == previousSource?.title { seed.title = birthday.title }
            seed.repeatOption = .yearly
            seed.seriesID = seed.seriesID ?? UUID()
            seed.contactBirthday = birthday
            var rule = RecurrenceRule(event: seed, end: .indefinitely, calendar: calendar)
            rule.calendarIdentifier = birthday.calendarIdentifier
            rule.excludedIndices = seed.recurrence?.excludedIndices ?? []
            let earliest = existing.compactMap(\.occurrenceIndex).min() ?? 0
            var generated = Recurrence.generate(seed, rule: rule, fromIndex: earliest,
                                                now: now, calendar: calendar)
            let byIndex = Dictionary(existing.compactMap { event -> (Int, Event)? in
                event.occurrenceIndex.map { ($0, event) }
            }, uniquingKeysWith: { first, _ in first })
            generated = generated.compactMap { event in
                var updated = event
                if let index = event.occurrenceIndex, let previous = byIndex[index] {
                    updated.id = previous.id
                    if previous.isRecurrenceException {
                        updated = previous
                        updated.contactBirthday = birthday
                        updated.recurrence = rule
                    }
                } else if event.date < calendar.startOfDay(for: now) { return nil }
                return updated
            }
            // Keep occurrences already materialized beyond this import's rolling horizon.
            let generatedIndices = Set(generated.compactMap(\.occurrenceIndex))
            for previous in existing {
                guard let index = previous.occurrenceIndex, !generatedIndices.contains(index),
                      !rule.excludedIndices.contains(index), let date = rule.date(at: index, calendar: calendar) else { continue }
                var updated = previous
                if !previous.isRecurrenceException {
                    updated.date = date
                    updated.calendarDay = CalendarDay(date, calendar: calendar)
                    if previous.title == previous.contactBirthday?.title { updated.title = birthday.title }
                }
                updated.contactBirthday = birthday
                updated.recurrence = rule
                generated.append(updated)
            }
            result.append(contentsOf: generated)
        }
        return result
    }
}
