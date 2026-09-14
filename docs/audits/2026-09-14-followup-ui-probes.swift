// Audit reproductions/diagnostics, NOT desired-behavior regression assertions.
// Append to EventFlowTests.swift only in a disposable copy for reproduction.
import XCTest
import UIKit

final class RemainingAuditUIProbes: XCTestCase {
    func app(events: [(String, Int)], category: String? = nil) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ALMANAC_UI_TEST_ID"] = UUID().uuidString
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        let fixtures: [[String: Any]] = events.map { title, offset in
            var record: [String: Any] = ["id": UUID().uuidString, "title": title,
                "date": formatter.string(from: calendar.date(byAdding: .day, value: offset, to: today)!),
                "color": ["red": 0.0, "green": 0.5, "blue": 1.0, "opacity": 1.0],
                "notificationsEnabled": false, "calendarSchemaVersion": 1]
            if let category { record["category"] = category }
            return record
        }
        app.launchEnvironment["ALMANAC_UI_TEST_EVENTS"] = String(decoding: try JSONSerialization.data(withJSONObject: fixtures), as: UTF8.self)
        return app
    }
    func capture(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }

    func testCancelingNewCategoryClearsExistingEventCategory() throws {
        continueAfterFailure = false
        let app = try app(events: [("Category cancellation probe", 0)], category: "Work")
        app.launch()
        let row = app.scrollViews["eventList"].staticTexts["Category cancellation probe"]
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        XCTAssertTrue(app.navigationBars["Edit Event"].waitForExistence(timeout: 5))
        app.buttons["Work"].tap()
        app.buttons["Add Category"].tap()
        XCTAssertTrue(app.navigationBars["Add Category"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["None"].waitForExistence(timeout: 5), "Observed bug: canceling category creation cleared Work")
        capture("Cancel category changed Work to None", app)
        app.buttons["Save"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        XCTAssertTrue(app.buttons["None"].waitForExistence(timeout: 5), "The unwanted category change also persists")
        app.terminate()
    }

    func testFullEditorCannotCommitItsInitiallySelectedEndDate() throws {
        continueAfterFailure = false
        let app = try app(events: [("Same day end probe", 0)])
        app.launch()
        let row = app.scrollViews["eventList"].staticTexts["Same day end probe"]
        XCTAssertTrue(row.waitForExistence(timeout: 5)); row.tap()
        app.buttons["End date"].tap()
        let picker = app.datePickers.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let selected = picker.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Today,")).firstMatch
        XCTAssertTrue(selected.isSelected); selected.tap()
        XCTAssertTrue(picker.exists, "Observed bug: tapping the selected start day cannot add a same-day end")
        XCTAssertEqual(app.buttons["End date"].value as? String, "None")
        capture("Same-day end selection has no effect", app)
        let formatter = DateFormatter(); formatter.dateFormat = "EEEE, MMMM d"
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        picker.buttons[formatter.string(from: tomorrow)].tap()
        XCTAssertTrue(picker.waitForNonExistence(timeout: 5), "Control: another day commits and closes the picker")
        XCTAssertNotEqual(app.buttons["End date"].value as? String, "None")
        app.terminate()
    }

    func testInspectFocusWhileOverlayChangesHeight() throws {
        continueAfterFailure = false
        let fixtures = [("Quiet", 0)] + (1...4).map { ("Crowded \($0)", 15) } + (1...10).map { ("Later \($0)", 15 + $0 * 15) }
        let app = try app(events: fixtures)
        app.launch()
        XCTAssertTrue(app.scrollViews["eventList"].waitForExistence(timeout: 5))
        let timeline = app.scrollViews["eventTimeline"]
        for step in 0..<14 {
            let visible = fixtures.compactMap { title, day -> String? in
                let row = app.scrollViews["eventList"].staticTexts[title]
                guard row.exists else { return nil }
                let frame = row.frame
                guard frame.maxY + 14 > timeline.frame.maxY && frame.minY < app.frame.height - 90 else { return nil }
                return "\(title) day=\(day) y=\(frame.minY)...\(frame.maxY)"
            }
            print("AUDIT FOCUS step=\(step) bottom=\(timeline.frame.maxY) height=\(timeline.frame.height) value=\(timeline.value ?? "nil") visible=\(visible)")
            if step == 9 {
                let crowded = app.scrollViews["eventList"].buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Crowded")).allElementsBoundByIndex
                XCTAssertFalse(crowded.isEmpty)
                XCTAssertTrue(crowded.allSatisfy { $0.frame.maxY < timeline.frame.maxY }, "All crowded event cards are covered by the header")
                let crowdedDate = Calendar.current.date(byAdding: .day, value: 15, to: Date())!
                XCTAssertTrue((timeline.value as? String ?? "").hasPrefix("Days view, \(crowdedDate.formatted(date: .abbreviated, time: .omitted))"),
                              "Observed bug: timeline still follows the fully hidden group")
                print("AUDIT HIDDEN CARDS maxY=\(crowded.map { $0.frame.maxY }) overlayBottom=\(timeline.frame.maxY)")
                capture("Timeline follows fully hidden September cards", app)
            }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.7)).press(forDuration: 0.05,
                thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.7)).withOffset(CGVector(dx: 0, dy: -55)),
                withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        app.terminate()
    }

    func testLandscapeLayoutRetainsReachableControls() throws {
        continueAfterFailure = false
        let app = try app(events: (1...12).map { ("Landscape \($0)", $0 * 10) })
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait; app.terminate() }
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = NSPredicate { _, _ in app.frame.width > app.frame.height }
        _ = expectation(for: landscape, evaluatedWith: app)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.buttons["quickAddButton"].waitForExistence(timeout: 5))
        print("AUDIT LANDSCAPE app=\(app.frame) list=\(app.scrollViews["eventList"].frame)")
        capture("Landscape event list", app)
        app.buttons["quickAddButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch.waitForExistence(timeout: 5))
        capture("Landscape composer", app)
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screen.name = "Settled landscape screen"; screen.lifetime = .keepAlways; add(screen)
    }

    func testCaptureLargeTextLayout() throws {
        let app = try app(events: [("Accessibility event with a long title to exercise wrapping", 0), ("Later", 15)])
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.scrollViews["eventList"].waitForExistence(timeout: 5))
        capture("Largest text event list", app)
        print("AUDIT LARGE TEXT \(app.debugDescription)")
        app.buttons["quickAddButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "quickEventInput").firstMatch.waitForExistence(timeout: 5))
        capture("Largest text composer", app)
    }

    func testCollectAccessibilityFindings() throws {
        let app = try app(events: [("Accessibility event with a long title to exercise wrapping", 0), ("Later", 15)])
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.scrollViews["eventList"].waitForExistence(timeout: 5))
        func audit(_ screen: String) throws {
            try app.performAccessibilityAudit { issue in
                print("AUDIT ACCESSIBILITY \(screen): \(issue.compactDescription); \(issue.detailedDescription); element=\(issue.element?.debugDescription ?? "none")")
                // Collect findings as evidence instead of calling an observed defect a test regression.
                return true
            }
            capture("Accessibility \(screen)", app)
        }
        try audit("event list")
        app.buttons["quickAddButton"].tap()
        try audit("composer")
    }
}
