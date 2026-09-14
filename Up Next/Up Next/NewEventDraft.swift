import SwiftUI

/// Shared defaults and event construction for quick entry and the full form.
struct NewEventDraft {
    var title: String
    var dateOptions: DateOptions
    var categoryOptions: CategoryOptions
    var usesCustomRepeat = false
    var hasCategorySelection = false
    var hasRepeatSelection = false
    var scheduleReviewMessage: String?
    var requiresScheduleReview: Bool { scheduleReviewMessage != nil }

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
    var endDate: Date?
    var hasDateOverride: Bool { date != nil }
    // nil follows parsing/defaults; an empty name explicitly means no category.
    var categoryName: String?
    var color: CodableColor?
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
        let inferredCategory = QuickEventCategoryMatcher.category(for: title, available: appData.categories.map(\.name))
        var draft = NewEventDraft(
            title: title, date: date ?? parsed?.date ?? calendar.startOfDay(for: now),
            endDate: hasDateOverride ? endDate : parsed?.endDate,
            category: categoryName ?? taggedCategory ?? inferredCategory ?? category, appData: appData,
            recurrence: parsed?.recurrence ?? QuickEventParser.inferredRecurrence(for: title))
        if let color { draft.categoryOptions.selectedColor = color }
        draft.hasCategorySelection = categoryName != nil || taggedCategory != nil || inferredCategory != nil
        draft.hasRepeatSelection = repeatOptions != nil || parsed?.recurrence != nil ||
            QuickEventParser.inferredRecurrence(for: title) != nil
        // Invalid text stays in the composer until its schedule is corrected
        // either in the text itself or through the relevant pill.
        let rangeHint = QuickEventParser.containsDateRange(text)
        let dateHint = #"(?:^|\s)\d{1,4}[-/]\d*|\b(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+\d"#
        let repeatHint = #"\b(?:every|until|through|starting)\b"#
        let dateNeedsReview = parsed == nil && date == nil && (rangeHint || text.range(
            of: dateHint, options: [.regularExpression, .caseInsensitive]) != nil)
        let repeatNeedsReview = parsed == nil && repeatOptions == nil && !rangeHint && text.range(
            of: repeatHint, options: [.regularExpression, .caseInsensitive]) != nil
        if dateNeedsReview && repeatNeedsReview {
            draft.scheduleReviewMessage = "Choose a date and repeat setting, or update the text."
        } else if dateNeedsReview {
            draft.scheduleReviewMessage = "Choose a date or update the date in the text."
        } else if repeatNeedsReview {
            draft.scheduleReviewMessage = "Choose a repeat setting or update the text."
        }
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

/// Match existing categories conservatively; explicit choices and tags are
/// resolved separately and always take precedence over these suggestions.
enum QuickEventCategoryMatcher {
    static func category(for title: String, available: [String]) -> String? {
        func matches(_ pattern: String) -> Bool {
            title.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
        func normalized(_ name: String) -> String {
            name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        let occasions: [(names: [String], pattern: String)] = [
            (["birthday", "birthdays"], #"\b(?:birthday|b[ -]?day)$"#),
            (["anniversary", "anniversaries"], #"\banniversary$"#),
            (["holiday", "holidays"], #"\b(?:holiday|christmas|thanksgiving|halloween|new year['’]?s(?: day| eve)?|easter|hanukkah|diwali)$"#)
        ]
        for occasion in occasions where matches(occasion.pattern) {
            if let name = available.first(where: { occasion.names.contains(normalized($0)) }) { return name }
        }
        let aliases: [String: String] = [
            "work": #"\b(?:meeting|conference|deadline|interview|workshop)\b"#,
            "social": #"\b(?:dinner|lunch|brunch|party|reunion)\b"#,
            "travel": #"\b(?:trip|flight|vacation)\b"#,
            "trips": #"\b(?:trip|flight|vacation)\b"#,
            "movies": #"\b(?:movie|film|cinema|premiere)\b"#,
            "music": #"\b(?:concert|gig)\b"#
        ]
        let candidates = available.filter { name in
            let key = normalized(name)
            // Occasion categories often repeat yearly. Avoid classifying errands
            // such as buying a birthday gift as the occasion itself.
            guard !occasions.contains(where: { $0.names.contains(key) }), !key.isEmpty else { return false }
            var names = [key]
            if key.hasSuffix("ies") { names.append(String(key.dropLast(3)) + "y") }
            else if key.count > 3 && key.hasSuffix("s") && !key.hasSuffix("ss") { names.append(String(key.dropLast())) }
            let namePattern = #"\b(?:"# + names.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|") + #")\b"#
            return matches(namePattern) || aliases[key].map(matches) == true
        }
        return candidates.count == 1 ? candidates.first : nil
    }
}
