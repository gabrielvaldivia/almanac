import XCTest

final class EventFlowTests: XCTestCase {
    func testEventSheetResizesAndTimelineScrollsTheSameEventList() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let prefix = "Sheet \(UUID().uuidString.prefix(6))"
        let names = ["\(prefix) First planning session", "\(prefix) Second", "\(prefix) Later"]
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
        let timelineTitles = timeline.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "timelineEventTitle-"))
        XCTAssertTrue(timelineTitles.firstMatch.waitForExistence(timeout: 5))
        screenshot("Expanded timeline with connected event titles")
        timelineTitles.matching(NSPredicate(format: "label == %@", names[0])).firstMatch.tap()
        XCTAssertTrue(list.staticTexts[names[0]].isHittable)
        XCTAssertFalse(app.navigationBars["Edit Event"].exists, "A timeline title reveals and highlights its event")
        let smallSheetTop = handle.frame.midY
        timeline.swipeLeft()
        XCTAssertEqual(handle.frame.midY, smallSheetTop, accuracy: 1)
        let later = list.staticTexts[names[2]].firstMatch
        let revealed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: later)
        XCTAssertEqual(XCTWaiter.wait(for: [revealed], timeout: 5), .completed)
        screenshot("Small events sheet follows timeline scrolling")
        let timelineAfterPan = timeline.value as? String
        list.swipeDown()
        func assertTimelineStarts(on date: Date, file: StaticString = #filePath, line: UInt = #line) {
            let prefix = "Days view, \(date.formatted(date: .abbreviated, time: .omitted))"
            let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value BEGINSWITH %@", prefix), object: timeline)
            XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed,
                           "Actual timeline: \(timeline.value as? String ?? "missing")", file: file, line: line)
        }
        assertTimelineStarts(on: Date())
        XCTAssertNotEqual(timeline.value as? String, timelineAfterPan)
        XCTAssertTrue(list.staticTexts[names[0]].isHittable)
        screenshot("Scrolling the sheet returns the timeline to today's events")
        list.swipeUp()
        screenshot("Events sheet after scrolling forward")
        assertTimelineStarts(on: Calendar.current.date(byAdding: .day, value: 3, to: Date())!)
        XCTAssertTrue(later.isHittable)
        screenshot("Scrolling the sheet advances the timeline to the next event date")
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

    func testPinchZoomsTheTimelineInBothEventSheetSizes() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let monthTitle = app.staticTexts["appTitle"]
        XCTAssertTrue(monthTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(monthTitle.label, Date().formatted(.dateTime.month(.wide)))
        XCTAssertFalse(app.staticTexts["timelineScaleHeader"].exists)
        let handle = app.buttons["eventSheetResizeHandle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        let timeline = app.scrollViews["eventTimeline"]
        resizeEventSheet(handle, timeline: timeline)
        XCTAssertEqual(handle.value as? String, "Small")
        func assertScale(_ scale: String, file: StaticString = #filePath, line: UInt = #line) {
            let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value BEGINSWITH %@", "\(scale) view,"), object: timeline)
            XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 5), .completed, file: file, line: line)
            XCTAssertEqual(app.staticTexts["eventSheetTitle"].label, "Up Next", file: file, line: line)
            XCTAssertTrue(app.staticTexts["eventSheetTitle"].isHittable, file: file, line: line)
            XCTAssertFalse(app.staticTexts["timelineScaleHeader"].exists, file: file, line: line)
            XCTAssertEqual(monthTitle.label, scale == "Days" ? Date().formatted(.dateTime.month(.wide)) : Date().formatted(.dateTime.year()),
                           file: file, line: line)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Event sheet with linear \(scale.lowercased()) timeline"
            screenshot.lifetime = .keepAlways; add(screenshot)
        }
        timeline.pinch(withScale: 0.15, velocity: -1)
        assertScale("Weeks")
        let weekDates = timeline.value as? String
        resizeEventSheet(handle, timeline: timeline)
        XCTAssertEqual(handle.value as? String, "Large")
        assertScale("Weeks")
        XCTAssertEqual(timeline.value as? String, weekDates)
        timeline.pinch(withScale: 0.2, velocity: -1)
        assertScale("Months")
        timeline.pinch(withScale: 5, velocity: 2)
        assertScale("Weeks")
        resizeEventSheet(handle, timeline: timeline)
        XCTAssertEqual(handle.value as? String, "Small")
        timeline.pinch(withScale: 0.7, velocity: -1)
        let transition = XCTAttachment(screenshot: app.screenshot())
        transition.name = "Readable labels between weeks and months"
        transition.lifetime = .keepAlways; add(transition)
        timeline.pinch(withScale: 0.2, velocity: -1)
        assertScale("Months")
        let monthDates = timeline.value as? String
        resizeEventSheet(handle, timeline: timeline)
        XCTAssertEqual(handle.value as? String, "Large")
        assertScale("Months")
        XCTAssertEqual(timeline.value as? String, monthDates)
        resizeEventSheet(handle, timeline: timeline)
        XCTAssertEqual(handle.value as? String, "Small")
        timeline.pinch(withScale: 5, velocity: 2)
        assertScale("Weeks")
        timeline.pinch(withScale: 8, velocity: 2)
        assertScale("Days")
        timeline.pinch(withScale: 0.15, velocity: -1)
        assertScale("Weeks")
        timeline.swipeLeft()
        app.buttons["scrollToToday"].tap()
        let todayMonth = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", Date().formatted(.dateTime.year())), object: monthTitle)
        XCTAssertEqual(XCTWaiter.wait(for: [todayMonth], timeout: 5), .completed)
        resizeEventSheet(handle, timeline: timeline)
        XCTAssertEqual(handle.value as? String, "Large")
    }

    func testShortPinchesRespondAboveBothSheetSizesAndKeepTheMonthHeading() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let timeline = app.scrollViews["eventTimeline"]
        XCTAssertTrue(timeline.waitForExistence(timeout: 5))
        let handle = app.buttons["eventSheetResizeHandle"]
        for size in ["Large", "Small"] {
            XCTAssertEqual(handle.value as? String, size)
            for _ in 0..<3 {
                timeline.pinch(withScale: 0.6, velocity: -2)
                let zoomedOut = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value BEGINSWITH 'Weeks view,'"), object: timeline)
                XCTAssertEqual(XCTWaiter.wait(for: [zoomedOut], timeout: 5), .completed)
                XCTAssertEqual(app.staticTexts["appTitle"].label, Date().formatted(.dateTime.month(.wide)))
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = "Close weekly zoom above the \(size.lowercased()) sheet"
                screenshot.lifetime = .keepAlways
                add(screenshot)
                timeline.pinch(withScale: 2, velocity: 2)
                let zoomedIn = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value BEGINSWITH 'Days view,'"), object: timeline)
                XCTAssertEqual(XCTWaiter.wait(for: [zoomedIn], timeout: 5), .completed)
            }
            let beforeScroll = timeline.value as? String
            timeline.swipeLeft()
            XCTAssertNotEqual(timeline.value as? String, beforeScroll, "Single-finger scrolling must still work after pinching")
            app.buttons["scrollToToday"].tap()
            resizeEventSheet(handle, timeline: timeline)
        }
    }

    private func resizeEventSheet(_ handle: XCUIElement, timeline: XCUIElement,
                                  file: StaticString = #filePath, line: UInt = #line) {
        handle.tap()
        // The sheet's value changes before its spring finishes. Pinching the
        // destination frame too early puts one finger on the moving sheet.
        var previousFrame: CGRect?
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = timeline.frame
            defer { previousFrame = frame }
            return !frame.isEmpty && frame == previousFrame
        }, object: timeline)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed, file: file, line: line)
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
