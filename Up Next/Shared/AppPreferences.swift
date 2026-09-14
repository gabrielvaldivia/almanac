import Foundation

enum AppPreferences {
    // UI tests get their own persistent store, retained across relaunches within
    // a test. This cannot redirect storage on a device or in a Release build.
    static let uiTestSuiteName: String? = {
        #if DEBUG && targetEnvironment(simulator)
        if let value = ProcessInfo.processInfo.environment["ALMANAC_UI_TEST_ID"],
           let id = UUID(uuidString: value) {
            return "almanac.ui-tests.\(id.uuidString)"
        }
        #endif
        return nil
    }()
    static let shared = UserDefaults(suiteName: uiTestSuiteName ?? "group.UpNextIdentifier")!
    static let keys = ["notificationTime", "dailyNotificationEnabled", "defaultCategory", "eventStyle"]

    static func reminderComponents(defaults: UserDefaults = shared) -> DateComponents {
        DateComponents(hour: min(23, max(0, defaults.object(forKey: "notificationHour") as? Int ?? 8)),
                       minute: min(59, max(0, defaults.object(forKey: "notificationMinute") as? Int ?? 0)))
    }

    static func reminderTime(now: Date = Date(), calendar: Calendar = .current, defaults: UserDefaults = shared) -> Date {
        let parts = reminderComponents(defaults: defaults)
        return calendar.date(bySettingHour: parts.hour!, minute: parts.minute!, second: 0, of: now) ?? now
    }

    static func saveReminderTime(_ date: Date, calendar: Calendar = .current, defaults: UserDefaults = shared) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        defaults.set(parts.hour, forKey: "notificationHour")
        defaults.set(parts.minute, forKey: "notificationMinute")
        defaults.removeObject(forKey: "notificationTime")
    }

    static func migrate(from legacy: UserDefaults = .standard, to shared: UserDefaults = shared) {
        for key in keys {
            // The last released app continued writing standard defaults after migration.
            if let latest = legacy.object(forKey: key) {
                shared.set(latest, forKey: key)
                legacy.removeObject(forKey: key)
            }
        }
        if let legacyTime = shared.object(forKey: "notificationTime") as? Date {
            saveReminderTime(legacyTime, defaults: shared)
        }
    }
}
