//
//  AppData.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI
import WidgetKit // Add this import
import UserNotifications

struct Event: Identifiable, Codable {
    var id = UUID()
    var title: String
    var date: Date
    var endDate: Date?
    var color: CodableColor
    var category: String?
    var notificationsEnabled: Bool = true
    var repeatOption: RepeatOption = .never
    var repeatUntil: Date?

    init(title: String, date: Date, endDate: Date? = nil, color: CodableColor, category: String? = nil, notificationsEnabled: Bool = true, repeatOption: RepeatOption = .never, repeatUntil: Date? = nil) {
        self.title = title
        self.date = date
        self.endDate = endDate
        self.color = color
        self.category = category
        self.notificationsEnabled = notificationsEnabled
        self.repeatOption = repeatOption
        self.repeatUntil = repeatUntil
        print("Event initialized: \(self)")
    }
}

enum RepeatOption: String, Codable, CaseIterable {
    case never = "Never"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
}

struct CategoryData: Codable {
    let name: String
    let color: CodableColor
}

struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    init(color: Color) {
        if let components = UIColor(color).cgColor.components {
            self.red = Double(components[0])
            self.green = Double(components[1])
            self.blue = Double(components[2])
            self.opacity = Double(components[3])
        } else {
            self.red = 0
            self.green = 0
            self.blue = 0
            self.opacity = 1
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        red = try container.decode(Double.self, forKey: .red)
        green = try container.decode(Double.self, forKey: .green)
        blue = try container.decode(Double.self, forKey: .blue)
        opacity = try container.decode(Double.self, forKey: .opacity)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(red, forKey: .red)
        try container.encode(green, forKey: .green)
        try container.encode(blue, forKey: .blue)
        try container.encode(opacity, forKey: .opacity)
    }

    enum CodingKeys: String, CodingKey {
        case red, green, blue, opacity
    }
}

class AppData: NSObject, ObservableObject {
    static let shared = AppData() // Singleton instance

    @Published var events: [Event] = []
    @Published var categories: [(name: String, color: Color)] = [
        ("Work", .blue),
        ("Social", .green),
        ("Birthdays", .red),
        ("Holidays", .purple)
    ] {
        didSet {
            if isDataLoaded {
                saveCategories()
            }
        }
    }
    @Published var defaultCategory: String = "" {
        didSet {
            if isDataLoaded {
                UserDefaults.standard.set(defaultCategory, forKey: "defaultCategory")
                objectWillChange.send() // Notify observers
            }
        }
    }
    @Published var notificationTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date() {
        didSet {
            if isDataLoaded {
                UserDefaults.standard.set(notificationTime, forKey: "notificationTime")
                scheduleDailyNotification()
                saveState()
            }
        }
    }

    private var isDataLoaded = false

    var defaultCategoryColor: Color {
        if let category = categories.first(where: { $0.name == defaultCategory }) {
            return category.color
        }
        return .blue
    }

    override init() {
        super.init()
        migrateUserDefaults() // Call the migration function
        loadCategories()
        defaultCategory = "" // Ensure no default category is set
        if let savedTime = UserDefaults.standard.object(forKey: "notificationTime") as? Date {
            notificationTime = savedTime
        }
        loadEvents()
        isDataLoaded = true
        UNUserNotificationCenter.current().delegate = self
    }

    func saveCategories() {
        let categoryData = categories.map { CategoryData(name: $0.name, color: CodableColor(color: $0.color)) }
        encodeToUserDefaults(categoryData, forKey: "categories", suiteName: "group.UpNextIdentifier")
    }

    func loadCategories() {
        if let decoded: [CategoryData] = decodeFromUserDefaults([CategoryData].self, forKey: "categories", suiteName: "group.UpNextIdentifier") {
            self.categories = decoded.map { categoryData in
                return (name: categoryData.name, color: categoryData.color.color)
            }
            // print("Decoded categories: \(self.categories)")
        } else {
            self.categories = [
                ("Work", .blue),
                ("Social", .green),
                ("Birthdays", .red),
                ("Holidays", .purple)
            ]
            // print("Default categories set: \(self.categories)")
        }
        
        if let savedTime = UserDefaults.standard.object(forKey: "notificationTime") as? Date {
            notificationTime = savedTime
            // print("Notification time loaded: \(notificationTime)")
        }
    }

    
    // Filtered events
    func filteredEvents(selectedCategoryFilter: String?) -> [Event] {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        var allEvents = [Event]()

        for event in events {
            if let filter = selectedCategoryFilter {
                if event.category == filter && (event.date >= startOfToday || (event.endDate != nil && event.endDate! >= startOfToday)) {
                    allEvents.append(event)
                }
            } else {
                if event.date >= startOfToday || (event.endDate != nil && event.endDate! >= startOfToday) {
                    allEvents.append(event)
                }
            }
        }

        return allEvents.sorted { $0.date < $1.date }
    }

    func loadEvents() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier"),
           let data = sharedDefaults.data(forKey: "events") {
            do {
                var decodedEvents = try decoder.decode([Event].self, from: data)
                // Ensure all events have the new properties
                for i in 0..<decodedEvents.count {
                    if decodedEvents[i].repeatUntil == nil {
                        decodedEvents[i].repeatUntil = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date()
                    }
                }
                events = decodedEvents
                print("Loaded \(events.count) events from user defaults.")
            } catch {
                print("Failed to decode events: \(error)")
            }
        } else {
            print("No events found in shared UserDefaults.")
        }
    }

    func saveEvents() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let encoded = try? encoder.encode(events),
           let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier") {
            sharedDefaults.set(encoded, forKey: "events")
            // print("Saved events: \(events)")
            WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
        } else {
            // print("Failed to encode events.")
        }
    }

    func scheduleDailyNotification() {
        print("scheduleDailyNotification called")
        let content = UNMutableNotificationContent()
        content.title = "Today's Events"
        
        // Fetch today's events
        let todayEvents = getTodayEvents()
        let eventsString = todayEvents.map { $0.title }.joined(separator: ", ")
        
        // If there are no events, do not schedule the notification
        if eventsString.isEmpty {
            print("No events for today. Notification will not be scheduled.")
            return
        }
        
        content.body = eventsString
        content.sound = .default
        content.categoryIdentifier = "DAILY_NOTIFICATION"
        
        var dateComponents = Calendar.current.dateComponents([.hour, .minute], from: notificationTime)
        dateComponents.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyNotification", content: content, trigger: trigger)

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyNotification"]) // Remove any existing daily notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling daily notification: \(error)")
            } else {
                print("Daily notification scheduled successfully.")
            }
        }

        // Define the custom action
        let action = UNNotificationAction(identifier: "VIEW_ACTION", title: "View", options: .foreground)
        let category = UNNotificationCategory(identifier: "DAILY_NOTIFICATION", actions: [action], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func getTodayEvents() -> [Event] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let todayEvents = events.filter { event in
            let eventStartOfDay = calendar.startOfDay(for: event.date)
            return eventStartOfDay >= today && eventStartOfDay < tomorrow
        }

        return todayEvents
    }
    
    func saveState() {
        UserDefaults.standard.set(notificationTime, forKey: "notificationTime")
    }
    
    func removeNotification(for event: Event) {
        let center = UNUserNotificationCenter.current()
        let identifier = event.id.uuidString
        print("Removing notification for event ID: \(identifier)")
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

// Extend AppData to conform to UNUserNotificationCenterDelegate
extension AppData: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("Notification will present: \(notification.request.content.body)")
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == "VIEW_ACTION" {
            print("Notification action triggered: \(response.actionIdentifier)")
        }
        completionHandler()
    }
}

private func decodeFromUserDefaults<T: Decodable>(_ type: T.Type, forKey key: String, suiteName: String) -> T? {
    if let sharedDefaults = UserDefaults(suiteName: suiteName),
       let data = sharedDefaults.data(forKey: key) {
        let decoder = JSONDecoder()
        return try? decoder.decode(type, from: data)
    }
    return nil
}

private func encodeToUserDefaults<T: Encodable>(_ value: T, forKey key: String, suiteName: String) {
    if let sharedDefaults = UserDefaults(suiteName: suiteName) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(value) {
            sharedDefaults.set(encoded, forKey: key)
        }
    }
}

func migrateUserDefaults() {
    let defaults = UserDefaults.standard
    let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier")

    // Migrate events
    if let oldEventsData = defaults.data(forKey: "events"), sharedDefaults?.data(forKey: "events") == nil {
        sharedDefaults?.set(oldEventsData, forKey: "events")
        defaults.removeObject(forKey: "events")
        print("Migrated events to shared UserDefaults.")
    }

    // Migrate categories
    if let oldCategoriesData = defaults.data(forKey: "categories"), sharedDefaults?.data(forKey: "categories") == nil {
        sharedDefaults?.set(oldCategoriesData, forKey: "categories")
        defaults.removeObject(forKey: "categories")
        print("Migrated categories to shared UserDefaults.")
    }

    // Migrate notification time
    if let oldNotificationTime = defaults.object(forKey: "notificationTime") as? Date, sharedDefaults?.object(forKey: "notificationTime") == nil {
        sharedDefaults?.set(oldNotificationTime, forKey: "notificationTime")
        defaults.removeObject(forKey: "notificationTime")
        print("Migrated notification time to shared UserDefaults.")
    }

    // Migrate default category
    if let oldDefaultCategory = defaults.string(forKey: "defaultCategory"), sharedDefaults?.string(forKey: "defaultCategory") == nil {
        sharedDefaults?.set(oldDefaultCategory, forKey: "defaultCategory")
        defaults.removeObject(forKey: "defaultCategory")
        print("Migrated default category to shared UserDefaults.")
    }
}