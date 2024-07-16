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

        if let endDate = endDate, startOfSelf <= startOfNow, calendar.startOfDay(for: endDate) >= startOfNow {
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
            return String(format: "#%02X%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
        } else {
            return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        }
    }

    // Initializes UIColor from a hexadecimal string representation
    convenience init?(hex: String) {
        let r, g, b, a: CGFloat
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

// Utility Functions

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
        let days = Int(otherDay.replacingOccurrences(of: "in ", with: "").replacingOccurrences(of: " days", with: "")) ?? 0
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
func decodeFromUserDefaults<T: Decodable>(_ type: T.Type, forKey key: String, suiteName: String? = nil) -> T? {
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
func generateRepeatingEvents(for event: Event, repeatUntilOption: RepeatUntilOption, showEndDate: Bool) -> [Event] {
    var repeatingEvents = [Event]()
    var currentEvent = event
    let seriesID = UUID()
    currentEvent.seriesID = seriesID
    repeatingEvents.append(currentEvent)
    
    var repetitionCount = 1
    let maxRepetitions: Int
    
    switch repeatUntilOption {
    case .indefinitely, .onDate:
        maxRepetitions = 100
    case .after:
        maxRepetitions = event.repeatUntilCount ?? 1
    }
    
    let duration = Calendar.current.dateComponents([.day], from: event.date, to: event.endDate ?? event.date).day ?? 0
    
    while let nextDate = getNextRepeatDate(for: currentEvent),
          nextDate <= (event.repeatUntil ?? Date.distantFuture),
          repetitionCount < maxRepetitions {
        currentEvent = Event(
            title: event.title,
            date: nextDate,
            endDate: showEndDate ? Calendar.current.date(byAdding: .day, value: duration, to: nextDate) : nil,
            color: event.color,
            category: event.category,
            repeatOption: event.repeatOption,
            repeatUntil: event.repeatUntil,
            seriesID: seriesID,
            customRepeatCount: event.customRepeatCount,
            repeatUnit: event.repeatUnit
        )
        repeatingEvents.append(currentEvent)
        repetitionCount += 1
    }
    
    return repeatingEvents
}

// Calculates the next repeat date for a given event based on its repeat option
func getNextRepeatDate(for event: Event) -> Date? {
    let calendar = Calendar.current
    let value: Int
    
    switch event.repeatOption {
    case .never:
        return nil
    case .daily:
        value = 1
    case .weekly:
        value = 1
    case .monthly:
        value = 1
    case .yearly:
        value = 1
    case .custom:
        value = event.customRepeatCount ?? 1
    }
    
    switch event.repeatOption {
    case .daily, .custom where event.repeatUnit == "Days":
        return calendar.date(byAdding: .day, value: value, to: event.date)
    case .weekly, .custom where event.repeatUnit == "Weeks":
        return calendar.date(byAdding: .weekOfYear, value: value, to: event.date)
    case .monthly, .custom where event.repeatUnit == "Months":
        return calendar.date(byAdding: .month, value: value, to: event.date)
    case .yearly, .custom where event.repeatUnit == "Years":
        return calendar.date(byAdding: .year, value: value, to: event.date)
    default:
        return nil
    }
}

// Enum to represent different repeat until options
enum RepeatUntilOption: String, CaseIterable {
    case indefinitely = "Never"
    case after = "After"
    case onDate = "On"
}

// Calculates the repeat until date based on the repeat option, start date, count, and repeat unit
func calculateRepeatUntilDate(for option: RepeatOption, from startDate: Date, count: Int, repeatUnit: String) -> Date? {
    switch option {
    case .never:
        return nil
    case .daily:
        return Calendar.current.date(byAdding: .day, value: count - 1, to: startDate)
    case .weekly:
        return Calendar.current.date(byAdding: .weekOfYear, value: count - 1, to: startDate)
    case .monthly:
        return Calendar.current.date(byAdding: .month, value: count - 1, to: startDate)
    case .yearly:
        return Calendar.current.date(byAdding: .year, value: count - 1, to: startDate)
    case .custom:
        switch repeatUnit {
        case "Days":
            return Calendar.current.date(byAdding: .day, value: count - 1, to: startDate)
        case "Weeks":
            return Calendar.current.date(byAdding: .weekOfYear, value: count - 1, to: startDate)
        case "Months":
            return Calendar.current.date(byAdding: .month, value: count - 1, to: startDate)
        case "Years":
            return Calendar.current.date(byAdding: .year, value: count - 1, to: startDate)
        default:
            return nil
        }
    }
}