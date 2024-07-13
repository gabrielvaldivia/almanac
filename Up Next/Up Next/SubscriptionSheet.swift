import Foundation
import SwiftUI
import StoreKit

struct SubscriptionSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var appData: AppData
    @State private var isPurchasing = false
    @State private var subscriptionProduct: Product?
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack {
                Text("Unlock Pro Features")
                    .font(.largeTitle)
                    .padding()

                Text("Subscribe to unlock custom categories and more!")
                    .font(.body)
                    .padding()

                if let product = subscriptionProduct {
                    Button(action: {
                        Task {
                            await purchaseSubscription(product: product, appData: appData)
                        }
                    }) {
                        Text("Subscribe for \(product.displayPrice)/month")
                            .font(.title2)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                } else {
                    Text("Loading subscription...")
                        .padding()
                }

                if let errorMessage = errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                }

                Spacer()
            }
            .navigationBarItems(trailing: Button("Close") {
                isPresented = false
            })
            .onAppear {
                Task {
                    await fetchSubscriptionProduct()
                }
            }
        }
    }

    private func fetchSubscriptionProduct() async {
        do {
            let products = try await Product.products(for: ["AP0001"])
            if let product = products.first {
                subscriptionProduct = product
            } else {
                errorMessage = "No products found"
            }
        } catch {
            errorMessage = "Failed to fetch products: \(error.localizedDescription)"
        }
    }

    private func purchaseSubscription(product: Product, appData: AppData) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    appData.isSubscribed = true
                    await transaction.finish()
                case .unverified(_, let error):
                    errorMessage = "Unverified transaction: \(error)"
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error)"
        }
    }
}