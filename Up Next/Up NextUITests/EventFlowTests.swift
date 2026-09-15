import XCTest
import UIKit

final class EventFlowTests: XCTestCase {
    private var testStoreID = UUID().uuidString

    override func setUp() {
        super.setUp()
        // Simulator startup and XCTest transport also consume this budget.
        // Individual UI expectations still fail within their 5–10 second limits.
        executionTimeAllowance = 180
        testStoreID = UUID().uuidString
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ALMANAC_UI_TEST_ID"] = testStoreID
        return app
    }

    private func seedEvents(_ events: [(String, Int)], category: String? = nil, in app: XCUIApplication) throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        let fixtures: [[String: Any]] = events.map { name, offset in
            var fixture: [String: Any] = ["id": UUID().uuidString, "title": name,
             "date": formatter.string(from: calendar.date(byAdding: .day, value: offset, to: today)!),
             "color": ["red": 0.0, "green": 0.5, "blue": 1.0, "opacity": 1.0],
             "notificationsEnabled": false, "calendarSchemaVersion": 1]
            if let category { fixture["category"] = category }
            return fixture
        }
        app.launchEnvironment["ALMANAC_UI_TEST_EVENTS"] = String(
            decoding: try JSONSerialization.data(withJSONObject: fixtures), as: UTF8.self)
    }

    func testAComposerAcceptsCompleteTextOnFirstLaunch() {
        // Run before tests that warm up the system keyboard. Keep first-launch
        // typing covered independently of the timeline's fixture setup.
        continueAfterFailure = false
        let app = makeApp()
        app.launch()
        openComposer(app)
        let input = app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch
        let title = "First launch planning session"
        input.typeText(title)
        let entered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", title), object: input)
        XCTAssertEqual(XCTWaiter.wait(for: [entered], timeout: 5), .completed,
                       "The first keyboard entry must preserve the complete text")
        app.buttons["quickAddSubmit"].tap()
        XCTAssertTrue(app.scrollViews["eventList"].staticTexts[title].waitForExistence(timeout: 5))
    }

    func testAutomaticTimelineAndPlainListStaySynchronizedWithoutSheetResizing() throws {
        continueAfterFailure = false
        let app = makeApp()
        let prefix = "Timeline \(UUID().uuidString.prefix(6))"
        // The plain list is taller than the old sheet; provide enough rows to
        // scroll today's entire group offscreen and exercise date synchronization.
        let names = ["\(prefix) First planning session", "\(prefix) Second", "\(prefix) Later"] +
            (1...9).map { "\(prefix) Future \($0)" }
        let offsets = [0, 0, 3, 15, 20, 25, 30, 35, 40, 45, 50, 55]
        try seedEvents(Array(zip(names, offsets)), in: app)
        app.launch()
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
        // The scroll view now extends underneath its timeline inset. Start on
        // the visible list edge, below the timeline's own gesture surface.
        list.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: list.frame.width * 0.5, dy: timeline.frame.maxY - list.frame.minY + 2))
            .press(forDuration: 0.1, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        waitForTimelineLayout(timeline)
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
        let first = list.staticTexts[names[0]].firstMatch
        func isVisible(_ row: XCUIElement) -> Bool {
            row.exists && row.frame.maxY > timeline.frame.maxY && row.frame.minY < list.frame.maxY - 100
        }
        let revealed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            later.isHittable && isVisible(later) && !isVisible(first)
        }, object: list)
        XCTAssertEqual(XCTWaiter.wait(for: [revealed], timeout: 5), .completed,
                       "The list must follow the timeline: \(timeline.value as? String ?? "missing")")
        screenshot("Timeline pan scrolls the plain event list")
        let timelineAfterPan = timeline.value as? String
        // XCTest's default swipe is a 0.2-second flick. On a busy CI simulator
        // it can complete without moving the list. Use a sustained drag, then
        // verify the list's position before asserting the timeline follows it.
        func dragList(from start: CGFloat, to end: CGFloat) {
            // The list fills the viewport underneath the timeline overlay.
            // Keep both ends within the actually visible list surface.
            let top = timeline.frame.maxY - list.frame.minY + 20
            let height = list.frame.height - 100 - top
            let origin = list.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: list.frame.width * 0.5, dy: top + height * start))
                .press(forDuration: 0.1,
                       thenDragTo: origin.withOffset(CGVector(dx: list.frame.width * 0.5, dy: top + height * end)),
                       withVelocity: .slow, thenHoldForDuration: 0.3)
        }
        dragList(from: 0.15, to: 0.85)
        let firstRevealed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            first.isHittable && isVisible(first)
        }, object: list)
        XCTAssertEqual(XCTWaiter.wait(for: [firstRevealed], timeout: 5), .completed,
                       "Dragging the list back must reveal today's events")
        let todayPrefix = "Days view, \(Date().formatted(date: .abbreviated, time: .omitted))"
        let returned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value BEGINSWITH %@", todayPrefix), object: timeline)
        XCTAssertEqual(XCTWaiter.wait(for: [returned], timeout: 5), .completed,
                       "Timeline must follow the list back to today: \(timeline.value as? String ?? "missing")")
        XCTAssertNotEqual(timeline.value as? String, timelineAfterPan)
        dragList(from: 0.85, to: 0.15)
        let firstHidden = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !isVisible(first) }, object: list)
        XCTAssertEqual(XCTWaiter.wait(for: [firstHidden], timeout: 5), .completed,
                       "Dragging the list forward must move today's events offscreen")
        let advanced = XCTNSPredicateExpectation(predicate: NSPredicate(format: "NOT (value BEGINSWITH %@)", todayPrefix), object: timeline)
        XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 5), .completed,
                       "Timeline must follow the list forward: \(timeline.value as? String ?? "missing")")
        screenshot("List scrolling advances the timeline")
        if app.buttons["scrollToToday"].exists { app.buttons["scrollToToday"].tap() }
    }

    func testVerticalBrowsingKeepsTheListFrameStableAcrossTimelineDensityChanges() throws {
        continueAfterFailure = false
        let crowded = (1...4).map { ("Crowded day \($0)", 0) }
        // Calibrate against a constant-height timeline: UIKit's synthesized
        // pan includes gesture recognition and rounding beyond the endpoint delta.
        let controlApp = makeApp()
        let controlEvents = (1...12).flatMap { day in
            (1...4).map { ("Control day \(day) event \($0)", day * 7) }
        }
        try seedEvents(crowded + controlEvents, in: controlApp)
        controlApp.launch()
        let controlList = controlApp.scrollViews["eventList"]
        let controlTimeline = controlApp.scrollViews["eventTimeline"]
        XCTAssertTrue(controlList.waitForExistence(timeout: 5))
        waitForTimelineLayout(controlTimeline)
        let controlHeight = controlTimeline.frame.height
        let referenceName = (1...4).map { "Control day 1 event \($0)" }
            .min { controlList.staticTexts[$0].frame.minY < controlList.staticTexts[$1].frame.minY }!
        let controlTop = controlList.staticTexts[referenceName].frame.minY
        controlApp.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.8))
            .press(forDuration: 0.1,
                   thenDragTo: controlApp.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3)),
                   withVelocity: .slow, thenHoldForDuration: 0.3)
        waitForTimelineLayout(controlTimeline)
        let nativeDragDistance = controlTop - controlList.staticTexts[referenceName].frame.minY
        XCTAssertEqual(controlTimeline.frame.height, controlHeight, accuracy: 1)
        controlApp.terminate()
        testStoreID = UUID().uuidString

        let app = makeApp()
        let sparse = (1...12).map { ("Later event \($0)", $0 * 15) }
        try seedEvents(crowded + sparse, in: app)
        app.launch()
        let list = app.scrollViews["eventList"]
        let timeline = app.scrollViews["eventTimeline"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        waitForTimelineLayout(timeline)
        let initialTop = list.frame.minY
        let initialHeight = timeline.frame.height
        let todayPrefix = "Days view, \(Date().formatted(date: .abbreviated, time: .omitted))"

        for index in 0..<3 {
            let referenceTop = index == 0 ? list.staticTexts["Later event 1"].frame.minY : 0
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.8))
                .press(forDuration: 0.1,
                       thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.3)),
                       withVelocity: .slow, thenHoldForDuration: 0.3)
            waitForTimelineLayout(timeline)
            XCTAssertEqual(list.frame.minY, initialTop, accuracy: 1,
                           "Following list dates must not resize the viewport under the user's finger")
            if index == 0 {
                XCTAssertEqual(referenceTop - list.staticTexts["Later event 1"].frame.minY, nativeDragDistance, accuracy: 4,
                               "The row must follow only the finger, without an extra jump when the timeline resizes")
            }
        }
        XCTAssertFalse((timeline.value as? String ?? "").hasPrefix(todayPrefix),
                       "The timeline must still follow vertical scrolling")
        XCTAssertFalse(list.staticTexts["Crowded day 1"].isHittable)

        let resized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            timeline.frame.height < initialHeight - 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [resized], timeout: 5), .completed,
                       "Following quiet dates must shrink the timeline while browsing the list")
        for _ in 0..<5 where !(timeline.value as? String ?? "").hasPrefix(todayPrefix) {
            list.swipeDown()
        }
        let expanded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            timeline.frame.height >= initialHeight - 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expanded], timeout: 5), .completed,
                       "Following crowded dates must expand the timeline again")
        XCTAssertEqual(list.frame.minY, initialTop, accuracy: 1)
        for index in 1...4 {
            let marker = timeline.buttons["Crowded day \(index)"]
            XCTAssertTrue(marker.isHittable, "Every overlapping event must fit in the expanded timeline")
            XCTAssertLessThanOrEqual(marker.frame.maxY, timeline.frame.maxY)
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Timeline expands for overlapping events after vertical scrolling"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testVerticalBrowsingExpandsTheTimelineBeyondItsInitialInset() throws {
        continueAfterFailure = false
        let app = makeApp()
        let crowded = (1...4).map { ("Overlapping event \($0)", 15) }
        let later = (1...8).map { ("Later \($0)", 30 + $0 * 15) }
        try seedEvents([("Quiet today", 0)] + crowded + later, in: app)
        app.launch()
        let timeline = app.scrollViews["eventTimeline"]
        let list = app.scrollViews["eventList"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        waitForTimelineLayout(timeline)
        let initialHeight = timeline.frame.height
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.8))
            .press(forDuration: 0.1,
                   thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.6)),
                   withVelocity: .slow, thenHoldForDuration: 0.3)
        let expanded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            timeline.frame.height > initialHeight + 50
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expanded], timeout: 5), .completed)
        for index in 1...4 {
            let marker = timeline.buttons["Overlapping event \(index)"]
            XCTAssertTrue(marker.isHittable, "Expanded markers must remain visible and interactive beyond the original inset")
            XCTAssertLessThanOrEqual(marker.frame.maxY, timeline.frame.maxY)
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Timeline grows beyond its original inset without clipping"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testShowMoreAppends365DayPagesWithoutMovingTheCurrentRow() throws {
        continueAfterFailure = false
        let app = makeApp()
        try seedEvents([("Today event", 0), ("First page end", 364), ("Second page start", 365),
                        ("Second page end", 729), ("Third page start", 730)], in: app)
        app.launch()
        let list = app.scrollViews["eventList"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        waitForTimelineLayout(app.scrollViews["eventTimeline"])
        XCTAssertTrue(list.staticTexts["First page end"].isHittable)
        XCTAssertFalse(list.staticTexts["Second page start"].exists)
        let initialRow = list.staticTexts["Today event"].frame
        let more = list.buttons["showMoreEvents"]
        more.tap()
        XCTAssertTrue(list.staticTexts["Second page start"].waitForExistence(timeout: 5))
        XCTAssertEqual(list.staticTexts["Today event"].frame.minY, initialRow.minY, accuracy: 1)
        XCTAssertFalse(list.staticTexts["Third page start"].exists)
        for _ in 0..<3 where !more.isHittable { list.swipeUp() }
        more.tap()
        for _ in 0..<3 where !list.staticTexts["Third page start"].isHittable { list.swipeUp() }
        XCTAssertTrue(list.staticTexts["Third page start"].isHittable)
        XCTAssertFalse(more.exists, "The button disappears once all later events are loaded")
    }

    func testShowMoreGeneratesSparseRecurrencesWithoutMovingTheCurrentRow() throws {
        continueAfterFailure = false
        let app = makeApp()
        try seedEvents([("Every two years", 0)], in: app)
        let encoded = Data(app.launchEnvironment["ALMANAC_UI_TEST_EVENTS"]!.utf8)
        var fixtures = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [[String: Any]])
        let anchor = fixtures[0]["date"]!
        let until = Calendar.current.date(byAdding: .year, value: 2, to: Calendar.current.startOfDay(for: Date()))!
        fixtures[0]["seriesID"] = UUID().uuidString
        fixtures[0]["repeatOption"] = "Custom"
        fixtures[0]["customRepeatCount"] = 2
        fixtures[0]["repeatUnit"] = "Years"
        fixtures[0]["occurrenceIndex"] = 0
        fixtures[0]["recurrence"] = ["anchor": anchor, "frequency": "Custom", "interval": 2,
                                     "unit": "Years", "end": "On Date", "until": ISO8601DateFormatter().string(from: until), "count": 1]
        app.launchEnvironment["ALMANAC_UI_TEST_EVENTS"] = String(decoding: try JSONSerialization.data(withJSONObject: fixtures), as: UTF8.self)
        app.launch()
        let list = app.scrollViews["eventList"]
        let rows = list.staticTexts.matching(identifier: "Every two years")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        let originalY = rows.firstMatch.frame.minY
        let more = list.buttons["showMoreEvents"]
        XCTAssertTrue(more.exists)
        more.tap()
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.firstMatch.frame.minY, originalY, accuracy: 1)
        more.tap()
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == 2"), object: rows)
        XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 5), .completed)
        XCTAssertEqual(rows.firstMatch.frame.minY, originalY, accuracy: 1)
        XCTAssertFalse(more.exists)
        app.terminate(); app.launch()
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        more.tap(); more.tap()
        XCTAssertEqual(rows.count, 2, "Reloading pages must preserve the saved recurrence without duplicates")
    }

    func testShowMoreCanAdvanceThroughEmpty365DayPages() throws {
        continueAfterFailure = false
        let app = makeApp()
        try seedEvents([("Distant event", 800)], in: app)
        app.launch()
        let list = app.scrollViews["eventList"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        XCTAssertTrue(list.staticTexts["No events in the next 365 days"].exists)
        list.buttons["showMoreEvents"].tap()
        XCTAssertTrue(list.staticTexts["No events in the next 730 days"].exists)
        list.buttons["showMoreEvents"].tap()
        XCTAssertTrue(list.staticTexts["Distant event"].waitForExistence(timeout: 5))
        XCTAssertFalse(list.buttons["showMoreEvents"].exists)
    }

    func testPinchZoomsTheAutomaticallySizedTimelineThroughEveryScale() {
        continueAfterFailure = false
        let app = makeApp()
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
        // Land clearly inside the month-heading range, allowing for the native
        // pinch recognizer's scale variation as the timeline changes height.
        timeline.pinch(withScale: 6.5, velocity: 2)
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
        let app = makeApp()
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
        let app = makeApp()
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

    func testComposerLayoutAndShortDragPreserveTheListAndKeyboard() throws {
        continueAfterFailure = false
        let app = makeApp()
        try seedEvents([("Composer layout", 0)], in: app)
        app.launch()
        let list = app.scrollViews["eventList"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let timeline = app.scrollViews["eventTimeline"]
        waitForTimelineLayout(timeline)
        let listFrame = list.frame
        let timelineFrame = timeline.frame
        openComposer(app)
        XCTAssertEqual(list.frame.minY, listFrame.minY, accuracy: 1)
        XCTAssertEqual(list.frame.maxY, listFrame.maxY, accuracy: 1,
                       "The list must remain extended behind the keyboard")
        XCTAssertEqual(timeline.frame.height, timelineFrame.height, accuracy: 1)
        let input = app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch
        input.typeText("Dinner #Work tomorrow")
        let color = app.buttons["quickEventColor"]
        XCTAssertGreaterThanOrEqual(color.frame.width, 44)
        XCTAssertEqual(color.frame.midY, input.frame.midY, accuracy: 1)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Composer with event color beside text"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        XCTAssertFalse(app.buttons["manualEventInput"].exists)
        let handle = app.buttons["quickEntryDragHandle"]
        XCTAssertTrue(handle.isHittable)
        XCTAssertLessThan(handle.frame.maxY, input.frame.minY)
        let handleCenter = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let restingInputFrame = input.frame
        // A short drag follows the finger and returns without dismissing.
        handleCenter.press(forDuration: 0.05,
                           thenDragTo: handleCenter.withOffset(CGVector(dx: 0, dy: 30)),
                           withVelocity: .slow, thenHoldForDuration: 1)
        let returnedToRest = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            abs(input.frame.minY - restingInputFrame.minY) < 1
        }, object: input)
        XCTAssertEqual(XCTWaiter.wait(for: [returnedToRest], timeout: 5), .completed)
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertEqual(input.value as? String, "Dinner #Work tomorrow")
    }

    func testComposerSwipeDismissalRetainsDraftAndSelections() {
        continueAfterFailure = false
        let app = makeApp()
        app.launch()
        openComposer(app)
        let input = app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch
        input.typeText("Dinner #Work tomorrow")
        let color = app.buttons["quickEventColor"]
        color.tap()
        app.collectionViews.buttons["Orange"].tap()
        XCTAssertEqual(color.value as? String, "Orange")
        app.buttons["quickEventCategory"].tap()
        app.collectionViews.buttons["Social"].tap()
        XCTAssertTrue(input.exists)
        XCTAssertEqual(app.buttons["quickEventCategory"].value as? String, "Social")
        XCTAssertEqual(color.value as? String, "Orange")
        let handleCenter = app.buttons["quickEntryDragHandle"]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        handleCenter.press(forDuration: 0.05, thenDragTo: handleCenter.withOffset(CGVector(dx: 0, dy: 100)))
        XCTAssertTrue(app.buttons["quickAddButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(input.exists)
        openComposer(app)
        XCTAssertEqual(input.value as? String, "Dinner #Work tomorrow")
        XCTAssertEqual(app.buttons["quickEventCategory"].value as? String, "Social")
        XCTAssertEqual(color.value as? String, "Orange")
        color.tap()
        app.collectionViews.buttons["Use Category Color"].tap()
        XCTAssertNotEqual(color.value as? String, "Orange")
        let fieldCenter = input.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        fieldCenter.press(forDuration: 0.05, thenDragTo: fieldCenter.withOffset(CGVector(dx: 0, dy: 120)))
        XCTAssertTrue(app.buttons["quickAddButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(input.exists)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
    }

    func testComposerOutsideTapAndHandleTapDismissWithoutLosingDraft() {
        continueAfterFailure = false
        let app = makeApp()
        app.launch()
        openComposer(app)
        let input = app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch
        input.typeText("Dinner tomorrow")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        XCTAssertTrue(app.buttons["quickAddButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(input.exists)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        openComposer(app)
        XCTAssertEqual(input.value as? String, "Dinner tomorrow")
        app.staticTexts["appTitle"].tap()
        XCTAssertTrue(app.buttons["quickAddButton"].waitForExistence(timeout: 5))
        openComposer(app)
        XCTAssertEqual(input.value as? String, "Dinner tomorrow")
        app.buttons["quickEntryDragHandle"].tap()
        XCTAssertTrue(app.buttons["quickAddButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(input.exists)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
    }

    func testComposerParsesPillsAndSavesQuickEdits() {
        continueAfterFailure = false
        let app = makeApp()
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

    func testComposerCreatesAndSelectsACategoryWithoutLosingTheDraft() {
        continueAfterFailure = false
        let app = makeApp()
        app.launch()
        openComposer(app)
        let suffix = String(UUID().uuidString.prefix(6))
        let eventTitle = "Category event \(suffix)"
        let categoryName = "Reading \(suffix)"
        let input = app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch
        let category = app.buttons["quickEventCategory"]
        input.typeText("\(eventTitle) today")
        let previousCategory = category.value as? String
        category.tap()
        XCTAssertEqual(app.collectionViews.buttons.allElementsBoundByIndex.last?.label, "New category")
        let menuScreenshot = XCTAttachment(screenshot: app.screenshot())
        menuScreenshot.name = "New category at the bottom of the composer menu"
        menuScreenshot.lifetime = .keepAlways
        add(menuScreenshot)
        app.collectionViews.buttons["New category"].tap()
        let field = app.textFields["Category Name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let save = app.navigationBars["Add Category"].buttons["Save"]
        XCTAssertFalse(save.isEnabled)
        field.tap(); field.typeText("Work")
        XCTAssertFalse(save.isEnabled, "Existing category names must remain protected")
        app.navigationBars["Add Category"].buttons["Cancel"].tap()
        XCTAssertEqual(input.value as? String, "\(eventTitle) today")
        XCTAssertEqual(category.value as? String, previousCategory)

        category.tap()
        app.collectionViews.buttons["New category"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled, "A canceled category must not leave a name in the next form")
        field.tap(); field.typeText(categoryName)
        app.buttons["Color"].tap()
        app.buttons["Green"].tap()
        let keywords = app.textViews["categoryKeywords"]
        XCTAssertTrue(keywords.waitForExistence(timeout: 5))
        keywords.tap(); keywords.typeText("book club, reading")
        let keywordScreenshot = XCTAttachment(screenshot: app.screenshot())
        keywordScreenshot.name = "Category keywords text area"
        keywordScreenshot.lifetime = .keepAlways
        add(keywordScreenshot)
        save.tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, "\(eventTitle) today")
        XCTAssertEqual(category.value as? String, categoryName)
        XCTAssertTrue(category.isSelected)
        XCTAssertEqual(app.buttons["quickEventColor"].value as? String, "Green")
        let selectedScreenshot = XCTAttachment(screenshot: app.screenshot())
        selectedScreenshot.name = "New category selected in the unchanged event draft"
        selectedScreenshot.lifetime = .keepAlways
        add(selectedScreenshot)
        app.buttons["quickAddSubmit"].tap()
        XCTAssertTrue(app.staticTexts[eventTitle].waitForExistence(timeout: 5))

        app.terminate(); app.launch()
        let title = app.staticTexts[eventTitle].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        XCTAssertTrue(app.navigationBars["Edit Event"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[categoryName].exists)
        app.buttons["Delete Event"].tap()
        app.alerts["Delete Event"].buttons["Delete this event"].tap()
        openComposer(app)
        input.typeText("Book club tomorrow")
        XCTAssertEqual(category.value as? String, categoryName, "Saved keywords should select the category after relaunch")
        XCTAssertEqual(app.buttons["quickEventColor"].value as? String, "Green")
        category.tap()
        XCTAssertTrue(app.collectionViews.buttons[categoryName].exists)
        app.collectionViews.buttons[categoryName].tap()
        XCTAssertEqual(app.buttons["quickEventColor"].value as? String, "Green")
        app.staticTexts["appTitle"].tap()
        app.buttons["Settings"].tap()
        app.buttons["Manage Categories"].tap()
        app.buttons[categoryName].swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons[categoryName].waitForNonExistence(timeout: 5))
    }

    func testComposerAutomaticallySelectsBirthdayCategoryAndRespectsManualChoice() {
        continueAfterFailure = false
        let app = makeApp()
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
        let app = makeApp()
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
        XCTAssertTrue(app.buttons["calendarRemoveEndDate"].exists)
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
        let input = app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        // A cold simulator can spend seconds on each accessibility query. Wait
        // directly for the interaction we need instead of requiring identical
        // frames from multiple snapshots while the keyboard is appearing.
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: input)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed,
                       "The composer field must be tappable before typing")
        input.tap()
    }

    func testInlineCalendarSelectsAndSavesARangeAcrossMonths() {
        continueAfterFailure = false
        let app = makeApp()
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
        let endpoints = app.segmentedControls["calendarEndpoint"]
        XCTAssertFalse(endpoints.exists)
        XCTAssertTrue(app.buttons["calendarAddEndDate"].isHittable)
        XCTAssertFalse(app.buttons["calendarRemoveEndDate"].exists)
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
        let addEnd = app.buttons["calendarAddEndDate"]
        XCTAssertTrue(addEnd.isHittable)
        XCTAssertGreaterThanOrEqual(addEnd.frame.minY, app.buttons["calendarDay-\(lastDay)"].frame.maxY)
        screenshot("Inline calendar with all six weeks visible")
        addEnd.tap()
        // Adding the segment must leave all six calendar rows and the action visible.
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let endMonth = calendar.dateInterval(of: .month, for: tomorrow)!.start
        let monthsToSixWeekMonth = calendar.dateComponents([.month], from: sixWeekMonth, to: endMonth).month!
        for _ in 0..<monthsToSixWeekMonth { app.buttons["Previous month"].tap() }
        XCTAssertTrue(app.buttons["calendarDay-\(lastDay)"].isHittable)
        XCTAssertTrue(app.buttons["calendarRemoveEndDate"].isHittable)
        screenshot("Six-week calendar with range controls and remove action")
        app.buttons["calendarRemoveEndDate"].tap()
        // Removing the end returns to the start date's month.
        app.buttons["calendarDay-28"].tap()
        screenshot("Inline calendar with single date")
        app.buttons["calendarAddEndDate"].tap()
        XCTAssertTrue(endpoints.buttons["End"].isSelected)
        XCTAssertFalse(app.buttons["calendarAddEndDate"].exists)
        let defaultEnd = calendar.date(byAdding: .day, value: 28, to: month)!
        let defaultEndDay = calendar.component(.day, from: defaultEnd)
        XCTAssertEqual(app.buttons["calendarDay-\(defaultEndDay)"].value as? String, "End date")
        if calendar.isDate(defaultEnd, equalTo: month, toGranularity: .month) { app.buttons["Next month"].tap() }
        app.buttons["calendarDay-3"].tap()
        XCTAssertTrue(app.buttons["calendarDay-1"].isSelected)
        XCTAssertTrue(app.buttons["calendarDay-2"].isSelected)
        XCTAssertTrue(app.buttons["calendarDay-3"].isSelected)
        XCTAssertFalse(app.buttons["calendarDay-4"].isSelected)
        screenshot("Inline calendar with range continuing into next month")
        XCTAssertGreaterThanOrEqual(app.buttons["calendarRemoveEndDate"].frame.minY,
                                   app.buttons["calendarDay-28"].frame.maxY)
        XCTAssertTrue(endpoints.buttons["End"].isSelected, "Choosing a day keeps the current segment selected")
        endpoints.buttons["Start"].tap()
        XCTAssertTrue(app.buttons["calendarDay-28"].isSelected)
        screenshot("Inline calendar with range starting in previous month")
        endpoints.buttons["End"].tap()
        XCTAssertTrue(app.buttons["calendarDay-3"].isSelected, "Switching endpoints reveals its month")
        app.navigationBars["Dates"].buttons["Done"].tap()

        // Reopening preserves both endpoints; turning the range off keeps its start.
        openDates()
        XCTAssertTrue(app.buttons["calendarRemoveEndDate"].exists)
        app.buttons["calendarRemoveEndDate"].tap()
        XCTAssertFalse(endpoints.exists)
        XCTAssertTrue(app.buttons["calendarAddEndDate"].isHittable)
        XCTAssertFalse(app.buttons["calendarRemoveEndDate"].exists)
        XCTAssertTrue(app.buttons["calendarDay-28"].isSelected)
        app.buttons["calendarAddEndDate"].tap()
        XCTAssertEqual(app.buttons["calendarDay-\(defaultEndDay)"].value as? String, "End date")
        if calendar.isDate(defaultEnd, equalTo: month, toGranularity: .month) { app.buttons["Next month"].tap() }
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
        let app = makeApp()
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
        let app = makeApp()
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
        let app = makeApp()
        app.launch()
        let name = "Category \(UUID().uuidString.prefix(8))", renamed = name + " edited"
        app.buttons["Settings"].tap()
        app.buttons["Manage Categories"].tap()
        XCTAssertTrue(app.buttons["Add Category"].waitForExistence(timeout: 5))
        app.buttons["Add Category"].tap()
        let field = app.textFields["Category Name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText(name)
        let keywords = app.textViews["categoryKeywords"]
        keywords.tap(); keywords.typeText("chapter")
        let keyboardBackground = XCTAttachment(screenshot: app.screenshot())
        keyboardBackground.name = "Category background extends behind keyboard corners"
        keyboardBackground.lifetime = .keepAlways
        add(keyboardBackground)
        app.navigationBars["Add Category"].buttons["Save"].tap()
        app.buttons[name].tap()
        XCTAssertTrue(app.navigationBars["Edit Category"].waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, name)
        field.tap(); field.typeText(" edited")
        XCTAssertEqual(keywords.value as? String, "chapter")
        keywords.tap()
        // Focus first, then place the cursor after the existing first line.
        keywords.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.2)).tap()
        keywords.typeText(", library")
        app.navigationBars["Edit Category"].buttons["Save"].tap()
        XCTAssertTrue(app.buttons[renamed].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        app.buttons["Settings"].tap()
        app.buttons["Manage Categories"].tap()
        XCTAssertTrue(app.buttons[renamed].waitForExistence(timeout: 5))
        app.buttons[renamed].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, renamed)
        XCTAssertEqual(keywords.value as? String, "chapter, library")
        app.navigationBars["Edit Category"].buttons["Cancel"].tap()
        app.buttons[renamed].swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(app.buttons[renamed].waitForNonExistence(timeout: 5))
    }

    func testCreateEditPersistAndDeleteEvent() {
        continueAfterFailure = false
        let app = makeApp()
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

    func testCancelingNewCategoryPreservesTheFullEditorsExistingSelection() throws {
        continueAfterFailure = false
        let app = makeApp()
        let title = "Category cancellation"
        try seedEvents([(title, 0)], category: "Work", in: app)
        app.launch()
        let row = app.scrollViews["eventList"].staticTexts[title]
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        XCTAssertTrue(app.navigationBars["Edit Event"].waitForExistence(timeout: 5))
        app.buttons["Work"].tap()
        app.buttons["Add Category"].tap()
        XCTAssertTrue(app.navigationBars["Add Category"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Work"].waitForExistence(timeout: 5))
        app.navigationBars["Edit Event"].buttons["Save"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        XCTAssertTrue(app.buttons["Work"].waitForExistence(timeout: 5), "Canceling category creation must not remove Work when the event is saved")
    }

    func testTimelineFollowsVisibleRowsWithoutRevealingEarlierRowsWhenItShrinks() throws {
        continueAfterFailure = false
        let app = makeApp()
        let fixtures = [("Quiet", 0)] + (1...4).map { ("Crowded \($0)", 15) } +
            (1...10).map { ("Later \($0)", 15 + $0 * 15) }
        try seedEvents(fixtures, in: app)
        app.launch()
        let list = app.scrollViews["eventList"]
        let timeline = app.scrollViews["eventTimeline"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let originalFrame = list.frame
        func drag(_ distance: CGFloat) {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.7))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)),
                        withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        func expectFocus(offset: Int) {
            let date = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
            let prefix = "Days view, \(date.formatted(date: .abbreviated, time: .omitted))"
            let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value BEGINSWITH %@", prefix), object: timeline)
            XCTAssertEqual(XCTWaiter.wait(for: [focused], timeout: 5), .completed)
        }
        for _ in 0..<9 { drag(-55) }
        let crowded = list.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Crowded")).allElementsBoundByIndex
        XCTAssertTrue(crowded.allSatisfy { $0.frame.maxY < timeline.frame.maxY })
        XCTAssertGreaterThan(list.staticTexts["Later 1"].frame.minY, timeline.frame.maxY)
        expectFocus(offset: 30)
        let expandedHeight = timeline.frame.height
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Timeline follows the first visible October card"; screenshot.lifetime = .keepAlways; add(screenshot)
        drag(-55)
        expectFocus(offset: 30)
        XCTAssertLessThan(timeline.frame.height, expandedHeight)
        drag(55)
        expectFocus(offset: 30)
        for _ in 0..<3 { drag(55) }
        expectFocus(offset: 15)
        let finalFrame = list.frame
        XCTAssertEqual(finalFrame.minX, originalFrame.minX, accuracy: 0.5)
        XCTAssertEqual(finalFrame.minY, originalFrame.minY, accuracy: 0.5)
        XCTAssertEqual(finalFrame.width, originalFrame.width, accuracy: 0.5)
        XCTAssertEqual(finalFrame.height, originalFrame.height, accuracy: 0.5)
    }
}
