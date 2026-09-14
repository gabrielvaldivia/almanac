import XCTest

final class EventFlowTests: XCTestCase {
    func testEventSheetResizesAndTimelineScrollsTheSameEventList() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let prefix = "Sheet \(UUID().uuidString.prefix(6))"
        let names = ["\(prefix) First", "\(prefix) Second", "\(prefix) Later"]
        for (index, name) in names.enumerated() {
            openComposer(app)
            let input = app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch
            input.typeText("\(name) \(index == 2 ? "in 3 days" : "today")")
            app.buttons["quickAddSubmit"].tap()
        }
        let handle = app.buttons["eventSheetResizeHandle"]
        let list = app.scrollViews["eventList"]
        let timeline = app.scrollViews["eventTimeline"]
        XCTAssertEqual(handle.value as? String, "Large")
        XCTAssertTrue(list.staticTexts[names[0]].isHittable)
        XCTAssertGreaterThan(list.frame.maxY, app.buttons["quickAddButton"].frame.maxY)
        let originalTimelineHeight = timeline.frame.height
        let originalHandleY = handle.frame.midY
        func screenshot(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        screenshot("Large events sheet and compact timeline")
        handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)))
        XCTAssertEqual(handle.value as? String, "Small")
        XCTAssertGreaterThan(handle.frame.midY, originalHandleY)
        XCTAssertGreaterThan(timeline.frame.height, originalTimelineHeight)
        XCTAssertFalse(app.scrollViews["timelineEventCards"].exists, "Both sizes use the same event list")
        let smallSheetTop = handle.frame.midY
        timeline.swipeLeft()
        XCTAssertEqual(handle.frame.midY, smallSheetTop, accuracy: 1)
        let later = list.staticTexts[names[2]].firstMatch
        let revealed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: later)
        XCTAssertEqual(XCTWaiter.wait(for: [revealed], timeout: 5), .completed)
        screenshot("Small events sheet follows timeline scrolling")
        handle.tap()
        XCTAssertEqual(handle.value as? String, "Large")
        XCTAssertTrue(later.isHittable)
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

    func testPinchZoomsTheTimelineAboveTheSmallEventSheet() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let handle = app.buttons["eventSheetResizeHandle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        handle.tap()
        XCTAssertEqual(handle.value as? String, "Small")
        let timeline = app.scrollViews["eventTimeline"]
        func assertScale(_ scale: String, file: StaticString = #filePath, line: UInt = #line) {
            let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value BEGINSWITH %@", "\(scale) view,"), object: timeline)
            XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 5), .completed, file: file, line: line)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Event sheet with linear \(scale.lowercased()) timeline"
            screenshot.lifetime = .keepAlways; add(screenshot)
        }
        timeline.pinch(withScale: 0.15, velocity: -1)
        assertScale("Weeks")
        let weekDates = timeline.value as? String
        handle.tap()
        XCTAssertEqual(handle.value as? String, "Large")
        assertScale("Weeks")
        XCTAssertEqual(timeline.value as? String, weekDates)
        handle.tap()
        XCTAssertEqual(handle.value as? String, "Small")
        timeline.pinch(withScale: 0.2, velocity: -1)
        assertScale("Months")
        let monthDates = timeline.value as? String
        handle.tap()
        XCTAssertEqual(handle.value as? String, "Large")
        assertScale("Months")
        XCTAssertEqual(timeline.value as? String, monthDates)
        handle.tap()
        XCTAssertEqual(handle.value as? String, "Small")
        timeline.pinch(withScale: 5, velocity: 2)
        assertScale("Weeks")
        timeline.pinch(withScale: 8, velocity: 2)
        assertScale("Days")
        handle.tap()
        XCTAssertEqual(handle.value as? String, "Large")
    }

    func testComposerCollapsesOnSwipeAndOutsideTapAndRetainsItsDraft() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        openComposer(app)
        let input = app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch
        input.typeText("Dinner #Work tomorrow")
        app.buttons["quickEventCategory"].tap()
        app.collectionViews.buttons["Social"].tap()
        XCTAssertTrue(input.exists)
        XCTAssertEqual(app.buttons["quickEventCategory"].value as? String, "Social")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Composer with event color beside text"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let fieldCenter = input.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        fieldCenter.press(forDuration: 0.05, thenDragTo: fieldCenter.withOffset(CGVector(dx: 0, dy: 120)))
        XCTAssertTrue(app.buttons["quickAddButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(input.exists)
        openComposer(app)
        XCTAssertEqual(input.value as? String, "Dinner #Work tomorrow")
        XCTAssertEqual(app.buttons["quickEventCategory"].value as? String, "Social")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        XCTAssertTrue(app.buttons["quickAddButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(input.exists)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        openComposer(app)
        app.staticTexts["appTitle"].tap()
        XCTAssertTrue(app.buttons["quickAddButton"].waitForExistence(timeout: 5))
    }

    func testComposerParsesPillsAndKeepsQuickEditsInManualForm() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        openComposer(app)
        let input = app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["quickEventDate"].value as? String, "Today")
        XCTAssertFalse(app.buttons["quickAddSubmit"].isEnabled)
        XCTAssertFalse(app.buttons["closeQuickEntry"].exists)
        let name = "Composer \(UUID().uuidString.prefix(6))"
        input.tap()
        input.typeText("\(name) #Social tomorrow")
        XCTAssertEqual(app.buttons["quickEventDate"].value as? String, "Tomorrow")
        XCTAssertEqual(app.buttons["quickEventCategory"].value as? String, "Social")
        app.buttons["quickEventCategory"].tap()
        app.collectionViews.buttons["Work"].tap()
        app.buttons["quickEventRepeat"].tap()
        app.collectionViews.buttons["Weekly"].tap()
        XCTAssertEqual(app.buttons["quickEventRepeat"].value as? String, "Weekly")
        // Explicit choices survive a text change and are shared with the full form.
        input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "today")
        XCTAssertEqual(app.buttons["quickEventDate"].value as? String, "Today")
        XCTAssertEqual(app.buttons["quickEventCategory"].value as? String, "Work")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Composer with parsed date and editable pills"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["manualEventInput"].tap()
        XCTAssertTrue(app.navigationBars["Add Event"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Title"].value as? String, name)
        XCTAssertTrue(app.staticTexts["Weekly"].exists)
        XCTAssertTrue(app.staticTexts["Work"].exists)
        app.navigationBars["Add Event"].buttons["Close"].tap()
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
        screenshot.name = "Composer with date range and separate Edit control"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertFalse(app.scrollViews["quickEventPills"].buttons["manualEventInput"].exists)
        app.buttons["manualEventInput"].tap()
        XCTAssertTrue(app.navigationBars["Add Event"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Title"].value as? String, name)
        XCTAssertEqual(app.buttons["Start date"].value as? String, formatter.string(from: start))
        XCTAssertEqual(app.buttons["End date"].value as? String, formatter.string(from: end))
        app.navigationBars["Add Event"].buttons["Close"].tap()
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
        app.buttons["manualEventInput"].tap()
        let title = app.textFields["Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText(name)
        app.navigationBars["Add Event"].buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        app.staticTexts[name].tap()
        XCTAssertTrue(app.navigationBars["Edit Event"].waitForExistence(timeout: 5))
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
