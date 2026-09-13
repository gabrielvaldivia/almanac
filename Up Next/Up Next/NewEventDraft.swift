import SwiftUI

/// Shared defaults and event construction for quick entry and the full form.
struct NewEventDraft {
    var title: String
    var dateOptions: DateOptions
    var categoryOptions: CategoryOptions

    init(title: String, date: Date, endDate: Date? = nil, category: String?, appData: AppData,
         recurrence: ParsedEventRecurrence? = nil) {
        self.title = title
        let categoryName = category ?? (appData.defaultCategory.isEmpty ? nil : appData.defaultCategory)
        let selected = appData.categories.first { $0.name == categoryName }
        categoryOptions = CategoryOptions(selectedCategory: selected?.name,
                                          selectedColor: CodableColor(color: selected?.color ?? .blue))
        dateOptions = DateOptions(
            date: date, endDate: endDate ?? date, showEndDate: endDate != nil,
            repeatOption: selected?.repeatOption ?? .never,
            repeatUntil: selected?.repeatUntil ?? date,
            repeatUntilOption: selected?.repeatUntilOption ?? .indefinitely,
            repeatUntilCount: selected?.repeatUntilCount ?? 1,
            showRepeatOptions: (selected?.repeatOption ?? .never) != .never,
            repeatUnit: selected?.repeatUnit ?? "Days", customRepeatCount: selected?.customRepeatCount ?? 1)
        if let recurrence {
            dateOptions.repeatOption = recurrence.option
            dateOptions.customRepeatCount = recurrence.interval
            dateOptions.repeatUnit = recurrence.unit
            dateOptions.showRepeatOptions = true
            dateOptions.repeatUntilOption = recurrence.until == nil ? .indefinitely : .onDate
            dateOptions.repeatUntil = recurrence.until ?? date
            dateOptions.repeatUntilCount = 1
        }
    }

    static func events(title: String, dates: DateOptions, category: CategoryOptions, calendar: Calendar = .current) -> [Event] {
        let repeatUntil: Date?
        switch dates.repeatUntilOption {
        case .indefinitely:
            repeatUntil = nil
        case .after:
            repeatUntil = nil
        case .onDate:
            repeatUntil = dates.repeatUntil
        }
        let event = Event(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines), date: dates.date,
            endDate: dates.showEndDate ? dates.endDate : nil, color: category.selectedColor,
            category: category.selectedCategory, repeatOption: dates.repeatOption,
            repeatUntil: repeatUntil, seriesID: dates.repeatOption == .never ? nil : UUID(),
            customRepeatCount: dates.customRepeatCount, repeatUnit: dates.repeatUnit,
            repeatUntilCount: dates.repeatUntilCount, useCustomRepeatOptions: true)
        guard !event.title.isEmpty, dates.validationMessage == nil else { return [] }
        return dates.repeatOption == .never ? [event] : Recurrence.generate(
            event, rule: RecurrenceRule(event: event, end: dates.repeatUntilOption, calendar: calendar),
            calendar: calendar)
    }
}
