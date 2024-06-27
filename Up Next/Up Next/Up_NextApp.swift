//
//  Up_NextApp.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/19/24.
//

import SwiftUI
import UserNotifications

@main
struct Up_NextApp: App {
    var appData = AppData()
    private var notificationDelegate = NotificationDelegate() // Strong reference to NotificationDelegate

    init() {
        requestNotificationPermissions()
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appData)
        }
    }

    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification permissions: \(error)")
            } else {
                print("Notification permissions granted: \(granted)")
                if granted {
                    appData.scheduleDailyNotification() // Schedule the notification after permissions are granted
                }
            }
        }
    }
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }
}
