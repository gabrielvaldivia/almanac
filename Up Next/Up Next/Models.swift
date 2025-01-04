import Foundation
import SwiftUI
import UIKit

// Model for an event
struct Event: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var date: Date
    var endDate: Date?
    var color: CodableColor
    var category: String?
    var notificationsEnabled: Bool = true
    var repeatOption: RepeatOption = .never
    var repeatUntil: Date?
    var seriesID: UUID?
    var customRepeatCount: Int?
    var repeatUnit: String?
    var repeatUntilCount: Int?
    var useCustomRepeatOptions: Bool = false

    init(
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

    static func == (lhs: Event, rhs: Event) -> Bool {
        return lhs.id == rhs.id
    }
}

// Model for a color that can be encoded and decoded
struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    init(color: Color) {
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
enum RepeatOption: String, Codable, CaseIterable {
    case never = "Never"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    case custom = "Custom"
}

// Enum for repeat until options
enum RepeatUntilOption: String, Codable {
    case indefinitely = "Indefinitely"
    case after = "After"
    case onDate = "On Date"
}

// Model for category data
struct CategoryData: Codable {
    let name: String
    let color: CodableColor
    let repeatOption: RepeatOption
    let showRepeatOptions: Bool
    let customRepeatCount: Int
    let repeatUnit: String
    let repeatUntilOption: RepeatUntilOption
    let repeatUntilCount: Int
    let repeatUntil: Date
}

// Struct for event details
public struct EventDetails {
    var title: String
    var selectedEvent: Event?
}

// Struct for date options
public struct DateOptions {
    var date: Date
    var endDate: Date
    var showEndDate: Bool
    var repeatOption: RepeatOption
    var repeatUntil: Date
    var repeatUntilOption: RepeatUntilOption
    var repeatUntilCount: Int
    var showRepeatOptions: Bool
    var repeatUnit: String
    var customRepeatCount: Int
}

// Struct for category options
public struct CategoryOptions {
    var selectedCategory: String?
    var selectedColor: CodableColor
}

// Struct for view state
public struct ViewState {
    var showCategoryManagementView: Bool
    var showDeleteActionSheet: Bool
    var showDeleteButtons: Bool
}
