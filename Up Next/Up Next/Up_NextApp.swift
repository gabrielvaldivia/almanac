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
                    if phase == .active { appData.loadEvents(); appData.scheduleDailyNotification() }
                    if phase == .background { scheduleRefresh() }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    appData.scheduleDailyNotification()
                }
                .task {
                    appData.scheduleDailyNotification()
                    await updateSubscriptionStatus()
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
    
    func updateSubscriptionStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                appData.isSubscribed = transaction.productID == "AP0001"
            }
        }
    }
}

class StoreObserver: NSObject, SKPaymentTransactionObserver {
    static let shared = StoreObserver()
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased, .restored:
                SKPaymentQueue.default().finishTransaction(transaction)
            case .failed:
                SKPaymentQueue.default().finishTransaction(transaction)
            case .deferred, .purchasing:
                break
            @unknown default:
                break
            }
        }
    }
}
