import Foundation

final class EventStore {
    enum Failure: LocalizedError {
        case duplicateIDs, noBackup
        var errorDescription: String? {
            switch self {
            case .duplicateIDs: return "The saved list contains duplicate event identifiers."
            case .noBackup: return "No readable backup is available. Your original data has not been changed."
            }
        }
    }
    private let defaults: UserDefaults
    init(defaults: UserDefaults = AppPreferences.shared) { self.defaults = defaults }

    static func decode(_ data: Data) throws -> [Event] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let events = try decoder.decode([Event].self, from: data)
        guard Set(events.map(\.id)).count == events.count else { throw Failure.duplicateIDs }
        return events
    }

    func load() throws -> [Event] {
        guard let data = defaults.data(forKey: "events") else { return [] }
        do { return try Self.decode(data) }
        catch { preserve(data); throw error }
    }

    func save(_ events: [Event]) throws {
        // Never overwrite an unreadable payload, even if a caller did not load first.
        if let existing = defaults.data(forKey: "events") {
            do { _ = try Self.decode(existing) }
            catch { preserve(existing); throw error }
            defaults.set(existing, forKey: "events.lastReadableBackup")
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(events)
        _ = try Self.decode(data)
        defaults.set(data, forKey: "events")
        if defaults.data(forKey: "events.lastReadableBackup") == nil {
            defaults.set(data, forKey: "events.lastReadableBackup")
        }
    }

    func restoreBackup() throws -> [Event] {
        guard let data = defaults.data(forKey: "events.lastReadableBackup"),
              let events = try? Self.decode(data) else { throw Failure.noBackup }
        if let current = defaults.data(forKey: "events") { preserve(current) }
        defaults.set(data, forKey: "events")
        return events
    }

    private func preserve(_ data: Data) {
        if defaults.data(forKey: "events.preservedOriginal") == nil {
            defaults.set(data, forKey: "events.preservedOriginal")
        }
    }
}
