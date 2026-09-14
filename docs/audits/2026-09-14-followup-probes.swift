// Follow-up audit evidence. These assert observed defects, NOT desired behavior.
// Not a shipping test target. Run only in a disposable simulator/source copy.
import XCTest
import UIKit
@testable import Up_Next

@MainActor
final class RemainingAuditProbes: XCTestCase {
    var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
    func seed(_ frequency: RepeatOption, _ start: Date) -> Event {
        Event(title: "Audit series", date: start, color: CodableColor(color: .blue), notificationsEnabled: false,
              repeatOption: frequency, seriesID: UUID(), customRepeatCount: 1, repeatUnit: "Days",
              repeatUntilCount: 3, useCustomRepeatOptions: true)
    }
    func isolated(_ body: (AppData) throws -> Void) async rethrows {
        let defaults = AppPreferences.shared
        let domain = AppPreferences.uiTestSuiteName ?? "group.UpNextIdentifier"
        let original = defaults.persistentDomain(forName: domain)
        defer {
            if let original { defaults.setPersistentDomain(original, forName: domain) }
            else { defaults.removePersistentDomain(forName: domain) }
        }
        defaults.removePersistentDomain(forName: domain)
        let app = AppData()
        try body(app)
        await app.waitForNotifications()
    }

    func testEndingChangeDropsStoredHistory() {
        let event = seed(.daily, date(2024, 1, 1))
        let events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .indefinitely), now: event.date, calendar: calendar)
        var replacement = events[0]
        replacement.recurrence!.end = .onDate
        replacement.recurrence!.until = date(2030, 1, 1)
        let updated = EventSeries.updating(events[0], with: replacement, in: events, calendar: calendar)
        XCTAssertFalse(updated.contains { $0.id == events[0].id })
        XCTAssertFalse(updated.contains { calendar.component(.year, from: $0.date) == 2024 })
    }

    func testMovingMonthlySeriesDisagreesWithRule() {
        let event = seed(.monthly, date(2030, 1, 31))
        let events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .after), calendar: calendar)
        var replacement = events[0]; replacement.date = date(2030, 1, 30)
        let updated = EventSeries.updating(events[0], with: replacement, in: events, calendar: calendar)
        XCTAssertEqual(updated[1].date, date(2030, 2, 27))
        XCTAssertEqual(updated[1].recurrence?.date(at: 1, calendar: calendar), date(2030, 2, 28))
    }

    func testDeletingOnlyOccurrenceLosesFutureSchedule() {
        var event = seed(.custom, date(2030, 1, 1)); event.customRepeatCount = 2; event.repeatUnit = "Years"
        let events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .indefinitely), now: event.date, calendar: calendar)
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(Recurrence.replenishing(Recurrence.removingOccurrence(events[0], from: events),
                                             now: date(2032, 1, 1), calendar: calendar).isEmpty)
    }

    func testSingleOccurrenceEditsLeakIntoFutureSparseOccurrences() {
        var event = seed(.custom, date(2030, 1, 1)); event.customRepeatCount = 2; event.repeatUnit = "Years"
        var events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .indefinitely), now: event.date, calendar: calendar)
        XCTAssertEqual(events.count, 1)
        // Mirrors EditEventView's This Event Only branch.
        events[0].title = "Only this occurrence"
        events[0].endDate = date(2030, 1, 5)
        events[0].isRecurrenceException = true
        let refill = Recurrence.replenishing(events, now: date(2032, 1, 1), calendar: calendar)
        let future = refill.first { $0.date == date(2032, 1, 1) }
        XCTAssertEqual(future?.title, "Only this occurrence")
        XCTAssertEqual(future?.endDate, date(2032, 1, 5))
    }

    func testInvalidSupportedNamedDatesBecomeToday() async {
        await isolated { app in
            for text in ["Party 31 February", "Party Sept 32", "Party Feb. 30"] {
                let draft = QuickEventOverrides().resolve(text, category: nil, appData: app, now: date(2030, 1, 1), calendar: calendar)
                XCTAssertEqual(draft.dateOptions.date, date(2030, 1, 1))
                XCTAssertFalse(draft.requiresScheduleReview, text)
            }
        }
    }

    func testValidRecurrenceHidesAnInvalidStartDate() async {
        await isolated { app in
            for text in ["Party 2/30 every year", "Party 31 February weekly"] {
                let draft = QuickEventOverrides().resolve(text, category: nil, appData: app, now: date(2030, 1, 1), calendar: calendar)
                XCTAssertEqual(draft.dateOptions.date, date(2030, 1, 1))
                XCTAssertFalse(draft.requiresScheduleReview, text)
                XCTAssertTrue(draft.title.contains(text.contains("2/30") ? "2/30" : "31 February"))
                XCTAssertNotEqual(draft.dateOptions.repeatOption, .never)
            }
        }
    }

    func testOrdinaryTitlesIncorrectlyRequireScheduleReview() async {
        await isolated { app in
            for text in ["Until Dawn", "Through the Looking Glass", "Every Breath You Take"] {
                let draft = QuickEventOverrides().resolve(text, category: nil, appData: app)
                XCTAssertTrue(draft.requiresScheduleReview, text)
                XCTAssertEqual(draft.title, text)
            }
        }
    }

    func testValidHistoricalDateLimitedSeriesCreatesNoEvents() async {
        await isolated { app in
            var draft = NewEventDraft(title: "Past series", date: date(2024, 1, 1), category: nil, appData: app)
            draft.dateOptions.repeatOption = .daily
            draft.dateOptions.repeatUntilOption = .onDate
            draft.dateOptions.repeatUntil = date(2024, 1, 3)
            XCTAssertNil(draft.dateOptions.validationMessage)
            XCTAssertTrue(NewEventDraft.events(title: draft.title, dates: draft.dateOptions,
                                               category: draft.categoryOptions, calendar: calendar).isEmpty)
        }
    }

    func testCategoryMetadataSaveOverwritesColorOverride() async {
        await isolated { app in
            let original = Event(title: "Orange override", date: date(2030, 1, 1), color: CodableColor(color: .orange), category: "Work", notificationsEnabled: false)
            app.events = [original]
            app.updateEventsForCategoryChange(oldName: "Work", newName: "Work", newColor: .blue)
            XCTAssertEqual(app.events[0].color, CodableColor(color: .blue))
            XCTAssertNotEqual(app.events[0].color, original.color)
        }
    }

    func testCategoryRenameDuringRecoveryLeavesDanglingReference() async throws {
        try await isolated { app in
            app.events = [Event(title: "Work event", date: date(2030, 1, 1), color: CodableColor(color: .blue), category: "Work", notificationsEnabled: false)]
            app.saveEvents()
            let readable = try XCTUnwrap(AppPreferences.shared.data(forKey: "events"))
            AppPreferences.shared.set(Data("corrupt".utf8), forKey: "events")
            app.loadEvents()
            XCTAssertNotNil(app.storageError)
            let index = try XCTUnwrap(app.categories.firstIndex { $0.name == "Work" })
            app.categories[index].name = "Career"
            app.updateEventsForCategoryChange(oldName: "Work", newName: "Career", newColor: .blue)
            AppPreferences.shared.set(readable, forKey: "events")
            app.loadEvents(); app.loadCategories()
            XCTAssertEqual(app.events[0].category, "Work")
            XCTAssertFalse(app.categories.contains { $0.name == "Work" })
        }
    }

    func testWidgetRefillsHaveUnresolvableIDs() throws {
        let event = seed(.yearly, date(2030, 1, 1))
        let stored = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .indefinitely), now: event.date, calendar: calendar)
        let widget = Recurrence.replenishing(stored, now: date(2032, 6, 1), calendar: calendar)
        let app = Recurrence.replenishing(stored, now: date(2032, 6, 1), calendar: calendar)
        let shown = try XCTUnwrap(widget.first { $0.date == date(2033, 1, 1) })
        XCTAssertTrue(app.contains { $0.date == shown.date })
        XCTAssertFalse(app.contains { $0.id == shown.id })
    }

    func testCategoryRenameEmptiesSavedWidgetFilter() async {
        await isolated { app in
            app.events = [Event(title: "Meeting", date: date(2030, 1, 1), color: CodableColor(color: .blue), category: "Work", notificationsEnabled: false)]
            app.updateEventsForCategoryChange(oldName: "Work", newName: "Career", newColor: .blue)
            XCTAssertTrue(WidgetEvents.upcoming(app.events, category: "Work", at: date(2030, 1, 1), calendar: calendar).isEmpty)
            XCTAssertEqual(WidgetEvents.upcoming(app.events, category: "Career", at: date(2030, 1, 1), calendar: calendar).count, 1)
        }
    }

    func testCrossYearRangeOmitsYears() {
        let text = EventDateText.range(start: date(2026, 12, 31), end: date(2027, 1, 2), reference: date(2026, 9, 14), calendar: calendar)
        XCTAssertFalse(text.contains("2026")); XCTAssertFalse(text.contains("2027"))
    }

    func testTimelineTodayDriftsAfterTimeZoneChange() {
        let original = NSTimeZone.default
        defer { NSTimeZone.default = original }
        NSTimeZone.default = TimeZone(identifier: "America/New_York")!
        let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: 124))
        timeline.layoutIfNeeded()
        NSTimeZone.default = TimeZone(identifier: "America/Los_Angeles")!
        timeline.update(events: [])
        timeline.scrollToToday(animated: false)
        let focused = Calendar.current.date(byAdding: .day, value: Int(timeline.focusedDayPosition), to: timeline.anchor)!
        XCTAssertNotEqual(Calendar.current.startOfDay(for: focused), Calendar.current.startOfDay(for: Date()))
    }

    func testTimelineMarkersHaveTinyHitTargets() throws {
        let timeline = TimelineScrollView(frame: CGRect(x: 0, y: 0, width: 393, height: 124))
        let event = Event(title: "Touch target", date: Date(), color: CodableColor(color: .blue))
        timeline.update(events: [event]); timeline.layoutIfNeeded()
        let button = try XCTUnwrap(timeline.subviews.compactMap { $0 as? UIButton }.first)
        XCTAssertEqual(button.bounds.height, 20, accuracy: 1)
        XCTAssertFalse(button.point(inside: CGPoint(x: button.bounds.midX, y: button.bounds.maxY + 1), with: nil))
        timeline.beginZoom(at: 0); timeline.changeZoom(scale: 1 / 30, at: 0); timeline.endZoom(); timeline.layoutIfNeeded()
        let small = try XCTUnwrap(timeline.subviews.compactMap { $0 as? UIButton }.first)
        XCTAssertEqual(small.bounds.height, 6, accuracy: 0.1)
    }

    func testPaginationBoundaryDoesNotAdvanceWithToday() {
        let start = date(2030, 1, 1)
        let window = EventListWindow(today: start, calendar: calendar)
        let tomorrow = date(2030, 1, 2)
        XCTAssertEqual(calendar.dateComponents([.day], from: tomorrow, to: window.end).day, 364)
    }

    func testShowMoreExhaustsStoredDailyRecurrencesAfterOneExtraDay() {
        let today = date(2030, 1, 1)
        let event = seed(.daily, today)
        let events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .indefinitely), now: today, calendar: calendar)
        var window = EventListWindow(today: today, calendar: calendar)
        let firstPageEnd = window.end
        XCTAssertEqual(events.filter { $0.date < firstPageEnd }.count, 365)
        XCTAssertTrue(events.contains { $0.date >= firstPageEnd })
        // Mirrors the Show more action and its visibility predicate in ContentView.
        window.loadMore()
        XCTAssertEqual(events.filter { $0.date >= firstPageEnd && $0.date < window.end }.count, 1)
        XCTAssertFalse(events.contains { $0.date >= window.end }, "Button disappears although the recurrence never ends")
    }

    func testUnreadableCategoryHasBackupButNoAutomaticRecovery() async throws {
        try await isolated { app in
            app.saveCategories()
            app.categories[0].name = "Latest category"
            let defaults = AppPreferences.shared
            XCTAssertNotNil(defaults.data(forKey: "categories.lastReadableBackup"))
            defaults.set(Data("corrupt".utf8), forKey: "categories")
            app.loadCategories()
            XCTAssertNotNil(app.categoryStorageError)
            app.loadCategories()
            XCTAssertNotNil(app.categoryStorageError)
            XCTAssertNoThrow(try CategoryStorage.decode(XCTUnwrap(defaults.data(forKey: "categories.lastReadableBackup"))))
        }
    }

    func testRecurrenceAfterLongInactivityOnlyRefillsTenThousandOldDays() {
        let event = seed(.daily, date(2000, 1, 1))
        let stored = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .indefinitely), now: event.date, calendar: calendar)
        let refill = Recurrence.replenishing(stored, now: date(2030, 1, 1), calendar: calendar)
        XCTAssertFalse(refill.contains { $0.date >= date(2030, 1, 1) })
    }

    func testMeasureLargeSeriesEditsAndListGrouping() {
        for count in [1000, 5000, 10000] {
            var event = seed(.daily, date(2030, 1, 1)); event.repeatUntilCount = count
            let events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .after), calendar: calendar)
            var replacement = events[0]; replacement.title = "Metadata edit"
            let before = ProcessInfo.processInfo.systemUptime
            let updated = EventSeries.updating(events[0], with: replacement, in: events, calendar: calendar)
            let editTime = ProcessInfo.processInfo.systemUptime - before
            let groupingStart = ProcessInfo.processInfo.systemUptime
            let groups = EventListDay.group(events: updated, calendar: calendar)
            let groupTime = ProcessInfo.processInfo.systemUptime - groupingStart
            XCTAssertEqual(updated.count, count); XCTAssertEqual(groups.count, count)
            print("AUDIT PERFORMANCE events=\(count) editSeconds=\(editTime) groupSeconds=\(groupTime)")
        }
    }
}
