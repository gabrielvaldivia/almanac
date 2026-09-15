import Foundation

enum CategoryStorage {
    static let widgetAliasesKey = "categories.widgetAliases"
    static let widgetAliasesBackupKey = "categories.widgetAliases.lastReadableBackup"
    static let readableCurrentKey = "categories.lastReadableCurrent"

    enum Failure: LocalizedError {
        case noBackup
        var errorDescription: String? { "No readable category backup is available. Your original data has not been changed." }
    }

    struct Recovery {
        let categories: [CategoryData]
        let categoryData: Data
        let aliasData: Data
        let currentIDs: [String: UUID]

        func categoryName(for name: String?) -> String? {
            guard let name else { return nil }
            if let id = currentIDs[name] { return categories.first { $0.id == id }?.name }
            return categories.contains { $0.name == name } ? name : nil
        }
    }

    static func decode(_ data: Data) throws -> [CategoryData] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer()
            if let legacy = try? value.decode(Double.self) { return Date(timeIntervalSinceReferenceDate: legacy) }
            let text = try value.decode(String.self)
            guard let date = ISO8601DateFormatter().date(from: text) else {
                throw DecodingError.dataCorruptedError(in: value, debugDescription: "Invalid category date")
            }
            return date
        }
        return try decoder.decode([CategoryData].self, from: data)
    }

    static func save(_ categories: [CategoryData], renaming: (from: String, to: String)? = nil,
                     defaults: UserDefaults = AppPreferences.shared) throws {
        let previousData = defaults.data(forKey: "categories")
        let previous = try previousData.map(decode) ?? []
        let previousAliases = defaults.data(forKey: widgetAliasesKey)
        var aliases = try previousAliases.map { try JSONDecoder().decode([String: UUID].self, from: $0) } ?? [:]
        let records = categories.map { category -> CategoryData in
            var record = category
            let oldName = renaming?.to == category.name ? renaming!.from : category.name
            let old = previous.first { $0.name == oldName }
            let id = old?.id ?? category.id ?? (old == nil ? nil : aliases[oldName]) ?? UUID()
            record.id = id
            // Retain these mappings after deletion or name reuse so a legacy
            // widget can never silently switch to a different category.
            if aliases[oldName] == nil { aliases[oldName] = id }
            if aliases[record.name] == nil { aliases[record.name] = id }
            return record
        }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(records)
        let aliasData = try encoder.encode(aliases)
        if let previousData {
            defaults.set(previousData, forKey: "categories.lastReadableBackup")
            if let previousAliases { defaults.set(previousAliases, forKey: widgetAliasesBackupKey) }
            else { defaults.removeObject(forKey: widgetAliasesBackupKey) }
        } else {
            defaults.set(data, forKey: "categories.lastReadableBackup")
            defaults.set(aliasData, forKey: widgetAliasesBackupKey)
        }
        defaults.set(data, forKey: "categories")
        defaults.set(aliasData, forKey: widgetAliasesKey)
        defaults.set(data, forKey: readableCurrentKey)
    }

    static func prepareRecovery(defaults: UserDefaults = AppPreferences.shared) throws -> Recovery {
        guard let backup = defaults.data(forKey: "categories.lastReadableBackup"),
              var categories = try? decode(backup) else { throw Failure.noBackup }
        let current = defaults.data(forKey: "categories").flatMap { try? decode($0) }
            ?? defaults.data(forKey: readableCurrentKey).flatMap { try? decode($0) } ?? []
        let currentIDs = Dictionary(current.compactMap { category in category.id.map { (category.name, $0) } },
                                    uniquingKeysWith: { first, _ in first })
        var aliases = defaults.data(forKey: widgetAliasesKey).flatMap { try? JSONDecoder().decode([String: UUID].self, from: $0) } ?? [:]
        if let saved = defaults.data(forKey: widgetAliasesBackupKey) {
            guard let backupAliases = try? JSONDecoder().decode([String: UUID].self, from: saved) else { throw Failure.noBackup }
            aliases.merge(backupAliases, uniquingKeysWith: { current, _ in current })
        }
        for index in categories.indices {
            if categories[index].id == nil { categories[index].id = aliases[categories[index].name] ?? UUID() }
            if aliases[categories[index].name] == nil { aliases[categories[index].name] = categories[index].id }
        }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        return Recovery(categories: categories, categoryData: try encoder.encode(categories),
                        aliasData: try encoder.encode(aliases), currentIDs: currentIDs)
    }

    static func restore(_ recovery: Recovery, defaults: UserDefaults = AppPreferences.shared) {
        for key in ["categories", widgetAliasesKey] {
            if let original = defaults.data(forKey: key), defaults.data(forKey: key + ".preservedOriginal") == nil {
                defaults.set(original, forKey: key + ".preservedOriginal")
            }
        }
        defaults.set(recovery.categoryData, forKey: "categories")
        defaults.set(recovery.categoryData, forKey: readableCurrentKey)
        defaults.set(recovery.aliasData, forKey: widgetAliasesKey)
    }

    static func widgetSelection(for category: CategoryData) -> String {
        category.id.map { "almanac-category:\($0.uuidString)" } ?? category.name
    }

    static func name(forWidgetSelection selection: String, defaults: UserDefaults = AppPreferences.shared) -> String? {
        let categories = defaults.data(forKey: "categories").flatMap { try? decode($0) } ?? []
        if selection.hasPrefix("almanac-category:") {
            guard let id = UUID(uuidString: String(selection.dropFirst("almanac-category:".count))) else { return nil }
            return categories.first { $0.id == id }?.name
        }
        if let data = defaults.data(forKey: widgetAliasesKey) {
            guard let aliases = try? JSONDecoder().decode([String: UUID].self, from: data) else { return nil }
            if let id = aliases[selection] { return categories.first { $0.id == id }?.name }
        }
        return selection
    }
}
