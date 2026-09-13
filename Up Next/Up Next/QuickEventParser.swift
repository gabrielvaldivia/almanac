import Foundation

struct ParsedEventInput: Equatable {
    let title: String
    let date: Date
    let recurrence: ParsedEventRecurrence?

    init(title: String, date: Date, recurrence: ParsedEventRecurrence? = nil) {
        self.title = title
        self.date = date
        self.recurrence = recurrence
    }
}

struct ParsedEventRecurrence: Equatable {
    let option: RepeatOption
    let interval: Int
    let unit: String
    let until: Date?
}

/// An offline grammar for calendar dates and recurring schedules.
/// Slash dates use month/day; dates without a year use their next occurrence.
enum QuickEventParser {
    static func parse(_ input: String, now: Date = Date(), calendar: Calendar = .current) -> ParsedEventInput? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // Parse a recurrence before a trailing date, so "until December 15"
        // can never accidentally become a one-off event on December 15.
        let marker = #"(?:^|\s)(every\b|(?:daily|weekly|monthly|yearly|annually)(?=\s*(?:$|until\b|through\b|starting\b|from\b)))"#
        if let recurrence = match(marker, in: text) {
            return parseRecurrence(text, marker: recurrence, now: now, calendar: calendar)
        }
        return parseSingleEvent(text, now: now, calendar: calendar)
    }

    private static func parseSingleEvent(_ text: String, now: Date, calendar: Calendar) -> ParsedEventInput? {
        let today = calendar.startOfDay(for: now)

        func result(_ match: Match, date: Date?) -> ParsedEventInput? {
            guard let date else { return nil }
            let title = String(text[..<match.range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: #"\s+on$"#, with: "", options: [.regularExpression, .caseInsensitive])
            guard !title.isEmpty else { return nil }
            return ParsedEventInput(title: title, date: calendar.startOfDay(for: date),
                                    recurrence: inferredRecurrence(for: title))
        }

        if let match = match(#"(?:^|\s)(today|tomorrow|tonight)$"#, in: text) {
            let offset = match.groups[0].lowercased() == "tomorrow" ? 1 : 0
            return result(match, date: calendar.date(byAdding: .day, value: offset, to: today))
        }
        if let match = match(#"(?:^|\s)in\s+(\d{1,3})\s+(days?|weeks?)$"#, in: text),
           let count = Int(match.groups[0]) {
            let days = count * (match.groups[1].lowercased().hasPrefix("week") ? 7 : 1)
            return result(match, date: calendar.date(byAdding: .day, value: days, to: today))
        }
        if let match = match(#"(?:^|\s)(?:next\s+)?(sun(?:day)?|mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?)$"#, in: text) {
            let weekdays = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
            guard let index = weekdays.firstIndex(of: String(match.groups[0].lowercased().prefix(3))) else { return nil }
            let offset = (index + 1 - calendar.component(.weekday, from: today) + 7) % 7
            // A weekday means the next such day, including next week if today matches.
            return result(match, date: calendar.date(byAdding: .day, value: offset == 0 ? 7 : offset, to: today))
        }
        if let match = match(#"(?:^|\s)(\d{1,2})/(\d{1,2})(?:/(\d{4}|\d{2}))?$"#, in: text) {
            let year = Int(match.groups[2]).map { $0 < 100 ? 2000 + $0 : $0 }
            return result(match, date: nextDate(month: Int(match.groups[0])!, day: Int(match.groups[1])!,
                                                year: year, today: today, calendar: calendar))
        }
        if let match = match(#"(?:^|\s)(\d{4})-(\d{2})-(\d{2})$"#, in: text) {
            return result(match, date: nextDate(month: Int(match.groups[1])!, day: Int(match.groups[2])!,
                                                year: Int(match.groups[0]), today: today, calendar: calendar))
        }
        let monthNames = #"(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|sept|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\.?"#
        let day = #"(\d{1,2})(?:st|nd|rd|th)?"#
        let year = #"(?:,?\s+(\d{4}))?$"#
        if let match = match(#"(?:^|\s)"# + monthNames + #"\s+"# + day + year, in: text) {
            return result(match, date: nextDate(month: monthNumber(match.groups[0]), day: Int(match.groups[1])!,
                                                year: Int(match.groups[2]), today: today, calendar: calendar))
        }
        if let match = match(#"(?:^|\s)"# + day + #"\s+"# + monthNames + year, in: text) {
            return result(match, date: nextDate(month: monthNumber(match.groups[1]), day: Int(match.groups[0])!,
                                                year: Int(match.groups[2]), today: today, calendar: calendar))
        }
        return nil
    }

    private static let weekdays = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
    private static let weekdayPattern = #"(sun(?:day)?|mon(?:day)?|tue(?:sday)?|wed(?:nesday)?|thu(?:rsday)?|fri(?:day)?|sat(?:urday)?)s?"#
    private static let intervalPattern = #"(?:(other|\d{1,4}|one|two|three|four|five|six|seven|eight|nine|ten|twelve)\s+)?"#

    static func inferredRecurrence(for title: String) -> ParsedEventRecurrence? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        // Match the occasion itself, not errands like "buy a birthday gift".
        guard match(#"\b(?:birthday|b[ -]?day|anniversary)$"#, in: title) != nil else { return nil }
        return ParsedEventRecurrence(option: .yearly, interval: 1, unit: "Years", until: nil)
    }

    private static func parseRecurrence(_ text: String, marker: Match, now: Date,
                                        calendar: Calendar) -> ParsedEventInput? {
        let prefix = String(text[..<marker.range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty else { return nil }
        var schedule = String(text[marker.range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        var untilPhrase: String?
        if let ending = match(#"\s+(?:until|through)\b"#, in: schedule) {
            untilPhrase = String(schedule[ending.range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            schedule = String(schedule[..<ending.range.lowerBound])
        }

        // A starting date can precede the repeat phrase or follow "starting".
        // A weekday cadence advances that date to the first matching weekday.
        let datedPrefix = parseSingleEvent(prefix, now: now, calendar: calendar)
        let title = datedPrefix?.title ?? prefix
        var start = datedPrefix?.date ?? calendar.startOfDay(for: now)
        if let starting = match(#"\s+(?:starting|from)\b"#, in: schedule) {
            guard datedPrefix == nil,
                  let date = datePhrase(String(schedule[starting.range.upperBound...]), now: now, calendar: calendar) else { return nil }
            start = date
            schedule = String(schedule[..<starting.range.lowerBound])
        }
        schedule = schedule.trimmingCharacters(in: .whitespacesAndNewlines)

        let interval: Int
        let unit: String
        let standardOption: RepeatOption
        var weekday: Int?
        switch schedule.lowercased() {
        case "daily":
            interval = 1; unit = "Days"; standardOption = .daily
        case "weekly":
            interval = 1; unit = "Weeks"; standardOption = .weekly
        case "monthly":
            interval = 1; unit = "Months"; standardOption = .monthly
        case "yearly", "annually":
            interval = 1; unit = "Years"; standardOption = .yearly
        default:
            if let cadence = match(#"^every\s+"# + intervalPattern + weekdayPattern + "$", in: schedule),
               let count = repeatInterval(cadence.groups[0]),
               let dayIndex = weekdays.firstIndex(of: String(cadence.groups[1].lowercased().prefix(3))) {
                interval = count; unit = "Weeks"; standardOption = .weekly
                weekday = dayIndex + 1
            } else if let cadence = match(#"^every\s+"# + intervalPattern + #"(days?|weeks?|months?|years?)$"#, in: schedule),
                      let count = repeatInterval(cadence.groups[0]) {
                interval = count
                switch cadence.groups[1].lowercased() {
                case "day", "days": unit = "Days"; standardOption = .daily
                case "week", "weeks": unit = "Weeks"; standardOption = .weekly
                case "month", "months": unit = "Months"; standardOption = .monthly
                default: unit = "Years"; standardOption = .yearly
                }
            } else {
                return nil
            }
        }
        if let weekday {
            let offset = (weekday - calendar.component(.weekday, from: start) + 7) % 7
            guard let firstOccurrence = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            start = firstOccurrence
        }

        var until: Date?
        if let untilPhrase {
            guard let end = datePhrase(untilPhrase, now: now, calendar: calendar), end >= start else { return nil }
            until = end
        }
        return ParsedEventInput(
            title: title, date: start,
            recurrence: ParsedEventRecurrence(option: interval == 1 ? standardOption : .custom,
                                               interval: interval, unit: unit, until: until)
        )
    }

    private static func repeatInterval(_ value: String) -> Int? {
        let words = ["": 1, "one": 1, "other": 2, "two": 2, "three": 3, "four": 4,
                     "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10, "twelve": 12]
        guard let count = words[value.lowercased()] ?? Int(value), (1...1000).contains(count) else { return nil }
        return count
    }

    private static func datePhrase(_ phrase: String, now: Date, calendar: Calendar) -> Date? {
        let sentinel = "__schedule_date__"
        let phrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = parseSingleEvent("\(sentinel) \(phrase)", now: now, calendar: calendar),
              parsed.title == sentinel else { return nil }
        return parsed.date
    }

    private static func monthNumber(_ name: String) -> Int {
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        return months.firstIndex(of: String(name.lowercased().prefix(3)))! + 1
    }

    private static func nextDate(month: Int, day: Int, year: Int?, today: Date, calendar: Calendar) -> Date? {
        guard (1...12).contains(month), (1...31).contains(day) else { return nil }
        let startYear = year ?? calendar.component(.year, from: today)
        // Find the next February 29, including century boundaries.
        for candidateYear in startYear...(year == nil ? startYear + 8 : startYear) {
            let components = DateComponents(year: candidateYear, month: month, day: day)
            guard let date = calendar.date(from: components) else { continue }
            let actual = calendar.dateComponents([.year, .month, .day], from: date)
            // Calendar.date normalizes impossible dates, so validate the round trip.
            guard actual.year == candidateYear, actual.month == month, actual.day == day else { continue }
            if year != nil || date >= today { return date }
        }
        return nil
    }

    private struct Match {
        let range: Range<String.Index>
        let groups: [String]
    }

    private static func match(_ pattern: String, in text: String) -> Match? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return nil }
        return Match(range: range, groups: (1..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
        })
    }
}
