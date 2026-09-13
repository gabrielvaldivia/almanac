import XCTest
@testable import Up_Next

final class QuickEventTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func parse(_ text: String, now: Date? = nil) -> ParsedEventInput? {
        QuickEventParser.parse(text, now: now ?? date(2026, 9, 13, hour: 14), calendar: calendar)
    }

    func testRequestedExampleAndTitlePreservation() {
        XCTAssertEqual(parse("Dune 12/18"), ParsedEventInput(title: "Dune", date: date(2026, 12, 18)))
        XCTAssertEqual(parse("  🎬 Dune: Part 2 on 12/18  "),
                       ParsedEventInput(title: "🎬 Dune: Part 2", date: date(2026, 12, 18)))
    }

    func testMissingYearUsesNextOccurrenceButIncludesToday() {
        XCTAssertEqual(parse("Dune 1/2")?.date, date(2027, 1, 2))
        XCTAssertEqual(parse("Dune 9/13")?.date, date(2026, 9, 13))
        XCTAssertEqual(parse("Dune Dec 18", now: date(2026, 12, 19))?.date, date(2027, 12, 18))
    }

    func testExplicitYearIsRespectedEvenInThePast() {
        for input in ["Dune 12/18/25", "Dune 12/18/2025", "Dune 2025-12-18", "Dune December 18, 2025"] {
            XCTAssertEqual(parse(input)?.date, date(2025, 12, 18), input)
        }
    }

    func testNamedMonthsAndOrdinals() {
        for input in ["Dune Dec 18", "Dune December 18th", "Dune 18 December", "Dune 18th Dec."] {
            XCTAssertEqual(parse(input), ParsedEventInput(title: "Dune", date: date(2026, 12, 18)), input)
        }
    }

    func testRelativeDatesAndWeekdays() {
        XCTAssertEqual(parse("Dinner tomorrow")?.date, date(2026, 9, 14))
        XCTAssertEqual(parse("Dinner TODAY")?.date, date(2026, 9, 13))
        XCTAssertEqual(parse("Dinner tonight")?.date, date(2026, 9, 13))
        XCTAssertEqual(parse("Dinner Friday")?.date, date(2026, 9, 18))
        XCTAssertEqual(parse("Dinner next Sunday")?.date, date(2026, 9, 20))
        XCTAssertEqual(parse("Dinner in 2 weeks")?.date, date(2026, 9, 27))
        XCTAssertEqual(parse("Dinner in 3 days")?.date, date(2026, 9, 16))
    }

    func testTomorrowAcrossDaylightSavingAndNewYear() {
        XCTAssertEqual(parse("Dinner tomorrow", now: date(2026, 3, 8, hour: 1))?.date, date(2026, 3, 9))
        XCTAssertEqual(parse("Dinner tomorrow", now: date(2026, 12, 31, hour: 23))?.date, date(2027, 1, 1))
    }

    func testLeapDaysAndImpossibleDates() {
        XCTAssertEqual(parse("Leap day 2/29")?.date, date(2028, 2, 29))
        for input in ["Dune 2/30", "Dune 2/29/2027", "Dune 13/18", "Dune 4/31", "Dune 0/1", "Dune 12/0"] {
            XCTAssertNil(parse(input), input)
        }
    }

    func testIncompleteInputDoesNotCreateAnEvent() {
        for input in ["", "   ", "12/18", "tomorrow", "Dune", "Dune 2", "Dune 12/", "Dune 12/18/", "Dune 12/18 at 7pm"] {
            XCTAssertNil(parse(input), input)
        }
    }

    func testEveryOtherSaturdayUntilDate() {
        let input = parse("Event every other saturday until December 15")
        XCTAssertEqual(input?.title, "Event")
        XCTAssertEqual(input?.date, date(2026, 9, 19))
        XCTAssertEqual(input?.recurrence, ParsedEventRecurrence(option: .custom, interval: 2,
                                                               unit: "Weeks", until: date(2026, 12, 15)))
        XCTAssertEqual(parse("Event every other Saturday", now: date(2026, 9, 19))?.date, date(2026, 9, 19))
    }

    func testRepeatCadencesAndExplicitStartingDates() {
        for (phrase, option, interval, unit) in [
            ("daily", RepeatOption.daily, 1, "Days"),
            ("every week", .weekly, 1, "Weeks"),
            ("monthly", .monthly, 1, "Months"),
            ("annually", .yearly, 1, "Years"),
            ("every other month", .custom, 2, "Months"),
            ("every three days", .custom, 3, "Days"),
            ("every 2 weeks", .custom, 2, "Weeks"),
            ("every two Saturdays", .custom, 2, "Weeks")
        ] {
            let recurrence = parse("Event \(phrase)")?.recurrence
            XCTAssertEqual(recurrence?.option, option, phrase)
            XCTAssertEqual(recurrence?.interval, interval, phrase)
            XCTAssertEqual(recurrence?.unit, unit, phrase)
        }
        XCTAssertEqual(parse("Event 10/1 every 2 weeks")?.date, date(2026, 10, 1))
        XCTAssertEqual(parse("Event every other Saturday starting 10/1 until 12/15")?.date, date(2026, 10, 3))
        XCTAssertEqual(parse("Event daily from tomorrow through 12/15")?.date, date(2026, 9, 14))
    }

    func testIncompleteOrInvalidRecurrenceNeverFallsBackToUntilDate() {
        for input in ["Event every other Saturday until", "Event every other Saturday until someday 12/15",
                      "Event every 0 days until 12/15", "Event every 1001 days until 12/15",
                      "Event every Monday and Wednesday until 12/15", "Event every month until 2/30",
                      "Event every Saturday until 9/1/2026", "every Saturday until 12/15",
                      "Event daily starting unknown until 12/15", "Event 10/1 daily starting 11/1"] {
            XCTAssertNil(parse(input), input)
        }
        XCTAssertEqual(parse("The Daily Show 12/18")?.title, "The Daily Show")
        XCTAssertNil(parse("The Daily Show 12/18")?.recurrence)
    }

    func testBirthdaysAndAnniversariesInferYearlyRepeat() {
        for input in ["Brian's birthday 12/18", "Brian’s Birthday December 18", "Our anniversary 12/18"] {
            XCTAssertEqual(parse(input)?.recurrence?.option, .yearly, input)
        }
        XCTAssertNil(parse("Brian's birthday")) // A birthday name doesn't supply its date.
        XCTAssertEqual(QuickEventParser.inferredRecurrence(for: "Brian's birthday")?.option, .yearly)
        XCTAssertNil(parse("Buy a birthday gift tomorrow")?.recurrence)
        XCTAssertNil(parse("Brian's birthday party tomorrow")?.recurrence)
        XCTAssertEqual(parse("Brian's birthday every month")?.recurrence?.option, .monthly)
    }

    func testParsedRepeatOverridesCategoryAndSurvivesFormPrefill() throws {
        let input = try XCTUnwrap(parse("Event every other Saturday until December 15"))
        let appData = AppData()
        let draft = NewEventDraft(title: input.title, date: input.date, category: "Birthdays", appData: appData,
                                  recurrence: input.recurrence)
        XCTAssertEqual(draft.dateOptions.repeatOption, .custom)
        XCTAssertEqual(draft.dateOptions.customRepeatCount, 2)
        XCTAssertEqual(draft.dateOptions.repeatUnit, "Weeks")
        XCTAssertEqual(draft.dateOptions.repeatUntilOption, .onDate)
        XCTAssertEqual(draft.dateOptions.repeatUntil, date(2026, 12, 15))
        XCTAssertTrue(draft.dateOptions.showRepeatOptions)
        XCTAssertFalse(draft.dateOptions.showEndDate)
        XCTAssertNil(draft.dateOptions.validationMessage)

        let birthdayDraft = NewEventDraft(title: "Brian's birthday", date: date(2026, 12, 18),
                                          category: "Work", appData: appData,
                                          recurrence: QuickEventParser.inferredRecurrence(for: "Brian's birthday"))
        XCTAssertEqual(birthdayDraft.dateOptions.repeatOption, .yearly)
        XCTAssertEqual(birthdayDraft.dateOptions.repeatUntilOption, .indefinitely)
    }

    func testRequestedSeriesSavesOnlyAlternateSaturdaysThroughInclusiveEnd() throws {
        let input = try XCTUnwrap(parse("Event every other Saturday until December 15"))
        let draft = NewEventDraft(title: input.title, date: input.date, category: nil, appData: AppData(),
                                  recurrence: input.recurrence)
        let events = NewEventDraft.events(title: draft.title, dates: draft.dateOptions, category: draft.categoryOptions)
        XCTAssertEqual(events.count, 7)
        XCTAssertEqual(events.first?.date, date(2026, 9, 19))
        XCTAssertEqual(events.last?.date, date(2026, 12, 12))
        XCTAssertEqual(Set(events.compactMap(\.seriesID)).count, 1)
        for event in events {
            XCTAssertEqual(calendar.component(.weekday, from: event.date), 7)
            XCTAssertEqual(event.repeatOption, .custom)
            XCTAssertEqual(event.customRepeatCount, 2)
            XCTAssertEqual(event.repeatUntil, date(2026, 12, 15))
        }
        for pair in zip(events, events.dropFirst()) {
            XCTAssertEqual(calendar.dateComponents([.day], from: pair.0.date, to: pair.1.date).day, 14)
        }

        let inclusive = try XCTUnwrap(parse("Event every other Saturday until December 12"))
        let inclusiveDraft = NewEventDraft(title: inclusive.title, date: inclusive.date, category: nil, appData: AppData(),
                                           recurrence: inclusive.recurrence)
        XCTAssertEqual(NewEventDraft.events(title: inclusiveDraft.title, dates: inclusiveDraft.dateOptions,
                                            category: inclusiveDraft.categoryOptions).last?.date, date(2026, 12, 12))
    }

    func testDraftKeepsPrefilledTitleDatesAndCategory() {
        let appData = AppData()
        let selected = appData.categories.first
        let draft = NewEventDraft(title: "Dune", date: date(2026, 12, 18), endDate: date(2026, 12, 20),
                                  category: selected?.name, appData: appData)
        XCTAssertEqual(draft.title, "Dune")
        XCTAssertEqual(draft.dateOptions.date, date(2026, 12, 18))
        XCTAssertEqual(draft.dateOptions.endDate, date(2026, 12, 20))
        XCTAssertTrue(draft.dateOptions.showEndDate)
        XCTAssertEqual(draft.categoryOptions.selectedCategory, selected?.name)
        XCTAssertEqual(draft.dateOptions.repeatOption, selected?.repeatOption ?? .never)
    }

    func testQuickAndManualCreationPreserveEditableDetails() {
        var dates = DateOptions(date: date(2026, 12, 18), endDate: date(2026, 12, 20), showEndDate: true,
                                repeatOption: .never, repeatUntil: date(2027, 12, 18),
                                repeatUntilOption: .indefinitely, repeatUntilCount: 1,
                                showRepeatOptions: false, repeatUnit: "Days", customRepeatCount: 1)
        let category = CategoryOptions(selectedCategory: "Movies", selectedColor: CodableColor(color: .red))
        let events = NewEventDraft.events(title: " Dune ", dates: dates, category: category)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.title, "Dune")
        XCTAssertEqual(events.first?.date, dates.date)
        XCTAssertEqual(events.first?.endDate, dates.endDate)
        XCTAssertEqual(events.first?.category, "Movies")
        XCTAssertEqual(events.first?.color.red, category.selectedColor.red)
        XCTAssertNil(events.first?.seriesID)
        dates.repeatOption = .yearly
        let series = NewEventDraft.events(title: "Dune", dates: dates, category: category)
        XCTAssertGreaterThan(series.count, 1)
        XCTAssertEqual(Set(series.compactMap(\.seriesID)).count, 1)
        XCTAssertTrue(series.allSatisfy { $0.repeatOption == .yearly && $0.category == "Movies" })
        XCTAssertTrue(NewEventDraft.events(title: "  ", dates: dates, category: category).isEmpty)
    }
}
