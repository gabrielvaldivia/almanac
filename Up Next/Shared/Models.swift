import Foundation
import SwiftUI
import UIKit

// Model for an event
struct Event: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var date: Date { didSet { calendarDay = CalendarDay(date) } }
    var endDate: Date? { didSet { calendarEndDay = endDate.map { CalendarDay($0) } } }
    var calendarDay: CalendarDay?
    var calendarEndDay: CalendarDay?
    var calendarSchemaVersion = 1
    var color: CodableColor
    var category: String?
    var notificationsEnabled: Bool = true
    var repeatOption: RepeatOption = .never
    var repeatUntil: Date?
    var seriesID: UUID?
    var customRepeatCount: Int?
    var repeatUnit: String?
    var repeatUntilCount: Int?  // Added this line
    var useCustomRepeatOptions: Bool = false
    var recurrence: RecurrenceRule?
    var occurrenceIndex: Int?
    var isRecurrenceException = false

    // Initializer for Event
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
        self.calendarDay = CalendarDay(date)
        self.calendarEndDay = endDate.map { CalendarDay($0) }
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

    // Custom decoding to provide default values for new properties
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        let calendar = decoder.userInfo[.eventCalendar] as? Calendar ?? .current
        let legacyDate = try container.decode(Date.self, forKey: .date)
        let legacyEnd = try container.decodeIfPresent(Date.self, forKey: .endDate)
        calendarDay = try container.decodeIfPresent(CalendarDay.self, forKey: .calendarDay) ?? CalendarDay(legacyDate, calendar: calendar)
        calendarEndDay = try container.decodeIfPresent(CalendarDay.self, forKey: .calendarEndDay) ?? legacyEnd.map { CalendarDay($0, calendar: calendar) }
        guard let resolved = calendarDay?.date(in: calendar) else {
            throw DecodingError.dataCorruptedError(forKey: .calendarDay, in: container, debugDescription: "Invalid calendar date")
        }
        date = resolved
        endDate = calendarEndDay?.date(in: calendar)
        if calendarEndDay != nil && endDate == nil {
            throw DecodingError.dataCorruptedError(forKey: .calendarEndDay, in: container, debugDescription: "Invalid end calendar date")
        }
        calendarSchemaVersion = try container.decodeIfPresent(Int.self, forKey: .calendarSchemaVersion) ?? 0
        color = try container.decode(CodableColor.self, forKey: .color)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        repeatOption = try container.decodeIfPresent(RepeatOption.self, forKey: .repeatOption) ?? .never
        repeatUntil = try container.decodeIfPresent(Date.self, forKey: .repeatUntil)
        seriesID = try container.decodeIfPresent(UUID.self, forKey: .seriesID)
        customRepeatCount = try container.decodeIfPresent(Int.self, forKey: .customRepeatCount) ?? 1  // Default value
        repeatUnit = try container.decodeIfPresent(String.self, forKey: .repeatUnit) ?? "Days"  // Default value
        repeatUntilCount = try container.decodeIfPresent(Int.self, forKey: .repeatUntilCount) ?? 1  // Default value
        useCustomRepeatOptions = try container.decodeIfPresent(Bool.self, forKey: .useCustomRepeatOptions) ?? false
        recurrence = try container.decodeIfPresent(RecurrenceRule.self, forKey: .recurrence)
        occurrenceIndex = try container.decodeIfPresent(Int.self, forKey: .occurrenceIndex)
        isRecurrenceException = try container.decodeIfPresent(Bool.self, forKey: .isRecurrenceException) ?? false
    }

    // Coding keys for encoding and decoding
    enum CodingKeys: String, CodingKey {
        case id, title, date, endDate, color, category, notificationsEnabled, repeatOption,
            repeatUntil, seriesID, customRepeatCount, repeatUnit, repeatUntilCount,
            useCustomRepeatOptions, recurrence, occurrenceIndex, isRecurrenceException, calendarDay, calendarEndDay, calendarSchemaVersion
    }

}

// A missing series ID must never match unrelated standalone events.
enum CategoryName {
    static func isValid(_ name: String, existing: [String], excluding original: String? = nil) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.localizedCaseInsensitiveCompare("All Categories") != .orderedSame && !existing.contains {
            $0 != original && $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }
    }
}

enum EventSeries {
    static func members(of event: Event, in events: [Event]) -> [Event] {
        guard let seriesID = event.seriesID else { return [] }
        return events.filter { $0.seriesID == seriesID }
    }

    static func updating(_ selected: Event, with replacement: Event, in events: [Event], calendar: Calendar = .current) -> [Event] {
        if selected.recurrence != nil { return Recurrence.updatingSeries(selected, with: replacement, in: events, calendar: calendar) }
        return updatingLegacy(selected, with: replacement, in: events, calendar: calendar)
    }

    static func updatingLegacy(_ selected: Event, with replacement: Event, in events: [Event],
                         calendar: Calendar = .current) -> [Event] {
        guard let seriesID = selected.seriesID else { return events }
        let members = self.members(of: selected, in: events).sorted {
            $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date
        }
        guard let anchor = members.firstIndex(where: { $0.id == selected.id }) else { return events }
        if replacement.repeatOption == .never {
            var single = replacement
            single.seriesID = nil
            return events.compactMap { event in
                event.id == selected.id ? single : (event.seriesID == seriesID ? nil : event)
            }
        }
        let sameInterval = selected.repeatOption == replacement.repeatOption
            && selected.customRepeatCount == replacement.customRepeatCount
            && selected.repeatUnit == replacement.repeatUnit
        let shift = calendar.dateComponents([.day], from: calendar.startOfDay(for: selected.date),
                                             to: calendar.startOfDay(for: replacement.date)).day ?? 0
        let duration = replacement.endDate.map {
            calendar.dateComponents([.day], from: calendar.startOfDay(for: replacement.date),
                                    to: calendar.startOfDay(for: $0)).day ?? 0
        }
        let component: Calendar.Component
        let interval: Int
        switch replacement.repeatOption {
        case .daily: component = .day; interval = 1
        case .weekly: component = .weekOfYear; interval = 1
        case .monthly: component = .month; interval = 1
        case .yearly: component = .year; interval = 1
        case .custom:
            interval = max(1, replacement.customRepeatCount ?? 1)
            switch replacement.repeatUnit?.lowercased() {
            case "weeks": component = .weekOfYear
            case "months": component = .month
            case "years": component = .year
            default: component = .day
            }
        case .never: return events
        }
        var updates: [UUID: Event] = [:]
        for (index, event) in members.enumerated() {
            var updated = replacement
            updated.id = event.id
            updated.seriesID = seriesID
            updated.date = sameInterval
                ? calendar.date(byAdding: .day, value: shift, to: event.date) ?? event.date
                : calendar.date(byAdding: component, value: (index - anchor) * interval,
                                to: replacement.date) ?? event.date
            updated.endDate = duration.flatMap { calendar.date(byAdding: .day, value: $0, to: updated.date) }
            updates[event.id] = updated
        }
        return events.map { updates[$0.id] ?? $0 }
    }

    static func removing(_ event: Event, from events: [Event]) -> [Event] {
        guard let seriesID = event.seriesID else { return events }
        return events.filter { $0.seriesID != seriesID }
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

// Model for a color that can be encoded and decoded
struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    // Initializer for CodableColor
    init(color: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        red = Double(r); green = Double(g); blue = Double(b); opacity = Double(a)
    }

    // Custom decoding for CodableColor
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        red = try container.decode(Double.self, forKey: .red)
        green = try container.decode(Double.self, forKey: .green)
        blue = try container.decode(Double.self, forKey: .blue)
        opacity = try container.decode(Double.self, forKey: .opacity)
    }

    // Custom encoding for CodableColor
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(red, forKey: .red)
        try container.encode(green, forKey: .green)
        try container.encode(blue, forKey: .blue)
        try container.encode(opacity, forKey: .opacity)
    }

    // Coding keys for encoding and decoding
    enum CodingKeys: String, CodingKey {
        case red, green, blue, opacity
    }
}


extension CategoryData {
    private enum CodingKeys: String, CodingKey {
        case name, color, repeatOption, showRepeatOptions, customRepeatCount, repeatUnit,
             repeatUntilOption, repeatUntilCount, repeatUntil, calendarRepeatUntil
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
        color = try values.decode(CodableColor.self, forKey: .color)
        repeatOption = try values.decodeIfPresent(RepeatOption.self, forKey: .repeatOption) ?? .never
        showRepeatOptions = try values.decodeIfPresent(Bool.self, forKey: .showRepeatOptions) ?? false
        customRepeatCount = try values.decodeIfPresent(Int.self, forKey: .customRepeatCount) ?? 1
        repeatUnit = try values.decodeIfPresent(String.self, forKey: .repeatUnit) ?? "Days"
        repeatUntilOption = try values.decodeIfPresent(RepeatUntilOption.self, forKey: .repeatUntilOption) ?? .indefinitely
        repeatUntilCount = try values.decodeIfPresent(Int.self, forKey: .repeatUntilCount) ?? 1
        let legacyDate = try values.decodeIfPresent(Date.self, forKey: .repeatUntil) ?? Date()
        let day = try values.decodeIfPresent(CalendarDay.self, forKey: .calendarRepeatUntil)
        repeatUntil = day?.date() ?? legacyDate
    }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(name, forKey: .name)
        try values.encode(color, forKey: .color)
        try values.encode(repeatOption, forKey: .repeatOption)
        try values.encode(showRepeatOptions, forKey: .showRepeatOptions)
        try values.encode(customRepeatCount, forKey: .customRepeatCount)
        try values.encode(repeatUnit, forKey: .repeatUnit)
        try values.encode(repeatUntilOption, forKey: .repeatUntilOption)
        try values.encode(repeatUntilCount, forKey: .repeatUntilCount)
        try values.encode(repeatUntil, forKey: .repeatUntil)
        try values.encode(CalendarDay(repeatUntil), forKey: .calendarRepeatUntil)
    }
}
