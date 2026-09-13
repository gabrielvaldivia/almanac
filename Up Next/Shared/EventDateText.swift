import Foundation

enum EventDateText {
    static func range(start: Date, end: Date?, reference: Date = Date(), calendar: Calendar = .current) -> String {
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
        formatter.dateFormat = calendar.component(.year, from: start) == calendar.component(.year, from: reference) ? "E, MMM d" : "E, MMM d, yyyy"
        let first = formatter.string(from: start)
        guard let end else { return first }
        let today = calendar.startOfDay(for: reference), startDay = calendar.startOfDay(for: start), endDay = calendar.startOfDay(for: end)
        let span = calendar.isDate(start, inSameDayAs: end) ? first : "\(first) → \(formatter.string(from: end))"
        let ongoing = startDay <= today && endDay >= today
        let count = max(1, (calendar.dateComponents([.day], from: ongoing ? today : startDay, to: endDay).day ?? 0) + 1)
        return "\(span) (\(count) \(count == 1 ? "day" : "days")\(ongoing ? " left" : ""))"
    }
}

// Date Extensions
extension Date {
    // Returns a relative date string compared to the current date or an optional end date
    func relativeDate(to endDate: Date? = nil, now: Date = Date()) -> String {
        let calendar = Calendar.current
        let startOfNow = calendar.startOfDay(for: now)
        let startOfSelf = calendar.startOfDay(for: self)

        if let endDate = endDate, startOfSelf <= startOfNow,
            calendar.startOfDay(for: endDate) >= startOfNow
        {
            return "Today"
        } else {
            let components = calendar.dateComponents([.day], from: startOfNow, to: startOfSelf)
            guard let dayCount = components.day else { return "Error" }

            switch dayCount {
            case 0:
                return "Today"
            case 1:
                return "Tomorrow"
            case let x where x > 1:
                return "in \(x) days"
            case -1:
                return "Yesterday"
            case let x where x < -1:
                return "\(abs(x)) days ago"
            default:
                return "Error"
            }
        }
    }
}

// Converts a relative date string to the number of days from today
func daysFromRelativeDate(_ relativeDate: String) -> Int {
    switch relativeDate {
    case "Today":
        return 0
    case "Yesterday":
        return -1
    case "Tomorrow":
        return 1
    case let otherDay where otherDay.contains(" days ago"):
        let days = Int(otherDay.replacingOccurrences(of: " days ago", with: "")) ?? 0
        return -days
    case let otherDay where otherDay.contains(" day ago"):
        return -1
    case let otherDay where otherDay.starts(with: "in ") && otherDay.hasSuffix(" days"):
        let days =
            Int(
                otherDay.replacingOccurrences(of: "in ", with: "").replacingOccurrences(
                    of: " days", with: "")) ?? 0
        return days
    default:
        return 0
    }
}
