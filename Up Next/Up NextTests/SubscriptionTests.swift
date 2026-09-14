import XCTest
import StoreKit
import StoreKitTest
import Combine
@testable import Up_Next

final class SubscriptionTests: XCTestCase {
    @MainActor
    func testVerifiedPurchaseAndRefundRefreshEntitlements() async throws {
        executionTimeAllowance = 240
        let session = try SKTestSession(configurationFileNamed: "Almanac Pro")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.timeRate = .realTime
        session.clearTransactions()
        defer { session.clearTransactions() }
        // Configure the local store before the app queries products or receipts.
        let appData = AppData()
        let catalogLoaded = expectation(description: "The app loads the test catalog and initial entitlements")
        let catalogObservation = appData.$isLoadingSubscription.dropFirst().filter { !$0 }.first()
            .sink { _ in catalogLoaded.fulfill() }
        defer { catalogObservation.cancel() }
        appData.loadSubscriptionProduct()
        guard await XCTWaiter.fulfillment(of: [catalogLoaded], timeout: 60) == .completed else {
            return XCTFail("StoreKit initialization did not complete in 60 seconds. Product: \(appData.subscriptionProduct?.id ?? "none"); message: \(appData.subscriptionMessage ?? "none")")
        }
        XCTAssertFalse(appData.isSubscribed)
        let product = try XCTUnwrap(appData.subscriptionProduct, appData.subscriptionMessage ?? "Missing test product")
        let purchaseObserved = expectation(description: "The app grants the verified purchased entitlement")
        let purchaseObservation = appData.$isSubscribed.filter { $0 }.first()
            .sink { _ in purchaseObserved.fulfill() }
        defer { purchaseObservation.cancel() }
        guard case .success(let verification) = try await step("Purchase the test subscription", operation: { try await product.purchase() }),
              case .verified(let transaction) = verification else { return XCTFail("Expected a verified test purchase") }
        XCTAssertEqual(transaction.environment, .xcode)
        // SKTestSession records the purchase before the simulator necessarily
        // invalidates its cached empty entitlements. Synchronize the local test
        // storefront before asking the app to read it; waiting on isSubscribed
        // alone cannot refresh StoreKit's cache.
        try await step("Synchronize the test purchase") { try await AppStore.sync() }
        try await step("Finish the verified transaction") { await transaction.finish() }
        try await step("Refresh the purchased entitlement") { await appData.refreshSubscriptionStatus() }
        // The transaction listener may start a newer refresh while the explicit
        // refresh is suspended. Wait for the published result of that refresh.
        guard await XCTWaiter.fulfillment(of: [purchaseObserved], timeout: 30) == .completed else {
            return XCTFail("The verified purchase did not grant the entitlement")
        }
        XCTAssertTrue(appData.isSubscribed)
        let refundObserved = expectation(description: "The transaction listener removes the refunded entitlement")
        let observation = appData.$isSubscribed.filter { !$0 }.first().sink { _ in refundObserved.fulfill() }
        defer { observation.cancel() }
        try session.refundTransaction(identifier: UInt(transaction.id))
        guard await XCTWaiter.fulfillment(of: [refundObserved], timeout: 30) == .completed else {
            return XCTFail("The refunded purchase did not remove the entitlement")
        }
        XCTAssertFalse(appData.isSubscribed)
    }

    @MainActor
    private func step<Value>(_ name: String, operation: @escaping @MainActor () async throws -> Value) async throws -> Value {
        let completed = expectation(description: name)
        var result: Result<Value, Error>?
        let task = Task { @MainActor in
            do { result = .success(try await operation()) }
            catch { result = .failure(error) }
            completed.fulfill()
        }
        defer { task.cancel() }
        guard await XCTWaiter.fulfillment(of: [completed], timeout: 45) == .completed,
              let result else {
            throw NSError(domain: "SubscriptionTests", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Timed out: \(name)"])
        }
        return try result.get()
    }
}
