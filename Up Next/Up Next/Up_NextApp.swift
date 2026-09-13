//
//  Up_NextApp.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/19/24.
//

import SwiftUI
import StoreKit
import BackgroundTasks

@main
struct Up_NextApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appData = AppData.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appData)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        appData.loadEvents(); appData.scheduleDailyNotification()
                        Task { await appData.refreshSubscriptionStatus() }
                    }
                    if phase == .background { scheduleRefresh() }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    appData.loadEvents()
                    appData.scheduleDailyNotification()
                }
                .task {
                    appData.scheduleDailyNotification()
                    await appData.refreshSubscriptionStatus()
                }
        }
        .backgroundTask(.appRefresh("com.almanac.reminders")) {
            await MainActor.run { appData.loadEvents(); appData.scheduleDailyNotification(); scheduleRefresh() }
            await appData.waitForNotifications()
        }
    }

    private func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.almanac.reminders")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 60 * 60)
        // iOS chooses when to run this; already queued reminders do not depend on it.
        try? BGTaskScheduler.shared.submit(request)
    }
    
}
