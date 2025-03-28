import Foundation

public enum DateUtilities {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter
    }()

    public static func calculateTimeRemaining(from startDate: Date, to endDate: Date?) -> String {
        guard let endDate = endDate else {
            return startDate.relativeDate()
        }

        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let startOfStartDate = calendar.startOfDay(for: startDate)
        let startOfEndDate = calendar.startOfDay(for: endDate)

        let startDateString = dateFormatter.string(from: startDate)
        let endDateString = dateFormatter.string(from: endDate)

        // Calculate total duration of the event (using start of days)
        let duration =
            calendar.dateComponents([.day], from: startOfStartDate, to: startOfEndDate).day! + 1
        let durationText = duration == 1 ? "day" : "days"

        // If start date is after today, show duration
        if startOfStartDate > now {
            if calendar.isDate(startDate, inSameDayAs: endDate) {
                return "\(startDateString) (\(duration) \(durationText))"
            } else {
                return "\(startDateString) → \(endDateString) (\(duration) \(durationText))"
            }
        }

        // For ongoing or past events, show days remaining
        let daysRemaining = calendar.dateComponents([.day], from: now, to: startOfEndDate).day! + 1
        let dayText = daysRemaining == 1 ? "day" : "days"

        if calendar.isDate(startDate, inSameDayAs: endDate) {
            return "\(startDateString) (\(daysRemaining) \(dayText) left)"
        } else {
            return "\(startDateString) → \(endDateString) (\(daysRemaining) \(dayText) left)"
        }
    }
}

// Date Extensions
extension Date {
    // Returns a relative date string compared to the current date or an optional end date
    public func relativeDate(to endDate: Date? = nil) -> String {
        let calendar = Calendar.current
        let now = Date()
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
                return "In \(x) days"
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
