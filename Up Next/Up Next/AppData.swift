//
//  AppData.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI
import WidgetKit
import UserNotifications
import StoreKit

// Model for an event
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
    var seriesID: UUID?
    var customRepeatCount: Int?
    var repeatUnit: String?
    var repeatUntilCount: Int? // Added this line

    // Initializer for Event
    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        endDate: Date? = nil,
        color: CodableColor,
        category: String? = nil,
        notificationsEnabled: Bool = true,
        repeatOption: RepeatOption = .never,
        repeatUntil: Date? = nil,
        seriesID: UUID? = nil,
        customRepeatCount: Int? = nil,
        repeatUnit: String? = nil,
        repeatUntilCount: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.endDate = endDate
        self.color = color
        self.category = category
        self.notificationsEnabled = notificationsEnabled
        self.repeatOption = repeatOption
        self.repeatUntil = repeatUntil
        self.seriesID = repeatOption == .never ? nil : seriesID
        self.customRepeatCount = customRepeatCount
        self.repeatUnit = repeatUnit
        self.repeatUntilCount = repeatUntilCount
        print("Event initialized: \(self)")
    }

    // Custom decoding to provide default values for new properties
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        color = try container.decode(CodableColor.self, forKey: .color)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        notificationsEnabled = try container.decode(Bool.self, forKey: .notificationsEnabled)
        repeatOption = try container.decode(RepeatOption.self, forKey: .repeatOption)
        repeatUntil = try container.decodeIfPresent(Date.self, forKey: .repeatUntil)
        seriesID = try container.decodeIfPresent(UUID.self, forKey: .seriesID)
        customRepeatCount = try container.decodeIfPresent(Int.self, forKey: .customRepeatCount) ?? 1 // Default value
        repeatUnit = try container.decodeIfPresent(String.self, forKey: .repeatUnit) ?? "Days" // Default value
        repeatUntilCount = try container.decodeIfPresent(Int.self, forKey: .repeatUntilCount) ?? 1 // Default value
    }

    // Coding keys for encoding and decoding
    enum CodingKeys: String, CodingKey {
        case id, title, date, endDate, color, category, notificationsEnabled, repeatOption, repeatUntil, seriesID, customRepeatCount, repeatUnit, repeatUntilCount // Added repeatUntilCount
    }
}

// Enum for repeat options
enum RepeatOption: String, Codable, CaseIterable {
    case never = "Never"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    case custom = "Custom"
}

// Enum for repeat until options
enum RepeatUntilOption: String, Codable {
    case indefinitely = "Indefinitely"
    case after = "After"
    case onDate = "On Date"
}

// Model for category data
struct CategoryData: Codable {
    let name: String
    let color: CodableColor
    let repeatOption: RepeatOption
    let showRepeatOptions: Bool
    let customRepeatCount: Int
    let repeatUnit: String
    let repeatUntilOption: RepeatUntilOption
    let repeatUntilCount: Int
    let repeatUntil: Date
}

// Model for a color that can be encoded and decoded
struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    // Initializer for CodableColor
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

    // Custom decoding for CodableColor
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        red = try container.decode(Double.self, forKey: .red)
        green = try container.decode(Double.self, forKey: .green)
        blue = try container.decode(Double.self, forKey: .blue)
        opacity = try container.decode(Double.self, forKey: .opacity)
    }

    // Custom encoding for CodableColor
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(red, forKey: .red)
        try container.encode(green, forKey: .green)
        try container.encode(blue, forKey: .blue)
        try container.encode(opacity, forKey: .opacity)
    }

    // Coding keys for encoding and decoding
    enum CodingKeys: String, CodingKey {
        case red, green, blue, opacity
    }
}

// Main class for managing app data
class AppData: NSObject, ObservableObject {
    static let shared = AppData() // Singleton instance

    @Published var events: [Event] = []
    @Published var categories: [(name: String, color: Color, repeatOption: RepeatOption, customRepeatCount: Int, repeatUnit: String, repeatUntilOption: RepeatUntilOption, repeatUntilCount: Int, repeatUntil: Date)] = [
        ("Work", .blue, .never, 1, "Days", .indefinitely, 1, Date()),
        ("Social", .green, .never, 1, "Days", .indefinitely, 1, Date()),
        ("Birthdays", .red, .yearly, 1, "Years", .indefinitely, 1, Date()),
        ("Holidays", .purple, .yearly, 1, "Years", .indefinitely, 1, Date())
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
                saveState()
                scheduleDailyNotification()
            }
        }
    }
    @Published var dailyNotificationEnabled: Bool = UserDefaults.standard.bool(forKey: "dailyNotificationEnabled") {
        didSet {
            if isDataLoaded {
                UserDefaults.standard.set(dailyNotificationEnabled, forKey: "dailyNotificationEnabled")
                scheduleDailyNotification()
            }
        }
    }
    @Published var eventStyle: String = UserDefaults.standard.string(forKey: "eventStyle") ?? "flat" {
        didSet {
            if isDataLoaded {
                UserDefaults.standard.set(eventStyle, forKey: "eventStyle")
            }
        }
    }

    @Published var isSubscribed = false

    private var isDataLoaded = false

    private var subscriptionProduct: Product?

    // Computed property for default category color
    var defaultCategoryColor: Color {
        if let category = categories.first(where: { $0.name == defaultCategory }) {
            return category.color
        }
        return .blue
    }

    // Initializer for AppData
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
        loadSubscriptionProduct()
    }

    // Function to save categories to UserDefaults
    func saveCategories() {
        let categoryData = categories.map { CategoryData(name: $0.name, color: CodableColor(color: $0.color), repeatOption: $0.repeatOption, showRepeatOptions: false, customRepeatCount: $0.customRepeatCount, repeatUnit: $0.repeatUnit, repeatUntilOption: $0.repeatUntilOption, repeatUntilCount: $0.repeatUntilCount, repeatUntil: $0.repeatUntil) }
        encodeToUserDefaults(categoryData, forKey: "categories", suiteName: "group.UpNextIdentifier")
    }

    // Function to load categories from UserDefaults
    func loadCategories() {
        if let decoded: [CategoryData] = decodeFromUserDefaults([CategoryData].self, forKey: "categories", suiteName: "group.UpNextIdentifier") {
            self.categories = decoded.map { categoryData in
                return (name: categoryData.name, color: categoryData.color.color, repeatOption: categoryData.repeatOption, customRepeatCount: categoryData.customRepeatCount, repeatUnit: categoryData.repeatUnit, repeatUntilOption: categoryData.repeatUntilOption, repeatUntilCount: categoryData.repeatUntilCount, repeatUntil: categoryData.repeatUntil)
            }
        } else {
            self.categories = [
                ("Work", .blue, .never, 1, "Days", .indefinitely, 1, Date()),
                ("Social", .green, .never, 1, "Days", .indefinitely, 1, Date()),
                ("Birthdays", .red, .yearly, 1, "Years", .indefinitely, 1, Date()),
                ("Holidays", .purple, .yearly, 1, "Years", .indefinitely, 1, Date())
            ]
        }
        
        if let savedTime = UserDefaults.standard.object(forKey: "notificationTime") as? Date {
            notificationTime = savedTime
        }
    }

    // Function to filter events based on selected category
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

    // Function to load events from UserDefaults
    func loadEvents() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier"),
           let data = sharedDefaults.data(forKey: "events") {
            do {
                var decodedEvents = try decoder.decode([Event].self, from: data)
                for i in 0..<decodedEvents.count {
                    if decodedEvents[i].repeatUntil == nil {
                        decodedEvents[i].repeatUntil = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 12, day: 31)) ?? Date()
                    }
                }
                events = decodedEvents
                print("Loaded \(events.count) events from user defaults.")
                print("First event: \(events.first?.title ?? "No events")")
            } catch {
                print("Failed to decode events: \(error)")
                print("Error description: \(error.localizedDescription)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .dataCorrupted(let context):
                        print("Data corrupted: \(context.debugDescription)")
                    case .keyNotFound(let key, let context):
                        print("Key not found: \(key.stringValue) - \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("Type mismatch: \(type) - \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("Value not found: \(type) - \(context.debugDescription)")
                    @unknown default:
                        print("Unknown decoding error")
                    }
                }
                // If decoding fails, attempt to recover old events
                if let oldEvents = decodeOldEvents(from: data) {
                    events = oldEvents
                    print("Recovered \(events.count) events from old format.")
                    saveEvents() // Save events in the new format
                }
            }
        } else {
            print("No events found in shared UserDefaults.")
        }
    }

    // Helper function to decode events from the old format
    private func decodeOldEvents(from data: Data) -> [Event]? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Define a struct that matches the old Event structure
        struct OldEvent: Codable {
            var id = UUID()
            var title: String
            var date: Date
            var endDate: Date?
            var color: CodableColor
            var category: String?
            var notificationsEnabled: Bool = true
            var repeatOption: RepeatOption = .never
            var repeatUntil: Date?
            var seriesID: UUID?
            var customRepeatCount: Int?
            var repeatUnit: String?
            var repeatUntilCount: Int? // Added this line
        }
        
        do {
            let oldEvents = try decoder.decode([OldEvent].self, from: data)
            // Convert OldEvent to Event, setting isGoogleCalendarEvent to false
            return oldEvents.map { oldEvent in
                Event(
                    id: oldEvent.id,
                    title: oldEvent.title,
                    date: oldEvent.date,
                    endDate: oldEvent.endDate,
                    color: oldEvent.color,
                    category: oldEvent.category,
                    notificationsEnabled: oldEvent.notificationsEnabled,
                    repeatOption: oldEvent.repeatOption,
                    repeatUntil: oldEvent.repeatUntil,
                    seriesID: oldEvent.seriesID,
                    customRepeatCount: oldEvent.customRepeatCount,
                    repeatUnit: oldEvent.repeatUnit,
                    repeatUntilCount: oldEvent.repeatUntilCount
                )
            }
        } catch {
            print("Failed to decode old events: \(error)")
            return nil
        }
    }

    // Function to save events to UserDefaults
    func saveEvents() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let encoded = try? encoder.encode(events),
           let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier") {
            sharedDefaults.set(encoded, forKey: "events")
            WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
            scheduleDailyNotification() // Reschedule daily notification
            print("Saved events: \(events)") // Debugging line
        } else {
            print("Failed to encode events.")
        }
    }

    // Function to set daily notification
    func setDailyNotification(enabled: Bool) {
        dailyNotificationEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "dailyNotificationEnabled")
        
        let center = UNUserNotificationCenter.current()
        
        if enabled {
            // Schedule notifications for upcoming events
            scheduleDailyNotification()
            scheduleUpcomingEventNotifications()
        } else {
            // Clear all scheduled notifications
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
            print("All notifications have been cleared.")
        }
    }

    private func scheduleUpcomingEventNotifications() {
        let center = UNUserNotificationCenter.current()
        let upcomingEvents = events.filter { $0.date > Date() }.prefix(10) // Schedule for next 10 upcoming events
        
        for event in upcomingEvents {
            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = "Your event is starting soon"
            content.sound = .default
            
            let triggerDate = Calendar.current.date(byAdding: .minute, value: -15, to: event.date)!
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            
            let request = UNNotificationRequest(identifier: event.id.uuidString, content: content, trigger: trigger)
            
            center.add(request) { error in
                if let error = error {
                    print("Error scheduling notification for event \(event.title): \(error)")
                }
            }
        }
    }

    // Function to schedule daily notification
    func scheduleDailyNotification() {
        guard dailyNotificationEnabled else {
            print("Daily notifications are disabled.")
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyNotification"])
            return
        }

        let content = UNMutableNotificationContent()
        
        // Get today's events
        let todayEvents = getTodayEvents()
        let eventsCount = todayEvents.count
        
        // If no events for today, do not schedule a notification
        if eventsCount == 0 {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyNotification"])
            return
        }
        
        // Set notification content
        content.title = "You have \(eventsCount) event\(eventsCount > 1 ? "s" : "") today"
        content.body = todayEvents.map { $0.title }.joined(separator: ", ")
        content.sound = .default
        content.categoryIdentifier = "DAILY_NOTIFICATION"
        
        // Set notification trigger time
        var dateComponents = Calendar.current.dateComponents([.hour, .minute], from: notificationTime)
        dateComponents.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyNotification", content: content, trigger: trigger)
        
        // Add the notification request to the notification center
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling daily notification: \(error)")
            } else {
                print("Daily notification scheduled successfully.")
            }
        }
    }

    // Function to get today's events
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

    // Function to save state to UserDefaults
    func saveState() {
        UserDefaults.standard.set(notificationTime, forKey: "notificationTime")
    }

    // Function to remove notification for an event
    func removeNotification(for event: Event) {
        let center = UNUserNotificationCenter.current()
        let identifier = event.id.uuidString
        print("Removing notification for event ID: \(identifier)")
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    // Function to add a new event
    func addEvent(_ event: Event) {
        events.append(event)
        saveEvents()
    }

    // Function to edit an existing event
    func editEvent(_ event: Event) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
            saveEvents()
        }
    }

    // Function to update event colors when a category color is changed
    func updateEventColors(forCategory category: String, from oldColor: Color, to newColor: Color) {
        for index in events.indices {
            if events[index].category == category {
                events[index].color = CodableColor(color: newColor)
            }
        }
        saveEvents()
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "NextEventWidget")
    }

    // Function to update events when a category is edited
    func updateEventsForCategoryChange(oldName: String, newName: String, newColor: Color) {
        var eventsUpdated = false
        print("Total events: \(events.count)")
        print("Searching for events with category: \(oldName)")
        for i in 0..<events.count {
            print("Event \(i): title = \(events[i].title), category = \(events[i].category ?? "nil")")
            if events[i].category == oldName {
                events[i].category = newName
                events[i].color = CodableColor(color: newColor)
                eventsUpdated = true
                print("Updated event: \(events[i])")
            }
        }
        if eventsUpdated {
            saveEvents()
            objectWillChange.send()
            WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget")
            WidgetCenter.shared.reloadTimelines(ofKind: "NextEventWidget")
            print("Events updated and saved.")
        } else {
            print("No events updated.")
        }
    }

    func loadSubscriptionProduct() {
        Task {
            do {
                let products = try await Product.products(for: ["AP0001"])
                if let product = products.first {
                    self.subscriptionProduct = product
                }
            } catch {
                print("Failed to load subscription product: \(error)")
            }
        }
    }

    func purchase() {
        guard let product = subscriptionProduct else { return }
        Task {
            do {
                let result = try await product.purchase()
                switch result {
                case .success(let verificationResult):
                    switch verificationResult {
                    case .verified(let transaction):
                        await transaction.finish()
                        isSubscribed = true
                    case .unverified:
                        print("Transaction unverified")
                    }
                case .userCancelled:
                    print("User cancelled")
                case .pending:
                    print("Transaction pending")
                @unknown default:
                    break
                }
            } catch {
                print("Failed to purchase: \(error)")
            }
        }
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

// Helper function to decode from UserDefaults
private func decodeFromUserDefaults<T: Decodable>(_ type: T.Type, forKey key: String, suiteName: String) -> T? {
    if let sharedDefaults = UserDefaults(suiteName: suiteName),
       let data = sharedDefaults.data(forKey: key) {
        let decoder = JSONDecoder()
        return try? decoder.decode(type, from: data)
    }
    return nil
}

// Helper function to encode to UserDefaults
private func encodeToUserDefaults<T: Encodable>(_ value: T, forKey key: String, suiteName: String) {
    if let sharedDefaults = UserDefaults(suiteName: suiteName) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(value) {
            sharedDefaults.set(encoded, forKey: key)
        }
    }
}

// Function to migrate user defaults to shared user defaults
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

enum RepeatUnit: String, Codable {
    case day = "day"
    case week = "week"
    case month = "month"
    case year = "year"
}