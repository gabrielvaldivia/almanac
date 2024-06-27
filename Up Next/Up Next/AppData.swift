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
    var color: CodableColor // Use CodableColor to store color
    var category: String?
    var notificationsEnabled: Bool = true // New property to track notification status
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
    @Published var notificationTime: Date = Date() {
        didSet {
            if isDataLoaded {
                UserDefaults.standard.set(notificationTime, forKey: "notificationTime")
                print("Notification time saved: \(notificationTime)")
                scheduleDailyNotification()
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
        isDataLoaded = true
        UNUserNotificationCenter.current().delegate = self
    }

    private func saveCategories() {
        let encoder = JSONEncoder()
        let categoryData = categories.map { CategoryData(name: $0.name, color: CodableColor(color: $0.color)) }
        do {
            let encodedData = try encoder.encode(categoryData)
            guard let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier") else {
                print("Failed to access shared UserDefaults.")
                return
            }
            sharedDefaults.set(encodedData, forKey: "categories")
            print("Categories saved successfully: \(categoryData)")
        } catch {
            print("Failed to encode categories: \(error.localizedDescription)")
        }
        
        // Save notification time
        UserDefaults.standard.set(notificationTime, forKey: "notificationTime")
    }

    func loadCategories() {
        let decoder = JSONDecoder()
        guard let sharedDefaults = UserDefaults(suiteName: "group.UpNextIdentifier") else {
            print("Failed to access shared UserDefaults.")
            return
        }
        guard let data = sharedDefaults.data(forKey: "categories") else {
            print("No categories data found in UserDefaults.")
            self.categories = [
                ("Work", .blue),
                ("Social", .green),
                ("Birthdays", .red),
                ("Movies", .purple)
            ] // Default to all categories if nothing is loaded
            print("Default categories set: \(self.categories)")
            return
        }
        
        do {
            let decoded = try decoder.decode([CategoryData].self, from: data)
            self.categories = decoded.map { categoryData in
                return (name: categoryData.name, color: categoryData.color.color)
            }
            print("Decoded categories: \(self.categories)")
        } catch {
            print("Failed to decode categories: \(error.localizedDescription)")
            self.categories = [
                ("Work", .blue),
                ("Social", .green),
                ("Birthdays", .red),
                ("Movies", .purple)
            ] // Default to all categories if decoding fails
            print("Default categories set after decoding failure: \(self.categories)")
        }
        
        // Load notification time
        if let savedTime = UserDefaults.standard.object(forKey: "notificationTime") as? Date {
            notificationTime = savedTime
            print("Notification time loaded: \(notificationTime)")
        }
    }
    
    func scheduleDailyNotification() {
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

    private func getTodayEvents() -> [Event] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        return events.filter { $0.date >= today && $0.date < tomorrow }
    }
    
    func saveState() {
        UserDefaults.standard.set(notificationTime, forKey: "notificationTime")
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
