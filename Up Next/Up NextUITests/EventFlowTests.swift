import XCTest

final class EventFlowTests: XCTestCase {
    func testExpandTimelineScrollFloatingStacksAndOpenStackedEvent() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let prefix = "Timeline \(UUID().uuidString.prefix(6))"
        let names = ["\(prefix) Alpha", "\(prefix) Beta", "\(prefix) Later"]
        let input = app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch
        for (index, name) in names.enumerated() {
            openComposer(app)
            input.tap()
            input.typeText("\(name) \(index == 2 ? "tomorrow" : "today")")
            app.buttons["quickAddSubmit"].tap()
        }

        let handle = app.buttons["timelineResizeHandle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: destination)
        let expanded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Full timeline"), object: handle)
        XCTAssertEqual(XCTWaiter.wait(for: [expanded], timeout: 5), .completed)

        let cards = app.scrollViews["timelineEventCards"]
        XCTAssertTrue(cards.waitForExistence(timeout: 5))
        XCTAssertTrue(cards.buttons["timelineStackEvents"].firstMatch.isHittable)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Expanded timeline with floating same-day stack"
        attachment.lifetime = .keepAlways
        add(attachment)

        let timeline = app.scrollViews["eventTimeline"]
        let originalDates = timeline.value as? String
        timeline.swipeLeft()
        let moved = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", originalDates ?? ""), object: timeline)
        XCTAssertEqual(XCTWaiter.wait(for: [moved], timeout: 5), .completed)
        XCTAssertEqual(cards.value as? String, "Page 2 of 2")
        let movedDates = timeline.value as? String
        cards.swipeRight()
        let followedCards = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", movedDates ?? ""), object: timeline)
        XCTAssertEqual(XCTWaiter.wait(for: [followedCards], timeout: 5), .completed)
        XCTAssertEqual(cards.value as? String, "Page 1 of 2")
        let frontCard = cards.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "timelineCard-"))
            .allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(frontCard)
        XCTAssertGreaterThanOrEqual(frontCard!.frame.minX, cards.frame.minX)
        XCTAssertLessThanOrEqual(frontCard!.frame.maxX, cards.frame.maxX)
        if app.buttons["scrollToToday"].exists { app.buttons["scrollToToday"].tap() }
        frontCard!.tap()
        let verticalCards = cards.tables["timelineExpandedStack"]
        XCTAssertTrue(verticalCards.waitForExistence(timeout: 5))
        let first = verticalCards.buttons[names[0]]
        let second = verticalCards.buttons[names[1]]
        XCTAssertTrue(first.isHittable)
        XCTAssertTrue(second.isHittable)
        XCTAssertTrue(first.frame.maxY <= second.frame.minY || second.frame.maxY <= first.frame.minY)
        let verticalScreenshot = XCTAttachment(screenshot: app.screenshot())
        verticalScreenshot.name = "Same-day stack arranged vertically"
        verticalScreenshot.lifetime = .keepAlways
        add(verticalScreenshot)
        cards.buttons["timelineCollapseStack"].firstMatch.tap()
        XCTAssertFalse(verticalCards.isHittable)
        cards.buttons["timelineStackEvents"].firstMatch.tap()
        second.tap()
        XCTAssertTrue(app.navigationBars["Edit Event"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Title"].value as? String, names[1])
        app.navigationBars["Edit Event"].buttons["Close"].tap()

        handle.tap()
        XCTAssertEqual(handle.value as? String, "Compact")
        for name in names {
            let title = app.staticTexts[name].firstMatch
            XCTAssertTrue(title.waitForExistence(timeout: 5))
            title.tap()
            app.buttons["Delete Event"].tap()
            app.alerts["Delete Event"].buttons["Delete this event"].tap()
        }
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
