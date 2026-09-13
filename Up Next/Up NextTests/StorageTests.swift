import XCTest
@testable import Up_Next

final class StorageTests: XCTestCase {
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
