import SwiftUI

/// Shared defaults and event construction for quick entry and the full form.
struct NewEventDraft {
    var title: String
    var dateOptions: DateOptions
    var categoryOptions: CategoryOptions
    var usesCustomRepeat = false
    var requiresScheduleReview = false

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
            usesCustomRepeat = true
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

/// Explicit chip choices take precedence over live parsing and category defaults.
struct QuickEventOverrides {
    var date: Date?
    // nil follows parsing/defaults; an empty name explicitly means no category.
    var categoryName: String?
    var repeatOptions: DateOptions?

    func resolve(_ input: String, category: String?, appData: AppData,
                 now: Date = Date(), calendar: Calendar = .current) -> NewEventDraft {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var taggedCategory: String?
        for name in appData.categories.map(\.name).sorted(by: { $0.count > $1.count }) {
            let pattern = #"(?<!\S)[#]"# + NSRegularExpression.escapedPattern(for: name) + #"(?=\s|$)"#
            if let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                taggedCategory = name
                text.removeSubrange(range)
                text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        let parsed = QuickEventParser.parse(text, now: now, calendar: calendar)
        let title = parsed?.title ?? text
        var draft = NewEventDraft(
            title: title, date: date ?? parsed?.date ?? calendar.startOfDay(for: now),
            category: categoryName ?? taggedCategory ?? category, appData: appData,
            recurrence: parsed?.recurrence ?? QuickEventParser.inferredRecurrence(for: title))
        // Keep incomplete/invalid scheduling input in the manual review flow;
        // a plain title can use the default date displayed by the composer.
        let scheduleHint = #"(?:^|\s)\d{1,4}[-/]\d*|\b(?:every|until|through|starting)\b|\b(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+\d"#
        draft.requiresScheduleReview = parsed == nil && text.range(
            of: scheduleHint, options: [.regularExpression, .caseInsensitive]) != nil
        if let repeatOptions {
            draft.dateOptions.repeatOption = repeatOptions.repeatOption
            draft.dateOptions.customRepeatCount = repeatOptions.customRepeatCount
            draft.dateOptions.repeatUnit = repeatOptions.repeatUnit
            draft.dateOptions.repeatUntilOption = repeatOptions.repeatUntilOption
            draft.dateOptions.repeatUntilCount = repeatOptions.repeatUntilCount
            draft.dateOptions.repeatUntil = repeatOptions.repeatUntil
            draft.dateOptions.showRepeatOptions = repeatOptions.repeatOption != .never
            draft.usesCustomRepeat = true
        }
        return draft
    }
}
