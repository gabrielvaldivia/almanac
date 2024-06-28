//
//  AppData.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/23/24.
//

import Foundation
import SwiftUI

struct Event: Identifiable, Codable {
    var id = UUID()
    var title: String
    var date: Date
    var endDate: Date?
    var color: CodableColor
    var category: String?
    var notificationsEnabled: Bool = true

    init(title: String, date: Date, endDate: Date? = nil, color: CodableColor, category: String? = nil, notificationsEnabled: Bool = true) {
        self.title = title
        self.date = date
        self.endDate = endDate
        self.color = color
        self.category = category
        self.notificationsEnabled = notificationsEnabled
        print("Event initialized: \(self)")
    }
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
    @Published var events: [Event] = []
    @Published var categories: [(name: String, color: Color)] = [
        ("Work", .blue),
        ("Social", .green),
        ("Birthdays", .red),
        ("Movies", .purple)
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
            }
        }
    }
    @Published var notificationTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date() {
        didSet {
            if isDataLoaded {
                UserDefaults.standard.set(notificationTime, forKey: "notificationTime")
                print("Notification time saved: \(notificationTime)")
                scheduleDailyNotification()
                saveState()
            }
        }
    }

    private var isDataLoaded = false

    override init() {
        super.init()
        loadCategories()
        defaultCategory = UserDefaults.standard.string(forKey: "defaultCategory") ?? ""
        if let savedTime = UserDefaults.standard.object(forKey: "notificationTime") as? Date {
            notificationTime = savedTime
            print("Notification time loaded: \(notificationTime)")
        }
        loadEvents()  // Add this line to load events
        isDataLoaded = true
        UNUserNotificationCenter.current().delegate = self
    }

    private func saveCategories() {
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
                ("Movies", .purple)
            ]
            // print("Default categories set: \(self.categories)")
        }
        
        if let savedTime = UserDefaults.standard.object(forKey: "notificationTime") as? Date {
            notificationTime = savedTime
            // print("Notification time loaded: \(notificationTime)")
        }
    }

    func filteredEvents(events: [Event], selectedCategoryFilter: String?) -> [Event] {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        return events.filter { event in
            (selectedCategoryFilter == nil || event.category == selectedCategoryFilter) && event.date >= startOfToday
        }
    }

    func loadEvents() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier"),
           let data = sharedDefaults.data(forKey: "events"),
           let decoded = try? decoder.decode([Event].self, from: data) {
            events = decoded
            print("Loaded events: \(events)")
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
            print("Saved events: \(events)")
        } else {
            print("Failed to encode events.")
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
            print("Event date: \(event.date), Event start of day: \(eventStartOfDay), Today: \(today), Tomorrow: \(tomorrow)")
            return eventStartOfDay >= today && eventStartOfDay < tomorrow
        }

        // Debug prints
        print("Today's date: \(today)")
        print("Tomorrow's date: \(tomorrow)")
        print("Events for today: \(todayEvents)")

        return todayEvents
    }
    
    func saveState() {
        UserDefaults.standard.set(notificationTime, forKey: "notificationTime")
    }
    
    func scheduleNotification(for event: Event) {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = "Event is starting soon!"
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: event.date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: event.id.uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Notification scheduled for event: \(event.title)")
            }
        }
    }

    func removeNotification(for event: Event) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [event.id.uuidString])
        print("Notification removed for event: \(event.title).")
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
