//
//  Utilities.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI

// Date Extensions
extension Date {
    // Returns a relative date string compared to the current date or an optional end date
    func relativeDate(to endDate: Date? = nil) -> String {
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

// UIColor Extensions
extension UIColor {
    // Converts UIColor to a hexadecimal string representation
    func toHex(includeAlpha alpha: Bool = false) -> String? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)

        if alpha {
            return String(
                format: "#%02X%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
        } else {
            return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        }
    }

    // Initializes UIColor from a hexadecimal string representation
    convenience init?(hex: String) {
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        let a: CGFloat
        let start = hex.index(hex.startIndex, offsetBy: hex.hasPrefix("#") ? 1 : 0)
        let hexColor = String(hex[start...])

        if hexColor.count == 6 {
            let scanner = Scanner(string: hexColor)
            var hexNumber: UInt64 = 0

            if scanner.scanHexInt64(&hexNumber) {
                r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255
                g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255
                b = CGFloat(hexNumber & 0x0000FF) / 255
                a = 1.0
                self.init(red: r, green: g, blue: b, alpha: a)
                return
            }
        }
        return nil
    }
}

// Converts a relative date string to the number of days from today
func daysFromRelativeDate(_ relativeDate: String) -> Int {
    switch relativeDate {
    case "Today":
        return 0
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

// Encodes an encodable object to UserDefaults
func encodeToUserDefaults<T: Encodable>(_ value: T, forKey key: String, suiteName: String? = nil) {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    do {
        let data = try encoder.encode(value)
        let defaults = suiteName != nil ? UserDefaults(suiteName: suiteName) : UserDefaults.standard
        defaults?.set(data, forKey: key)
        print("Successfully saved data for key: \(key)")
    } catch {
        print("Failed to encode data for key \(key): \(error.localizedDescription)")
    }
}

// Decodes a decodable object from UserDefaults
func decodeFromUserDefaults<T: Decodable>(
    _ type: T.Type, forKey key: String, suiteName: String? = nil
) -> T? {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let defaults = suiteName != nil ? UserDefaults(suiteName: suiteName) : UserDefaults.standard
    guard let data = defaults?.data(forKey: key) else {
        print("No data found for key: \(key)")
        return nil
    }
    do {
        let value = try decoder.decode(T.self, from: data)
        print("Successfully loaded data for key: \(key)")
        return value
    } catch {
        print("Failed to decode data for key \(key): \(error.localizedDescription)")
        return nil
    }
}

// Generates a series of repeating events based on the given event and repeat options
func generateRepeatingEvents(
    for event: Event, repeatUntilOption: RepeatUntilOption, showEndDate: Bool
) -> [Event] {
    var repeatingEvents = [Event]()

    // If no repetition is needed, return just the original event
    if !event.useCustomRepeatOptions || event.repeatOption == .never {
        var singleEvent = event
        singleEvent.seriesID = nil  // Ensure no series ID for non-repeating events
        repeatingEvents.append(singleEvent)
        return repeatingEvents
    }

    // Create initial event with series ID
    var currentEvent = event
    let seriesID = UUID()
    currentEvent.seriesID = seriesID
    repeatingEvents.append(currentEvent)

    // Set maximum number of repetitions to prevent infinite loops
    let maxRepetitions: Int
    switch repeatUntilOption {
    case .indefinitely:
        maxRepetitions = 365  // Limit to 1 year for indefinite repeats
    case .onDate:
        maxRepetitions = 365  // Also limit date-based repeats
    case .after:
        maxRepetitions = event.repeatUntilCount ?? 1
    }

    // Calculate event duration for end date
    let duration =
        Calendar.current.dateComponents(
            [.day],
            from: event.date,
            to: event.endDate ?? event.date
        ).day ?? 0

    var currentDate = event.date
    var repetitionCount = 1

    while repetitionCount < maxRepetitions {
        // Calculate next date based on repeat option
        let nextDate: Date?

        if case .custom = event.repeatOption,
            let count = event.customRepeatCount,
            let unit = event.repeatUnit?.lowercased()
        {
            // Handle custom repeat interval
            switch unit {
            case "days":
                nextDate = Calendar.current.date(byAdding: .day, value: count, to: currentDate)
            case "weeks":
                nextDate = Calendar.current.date(
                    byAdding: .weekOfYear, value: count, to: currentDate)
            case "months":
                nextDate = Calendar.current.date(byAdding: .month, value: count, to: currentDate)
            case "years":
                nextDate = Calendar.current.date(byAdding: .year, value: count, to: currentDate)
            default:
                nextDate = nil
            }
        } else {
            // Handle standard repeat intervals
            switch event.repeatOption {
            case .daily:
                nextDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)
            case .weekly:
                nextDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentDate)
            case .monthly:
                nextDate = Calendar.current.date(byAdding: .month, value: 1, to: currentDate)
            case .yearly:
                nextDate = Calendar.current.date(byAdding: .year, value: 1, to: currentDate)
            case .custom, .never:
                nextDate = nil
            }
        }

        guard let validNextDate = nextDate else { break }

        // Check if we've reached the until date
        if case .onDate = repeatUntilOption,
            let untilDate = event.repeatUntil,
            validNextDate > untilDate
        {
            break
        }

        // Create the next event
        let nextEvent = Event(
            title: event.title,
            date: validNextDate,
            endDate: showEndDate
                ? Calendar.current.date(byAdding: .day, value: duration, to: validNextDate) : nil,
            color: event.color,
            category: event.category,
            repeatOption: event.repeatOption,
            repeatUntil: event.repeatUntil,
            seriesID: seriesID,
            customRepeatCount: event.customRepeatCount,
            repeatUnit: event.repeatUnit,
            repeatUntilCount: event.repeatUntilCount,
            useCustomRepeatOptions: event.useCustomRepeatOptions
        )

        repeatingEvents.append(nextEvent)
        currentDate = validNextDate
        repetitionCount += 1
    }

    return repeatingEvents
}

// Calculates the next repeat date for a given event based on its repeat option
func getNextRepeatDate(for event: Event) -> Date? {
    switch event.repeatOption {
    case .daily:
        return Calendar.current.date(byAdding: .day, value: 1, to: event.date)
    case .weekly:
        return Calendar.current.date(byAdding: .weekOfYear, value: 1, to: event.date)
    case .monthly:
        return Calendar.current.date(byAdding: .month, value: 1, to: event.date)
    case .yearly:
        return Calendar.current.date(byAdding: .year, value: 1, to: event.date)
    case .custom:
        guard let repeatUnit = event.repeatUnit,
            let customRepeatCount = event.customRepeatCount
        else {
            return nil
        }

        switch repeatUnit.lowercased() {
        case "days":
            return Calendar.current.date(byAdding: .day, value: customRepeatCount, to: event.date)
        case "weeks":
            return Calendar.current.date(
                byAdding: .weekOfYear, value: customRepeatCount, to: event.date)
        case "months":
            return Calendar.current.date(byAdding: .month, value: customRepeatCount, to: event.date)
        case "years":
            return Calendar.current.date(byAdding: .year, value: customRepeatCount, to: event.date)
        default:
            return nil
        }
    case .never:
        return nil
    }
}

// // Enum to represent different repeat until options
// enum RepeatUntilOption: String, CaseIterable {
//     case indefinitely = "Never"
//     case after = "After"
//     case onDate = "On"
// }

// Calculates the repeat until date based on the repeat option, start date, count, and repeat unit
func calculateRepeatUntilDate(
    for repeatOption: RepeatOption, from startDate: Date, count: Int, repeatUnit: String
) -> Date {
    let calendar = Calendar.current

    switch repeatOption {
    case .daily:
        return calendar.date(byAdding: .day, value: count, to: startDate) ?? startDate
    case .weekly:
        return calendar.date(byAdding: .weekOfYear, value: count, to: startDate) ?? startDate
    case .monthly:
        return calendar.date(byAdding: .month, value: count, to: startDate) ?? startDate
    case .yearly:
        return calendar.date(byAdding: .year, value: count, to: startDate) ?? startDate
    case .custom:
        switch repeatUnit.lowercased() {
        case "days":
            return calendar.date(byAdding: .day, value: count, to: startDate) ?? startDate
        case "weeks":
            return calendar.date(byAdding: .weekOfYear, value: count, to: startDate) ?? startDate
        case "months":
            return calendar.date(byAdding: .month, value: count, to: startDate) ?? startDate
        case "years":
            return calendar.date(byAdding: .year, value: count, to: startDate) ?? startDate
        default:
            return startDate
        }
    case .never:
        return startDate
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "E, MMM d"
    return formatter
}()

enum DateFormatting {
    static func calculateTimeRemaining(from startDate: Date, to endDate: Date?) -> String {
        guard let endDate = endDate else {
            return startDate.relativeDate()
        }
        let now = Date()
        let calendar = Calendar.current
        let daysRemaining = calendar.dateComponents([.day], from: now, to: endDate).day! + 1
        let dayText = daysRemaining == 1 ? "day" : "days"

        let startDateString = dateFormatter.string(from: startDate)
        let endDateString = dateFormatter.string(from: endDate)

        if calendar.isDate(startDate, inSameDayAs: endDate) {
            return "\(startDateString) (\(daysRemaining) \(dayText) left)"
        } else {
            return "\(startDateString) → \(endDateString) (\(daysRemaining) \(dayText) left)"
        }
    }
}
