import XCTest
@testable import Up_Next

final class StorageTests: XCTestCase {
    func testCategoryCodecMigratesNumericDatesAndPreservesUnreadablePayloads() throws {
        let name = "test.categories.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let category = CategoryData(name: "Work", color: CodableColor(color: .blue), repeatOption: .never,
            showRepeatOptions: false, customRepeatCount: 1, repeatUnit: "Days", repeatUntilOption: .indefinitely,
            repeatUntilCount: 1, repeatUntil: Date())
        let legacy = try JSONEncoder().encode([category])
        XCTAssertEqual(try CategoryStorage.decode(legacy).first?.name, "Work")
        try CategoryStorage.save([category], defaults: defaults)
        XCTAssertEqual(try CategoryStorage.decode(defaults.data(forKey: "categories")!).first?.name, "Work")
        let bad = Data("broken".utf8); defaults.set(bad, forKey: "categories")
        XCTAssertThrowsError(try CategoryStorage.save([], defaults: defaults))
        XCTAssertEqual(defaults.data(forKey: "categories"), bad)
    }

    func testCategoryKeywordsPersistAndOlderCategoriesLoadWithoutKeywords() throws {
        let suite = "test.categoryKeywords.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let category = CategoryData(name: "Reading", color: CodableColor(color: .blue), repeatOption: .never,
                                    showRepeatOptions: false, customRepeatCount: 1, repeatUnit: "Days",
                                    repeatUntilOption: .indefinitely, repeatUntilCount: 1, repeatUntil: Date(),
                                    keywords: ["book club", "reading"])
        try CategoryStorage.save([category], defaults: defaults)
        let stored = try XCTUnwrap(defaults.data(forKey: "categories"))
        XCTAssertEqual(try CategoryStorage.decode(stored).first?.keywords, ["book club", "reading"])
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: stored) as? [[String: Any]])
        legacy[0].removeValue(forKey: "keywords")
        let decoded = try CategoryStorage.decode(JSONSerialization.data(withJSONObject: legacy))
        XCTAssertEqual(decoded.first?.name, "Reading")
        XCTAssertEqual(decoded.first?.keywords, [])
        var cleared = category
        cleared.keywords = []
        try CategoryStorage.save([cleared], defaults: defaults)
        XCTAssertEqual(try CategoryStorage.decode(XCTUnwrap(defaults.data(forKey: "categories"))).first?.keywords, [])
    }

    func testUnreadableEventsArePreservedAndCannotBeOverwritten() throws {
        let name = "test.storage.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = EventStore(defaults: defaults)
        let event = Event(title: "Keep me", date: Date(), color: CodableColor(color: .blue))
        try store.save([event])
        let corrupt = Data("[{bad data]".utf8)
        defaults.set(corrupt, forKey: "events")
        XCTAssertThrowsError(try store.load())
        XCTAssertThrowsError(try store.save([]))
        XCTAssertEqual(defaults.data(forKey: "events"), corrupt)
        XCTAssertEqual(defaults.data(forKey: "events.preservedOriginal"), corrupt)
        XCTAssertEqual(try store.restoreBackup().first?.id, event.id)
        XCTAssertEqual(try store.load().count, 1)
    }

    func testLegacyOptionalFieldsDecodeWithoutDroppingTheList() throws {
        let event = Event(title: "Legacy", date: Date(), color: CodableColor(color: .blue))
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        var json = try JSONSerialization.jsonObject(with: encoder.encode(event)) as! [String: Any]
        for key in ["notificationsEnabled", "repeatOption", "useCustomRepeatOptions", "repeatUntilCount"] { json.removeValue(forKey: key) }
        let decoded = try EventStore.decode(JSONSerialization.data(withJSONObject: [json]))
        XCTAssertEqual(decoded[0].id, event.id)
        XCTAssertTrue(decoded[0].notificationsEnabled)
        XCTAssertEqual(decoded[0].repeatOption, .never)
    }
}
