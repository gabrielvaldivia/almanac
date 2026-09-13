import Foundation

enum AppPreferences {
    static let shared = UserDefaults(suiteName: "group.UpNextIdentifier")!
    static let keys = ["notificationTime", "dailyNotificationEnabled", "defaultCategory", "eventStyle"]

    static func migrate(from legacy: UserDefaults = .standard, to shared: UserDefaults = shared) {
        for key in keys {
            // The last released app continued writing standard defaults after migration.
            if let latest = legacy.object(forKey: key) {
                shared.set(latest, forKey: key)
                legacy.removeObject(forKey: key)
            }
        }
    }
}
