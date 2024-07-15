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

    init() {
        requestNotificationPermissions()
        UNUserNotificationCenter.current().delegate = appData
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
            }
        }
    }
}