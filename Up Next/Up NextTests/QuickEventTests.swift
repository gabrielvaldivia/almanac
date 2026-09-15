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

    func testCalendarSwitchesBetweenSingleDateAndRangeWithoutChangingTheStart() {
        var selection = CalendarDateSelection(start: date(2026, 9, 14, hour: 13), end: nil, calendar: calendar)
        selection.select(date(2026, 9, 18, hour: 19))
        XCTAssertEqual(selection.start, date(2026, 9, 18))
        XCTAssertNil(selection.end)
        selection.setRangeEnabled(true)
        XCTAssertEqual(selection.end, date(2026, 9, 19))
        XCTAssertEqual(selection.endpoint, .end)
        selection.select(date(2026, 9, 21, hour: 15))
        XCTAssertEqual(selection.start, date(2026, 9, 18))
        XCTAssertEqual(selection.end, date(2026, 9, 21))
        XCTAssertTrue(selection.contains(date(2026, 9, 20)))
        XCTAssertFalse(selection.contains(date(2026, 9, 22)))
        selection.setRangeEnabled(false)
        XCTAssertEqual(selection.start, date(2026, 9, 18))
        XCTAssertNil(selection.end)
        XCTAssertFalse(selection.contains(date(2026, 9, 20)))
        XCTAssertEqual(selection.endpoint, .start)
        selection.select(date(2026, 9, 30))
        selection.setRangeEnabled(true)
        XCTAssertEqual(selection.end, date(2026, 10, 1), "Re-adding uses the day after the current start")
    }

    func testCalendarDefaultEndUsesTheNextCalendarDayAcrossBoundaries() {
        for (start, expectedEnd) in [
            (date(2026, 3, 8), date(2026, 3, 9)),
            (date(2026, 11, 1), date(2026, 11, 2)),
            (date(2026, 12, 31), date(2027, 1, 1)),
            (date(2024, 2, 28), date(2024, 2, 29)),
            (date(2024, 2, 29), date(2024, 3, 1))
        ] {
            var selection = CalendarDateSelection(start: start, end: nil, calendar: calendar)
            selection.setRangeEnabled(true)
            XCTAssertEqual(selection.end, expectedEnd)
            XCTAssertEqual(selection.start, start)
            XCTAssertEqual(selection.endpoint, .end)
        }
    }

    func testCalendarKeepsRangesOrderedWhenEitherEndpointMoves() {
        var selection = CalendarDateSelection(start: date(2026, 9, 18), end: date(2026, 9, 21), calendar: calendar)
        selection.select(date(2026, 9, 24))
        XCTAssertEqual(selection.start, date(2026, 9, 24))
        XCTAssertEqual(selection.end, date(2026, 9, 24))
        XCTAssertEqual(selection.endpoint, .start)
        selection.endpoint = .end
        selection.select(date(2026, 9, 20))
        XCTAssertEqual(selection.start, date(2026, 9, 20))
        XCTAssertEqual(selection.end, date(2026, 9, 20))
        selection.select(date(2026, 9, 23))
        XCTAssertEqual(selection.start, date(2026, 9, 20))
        XCTAssertEqual(selection.end, date(2026, 9, 23))
        XCTAssertEqual(selection.endpoint, .end)
        selection.select(date(2026, 9, 25))
        XCTAssertEqual(selection.start, date(2026, 9, 20))
        XCTAssertEqual(selection.end, date(2026, 9, 25), "Calendar taps keep editing the selected segment")
        selection.endpoint = .start
        selection.select(date(2026, 9, 19))
        XCTAssertEqual(selection.start, date(2026, 9, 19))
        XCTAssertEqual(selection.end, date(2026, 9, 25))
        XCTAssertEqual(selection.endpoint, .start)
    }

    func testCalendarRangeSpansYearAndDaylightSavingBoundaries() {
        for (start, end, inside) in [
            (date(2026, 12, 30), date(2027, 1, 2), date(2027, 1, 1)),
            (date(2026, 3, 7), date(2026, 3, 9), date(2026, 3, 8, hour: 23))
        ] {
            var selection = CalendarDateSelection(start: start, end: nil, calendar: calendar)
            selection.setRangeEnabled(true)
            selection.select(end)
            XCTAssertEqual(selection.start, start)
            XCTAssertEqual(selection.end, end)
            XCTAssertTrue(selection.contains(inside))
        }
    }

    func testCalendarGridRespectsFirstWeekdayLeapDayAndLocalMidnight() {
        var mondayFirst = calendar
        mondayFirst.firstWeekday = 2
        let selection = CalendarDateSelection(start: date(2024, 2, 1), end: nil, calendar: mondayFirst)
        let february = selection.monthDays(containing: date(2024, 2, 15))
        XCTAssertEqual(february.prefix(while: { $0 == nil }).count, 3)
        XCTAssertEqual(february.compactMap { $0 }.count, 29)
        XCTAssertEqual(february.compactMap { $0 }.last, date(2024, 2, 29))
        let march = selection.monthDays(containing: date(2026, 3, 8)).compactMap { $0 }
        XCTAssertEqual(march.count, 31)
        XCTAssertTrue(march.allSatisfy { calendar.component(.hour, from: $0) == 0 })
        XCTAssertEqual(march[8], date(2026, 3, 9))
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

    func testThisAndNextWeekdayUseTheSpecifiedCalendarWeek() {
        for firstWeekday in [1, 2] {
            var calendar = calendar
            calendar.firstWeekday = firstWeekday
            // The same Monday belongs to Sep 13–19 or Sep 14–20, depending
            // on the user's first weekday. Check every day within both weeks.
            let weekStart = firstWeekday == 1 ? 13 : 14
            let weekdayNames = firstWeekday == 1
                ? ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                : ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            for currentDay in weekStart..<(weekStart + 7) {
                for (index, weekday) in weekdayNames.enumerated() {
                    for (prefix, targetDay) in [("this", weekStart + index), ("next", weekStart + index + 7),
                                                ("this next", weekStart + index + 7)] {
                        let input = "Dinner \(prefix) \(weekday)"
                        XCTAssertEqual(QuickEventParser.parse(input, now: date(2026, 9, currentDay, hour: 14), calendar: calendar),
                                       ParsedEventInput(title: "Dinner", date: date(2026, 9, targetDay)), input)
                    }
                }
            }
        }
    }

    func testRequestedNextFridayPhraseUpdatesTheComposerAndSavedDate() {
        let now = date(2026, 9, 14, hour: 9)
        let title = "Brian and Jeff upstate"
        let data = AppData()
        for phrase in ["next friday", "this next Friday", "NEXT FRI"] {
            let draft = QuickEventOverrides().resolve("\(title) \(phrase)", category: nil, appData: data,
                                                      now: now, calendar: calendar)
            XCTAssertEqual(draft.title, title)
            XCTAssertEqual(draft.dateOptions.date, date(2026, 9, 25))
            XCTAssertFalse(draft.requiresScheduleReview)
            let saved = NewEventDraft.events(title: draft.title, dates: draft.dateOptions,
                                              category: draft.categoryOptions, calendar: calendar)
            XCTAssertEqual(saved.first?.date, date(2026, 9, 25))
        }
        XCTAssertEqual(parse("\(title) this Friday", now: now), ParsedEventInput(title: title, date: date(2026, 9, 18)))
        XCTAssertEqual(parse("\(title) Friday", now: now), ParsedEventInput(title: title, date: date(2026, 9, 18)))
    }

    func testQualifiedWeekdaysAndRangesCrossMonthYearAndDaylightSavingBoundaries() {
        XCTAssertEqual(parse("Dinner next Friday", now: date(2026, 12, 30))?.date, date(2027, 1, 8))
        XCTAssertEqual(parse("Dinner this Friday", now: date(2026, 12, 30))?.date, date(2027, 1, 1))
        XCTAssertEqual(parse("Dinner next Friday", now: date(2026, 3, 4))?.date, date(2026, 3, 13))
        XCTAssertEqual(parse("Dinner next Friday", now: date(2026, 10, 28))?.date, date(2026, 11, 6))
        let now = date(2026, 9, 14)
        for phrase in ["next Friday to Monday", "from this next Friday through Monday"] {
            XCTAssertEqual(parse("Trip \(phrase)", now: now),
                           ParsedEventInput(title: "Trip", date: date(2026, 9, 25), endDate: date(2026, 9, 28)))
        }
        XCTAssertEqual(parse("Trip this Friday to next Friday", now: now),
                       ParsedEventInput(title: "Trip", date: date(2026, 9, 18), endDate: date(2026, 9, 25)))
        XCTAssertNil(parse("Trip next Friday to this Friday", now: now), "Explicit weeks must not silently roll forward")
        XCTAssertNil(parse("Trip this Friday to", now: now))
    }

    func testTomorrowAcrossDaylightSavingAndNewYear() {
        XCTAssertEqual(parse("Dinner tomorrow", now: date(2026, 3, 8, hour: 1))?.date, date(2026, 3, 9))
        XCTAssertEqual(parse("Dinner tomorrow", now: date(2026, 12, 31, hour: 23))?.date, date(2027, 1, 1))
    }

    func testDateRangesKeepBothEndpointsAndRemoveTheWholePhraseFromTitle() {
        for phrase in ["Friday to Monday", "from Friday through Monday", "Friday–Monday",
                       "9/18-9/21", "Sep 18–21", "September 18th until September 21st",
                       "18 September to 21 September", "2026-09-18 to 2026-09-21"] {
            XCTAssertEqual(parse("Tampa \(phrase)"),
                           ParsedEventInput(title: "Tampa", date: date(2026, 9, 18), endDate: date(2026, 9, 21)), phrase)
        }
        XCTAssertEqual(parse("Trip today to tomorrow")?.endDate, date(2026, 9, 14))
        XCTAssertEqual(parse("Trip 12/30 to 1/2")?.endDate, date(2027, 1, 2))
        let dst = parse("Trip Saturday to Monday", now: date(2026, 3, 6))
        XCTAssertEqual(dst?.date, date(2026, 3, 7))
        XCTAssertEqual(dst?.endDate, date(2026, 3, 9))
    }

    func testInvalidOrIncompleteRangesNeverFallBackToTheLastDate() {
        let data = AppData()
        for text in ["Trip Friday to", "Trip Friday to someday Monday", "Trip 2/30 to Monday",
                     "Trip Friday to February 30", "Trip 9/18/2026 to 9/17/2026", "Trip Sep 18–17"] {
            XCTAssertNil(parse(text), text)
            XCTAssertTrue(QuickEventOverrides().resolve(text, category: nil, appData: data,
                                                        now: date(2026, 9, 13), calendar: calendar).requiresScheduleReview, text)
        }
        XCTAssertEqual(parse("Road to Tomorrow")?.title, "Road to")
    }

    func testComposerRangeSurvivesSubmissionAndManualDateOverridesCanRemoveIt() {
        let data = AppData()
        var overrides = QuickEventOverrides()
        let draft = overrides.resolve("Tampa Friday to Monday", category: nil, appData: data,
                                       now: date(2026, 9, 13), calendar: calendar)
        XCTAssertTrue(draft.dateOptions.showEndDate)
        XCTAssertEqual(draft.dateOptions.endDate, date(2026, 9, 21))
        let events = NewEventDraft.events(title: draft.title, dates: draft.dateOptions,
                                          category: draft.categoryOptions, calendar: calendar)
        XCTAssertEqual(events.first?.title, "Tampa")
        XCTAssertEqual(events.first?.date, date(2026, 9, 18))
        XCTAssertEqual(events.first?.endDate, date(2026, 9, 21))
        overrides.date = date(2026, 10, 1)
        XCTAssertFalse(overrides.resolve("Tampa Friday to Monday", category: nil, appData: data).dateOptions.showEndDate)
        overrides.endDate = date(2026, 10, 3)
        XCTAssertEqual(overrides.resolve("Tampa Friday to Monday", category: nil, appData: data).dateOptions.endDate, date(2026, 10, 3))
        let recurring = parse("Trip Friday to Monday every Saturday")
        XCTAssertEqual(recurring?.date, date(2026, 9, 19))
        XCTAssertEqual(recurring?.endDate, date(2026, 9, 22), "Aligning recurrence must preserve the span's duration")
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
        let events = NewEventDraft.events(title: draft.title, dates: draft.dateOptions, category: draft.categoryOptions, calendar: calendar)
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
                                            category: inclusiveDraft.categoryOptions, calendar: calendar).last?.date, date(2026, 12, 12))
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

    func testComposerShowsDefaultsAndParsesDateCategoryAndRepeat() {
        let data = AppData()
        let originalDefault = data.defaultCategory
        defer { data.defaultCategory = originalDefault }
        data.defaultCategory = "Work"
        let overrides = QuickEventOverrides()
        let empty = overrides.resolve("", category: nil, appData: data, now: date(2026, 9, 13), calendar: calendar)
        XCTAssertEqual(empty.dateOptions.date, date(2026, 9, 13))
        XCTAssertEqual(empty.categoryOptions.selectedCategory, "Work")
        XCTAssertEqual(empty.dateOptions.repeatOption, .never)
        XCTAssertFalse(empty.hasCategorySelection)
        XCTAssertFalse(empty.hasRepeatSelection)
        let parsed = overrides.resolve("Dinner #Social tomorrow", category: nil, appData: data,
                                       now: date(2026, 9, 13), calendar: calendar)
        XCTAssertEqual(parsed.title, "Dinner")
        XCTAssertEqual(parsed.dateOptions.date, date(2026, 9, 14))
        XCTAssertEqual(parsed.categoryOptions.selectedCategory, "Social")
        XCTAssertTrue(parsed.hasCategorySelection)
        XCTAssertFalse(parsed.hasRepeatSelection)
        let recurring = overrides.resolve("Dinner every other Saturday until December 15", category: nil,
                                          appData: data, now: date(2026, 9, 13), calendar: calendar)
        XCTAssertEqual(recurring.dateOptions.repeatOption, .custom)
        XCTAssertEqual(recurring.dateOptions.customRepeatCount, 2)
        XCTAssertEqual(recurring.dateOptions.repeatUntil, date(2026, 12, 15))
        XCTAssertTrue(recurring.hasRepeatSelection)
    }

    func testComposerManualChoicesOverrideTextAndExplicitNoneOverridesDefault() {
        let data = AppData()
        let originalDefault = data.defaultCategory
        defer { data.defaultCategory = originalDefault }
        data.defaultCategory = "Birthdays"
        var overrides = QuickEventOverrides(date: date(2026, 10, 1), categoryName: "")
        var repeatOptions = overrides.resolve("Dinner", category: nil, appData: data).dateOptions
        repeatOptions.repeatOption = .never
        overrides.repeatOptions = repeatOptions
        let draft = overrides.resolve("Dinner #Social every week", category: nil, appData: data,
                                      now: date(2026, 9, 13), calendar: calendar)
        XCTAssertEqual(draft.title, "Dinner")
        XCTAssertEqual(draft.dateOptions.date, date(2026, 10, 1))
        XCTAssertNil(draft.categoryOptions.selectedCategory)
        XCTAssertEqual(draft.dateOptions.repeatOption, .never)
        XCTAssertTrue(draft.hasCategorySelection)
        XCTAssertTrue(draft.hasRepeatSelection)
        let events = NewEventDraft.events(title: draft.title, dates: draft.dateOptions,
                                          category: draft.categoryOptions, calendar: calendar)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.date, date(2026, 10, 1))
        XCTAssertNil(events.first?.category)
    }

    func testBirthdayKeywordSelectsCategoryColorAndRepeatAndSavesThem() throws {
        let data = AppData()
        let draft = QuickEventOverrides().resolve("Alex’s birthday 9/20", category: nil, appData: data,
                                                  now: date(2026, 9, 13), calendar: calendar)
        let birthdays = try XCTUnwrap(data.categories.first { $0.name == "Birthdays" })
        XCTAssertEqual(draft.title, "Alex’s birthday")
        XCTAssertEqual(draft.dateOptions.date, date(2026, 9, 20))
        XCTAssertEqual(draft.categoryOptions.selectedCategory, birthdays.name)
        XCTAssertEqual(draft.categoryOptions.selectedColor, CodableColor(color: birthdays.color))
        XCTAssertTrue(draft.hasCategorySelection)
        XCTAssertEqual(draft.dateOptions.repeatOption, .yearly)
        XCTAssertTrue(draft.hasRepeatSelection)
        let events = NewEventDraft.events(title: draft.title, dates: draft.dateOptions,
                                          category: draft.categoryOptions, calendar: calendar)
        XCTAssertFalse(events.isEmpty)
        XCTAssertTrue(events.allSatisfy { $0.category == birthdays.name && $0.color == draft.categoryOptions.selectedColor })
    }

    func testCategoryKeywordsUseOnlyExistingCategoriesAndAvoidAmbiguousMatches() {
        let categories = ["Work", "Social", "Birthdays", "Holidays", "Anniversaries", "Movies", "Trips"]
        for (title, expected) in [
            ("Alex’s BIRTHDAY", "Birthdays"), ("Alex's bday", "Birthdays"),
            ("Alex's b-day", "Birthdays"), ("Our anniversary", "Anniversaries"),
            ("Christmas", "Holidays"), ("Team meeting", "Work"),
            ("Dinner with Alex", "Social"), ("Movie with Alex", "Movies"),
            ("Flight to Tampa", "Trips")
        ] {
            XCTAssertEqual(QuickEventCategoryMatcher.category(for: title, available: categories), expected, title)
        }
        for title in ["Buy a birthday gift", "Alex’s unbirthday", "Socialize", "Work dinner", "Dune"] {
            XCTAssertNil(QuickEventCategoryMatcher.category(for: title, available: categories), title)
        }
        XCTAssertNil(QuickEventCategoryMatcher.category(for: "Alex’s birthday", available: ["Work", "Social"]))
        XCTAssertEqual(QuickEventCategoryMatcher.category(for: "Dentist appointment", available: ["Appointments"]), "Appointments")
        XCTAssertEqual(QuickEventCategoryMatcher.category(for: "Alex’s birthday", available: ["Birthday"]), "Birthday")
    }

    func testCustomCategoryKeywordsNormalizeAndMatchWholeWordsAndPhrases() {
        let keywords = CategoryKeywords.parse(" book club, READING\nbook   club, café, C++,, \n")
        XCTAssertEqual(keywords, ["book club", "READING", "café", "C++"])
        let rules = [(name: "Literature", keywords: keywords)]
        for title in ["BOOK CLUB with Alex", "Evening reading", "Meet at the cafe", "C++ class", "Book\nclub"] {
            XCTAssertEqual(QuickEventCategoryMatcher.category(for: title, available: ["Literature"], keywordRules: rules), "Literature", title)
        }
        for title in ["Proofreading", "Book clubhouse", "Cafeteria", "C class", "Unrelated"] {
            XCTAssertNil(QuickEventCategoryMatcher.category(for: title, available: ["Literature"], keywordRules: rules), title)
        }
        XCTAssertNil(QuickEventCategoryMatcher.category(for: "Reading", available: [], keywordRules: rules))
        let conflict = rules + [(name: "Leisure", keywords: ["reading"])]
        XCTAssertNil(QuickEventCategoryMatcher.category(for: "Reading", available: ["Literature", "Leisure"], keywordRules: conflict))
    }

    func testCustomKeywordsSelectSavedCategoryDetailsAndRespectTagsAndManualOverrides() throws {
        let data = AppData()
        let original = data.categories
        defer { data.categories = original }
        data.categories.append(("Books", .orange, .monthly, 1, "Months", .indefinitely, 1, Date(), ["book club", "dinner"]))
        let input = "Book club tomorrow"
        let draft = QuickEventOverrides().resolve(input, category: "Work", appData: data,
                                                  now: date(2026, 9, 13), calendar: calendar)
        XCTAssertEqual(draft.title, "Book club")
        XCTAssertEqual(draft.categoryOptions.selectedCategory, "Books")
        XCTAssertEqual(draft.categoryOptions.selectedColor, CodableColor(color: .orange))
        XCTAssertEqual(draft.dateOptions.repeatOption, .monthly)
        XCTAssertTrue(draft.hasCategorySelection)
        let saved = NewEventDraft.events(title: draft.title, dates: draft.dateOptions,
                                          category: draft.categoryOptions, calendar: calendar)
        XCTAssertEqual(saved.first?.category, "Books")
        XCTAssertEqual(saved.first?.color, CodableColor(color: .orange))
        XCTAssertEqual(QuickEventOverrides().resolve("Dinner tomorrow", category: nil, appData: data).categoryOptions.selectedCategory, "Books",
                       "Custom rules take priority over built-in Social suggestions")
        XCTAssertEqual(QuickEventOverrides().resolve("Book club #Work tomorrow", category: nil, appData: data).categoryOptions.selectedCategory, "Work")
        XCTAssertEqual(QuickEventOverrides(categoryName: "Work").resolve(input, category: nil, appData: data).categoryOptions.selectedCategory, "Work")
        XCTAssertNil(QuickEventOverrides(categoryName: "").resolve(input, category: nil, appData: data).categoryOptions.selectedCategory)
        data.loadCategories()
        XCTAssertEqual(data.categories.last?.keywords, ["book club", "dinner"])
        let index = try XCTUnwrap(data.categories.firstIndex { $0.name == "Books" })
        data.categories[index].name = "Bookworms"
        XCTAssertEqual(QuickEventOverrides().resolve(input, category: nil, appData: data).categoryOptions.selectedCategory, "Bookworms")
        data.categories[index].keywords = []
        data.loadCategories()
        XCTAssertEqual(data.categories[index].keywords, [])
        XCTAssertEqual(QuickEventOverrides().resolve(input, category: "Work", appData: data).categoryOptions.selectedCategory, "Work")
    }

    func testCategoryInferenceUpdatesWithTextAndFallsBackToSelectedFilter() {
        let data = AppData()
        let overrides = QuickEventOverrides()
        let birthday = overrides.resolve("Alex’s birthday", category: "Work", appData: data)
        XCTAssertEqual(birthday.categoryOptions.selectedCategory, "Birthdays")
        XCTAssertTrue(birthday.hasCategorySelection)
        let dinner = overrides.resolve("Dinner with Alex tomorrow", category: "Work", appData: data)
        XCTAssertEqual(dinner.categoryOptions.selectedCategory, "Social")
        let cleared = overrides.resolve("Alex tomorrow", category: "Work", appData: data)
        XCTAssertEqual(cleared.categoryOptions.selectedCategory, "Work")
        XCTAssertFalse(cleared.hasCategorySelection)
        XCTAssertFalse(cleared.hasRepeatSelection)
        XCTAssertEqual(cleared.dateOptions.repeatOption, .never)
    }

    func testManualCategoryTagsAndColorOverrideKeywordSuggestions() {
        let data = AppData()
        let tagged = QuickEventOverrides().resolve("Alex’s birthday #Social 9/20", category: nil, appData: data)
        XCTAssertEqual(tagged.categoryOptions.selectedCategory, "Social")
        XCTAssertEqual(tagged.title, "Alex’s birthday")
        var overrides = QuickEventOverrides(categoryName: "Work", color: CodableColor(color: .orange))
        let manual = overrides.resolve("Alex’s birthday #Social 9/20", category: nil, appData: data)
        XCTAssertEqual(manual.categoryOptions.selectedCategory, "Work")
        XCTAssertEqual(manual.categoryOptions.selectedColor, overrides.color)
        overrides.categoryName = ""
        let none = overrides.resolve("Alex’s birthday 9/20", category: "Birthdays", appData: data)
        XCTAssertNil(none.categoryOptions.selectedCategory)
        XCTAssertTrue(none.hasCategorySelection)
        overrides.categoryName = nil
        let inferredAgain = overrides.resolve("Alex’s birthday 9/20", category: nil, appData: data)
        XCTAssertEqual(inferredAgain.categoryOptions.selectedCategory, "Birthdays")
        XCTAssertEqual(inferredAgain.categoryOptions.selectedColor, overrides.color)
    }

    func testComposerPreservesCustomRepeatCountAndResetsToParsedValues() {
        let data = AppData()
        var overrides = QuickEventOverrides()
        var options = overrides.resolve("Dinner weekly", category: nil, appData: data).dateOptions
        options.repeatUntilOption = .after
        options.repeatUntilCount = 3
        overrides.repeatOptions = options
        let draft = overrides.resolve("Dinner tomorrow", category: nil, appData: data,
                                      now: date(2026, 9, 13), calendar: calendar)
        XCTAssertEqual(draft.dateOptions.repeatUntilCount, 3)
        XCTAssertEqual(draft.dateOptions.repeatUntilOption, .after)
        XCTAssertEqual(NewEventDraft.events(title: draft.title, dates: draft.dateOptions,
                                            category: draft.categoryOptions, calendar: calendar).count, 3)
        overrides.repeatOptions = nil
        XCTAssertEqual(overrides.resolve("Dinner tomorrow", category: nil, appData: data).dateOptions.repeatOption, .never)
    }

    func testComposerColorChoiceSurvivesParsingAndSavingAndCanFollowCategoryAgain() {
        let data = AppData()
        let chosen = CodableColor(color: .orange)
        var overrides = QuickEventOverrides(color: chosen)
        for category in ["Work", "Social"] {
            let draft = overrides.resolve("Dinner #\(category) tomorrow", category: nil, appData: data,
                                          now: date(2026, 9, 13), calendar: calendar)
            XCTAssertEqual(draft.categoryOptions.selectedCategory, category)
            XCTAssertEqual(draft.categoryOptions.selectedColor, chosen)
            let events = NewEventDraft.events(title: draft.title, dates: draft.dateOptions,
                                              category: draft.categoryOptions, calendar: calendar)
            XCTAssertEqual(events.first?.color, chosen)
        }
        overrides.color = nil
        let draft = overrides.resolve("Dinner #Work tomorrow", category: nil, appData: data)
        XCTAssertEqual(draft.categoryOptions.selectedColor,
                       CodableColor(color: data.categories.first { $0.name == "Work" }!.color))
    }

    func testComposerReviewsInvalidSchedulesButAcceptsPlainTitlesWithDefaults() {
        let data = AppData()
        let overrides = QuickEventOverrides()
        for text in ["Dinner 2/30", "Dinner 12/", "Dinner every other Saturday until", "Dinner February 30"] {
            XCTAssertTrue(overrides.resolve(text, category: nil, appData: data).requiresScheduleReview, text)
        }
        XCTAssertFalse(overrides.resolve("Dinner", category: nil, appData: data).requiresScheduleReview)
        XCTAssertFalse(overrides.resolve("Dinner tomorrow", category: nil, appData: data).requiresScheduleReview)
        let correctedDate = QuickEventOverrides(date: date(2026, 9, 15))
        XCTAssertFalse(correctedDate.resolve("Dinner 2/30", category: nil, appData: data).requiresScheduleReview)
        XCTAssertFalse(correctedDate.resolve("Trip Friday to", category: nil, appData: data).requiresScheduleReview)
        let correctedRepeat = QuickEventOverrides(repeatOptions: overrides.resolve("Dinner", category: nil, appData: data).dateOptions)
        XCTAssertFalse(correctedRepeat.resolve("Dinner every", category: nil, appData: data).requiresScheduleReview)
        XCTAssertTrue(correctedRepeat.resolve("Dinner 2/30", category: nil, appData: data).requiresScheduleReview)
    }

    func testInvalidNamedDatesAndRecurringStartDatesRequireDateCorrection() {
        let data = AppData()
        let now = date(2026, 9, 13)
        for phrase in ["31 February", "Sept 32", "Feb. 30", "30th February", "2/30"] {
            for cadence in ["", " every year", " weekly"] {
                let text = "Party \(phrase)\(cadence)"
                let draft = QuickEventOverrides().resolve(text, category: nil, appData: data, now: now, calendar: calendar)
                XCTAssertTrue(draft.requiresScheduleReview, text)
                XCTAssertEqual(draft.scheduleReviewMessage, "Choose a date or update the date in the text.")
                let corrected = QuickEventOverrides(date: date(2026, 10, 1)).resolve(text, category: nil, appData: data, now: now, calendar: calendar)
                XCTAssertFalse(corrected.requiresScheduleReview, text)
                XCTAssertEqual(corrected.dateOptions.date, date(2026, 10, 1))
                XCTAssertEqual(corrected.dateOptions.repeatOption, cadence.isEmpty ? .never : cadence.contains("year") ? .yearly : .weekly)
            }
        }
        for text in ["Party 28 February", "Party Sept 30 every year", "Party Feb. 29 weekly", "Party 30th September"] {
            XCTAssertFalse(QuickEventOverrides().resolve(text, category: nil, appData: data, now: now, calendar: calendar).requiresScheduleReview, text)
        }
    }

    func testOrdinaryTitlesContainingScheduleWordsRemainTitles() {
        let data = AppData()
        let now = date(2026, 9, 13)
        for title in ["Until Dawn", "Through the Looking Glass", "Every Breath You Take", "Starting Over",
                      "Watch Every Breath You Take", "Think through the details", "The Daily Show"] {
            let plain = QuickEventOverrides().resolve(title, category: nil, appData: data, now: now, calendar: calendar)
            XCTAssertFalse(plain.requiresScheduleReview, title)
            XCTAssertEqual(plain.title, title)
            XCTAssertEqual(plain.dateOptions.repeatOption, .never)
            let dated = QuickEventOverrides().resolve(title + " tomorrow", category: nil, appData: data, now: now, calendar: calendar)
            XCTAssertFalse(dated.requiresScheduleReview, title)
            XCTAssertEqual(dated.title, title)
            XCTAssertEqual(dated.dateOptions.date, date(2026, 9, 14))
            let recurring = QuickEventOverrides().resolve(title + " every year", category: nil, appData: data, now: now, calendar: calendar)
            XCTAssertFalse(recurring.requiresScheduleReview, title)
            XCTAssertEqual(recurring.title, title)
            XCTAssertEqual(recurring.dateOptions.repeatOption, .yearly)
        }
        for input in ["Event every", "Event every other", "Event every 0 days", "Event every Monday and Wednesday",
                      "Event daily starting unknown", "Event until", "Event weekly until"] {
            XCTAssertTrue(QuickEventOverrides().resolve(input, category: nil, appData: data, now: now, calendar: calendar).requiresScheduleReview, input)
        }
    }

    func testCreatingHistoricalFiniteSeriesIncludesTheRequestedDates() throws {
        let data = AppData()
        for (start, end, count) in [(date(2024, 1, 1), date(2024, 1, 3), 3),
                                   (date(2024, 1, 1), date(2025, 1, 1), 367),
                                   (date(2024, 1, 1), date(2024, 1, 1), 1)] {
            var draft = NewEventDraft(title: "Historical series", date: start, category: "Work", appData: data)
            draft.dateOptions.repeatOption = .daily
            draft.dateOptions.repeatUntilOption = .onDate
            draft.dateOptions.repeatUntil = end
            let events = NewEventDraft.events(title: draft.title, dates: draft.dateOptions, category: draft.categoryOptions, calendar: calendar)
            XCTAssertEqual(events.count, count)
            XCTAssertEqual(events.first?.date, start)
            XCTAssertEqual(events.last?.date, end)
            XCTAssertEqual(events.map(\.occurrenceIndex), Array(0..<count).map(Optional.some))
            XCTAssertTrue(events.allSatisfy { $0.category == "Work" && $0.recurrence?.end == .onDate })
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            XCTAssertEqual(try EventStore.decode(encoder.encode(events)).map(\.id), events.map(\.id))
        }
    }

    func testQuickAndManualCreationPreserveEditableDetails() {
        var dates = DateOptions(date: date(2026, 12, 18), endDate: date(2026, 12, 20), showEndDate: true,
                                repeatOption: .never, repeatUntil: date(2027, 12, 18),
                                repeatUntilOption: .indefinitely, repeatUntilCount: 1,
                                showRepeatOptions: false, repeatUnit: "Days", customRepeatCount: 1)
        let category = CategoryOptions(selectedCategory: "Movies", selectedColor: CodableColor(color: .red))
        let events = NewEventDraft.events(title: " Dune ", dates: dates, category: category, calendar: calendar)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.title, "Dune")
        XCTAssertEqual(events.first?.date, dates.date)
        XCTAssertEqual(events.first?.endDate, dates.endDate)
        XCTAssertEqual(events.first?.category, "Movies")
        XCTAssertEqual(events.first?.color.red, category.selectedColor.red)
        XCTAssertNil(events.first?.seriesID)
        dates.repeatOption = .yearly
        let series = NewEventDraft.events(title: "Dune", dates: dates, category: category, calendar: calendar)
        XCTAssertGreaterThan(series.count, 1)
        XCTAssertEqual(Set(series.compactMap(\.seriesID)).count, 1)
        XCTAssertTrue(series.allSatisfy { $0.repeatOption == .yearly && $0.category == "Movies" })
        XCTAssertTrue(NewEventDraft.events(title: "  ", dates: dates, category: category, calendar: calendar).isEmpty)
    }
}
