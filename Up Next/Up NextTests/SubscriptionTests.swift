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
        // Start StoreKit only after the local test session is configured. Wait for
        // both the catalog and initial entitlements before attempting a purchase.
        let appData = AppData()
        let catalogLoaded = expectation(description: "The app loads the test catalog and initial entitlements")
        let catalogObservation = appData.$isLoadingSubscription.dropFirst().filter { !$0 }.first()
            .sink { _ in catalogLoaded.fulfill() }
        defer { catalogObservation.cancel() }
        appData.loadSubscriptionProduct()
        guard await XCTWaiter.fulfillment(of: [catalogLoaded], timeout: 60) == .completed else {
            return XCTFail("StoreKit initialization did not complete in 60 seconds")
        }
        XCTAssertFalse(appData.isSubscribed)
        let product = try XCTUnwrap(appData.subscriptionProduct, appData.subscriptionMessage ?? "Missing test product")
        guard case .success(let verification) = try await step("Purchase the test subscription", operation: { try await product.purchase() }),
              case .verified(let transaction) = verification else { return XCTFail("Expected a verified test purchase") }
        XCTAssertEqual(transaction.environment, .xcode)
        try await step("Finish the verified transaction") { await transaction.finish() }
        try await step("Refresh the purchased entitlement") { await appData.refreshSubscriptionStatus() }
        XCTAssertTrue(appData.isSubscribed)
        let refundObserved = expectation(description: "The transaction listener removes the refunded entitlement")
        let observation = appData.$isSubscribed.filter { !$0 }.first().sink { _ in refundObserved.fulfill() }
        defer { observation.cancel() }
        try session.refundTransaction(identifier: UInt(transaction.id))
        await fulfillment(of: [refundObserved], timeout: 30)
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
