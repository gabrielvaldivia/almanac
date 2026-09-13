import XCTest
import StoreKit
import StoreKitTest
import Combine
@testable import Up_Next

final class SubscriptionTests: XCTestCase {
    @MainActor
    func testVerifiedPurchaseAndRefundRefreshEntitlements() async throws {
        let session = try SKTestSession(configurationFileNamed: "Almanac Pro")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.timeRate = .realTime
        session.clearTransactions()
        defer { session.clearTransactions() }
        // The host app starts before XCTest can configure StoreKit. Create the
        // observer after the test session so it listens in the test environment.
        let appData = AppData()
        let catalogLoaded = expectation(description: "The app loads the test product catalog")
        let catalogObservation = appData.$subscriptionProduct.compactMap { $0 }.first()
            .sink { _ in catalogLoaded.fulfill() }
        defer { catalogObservation.cancel() }
        await fulfillment(of: [catalogLoaded], timeout: 60)
        XCTAssertFalse(appData.isSubscribed)
        let product = try XCTUnwrap(appData.subscriptionProduct, appData.subscriptionMessage ?? "Missing test product")
        guard case .success(let verification) = try await product.purchase(),
              case .verified(let transaction) = verification else { return XCTFail("Expected a verified test purchase") }
        await transaction.finish()
        await appData.refreshSubscriptionStatus()
        XCTAssertTrue(appData.isSubscribed)
        let refundObserved = expectation(description: "The transaction listener removes the refunded entitlement")
        let observation = appData.$isSubscribed.filter { !$0 }.first().sink { _ in refundObserved.fulfill() }
        defer { observation.cancel() }
        try session.refundTransaction(identifier: UInt(transaction.id))
        await fulfillment(of: [refundObserved], timeout: 60)
        XCTAssertFalse(appData.isSubscribed)
    }
}
