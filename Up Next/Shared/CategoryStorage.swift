import Foundation

enum CategoryStorage {
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

    static func save(_ categories: [CategoryData], defaults: UserDefaults = AppPreferences.shared) throws {
        if let previous = defaults.data(forKey: "categories") {
            _ = try decode(previous)
            defaults.set(previous, forKey: "categories.lastReadableBackup")
        }
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        defaults.set(try encoder.encode(categories), forKey: "categories")
    }
}
