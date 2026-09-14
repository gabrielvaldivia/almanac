import XCTest

final class EventFlowTests: XCTestCase {
    func testExpandTimelineScrollFloatingStacksAndOpenStackedEvent() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let prefix = "Timeline \(UUID().uuidString.prefix(6))"
        let names = ["\(prefix) Alpha", "\(prefix) Beta", "\(prefix) Later"]
        let input = app.textFields["quickEventInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        for (index, name) in names.enumerated() {
            input.tap()
            input.typeText("\(name) \(index == 2 ? "tomorrow" : "today")")
            app.buttons["quickAddSubmit"].tap()
        }
        if app.buttons["closeQuickEntry"].exists { app.buttons["closeQuickEntry"].tap() }

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
        cards.buttons["timelineStackEvents"].firstMatch.tap()
        app.collectionViews.buttons[names[1]].tap()
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
        XCTAssertTrue(app.buttons["manualEventInput"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.buttons["manualEventInput"].waitForExistence(timeout: 10))
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
