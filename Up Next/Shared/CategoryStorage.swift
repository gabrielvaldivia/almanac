import Foundation

enum CategoryStorage {
    static let widgetAliasesKey = "categories.widgetAliases"
    static let widgetAliasesBackupKey = "categories.widgetAliases.lastReadableBackup"

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
        }
        defaults.set(data, forKey: "categories")
        defaults.set(aliasData, forKey: widgetAliasesKey)
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
