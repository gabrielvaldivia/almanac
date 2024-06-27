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
