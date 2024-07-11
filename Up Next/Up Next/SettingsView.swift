//
//  SettingsView.swift
//  Up Next
//
//  Created by Gabriel Valdivia on 7/6/24.
//

import Foundation
import SwiftUI
import WidgetKit
import PassKit // Add this import

struct SettingsView: View {
    @EnvironmentObject var appData: AppData
    @State private var showingDeleteAllAlert = false
    @Environment(\.openURL) var openURL
    @State private var showingPaymentSheet = false // Add state for payment sheet

    var body: some View {
        Form {
            Section(header: Text("Notifications")) {
                DatePicker("Notification Time", selection: $appData.notificationTime, displayedComponents: .hourAndMinute)
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
            
            Section(header: Text("Feedback")) {
                Button(action: {
                    if let url = URL(string: "https://twitter.com/gabrielvaldivia") {
                        openURL(url)
                    }
                }) {
                    Text("Send Feedback")
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
            
            // Add a new section for subscription
            Section {
                Button(action: {
                    showingPaymentSheet = true
                }) {
                    Text("Subscribe")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                .background(PaymentViewControllerWrapper(isPresented: $showingPaymentSheet))
            }
            
        }
        .navigationTitle("Settings")
    }
    
    private func deleteAllEvents() {
        appData.objectWillChange.send()  // Notify the view of changes
        appData.events.removeAll()
        appData.saveEvents()
        WidgetCenter.shared.reloadTimelines(ofKind: "UpNextWidget") // Notify widget to reload
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
            request.merchantIdentifier = "merchant.valdiviaworks.upnext" // Replace with your merchant identifier
            request.supportedNetworks = [.visa, .masterCard, .amex]
            request.merchantCapabilities = .capability3DS
            request.countryCode = "US"
            request.currencyCode = "USD"
            request.paymentSummaryItems = [
                PKPaymentSummaryItem(label: "Up Next Pro - Monthly Subscription", amount: NSDecimalNumber(string: "2.99"))
            ]
            
            if let paymentController = PKPaymentAuthorizationViewController(paymentRequest: request) {
                paymentController.delegate = context.coordinator
                uiViewController.present(paymentController, animated: true, completion: nil)
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