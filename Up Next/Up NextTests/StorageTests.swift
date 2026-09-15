import XCTest
@testable import Up_Next

final class StorageTests: XCTestCase {
    @MainActor
    private func withIsolatedAppData(_ body: (AppData) throws -> Void) async throws {
        let defaults = AppPreferences.shared
        let domain = AppPreferences.uiTestSuiteName ?? "group.UpNextIdentifier"
        let original = defaults.persistentDomain(forName: domain)
        defer {
            if let original { defaults.setPersistentDomain(original, forName: domain) }
            else { defaults.removePersistentDomain(forName: domain) }
        }
        defaults.removePersistentDomain(forName: domain)
        let data = AppData()
        let result = Result { try body(data) }
        await data.waitForNotifications()
        try result.get()
    }

    @MainActor
    func testCategoryMetadataAndColorEditsPreserveEventOverrides() async throws {
        try await withIsolatedAppData { data in
            let today = Calendar.current.startOfDay(for: Date())
            let inherited = Event(title: "Inherited", date: today, color: CodableColor(color: .blue), category: "Work")
            let overridden = Event(title: "Override", date: today, color: CodableColor(color: .orange), category: "Work")
            let unrelated = Event(title: "Other", date: today, color: CodableColor(color: .blue), category: "Social")
            data.events = [inherited, overridden, unrelated]
            data.defaultCategory = "Work"
            var category = try XCTUnwrap(data.categories.first { $0.name == "Work" })
            XCTAssertTrue(data.updateCategory(named: "Work", with: category))
            XCTAssertEqual(data.events, [inherited, overridden, unrelated], "Saving unchanged metadata must preserve all event values")
            category.name = "Career"
            XCTAssertTrue(data.updateCategory(named: "Work", with: category))
            XCTAssertEqual(data.defaultCategory, "Career")
            XCTAssertEqual(data.events.map(\.color), [inherited.color, overridden.color, unrelated.color])
            XCTAssertEqual(data.events.map(\.category), ["Career", "Career", "Social"])
            category.color = .green
            XCTAssertTrue(data.updateCategory(named: "Career", with: category))
            XCTAssertEqual(data.events.map(\.color), [CodableColor(color: .green), overridden.color, unrelated.color])
            XCTAssertEqual(data.events.map(\.id), [inherited.id, overridden.id, unrelated.id])
            let saved = try EventStore().load()
            XCTAssertEqual(saved.map(\.color), data.events.map(\.color), "The preserved overrides must also survive persistence")
            XCTAssertEqual(saved.map(\.category), data.events.map(\.category))
            XCTAssertEqual(saved.map(\.id), data.events.map(\.id))
            XCTAssertEqual(saved.map(\.date), data.events.map(\.date))
        }
    }

    @MainActor
    func testCategoryChangesAreBlockedWhileEventsNeedRecovery() async throws {
        try await withIsolatedAppData { data in
            data.events = [Event(title: "Keep", date: Date(), color: CodableColor(color: .orange), category: "Work")]
            data.defaultCategory = "Work"
            data.saveEvents(); data.saveCategories()
            let categories = AppPreferences.shared.data(forKey: "categories")
            let corrupt = Data("corrupt events".utf8)
            AppPreferences.shared.set(corrupt, forKey: "events")
            data.loadEvents()
            XCTAssertFalse(data.canEditExistingCategories)
            var renamed = data.categories[0]; renamed.name = "Career"
            XCTAssertFalse(data.updateCategory(named: "Work", with: renamed))
            XCTAssertFalse(data.removeCategories(at: IndexSet(integer: 0)))
            XCTAssertEqual(data.categories[0].name, "Work")
            XCTAssertEqual(data.events[0].category, "Work")
            XCTAssertEqual(data.defaultCategory, "Work")
            XCTAssertEqual(AppPreferences.shared.data(forKey: "categories"), categories)
            XCTAssertEqual(AppPreferences.shared.data(forKey: "events"), corrupt)
            data.restoreEventBackup()
            XCTAssertTrue(data.canEditExistingCategories)
            XCTAssertEqual(data.events[0].category, "Work")
        }
    }

    @MainActor
    func testCategoryChangeSaveFailuresLeaveBothStoresAndDefaultsIntact() async throws {
        for damagedKey in ["events", "categories"] {
            try await withIsolatedAppData { data in
                data.events = [Event(title: "Keep", date: Date(), color: CodableColor(color: .orange), category: "Work")]
                data.defaultCategory = "Work"
                data.saveEvents(); data.saveCategories()
                let originalEvents = data.events
                AppPreferences.shared.set(Data("corrupt".utf8), forKey: damagedKey)
                let keys = ["events", "events.lastReadableBackup", "categories", "categories.lastReadableBackup"]
                let originalPayloads = keys.map { AppPreferences.shared.data(forKey: $0) }
                var renamed = data.categories[0]; renamed.name = "Career"
                XCTAssertFalse(data.updateCategory(named: "Work", with: renamed), damagedKey)
                XCTAssertEqual(data.events, originalEvents)
                XCTAssertEqual(data.categories[0].name, "Work")
                XCTAssertEqual(data.defaultCategory, "Work")
                XCTAssertEqual(keys.map { AppPreferences.shared.data(forKey: $0) }, originalPayloads)
                XCTAssertFalse(data.canEditExistingCategories)
            }
        }
    }

    @MainActor
    func testDeletingCategoriesPreservesTheirEventsAndColors() async throws {
        try await withIsolatedAppData { data in
            let event = Event(title: "Keep", date: Calendar.current.startOfDay(for: Date()), color: CodableColor(color: .orange), category: "Work")
            let other = Event(title: "Other", date: event.date, color: CodableColor(color: .green), category: "Social")
            data.events = [event, other]
            data.defaultCategory = "Work"
            XCTAssertTrue(data.removeCategories(at: IndexSet(integer: 0)))
            XCTAssertNil(data.events[0].category)
            XCTAssertEqual(data.events[0].color, event.color)
            XCTAssertEqual(data.events[0].id, event.id)
            XCTAssertEqual(data.events[1], other)
            XCTAssertEqual(data.defaultCategory, "")
            XCTAssertFalse(data.categories.contains { $0.name == "Work" })
            XCTAssertEqual(try EventStore().load().map(\.category), [nil, "Social"])
            let savedCategories = try CategoryStorage.decode(XCTUnwrap(AppPreferences.shared.data(forKey: "categories")))
            XCTAssertFalse(savedCategories.contains { $0.name == "Work" })
        }
    }

    @MainActor
    func testRecurrencePagePersistsBeforePublishingAndPreservesDataOnSaveFailure() async throws {
        try await withIsolatedAppData { data in
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let event = Event(title: "Daily", date: today, color: CodableColor(color: .blue), repeatOption: .daily, seriesID: UUID())
            data.events = Recurrence.generate(event, rule: RecurrenceRule(event: event, end: .indefinitely), now: today)
            data.saveEvents()
            let firstPage = data.events
            let end = calendar.date(byAdding: .day, value: 730, to: today)!
            XCTAssertTrue(data.extendRecurrences(before: end, now: today))
            XCTAssertEqual(data.events.count, 730)
            XCTAssertEqual(Array(data.events.prefix(firstPage.count)), firstPage)
            XCTAssertEqual(try EventStore().load().map(\.id), data.events.map(\.id))
            let saved = data.events
            let corrupt = Data("corrupt".utf8)
            AppPreferences.shared.set(corrupt, forKey: "events")
            let later = calendar.date(byAdding: .day, value: 1095, to: today)!
            XCTAssertFalse(data.extendRecurrences(before: later, now: today))
            XCTAssertEqual(data.events, saved)
            XCTAssertEqual(AppPreferences.shared.data(forKey: "events"), corrupt)
            XCTAssertNotNil(data.storageError)
            XCTAssertFalse(data.extendRecurrences(before: later, now: today))
        }
    }

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
