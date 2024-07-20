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
import StoreKit
import UIKit

struct SettingsView: View {
    @EnvironmentObject var appData: AppData
    @State private var showingDeleteAllAlert = false
    @Environment(\.openURL) var openURL
    @State private var showingPaymentSheet = false
    @State private var subscriptionProduct: Product?
    @State private var isPurchasing = false 
    @State private var isSubscribed = false 
    @State private var errorMessage: String? 
    @State private var dailyNotificationEnabled = UserDefaults.standard.bool(forKey: "dailyNotificationEnabled") // Load state from UserDefaults
    @State private var selectedAppIcon = "Default"
    let appIcons = ["Default", "Dark", "Monochrome", "Star", "Heart", "X", "2012 by Charlie Deets", "2013 by Charlie Deets"] 
    @State private var iconChangeSuccess: Bool? 

    var body: some View {
        Form {
            // Notifications Section
            Section(header: Text("Notifications")) {
                Toggle("Daily Notification", isOn: $dailyNotificationEnabled)
                    .onChange(of: dailyNotificationEnabled) { oldValue, newValue in
                        handleDailyNotificationToggle(newValue)
                    }
                if dailyNotificationEnabled {
                    DatePicker("Notification Time", selection: $appData.notificationTime, displayedComponents: .hourAndMinute)
                }
            }
            
            // Categories Section
            Section(header: Text("Categories")) {
                HStack {
                    Text("Default Category")
                        .foregroundColor(.primary) // Use primary color for the label
                    Spacer()
                    Menu {
                        Button(action: {
                            appData.defaultCategory = ""
                        }) {
                            Text("None").foregroundColor(.gray)
                        }
                        ForEach(appData.categories, id: \.name) { category in
                            Button(action: {
                                appData.defaultCategory = category.name
                            }) {
                                Text(category.name).foregroundColor(.gray)
                            }
                        }
                    } label: {
                        HStack {
                            Text(appData.defaultCategory.isEmpty ? "None" : appData.defaultCategory)
                                .foregroundColor(.gray)
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundColor(.gray)
                        }
                        // .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                    }
                }
                NavigationLink(destination: CategoriesView().environmentObject(appData)) {
                    Text("Manage Categories")
                }
            }

             // Appearance Section
            Section(header: Text("Appearance")) {
                NavigationLink(destination: AppIconSelectionView(selectedAppIcon: $selectedAppIcon)) {
                    Text("Change App Icon")
                }
            }
            
            // Support Section
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
            
            // Danger Zone Section
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
            dailyNotificationEnabled = UserDefaults.standard.bool(forKey: "dailyNotificationEnabled") // Load state from UserDefaults
        }
    }
    
    // Function to delete all events
    private func deleteAllEvents() {
        appData.objectWillChange.send()  // Notify the view of changes
        appData.events.removeAll()
        appData.saveEvents()
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
    }

    // Function to fetch subscription product
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

    // Function to handle subscription purchase
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

    // Function to listen for transactions
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

    // Function to handle daily notification toggle
    private func handleDailyNotificationToggle(_ isEnabled: Bool) {
        appData.setDailyNotification(enabled: isEnabled)
        UserDefaults.standard.set(isEnabled, forKey: "dailyNotificationEnabled") // Save state to UserDefaults
    }

    init() {
        listenForTransactions()
    }
}

// Wrapper for PaymentViewController
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

// Preview for SettingsView
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppData())
    }
}

struct AppIconSelectionView: View {
    @Binding var selectedAppIcon: String
    @State private var iconChangeSuccess: Bool?
    @Environment(\.openURL) var openURL
    let appIcons = ["Default", "Dark", "Monochrome", "Star", "Heart", "X", "2012", "2013"]
    
    // Dictionary to store author names and links
    let iconAuthors: [String: (name: String, link: String)] = [
        "2012": ("Charlie Deets", "https://charliedeets.com"),
        "2013": ("Charlie Deets", "https://charliedeets.com")
        // Add more icons with authors here in the future
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                ForEach(appIcons, id: \.self) { icon in
                    VStack {
                        Image(uiImage: iconImage(for: icon))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
                        
                        IconLabel(icon: icon, author: iconAuthors[icon], openURL: openURL)
                        
                        RadioButton(isSelected: selectedAppIcon == icon) {
                            selectedAppIcon = icon
                            changeAppIcon(to: icon)
                        }
                    }
                    .frame(height: 140)
                    .padding(.bottom, 16)
                }
            }
            .padding()
        }
        .navigationBarTitle("App Icons", displayMode: .inline)
        .background(Color(UIColor.secondarySystemBackground))
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Text("Want to add your own? ")
                        .foregroundColor(.secondary)
                    Button("Submit a proposal") {
                        openEmail()
                    }
                    .foregroundColor(.blue)
                }
                .font(.footnote)
                .padding(.bottom, 8)
            }
        )
    }
    
    private func iconImage(for iconName: String) -> UIImage {
        let iconToLoad: String?
        switch iconName {
        case "Default":
            iconToLoad = nil
        case "Dark":
            iconToLoad = "DarkAppIcon"
        case "Monochrome":
            iconToLoad = "MonochromeAppIcon"
        case "Star":
            iconToLoad = "StarAppIcon"
        case "Heart":
            iconToLoad = "HeartAppIcon"
        case "X":
            iconToLoad = "XAppIcon"
        case "2012":
            iconToLoad = "2012AppIcon"
        case "2013":
            iconToLoad = "2013AppIcon"
        default:
            iconToLoad = nil
        }
        
        if let iconName = iconToLoad, let alternateIcon = UIImage(named: iconName) {
            return alternateIcon
        } else {
            // Return the default app icon
            return UIImage(named: "AppIcon") ?? UIImage(systemName: "app.fill")!
        }
    }
    
    private func changeAppIcon(to iconName: String) {
        let iconToSet: String?
        switch iconName {
        case "Default":
            iconToSet = nil
        case "Dark":
            iconToSet = "DarkAppIcon"
        case "Monochrome":
            iconToSet = "MonochromeAppIcon"
        case "Star":
            iconToSet = "StarAppIcon"
        case "Heart":
            iconToSet = "HeartAppIcon"
        case "X":
            iconToSet = "XAppIcon"
        case "2012":
            iconToSet = "2012AppIcon"
        case "2013":
            iconToSet = "2013AppIcon"
        default:
            iconToSet = nil
        }
        
        UIApplication.shared.setAlternateIconName(iconToSet) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error changing app icon: \(error.localizedDescription)")
                    self.iconChangeSuccess = false
                } else {
                    print("App icon successfully changed to: \(iconName)")
                    self.selectedAppIcon = iconName
                    self.iconChangeSuccess = true
                }
            }
        }
    }

    private func openEmail() {
        if let url = URL(string: "mailto:gabe@valdivia.works") {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    print("Failed to open email client")
                }
            }
        }
    }
}

struct IconLabel: View {
    let icon: String
    let author: (name: String, link: String)?
    let openURL: OpenURLAction
    
    var body: some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            
            if let author = author {
                (Text("by ")
                    .font(.caption)
                    .foregroundColor(.secondary) +
                Text(author.name)
                    .font(.caption)
                    .foregroundColor(.blue))
                    .onTapGesture {
                        if let url = URL(string: author.link) {
                            openURL(url)
                        }
                    }
            }
        }
        .padding(.vertical, 4)
    }
}

struct RadioButton: View {
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.blue : Color.secondary, lineWidth: 1)
                    .frame(width: 20, height: 20)
                
                if isSelected {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                }
            }
        }
    }
}