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
        let appData = AppData.shared
        await appData.refreshSubscriptionStatus()
        XCTAssertFalse(appData.isSubscribed)
        let products = try await Product.products(for: ["AP0001"])
        let product = try XCTUnwrap(products.first)
        guard case .success(let verification) = try await product.purchase(),
              case .verified(let transaction) = verification else { return XCTFail("Expected a verified test purchase") }
        await transaction.finish()
        await appData.refreshSubscriptionStatus()
        XCTAssertTrue(appData.isSubscribed)
        let refundObserved = expectation(description: "The transaction listener removes the refunded entitlement")
        let observation = appData.$isSubscribed.filter { !$0 }.first().sink { _ in refundObserved.fulfill() }
        defer { observation.cancel() }
        try session.refundTransaction(identifier: UInt(transaction.id))
        await fulfillment(of: [refundObserved], timeout: 15)
        XCTAssertFalse(appData.isSubscribed)
    }
}
