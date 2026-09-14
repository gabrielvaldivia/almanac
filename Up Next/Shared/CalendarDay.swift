import Foundation

/// A floating Gregorian calendar date. Its identity does not change with the device time zone.
struct CalendarDay: Codable, Equatable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(_ date: Date, calendar: Calendar = .current) {
        var gregorian = Calendar(identifier: .gregorian); gregorian.timeZone = calendar.timeZone
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        year = parts.year!; month = parts.month!; day = parts.day!
    }

    func date(in calendar: Calendar = .current) -> Date? {
        var gregorian = Calendar(identifier: .gregorian); gregorian.timeZone = calendar.timeZone
        guard let date = gregorian.date(from: DateComponents(year: year, month: month, day: day)),
              CalendarDay(date, calendar: gregorian) == self else { return nil }
        return date
    }
}

extension CodingUserInfoKey {
    static let eventCalendar = CodingUserInfoKey(rawValue: "almanac.eventCalendar")!
}
