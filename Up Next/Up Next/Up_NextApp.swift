//
//  Up_NextApp.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 6/19/24.
//

import SwiftUI
import StoreKit

@main
struct Up_NextApp: App {
    @StateObject private var appData = AppData.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appData)
                .task {
                    await updateSubscriptionStatus()
                }
        }
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
