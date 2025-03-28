import Foundation
import SwiftUI
import UIKit

// Model for an event
public struct Event: Identifiable, Codable, Equatable {
    public var id = UUID()
    public var title: String
    public var date: Date
    public var endDate: Date?
    public var color: CodableColor
    public var category: String?
    public var notificationsEnabled: Bool = true
    public var repeatOption: RepeatOption = .never
    public var repeatUntil: Date?
    public var seriesID: UUID?
    public var customRepeatCount: Int?
    public var repeatUnit: String?
    public var repeatUntilCount: Int?
    public var useCustomRepeatOptions: Bool = false

    public init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        endDate: Date? = nil,
        color: CodableColor,
        category: String? = nil,
        notificationsEnabled: Bool = true,
        repeatOption: RepeatOption = .never,
        repeatUntil: Date? = nil,
        seriesID: UUID? = nil,
        customRepeatCount: Int? = nil,
        repeatUnit: String? = nil,
        repeatUntilCount: Int? = nil,
        useCustomRepeatOptions: Bool = false
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.endDate = endDate
        self.color = color
        self.category = category
        self.notificationsEnabled = notificationsEnabled
        self.repeatOption = repeatOption
        self.repeatUntil = repeatUntil
        self.seriesID = repeatOption == .never ? nil : seriesID
        self.customRepeatCount = customRepeatCount
        self.repeatUnit = repeatUnit
        self.repeatUntilCount = repeatUntilCount
        self.useCustomRepeatOptions = useCustomRepeatOptions
    }

    public static func == (lhs: Event, rhs: Event) -> Bool {
        return lhs.id == rhs.id
    }
}

// Model for a color that can be encoded and decoded
public struct CodableColor: Codable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var opacity: Double

    public var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    public init(color: Color) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.red = Double(red)
        self.green = Double(green)
        self.blue = Double(blue)
        self.opacity = Double(alpha)
    }
}

// Enum for repeat options
public enum RepeatOption: String, Codable, CaseIterable {
    case never = "Never"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    case custom = "Custom"
}

// Enum for repeat until options
public enum RepeatUntilOption: String, Codable {
    case indefinitely = "Indefinitely"
    case after = "After"
    case onDate = "On Date"
}

// Model for category data
public struct CategoryData: Codable {
    public let name: String
    public let color: CodableColor
    public let repeatOption: RepeatOption
    public let showRepeatOptions: Bool
    public let customRepeatCount: Int
    public let repeatUnit: String
    public let repeatUntilOption: RepeatUntilOption
    public let repeatUntilCount: Int
    public let repeatUntil: Date

    public init(
        name: String,
        color: CodableColor,
        repeatOption: RepeatOption,
        showRepeatOptions: Bool,
        customRepeatCount: Int,
        repeatUnit: String,
        repeatUntilOption: RepeatUntilOption,
        repeatUntilCount: Int,
        repeatUntil: Date
    ) {
        self.name = name
        self.color = color
        self.repeatOption = repeatOption
        self.showRepeatOptions = showRepeatOptions
        self.customRepeatCount = customRepeatCount
        self.repeatUnit = repeatUnit
        self.repeatUntilOption = repeatUntilOption
        self.repeatUntilCount = repeatUntilCount
        self.repeatUntil = repeatUntil
    }
}
