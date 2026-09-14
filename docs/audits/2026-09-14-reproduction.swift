// Evidence for the 2026-09-14 audit. Not part of an app or test target.
// These probes assert observed BUGGY behavior to demonstrate reproducibility.
// Use only a disposable simulator: tests temporarily replace its app-group preferences.
// Do not add these as passing correctness tests; fixes need assertions for desired behavior.

import XCTest
import UIKit
@testable import Up_Next

// Audit probes assert the observed failure mode, not the desired behavior.
final class AuditProbeTests: XCTestCase {
    var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int) -> Date { calendar.date(from: DateComponents(year: y, month: m, day: d))! }
    func seed(_ frequency: RepeatOption, _ start: Date) -> Event {
        Event(title: "Audit series", date: start, color: CodableColor(color: .blue), repeatOption: frequency,
              seriesID: UUID(), customRepeatCount: 1, repeatUnit: "Days", repeatUntilCount: 3, useCustomRepeatOptions: true)
    }
    func isolatedPreferences(_ body: (AppData) throws -> Void) rethrows {
        let defaults = AppPreferences.shared
        let domain = "group.UpNextIdentifier"
        let original = defaults.persistentDomain(forName: domain)
        defer { if let original { defaults.setPersistentDomain(original, forName: domain) } else { defaults.removePersistentDomain(forName: domain) } }
        defaults.removePersistentDomain(forName: domain)
        try body(AppData())
    }
    func testMonthlyMoveStoresADateThatDisagreesWithItsRule() throws {
        let event = seed(.monthly, date(2030, 1, 31))
        let events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .after), calendar: calendar)
        var replacement = events[0]; replacement.date = date(2030, 1, 30)
        let updated = EventSeries.updating(events[0], with: replacement, in: events, calendar: calendar)
        XCTAssertEqual(updated[1].date, date(2030, 2, 27))
        XCTAssertEqual(updated[1].recurrence?.date(at: 1, calendar: calendar), date(2030, 2, 28))
    }
    func testDeletingOnlyMaterializedOccurrenceErasesIndefiniteSchedule() {
        var event = seed(.custom, date(2030, 1, 1)); event.customRepeatCount = 2; event.repeatUnit = "Years"
        let events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .indefinitely), now: date(2030, 1, 1), calendar: calendar)
        XCTAssertEqual(events.count, 1)
        let removed = Recurrence.removingOccurrence(events[0], from: events)
        XCTAssertTrue(Recurrence.replenishing(removed, now: date(2032, 1, 1), calendar: calendar).isEmpty)
    }
    func testChangingOnlyEndDateDropsStoredHistory() {
        let event = seed(.daily, date(2024, 1, 1))
        let events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .indefinitely), now: date(2024, 1, 1), calendar: calendar)
        var replacement = events[0]
        replacement.recurrence!.end = .onDate
        replacement.recurrence!.until = date(2030, 1, 1)
        let updated = EventSeries.updating(events[0], with: replacement, in: events, calendar: calendar)
        XCTAssertFalse(updated.contains { $0.id == events[0].id })
        XCTAssertFalse(updated.contains { calendar.component(.year, from: $0.date) == 2024 })
    }
    func testInvalidSupportedDateSyntaxSilentlyDefaultsToToday() {
        isolatedPreferences { appData in
            for text in ["Party 31 February", "Party Sept 32"] {
                XCTAssertNil(QuickEventParser.parse(text, now: date(2030, 1, 1), calendar: calendar))
                let draft = QuickEventOverrides().resolve(text, category: nil, appData: appData, now: date(2030, 1, 1), calendar: calendar)
                XCTAssertEqual(draft.dateOptions.date, date(2030, 1, 1))
                XCTAssertFalse(draft.requiresScheduleReview, text)
            }
            XCTAssertTrue(QuickEventOverrides().resolve("Party 2/30", category: nil, appData: appData).requiresScheduleReview)
        }
    }
    func testIndependentWidgetAndAppRefillsGenerateDifferentDeepLinkIDs() {
        let event = seed(.yearly, date(2030, 1, 1))
        let stored = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .indefinitely), now: date(2030, 1, 1), calendar: calendar)
        let widget = Recurrence.replenishing(stored, now: date(2032, 6, 1), calendar: calendar)
        let app = Recurrence.replenishing(stored, now: date(2032, 6, 1), calendar: calendar)
        let widgetEvent = widget.first { $0.date == date(2033, 1, 1) }!
        XCTAssertTrue(app.contains { $0.date == widgetEvent.date })
        XCTAssertFalse(app.contains { $0.id == widgetEvent.id })
    }
    func testCategoryRenameOverwritesAnEventsCustomColor() {
        isolatedPreferences { appData in
            let original = Event(title: "Orange", date: date(2030, 1, 1), color: CodableColor(color: .orange), category: "Work")
            appData.events = [original]
            appData.updateEventsForCategoryChange(oldName: "Work", newName: "Career", newColor: .blue)
            XCTAssertNotEqual(appData.events[0].color, original.color)
            XCTAssertEqual(appData.events[0].color, CodableColor(color: .blue))
        }
    }
    func testCategoryRenameWhileEventsAreUnreadableLeavesDanglingCategory() throws {
        try isolatedPreferences { appData in
            appData.events = [Event(title: "Work event", date: date(2030, 1, 1), color: CodableColor(color: .blue), category: "Work")]
            appData.saveEvents()
            let readable = AppPreferences.shared.data(forKey: "events")!
            AppPreferences.shared.set(Data("corrupt".utf8), forKey: "events")
            appData.loadEvents()
            XCTAssertNotNil(appData.storageError)
            let index = appData.categories.firstIndex { $0.name == "Work" }!
            appData.categories[index].name = "Career"
            appData.updateEventsForCategoryChange(oldName: "Work", newName: "Career", newColor: .blue)
            AppPreferences.shared.set(readable, forKey: "events")
            appData.loadEvents(); appData.loadCategories()
            XCTAssertEqual(appData.events[0].category, "Work")
            XCTAssertFalse(appData.categories.contains { $0.name == "Work" })
            XCTAssertTrue(appData.categories.contains { $0.name == "Career" })
        }
    }
    func testCustomCategoryCadenceAlreadyWorksControl() {
        isolatedPreferences { appData in
            appData.categories = [("Fortnightly", .green, .custom, 2, "Weeks", .indefinitely, 1, Date())]
            let draft = NewEventDraft(title: "Control", date: date(2030, 1, 1), category: "Fortnightly", appData: appData)
            XCTAssertEqual(draft.dateOptions.customRepeatCount, 2)
            XCTAssertEqual(draft.dateOptions.repeatUnit, "Weeks")
        }
    }
    @MainActor func testTimelineTodayFocusPointsToYesterdayAfterWestwardTimeZoneChange() {
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
}

extension AuditProbeTests {
    func testRenamingCategoryEmptiesExistingWidgetFilter() {
        isolatedPreferences { appData in
            appData.events = [Event(title: "Meeting", date: date(2030, 1, 1), color: CodableColor(color: .blue), category: "Work")]
            XCTAssertEqual(WidgetEvents.upcoming(appData.events, category: "Work", at: date(2030, 1, 1), calendar: calendar).count, 1)
            appData.updateEventsForCategoryChange(oldName: "Work", newName: "Career", newColor: .blue)
            XCTAssertTrue(WidgetEvents.upcoming(appData.events, category: "Work", at: date(2030, 1, 1), calendar: calendar).isEmpty)
            XCTAssertEqual(WidgetEvents.upcoming(appData.events, category: "Career", at: date(2030, 1, 1), calendar: calendar).count, 1)
        }
    }
    func testRangeCrossingNewYearOmitsBothYears() {
        let text = EventDateText.range(start: date(2026, 12, 31), end: date(2027, 1, 2), reference: date(2026, 9, 14), calendar: calendar)
        XCTAssertFalse(text.contains("2026"))
        XCTAssertFalse(text.contains("2027"))
        print("AUDIT: Cross-year range rendered as: \(text)")
    }
}
