//
//  SettingsView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 7/6/24.
//

import Foundation
import SwiftUI
import WidgetKit
import PassKit
import StoreKit // Add this import

struct SettingsView: View {
    @EnvironmentObject var appData: AppData
    @State private var showingDeleteAllAlert = false
    @Environment(\.openURL) var openURL
    @State private var showingPaymentSheet = false
    @State private var subscriptionProduct: Product? // Add state for subscription product
    @State private var isPurchasing = false // Add state for purchase process
    @State private var isSubscribed = false // Add state for subscription status
    @State private var errorMessage: String? // Add state for error message

    var body: some View {
        Form {
            Section(header: Text("Notifications")) {
                DatePicker("Notification Time", selection: $appData.notificationTime, displayedComponents: .hourAndMinute)
                NavigationLink(destination: NotificationsView().environmentObject(appData)) {
                    Text("Manage Notifications")
                }
            }
            
            Section(header: Text("Categories")) {
                Picker("Default Category", selection: Binding(
                    get: {
                        if appData.defaultCategory.isEmpty {
                            return "None"
                        }
                        return appData.defaultCategory
                    },
                    set: { newValue in
                        if newValue == "None" {
                            appData.defaultCategory = ""
                        } else {
                            appData.defaultCategory = newValue
                        }
                    }
                )) {
                    Text("None").tag("None")
                    ForEach(appData.categories, id: \.name) { category in
                        Text(category.name)
                            .tag(category.name)
                            .foregroundColor(.gray) // Set the text color to gray
                    }
                }
                .pickerStyle(MenuPickerStyle())
                NavigationLink(destination: CategoriesView().environmentObject(appData)) {
                    Text("Manage Categories")
                }
            }
            
            Section(header: Text("Support")) {
                Button(action: {
                    if let url = URL(string: "https://twitter.com/gabrielvaldivia") {
                        openURL(url)
                    }
                }) {
                    Text("Send Feedback")
                }
                if let product = subscriptionProduct {
                    if appData.isSubscribed {
                        Text("Thank you for being a subscriber")
                            .foregroundColor(.green)
                    } else {
                        Button(action: {
                            Task {
                                await purchaseSubscription(product: product)
                            }
                        }) {
                            Text("Subscribe for \(product.displayPrice)/month")
                                .foregroundColor(.blue)
                        }
                    }
                } else {
                    Text("Loading subscription...")
                }
                if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                }
            }
            
            Section(header: Text("Danger Zone")) {
                Button(action: {
                    showingDeleteAllAlert = true
                }) {
                    HStack {
                        Text("Delete All Events")
                    }
                    .foregroundColor(.red)
                }
                .alert(isPresented: $showingDeleteAllAlert) {
                    Alert(
                        title: Text("Delete All Events"),
                        message: Text("Are you sure you want to delete all events? This action cannot be undone."),
                        primaryButton: .destructive(Text("Delete")) {
                            deleteAllEvents()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            Task {
                await fetchSubscriptionProduct()
            }
        }
    }
    
    private func deleteAllEvents() {
        appData.objectWillChange.send()  // Notify the view of changes
        appData.events.removeAll()
        appData.saveEvents()
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
    }

    private func fetchSubscriptionProduct() async {
        do {
            print("Fetching products...")
            let products = try await Product.products(for: ["AP0001"])
            if let product = products.first {
                subscriptionProduct = product
                print("Product fetched successfully: \(product.displayName)")
            } else {
                print("No products found")
            }
        } catch {
            print("Failed to fetch products: \(error.localizedDescription)")
            if let skError = error as? SKError {
                switch skError.code {
                case .unknown:
                    print("Unknown error occurred.")
                case .clientInvalid:
                    print("Client is not allowed to issue the request.")
                case .paymentCancelled:
                    print("Payment was cancelled.")
                case .paymentInvalid:
                    print("The purchase identifier was invalid.")
                case .paymentNotAllowed:
                    print("The device is not allowed to make the payment.")
                case .storeProductNotAvailable:
                    print("The product is not available in the current storefront.")
                default:
                    print("Other error: \(skError.localizedDescription)")
                }
            }
        }
    }

    private func purchaseSubscription(product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // Handle successful purchase
                    isSubscribed = true // Update subscription status
                    await transaction.finish()
                case .unverified(_, let error):
                    // Handle unverified transaction
                    print("Unverified transaction: \(error)")
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            print("Purchase failed: \(error)")
        }
    }

    private func listenForTransactions() {
        Task {
            for await verification in Transaction.updates {
                switch verification {
                case .verified(let transaction):
                    // Handle successful purchase
                    isSubscribed = true // Update subscription status
                    await transaction.finish()
                case .unverified(_, let error):
                    // Handle unverified transaction
                    print("Unverified transaction: \(error)")
                }
            }
        }
    }

    init() {
        listenForTransactions()
    }
}

struct PaymentViewControllerWrapper: UIViewControllerRepresentable {
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .clear
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented {
            let request = PKPaymentRequest()
            request.merchantIdentifier = "merchant.valdiviaworks.upnext"
            request.supportedNetworks = [.visa, .masterCard, .amex]
            request.merchantCapabilities = .threeDSecure // Changed from .capability3DS
            request.countryCode = "US"
            request.currencyCode = "USD"
            request.paymentSummaryItems = [
                PKPaymentSummaryItem(label: "Up Next Pro - Monthly Subscription", amount: NSDecimalNumber(string: "2.99"))
            ]
            
            if let paymentController = PKPaymentAuthorizationViewController(paymentRequest: request) {
                paymentController.delegate = context.coordinator
                if let rootViewController = uiViewController.view.window?.rootViewController {
                    rootViewController.present(paymentController, animated: true, completion: nil)
                }
            }
            isPresented = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, PKPaymentAuthorizationViewControllerDelegate {
        func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
            // Handle successful payment here
            completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        }
        
        func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
            controller.dismiss(animated: true, completion: nil)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppData())
    }
}