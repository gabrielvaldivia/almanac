import XCTest
import UIKit

final class EventFlowTests: XCTestCase {
    func testAutomaticTimelineAndPlainListStaySynchronizedWithoutSheetResizing() {
        continueAfterFailure = false
        executionTimeAllowance = 240 // Create and remove enough rows to scroll the full-height list.
        let app = XCUIApplication()
        app.launch()
        let prefix = "Timeline \(UUID().uuidString.prefix(6))"
        // The plain list is taller than the old sheet; provide enough rows to
        // scroll today's entire group offscreen and exercise date synchronization.
        let names = ["\(prefix) First planning session", "\(prefix) Second", "\(prefix) Later"] +
            (1...9).map { "\(prefix) Future \($0)" }
        let offsets = [0, 0, 3, 15, 20, 25, 30, 35, 40, 45, 50, 55]
        for (name, offset) in zip(names, offsets) {
            openComposer(app)
            let input = app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch
            input.typeText("\(name) \(offset == 0 ? "today" : "in \(offset) days")")
            app.buttons["quickAddSubmit"].tap()
        }
        let list = app.scrollViews["eventList"]
        let timeline = app.scrollViews["eventTimeline"]
        if app.buttons["scrollToToday"].exists { app.buttons["scrollToToday"].tap() }
        waitForTimelineLayout(timeline)
        XCTAssertFalse(app.buttons["eventSheetResizeHandle"].exists)
        XCTAssertTrue(list.staticTexts[names[0]].isHittable)
        XCTAssertGreaterThan(list.frame.maxY, app.buttons["quickAddButton"].frame.maxY)
        let originalHeight = timeline.frame.height
        func screenshot(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        screenshot("Automatic timeline above plain event list")
        list.swipeDown()
        waitForTimelineLayout(timeline)
        XCTAssertEqual(timeline.frame.height, originalHeight, accuracy: 1, "Pulling the list cannot expand the timeline")
        list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.01))
            .press(forDuration: 0.1, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        XCTAssertEqual(timeline.frame.height, originalHeight, accuracy: 1, "The list's top edge is not a resize handle")
        timeline.buttons[names[0]].tap()
        XCTAssertTrue(list.staticTexts[names[0]].isHittable)
        XCTAssertFalse(app.navigationBars["Edit Event"].exists, "A timeline dot reveals and highlights its event")
        // A fling can coast several weeks. Drag a few days and hold before
        // releasing so this assertion targets the event three days from now.
        timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.75))
            .press(forDuration: 0.1,
                   thenDragTo: timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.75)),
                   withVelocity: .slow, thenHoldForDuration: 0.2)
        let later = list.staticTexts[names[2]].firstMatch
        let revealed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: later)
        XCTAssertEqual(XCTWaiter.wait(for: [revealed], timeout: 5), .completed,
                       "The list must follow the timeline: \(timeline.value as? String ?? "missing")")
        screenshot("Timeline pan scrolls the plain event list")
        let timelineAfterPan = timeline.value as? String
        list.swipeDown()
        let todayPrefix = "Days view, \(Date().formatted(date: .abbreviated, time: .omitted))"
        let returned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value BEGINSWITH %@", todayPrefix), object: timeline)
        XCTAssertEqual(XCTWaiter.wait(for: [returned], timeout: 5), .completed)
        XCTAssertNotEqual(timeline.value as? String, timelineAfterPan)
        XCTAssertTrue(list.staticTexts[names[0]].isHittable)
        list.swipeUp()
        let advanced = XCTNSPredicateExpectation(predicate: NSPredicate(format: "NOT (value BEGINSWITH %@)", todayPrefix), object: timeline)
        XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 5), .completed)
        screenshot("List scrolling advances the timeline")
        if app.buttons["scrollToToday"].exists { app.buttons["scrollToToday"].tap() }
        for name in names {
            let title = list.staticTexts[name].firstMatch
            if !title.isHittable { list.swipeUp() }
            XCTAssertTrue(title.waitForExistence(timeout: 5))
            title.tap()
            XCTAssertTrue(app.navigationBars["Edit Event"].waitForExistence(timeout: 5))
            app.buttons["Delete Event"].tap()
            app.alerts["Delete Event"].buttons["Delete this event"].tap()
        }
    }

    func testPinchZoomsTheAutomaticallySizedTimelineThroughEveryScale() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let monthTitle = app.staticTexts["appTitle"]
        XCTAssertTrue(monthTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(monthTitle.label, Date().formatted(.dateTime.month(.wide)))
        XCTAssertFalse(app.buttons["eventSheetResizeHandle"].exists)
        let timeline = app.scrollViews["eventTimeline"]
        waitForTimelineLayout(timeline)
        func assertScale(_ scale: String, yearHeading: Bool = true, file: StaticString = #filePath, line: UInt = #line) {
            let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value BEGINSWITH %@", "\(scale) view,"), object: timeline)
            XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 5), .completed, file: file, line: line)
            XCTAssertFalse(app.staticTexts["eventSheetTitle"].exists, file: file, line: line)
            XCTAssertEqual(monthTitle.label, scale == "Days" || !yearHeading ? Date().formatted(.dateTime.month(.wide)) : Date().formatted(.dateTime.year()),
                           file: file, line: line)
            waitForTimelineLayout(timeline)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Automatic timeline at \(scale.lowercased()) zoom"
            screenshot.lifetime = .keepAlways; add(screenshot)
        }
        timeline.pinch(withScale: 0.15, velocity: -1)
        assertScale("Weeks")
        timeline.pinch(withScale: 0.2, velocity: -1)
        assertScale("Months")
        timeline.pinch(withScale: 5, velocity: 2)
        // This intermediate weekly view fits fewer than eight weeks.
        assertScale("Weeks", yearHeading: false)
        timeline.pinch(withScale: 8, velocity: 2)
        assertScale("Days")
        timeline.pinch(withScale: 0.15, velocity: -1)
        assertScale("Weeks")
        timeline.swipeLeft()
        app.buttons["scrollToToday"].tap()
        let todayMonth = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", Date().formatted(.dateTime.year())), object: monthTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [todayMonth], timeout: 5), .completed)
    }

    func testShortPinchesRespondWhileTimelineHeightChangesAndKeepTheMonthHeading() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let timeline = app.scrollViews["eventTimeline"]
        XCTAssertTrue(timeline.waitForExistence(timeout: 5))
        for _ in 0..<3 {
            timeline.pinch(withScale: 0.6, velocity: -2)
            let zoomedOut = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value BEGINSWITH 'Weeks view,'"), object: timeline)
            XCTAssertEqual(XCTWaiter.wait(for: [zoomedOut], timeout: 5), .completed)
            XCTAssertEqual(app.staticTexts["appTitle"].label, Date().formatted(.dateTime.month(.wide)))
            waitForTimelineLayout(timeline)
            timeline.pinch(withScale: 2, velocity: 2)
            let zoomedIn = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value BEGINSWITH 'Days view,'"), object: timeline)
            XCTAssertEqual(XCTWaiter.wait(for: [zoomedIn], timeout: 5), .completed)
            waitForTimelineLayout(timeline)
        }
        let beforeScroll = timeline.value as? String
        timeline.swipeLeft()
        XCTAssertNotEqual(timeline.value as? String, beforeScroll, "Single-finger scrolling must still work after pinching")
        app.buttons["scrollToToday"].tap()
    }

    private func waitForTimelineLayout(_ timeline: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        var previousFrame: CGRect?
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = timeline.frame
            defer { previousFrame = frame }
            return !frame.isEmpty && frame == previousFrame
        }, object: timeline)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed, file: file, line: line)
    }

    func testComposerMenusDismissWithoutLeavingRectangularHighlights() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        openComposer(app)
        let input = app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch
        for (identifier, option) in [("quickEventRepeat", "Weekly"), ("quickEventCategory", "Work"), ("quickEventDate", "Tomorrow")] {
            let pill = app.buttons[identifier]
            let frame = pill.frame
            let value = pill.value as? String
            let before = app.screenshot()
            pill.tap()
            XCTAssertTrue(app.collectionViews.buttons[option].waitForExistence(timeout: 5))
            // Dismiss without a selection, keeping the composer and its backdrop
            // unchanged so the menu's returning highlight can be compared.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.15)).tap()
            XCTAssertFalse(app.collectionViews.buttons[option].exists)
            XCTAssertTrue(input.isHittable)
            XCTAssertEqual(pill.value as? String, value)
            let after = app.screenshot()
            let attachment = XCTAttachment(screenshot: after)
            attachment.name = "Composer immediately after dismissing \(identifier)"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTAssertEqual(pill.frame, frame)
            XCTAssertEqual(previewMarginBrightness(after, frame: frame, screen: app.frame),
                           previewMarginBrightness(before, frame: frame, screen: app.frame), accuracy: 0.04,
                           "The transparent margin above the capsule must not retain a rectangular menu highlight")
        }
        app.staticTexts["appTitle"].tap()
        XCTAssertTrue(app.buttons["quickAddButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(input.exists)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
    }

    private func previewMarginBrightness(_ screenshot: XCUIScreenshot, frame: CGRect, screen: CGRect) -> Double {
        guard let image = screenshot.image.cgImage else { XCTFail("Missing screenshot pixels"); return 0 }
        let scale = CGFloat(image.width) / screen.width
        let margin = CGRect(x: frame.minX + 2, y: frame.minY + 1, width: frame.width - 4, height: 4)
            .applying(CGAffineTransform(scaleX: scale, y: scale)).integral
        guard let sample = image.cropping(to: margin) else { XCTFail("Missing pill margin"); return 0 }
        var pixels = [UInt8](repeating: 0, count: sample.width * sample.height * 4)
        guard let context = CGContext(data: &pixels, width: sample.width, height: sample.height,
                                      bitsPerComponent: 8, bytesPerRow: sample.width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            XCTFail("Unable to read pill background"); return 0
        }
        context.draw(sample, in: CGRect(x: 0, y: 0, width: sample.width, height: sample.height))
        var total: Double = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = Double(pixels[index])
            let green = Double(pixels[index + 1])
            let blue = Double(pixels[index + 2])
            total += (red + green + blue) / 3
        }
        return total / Double(sample.width * sample.height) / 255
    }

    func testComposerCollapsesOnSwipeAndOutsideTapAndRetainsItsDraft() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        openComposer(app)
        let input = app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch
        input.typeText("Dinner #Work tomorrow")
        let color = app.buttons["quickEventColor"]
        XCTAssertGreaterThanOrEqual(color.frame.width, 44)
        XCTAssertEqual(color.frame.midY, input.frame.midY, accuracy: 1)
        color.tap()
        app.collectionViews.buttons["Orange"].tap()
        XCTAssertEqual(color.value as? String, "Orange")
        app.buttons["quickEventCategory"].tap()
        app.collectionViews.buttons["Social"].tap()
        XCTAssertTrue(input.exists)
        XCTAssertEqual(app.buttons["quickEventCategory"].value as? String, "Social")
        XCTAssertEqual(color.value as? String, "Orange")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Composer with event color beside text"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertFalse(app.buttons["manualEventInput"].exists)
        let fieldCenter = input.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        fieldCenter.press(forDuration: 0.05, thenDragTo: fieldCenter.withOffset(CGVector(dx: 0, dy: 120)))
        XCTAssertTrue(app.buttons["quickAddButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(input.exists)
        openComposer(app)
        XCTAssertEqual(input.value as? String, "Dinner #Work tomorrow")
        XCTAssertEqual(app.buttons["quickEventCategory"].value as? String, "Social")
        XCTAssertEqual(color.value as? String, "Orange")
        color.tap()
        app.collectionViews.buttons["Use Category Color"].tap()
        XCTAssertNotEqual(color.value as? String, "Orange")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        XCTAssertTrue(app.buttons["quickAddButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(input.exists)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        openComposer(app)
        app.staticTexts["appTitle"].tap()
        XCTAssertTrue(app.buttons["quickAddButton"].waitForExistence(timeout: 5))
    }

    func testComposerParsesPillsAndSavesQuickEdits() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        openComposer(app)
        let input = app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["quickEventDate"].value as? String, "Today")
        XCTAssertFalse(app.buttons["quickAddSubmit"].isEnabled)
        XCTAssertFalse(app.buttons["closeQuickEntry"].exists)
        XCTAssertTrue(app.buttons["quickEventDate"].isSelected)
        for id in ["quickEventCategory", "quickEventRepeat"] {
            XCTAssertFalse(app.buttons[id].isSelected)
        }
        let defaultsScreenshot = XCTAttachment(screenshot: app.screenshot())
        defaultsScreenshot.name = "Composer with active date and neutral optional pills"
        defaultsScreenshot.lifetime = .keepAlways
        add(defaultsScreenshot)
        let name = "Composer \(UUID().uuidString.prefix(6))"
        input.tap()
        input.typeText("\(name) #Social tomorrow")
        XCTAssertEqual(app.buttons["quickEventDate"].value as? String, "Tomorrow")
        XCTAssertEqual(app.buttons["quickEventCategory"].value as? String, "Social")
        XCTAssertTrue(app.buttons["quickEventDate"].isSelected)
        XCTAssertTrue(app.buttons["quickEventCategory"].isSelected)
        XCTAssertFalse(app.buttons["quickEventRepeat"].isSelected)
        app.buttons["quickEventCategory"].tap()
        app.collectionViews.buttons["Work"].tap()
        app.buttons["quickEventRepeat"].tap()
        app.collectionViews.buttons["Weekly"].tap()
        XCTAssertEqual(app.buttons["quickEventRepeat"].value as? String, "Weekly")
        // Explicit choices survive a text change and are saved directly.
        input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "today")
        XCTAssertEqual(app.buttons["quickEventDate"].value as? String, "Today")
        XCTAssertEqual(app.buttons["quickEventCategory"].value as? String, "Work")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Composer with parsed date and editable pills"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertFalse(app.buttons["manualEventInput"].exists)
        XCTAssertTrue(app.buttons["quickEventRepeat"].isSelected)
        app.buttons["quickEventRepeat"].tap()
        app.collectionViews.buttons["Never"].tap()
        app.buttons["quickEventDate"].tap()
        app.collectionViews.buttons["Tomorrow"].tap()
        XCTAssertEqual(app.buttons["quickEventDate"].value as? String, "Tomorrow")
        app.buttons["quickAddSubmit"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["quickAddButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(input.exists)
        app.staticTexts[name].tap()
        XCTAssertTrue(app.navigationBars["Edit Event"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Work"].exists)
        app.buttons["Delete Event"].tap()
        app.alerts["Delete Event"].buttons["Delete this event"].tap()
    }

    func testComposerAutomaticallySelectsBirthdayCategoryAndRespectsManualChoice() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        openComposer(app)
        let input = app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch
        input.typeText("Alex’s birthday 9/20")
        let category = app.buttons["quickEventCategory"]
        XCTAssertEqual(category.value as? String, "Birthdays")
        XCTAssertTrue(category.isSelected)
        XCTAssertEqual(app.buttons["quickEventColor"].value as? String, "Red")
        XCTAssertEqual(app.buttons["quickEventRepeat"].value as? String, "Yearly")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Birthday category inferred from event text"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        category.tap()
        app.collectionViews.buttons["Work"].tap()
        input.typeText(XCUIKeyboardKey.delete.rawValue + "1")
        XCTAssertEqual(category.value as? String, "Work")
        category.tap()
        app.collectionViews.buttons["None"].tap()
        XCTAssertEqual(category.value as? String, "None")
        category.tap()
        app.collectionViews.buttons["Use Text or Default"].tap()
        XCTAssertEqual(category.value as? String, "Birthdays")
    }

    func testPlusComposerRecognizesDateRangeAndPreservesItInEditorAndSavedEvent() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["quickAddButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch.exists)
        let plusScreenshot = XCTAttachment(screenshot: app.screenshot())
        plusScreenshot.name = "Collapsed plus button"
        plusScreenshot.lifetime = .keepAlways
        add(plusScreenshot)
        openComposer(app)
        let input = app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        let name = "Tampa \(UUID().uuidString.prefix(6))"
        input.typeText("\(name) Friday to Monday")
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let offset = (6 - calendar.component(.weekday, from: today) + 7) % 7
        let start = calendar.date(byAdding: .day, value: offset == 0 ? 7 : offset, to: today)!
        let end = calendar.date(byAdding: .day, value: 3, to: start)!
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Composer with date range and inline controls"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertFalse(app.buttons["manualEventInput"].exists)
        app.buttons["quickEventDate"].tap()
        app.collectionViews.buttons["Choose Dates…"].tap()
        XCTAssertTrue(app.navigationBars["Dates"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.switches["End date"].value as? String, "1")
        app.navigationBars["Dates"].buttons["Done"].tap()
        app.buttons["quickAddSubmit"].tap()
        XCTAssertTrue(app.buttons["quickAddButton"].waitForExistence(timeout: 5))
        let title = app.staticTexts[name].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        XCTAssertTrue(app.navigationBars["Edit Event"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["Start date"].value as? String, formatter.string(from: start))
        XCTAssertEqual(app.buttons["End date"].value as? String, formatter.string(from: end))
        app.buttons["Delete Event"].tap()
        app.alerts["Delete Event"].buttons["Delete this event"].tap()
    }

    private func openComposer(_ app: XCUIApplication) {
        let plus = app.buttons["quickAddButton"]
        XCTAssertTrue(plus.waitForExistence(timeout: 10))
        plus.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch.waitForExistence(timeout: 5))
    }

    func testInlineCalendarSelectsAndSavesARangeAcrossMonths() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        openComposer(app)
        let name = "Calendar \(UUID().uuidString.prefix(6))"
        app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch.typeText(name)
        func openDates() {
            app.buttons["quickEventDate"].tap()
            app.collectionViews.buttons["Choose Dates…"].tap()
            XCTAssertTrue(app.navigationBars["Dates"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["calendarDay-15"].isHittable, "Calendar should be exposed immediately")
        }
        func screenshot(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        openDates()
        XCTAssertEqual(app.switches["End date"].value as? String, "0")
        let calendar = Calendar.current
        let month = calendar.dateInterval(of: .month, for: Date())!.start
        var sixWeekMonth = month
        var monthsBack = 0
        while monthsBack < 12 {
            let leadingDays = (calendar.component(.weekday, from: sixWeekMonth) - calendar.firstWeekday + 7) % 7
            if leadingDays + calendar.range(of: .day, in: .month, for: sixWeekMonth)!.count > 35 { break }
            sixWeekMonth = calendar.date(byAdding: .month, value: -1, to: sixWeekMonth)!
            monthsBack += 1
            app.buttons["Previous month"].tap()
        }
        let lastDay = calendar.range(of: .day, in: .month, for: sixWeekMonth)!.count
        XCTAssertTrue(app.buttons["calendarDay-\(lastDay)"].isHittable, "A six-week month should fit without scrolling")
        screenshot("Inline calendar with all six weeks visible")
        for _ in 0..<monthsBack { app.buttons["Next month"].tap() }
        app.buttons["calendarDay-28"].tap()
        screenshot("Inline calendar with single date")
        app.switches["End date"].tap()
        app.buttons["Next month"].tap()
        app.buttons["calendarDay-3"].tap()
        XCTAssertTrue(app.buttons["calendarDay-1"].isSelected)
        XCTAssertTrue(app.buttons["calendarDay-2"].isSelected)
        XCTAssertTrue(app.buttons["calendarDay-3"].isSelected)
        XCTAssertFalse(app.buttons["calendarDay-4"].isSelected)
        screenshot("Inline calendar with range continuing into next month")
        app.buttons["calendarStartDate"].tap()
        XCTAssertTrue(app.buttons["calendarDay-28"].isSelected)
        screenshot("Inline calendar with range starting in previous month")
        app.navigationBars["Dates"].buttons["Done"].tap()

        // Reopening preserves both endpoints; turning the range off keeps its start.
        openDates()
        XCTAssertEqual(app.switches["End date"].value as? String, "1")
        app.switches["End date"].tap()
        XCTAssertFalse(app.buttons["calendarEndDate"].exists)
        XCTAssertTrue(app.buttons["calendarDay-28"].isSelected)
        app.switches["End date"].tap()
        app.buttons["Next month"].tap()
        app.buttons["calendarDay-3"].tap()
        app.navigationBars["Dates"].buttons["Done"].tap()
        app.buttons["quickAddSubmit"].tap()
        let title = app.staticTexts[name].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        XCTAssertTrue(app.navigationBars["Edit Event"].waitForExistence(timeout: 5))
        let start = calendar.date(byAdding: .day, value: 27, to: month)!
        let end = calendar.date(byAdding: .day, value: 2, to: calendar.date(byAdding: .month, value: 1, to: month)!)!
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        XCTAssertEqual(app.buttons["Start date"].value as? String, formatter.string(from: start))
        XCTAssertEqual(app.buttons["End date"].value as? String, formatter.string(from: end))
        app.buttons["Delete Event"].tap()
        app.alerts["Delete Event"].buttons["Delete this event"].tap()
    }

    func testInvalidScheduleCanBeCorrectedInComposer() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        openComposer(app)
        let input = app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch
        input.typeText("Trip 2/30")
        app.buttons["quickAddSubmit"].tap()
        XCTAssertTrue(app.staticTexts["quickEventValidation"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Add Event"].exists)
        app.buttons["quickEventDate"].tap()
        app.collectionViews.buttons["Today"].tap()
        XCTAssertFalse(app.staticTexts["quickEventValidation"].exists)
        XCTAssertTrue(input.exists)
        XCTAssertTrue(app.buttons["quickEventDate"].isSelected)
    }

    func testBirthdayReviewSelectionSaveAndRepeatedSync() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["--birthday-import-ui-test"]
        app.launch()
        app.buttons["Settings"].tap()
        app.buttons["syncContactBirthdays"].tap()
        let alex = app.switches["birthday-birthday-ui-alex"]
        let sam = app.switches["birthday-birthday-ui-sam"]
        XCTAssertTrue(alex.waitForExistence(timeout: 5))
        if alex.value as? String != "1" { alex.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
        if sam.value as? String == "1" { sam.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap() }
        let selectionUpdated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "1 of 2 selected"),
                                                         object: app.staticTexts["birthdaySelectionCount"])
        XCTAssertEqual(XCTWaiter.wait(for: [selectionUpdated], timeout: 3), .completed)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Birthday review with individual selection"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["saveContactBirthdays"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["Birthday Test Alex’s birthday"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Birthday Test Sam’s birthday"].exists)
        app.buttons["Settings"].tap()
        app.buttons["syncContactBirthdays"].tap()
        XCTAssertTrue(alex.waitForExistence(timeout: 5))
        XCTAssertEqual(alex.value as? String, "1")
        XCTAssertEqual(sam.value as? String, "0")
        sam.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        app.navigationBars["Contact Birthdays"].buttons["Cancel"].tap()
        app.buttons["syncContactBirthdays"].tap()
        XCTAssertTrue(sam.waitForExistence(timeout: 5))
        XCTAssertEqual(sam.value as? String, "0", "Cancel must not apply selection changes")
        app.buttons["saveContactBirthdays"].tap()

        // Deselecting imported birthdays removes only the reviewed fixture events.
        app.buttons["syncContactBirthdays"].tap()
        XCTAssertTrue(alex.waitForExistence(timeout: 5))
        app.buttons["Select All"].tap()
        XCTAssertEqual(sam.value as? String, "1")
        app.buttons["Deselect All"].tap()
        XCTAssertEqual(alex.value as? String, "0")
        app.buttons["saveContactBirthdays"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["quickAddButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Birthday Test Alex’s birthday"].exists)
    }

    func testCategoryRenamePersistsAndCanBeEditedAgain() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let name = "Category \(UUID().uuidString.prefix(8))", renamed = name + " edited"
        app.buttons["Settings"].tap()
        app.buttons["Manage Categories"].tap()
        XCTAssertTrue(app.buttons["Add Category"].waitForExistence(timeout: 5))
        app.buttons["Add Category"].tap()
        let field = app.textFields["Category Name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText(name)
        app.navigationBars["Add Category"].buttons["Save"].tap()
        app.buttons[name].tap()
        XCTAssertTrue(app.navigationBars["Edit Category"].waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, name)
        field.tap(); field.typeText(" edited")
        app.navigationBars["Edit Category"].buttons["Save"].tap()
        XCTAssertTrue(app.buttons[renamed].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        app.buttons["Settings"].tap()
        app.buttons["Manage Categories"].tap()
        XCTAssertTrue(app.buttons[renamed].waitForExistence(timeout: 5))
        app.buttons[renamed].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, renamed)
        app.navigationBars["Edit Category"].buttons["Cancel"].tap()
        app.buttons[renamed].swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons[renamed].waitForNonExistence(timeout: 5))
    }

    func testCreateEditPersistAndDeleteEvent() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let name = "Audit \(UUID().uuidString.prefix(8))", renamed = name + " edited"
        openComposer(app)
        let input = app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch
        input.typeText(name)
        app.buttons["quickAddSubmit"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        app.staticTexts[name].tap()
        XCTAssertTrue(app.navigationBars["Edit Event"].waitForExistence(timeout: 5))
        let title = app.textFields["Title"]
        title.tap()
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: name.count))
        title.typeText(renamed)
        app.navigationBars["Edit Event"].buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[renamed].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts[renamed].waitForExistence(timeout: 10))
        app.staticTexts[renamed].tap()
        XCTAssertTrue(app.buttons["Delete Event"].waitForExistence(timeout: 5))
        app.buttons["Delete Event"].tap()
        app.alerts["Delete Event"].buttons["Delete this event"].tap()
        XCTAssertTrue(app.staticTexts[renamed].waitForNonExistence(timeout: 5))
    }
}
