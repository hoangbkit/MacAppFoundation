import Foundation
import XCTest
@testable import MacAppFoundation

final class EntitlementEvaluatorTests: XCTestCase {
    private let entitledIDs: Set<String> = ["pro.monthly", "pro.yearly", "pro.lifetime"]
    private let now = Date(timeIntervalSince1970: 2_000_000)

    func testLifetimePurchaseIsActive() {
        let state = EntitlementEvaluator.evaluate(
            [EntitlementRecord(productID: "pro.lifetime")],
            entitledProductIDs: entitledIDs,
            at: now
        )

        XCTAssertTrue(state.isActive)
    }

    func testExpiredSubscriptionIsInactive() {
        let state = EntitlementEvaluator.evaluate(
            [EntitlementRecord(productID: "pro.monthly", expirationDate: now.addingTimeInterval(-1))],
            entitledProductIDs: entitledIDs,
            at: now
        )

        XCTAssertEqual(state, .inactive)
    }

    func testRevokedAndUpgradedTransactionsAreInactive() {
        let records = [
            EntitlementRecord(
                productID: "pro.yearly",
                expirationDate: now.addingTimeInterval(10_000),
                revocationDate: now.addingTimeInterval(-10)
            ),
            EntitlementRecord(
                productID: "pro.monthly",
                expirationDate: now.addingTimeInterval(10_000),
                isUpgraded: true
            )
        ]

        XCTAssertEqual(
            EntitlementEvaluator.evaluate(records, entitledProductIDs: entitledIDs, at: now),
            .inactive
        )
    }

    func testSnapshotContainsEveryActiveProductAndLatestExpiration() throws {
        let monthlyExpiration = now.addingTimeInterval(3_000)
        let yearlyExpiration = now.addingTimeInterval(8_000)

        let state = EntitlementEvaluator.evaluate(
            [
                EntitlementRecord(productID: "pro.monthly", expirationDate: monthlyExpiration),
                EntitlementRecord(productID: "pro.yearly", expirationDate: yearlyExpiration)
            ],
            entitledProductIDs: entitledIDs,
            at: now
        )

        guard case .active(let snapshot) = state else {
            return XCTFail("Expected an active entitlement")
        }

        XCTAssertEqual(snapshot.activeProductIDs, ["pro.monthly", "pro.yearly"])
        XCTAssertEqual(snapshot.latestExpirationDate, yearlyExpiration)
    }

    func testPermanentEntitlementMakesSnapshotNonExpiring() throws {
        let state = EntitlementEvaluator.evaluate(
            [
                EntitlementRecord(
                    productID: "pro.monthly",
                    expirationDate: now.addingTimeInterval(3_000)
                ),
                EntitlementRecord(productID: "pro.lifetime")
            ],
            entitledProductIDs: entitledIDs,
            at: now
        )

        guard case .active(let snapshot) = state else {
            return XCTFail("Expected an active entitlement")
        }

        XCTAssertEqual(snapshot.activeProductIDs, ["pro.monthly", "pro.lifetime"])
        XCTAssertNil(snapshot.latestExpirationDate)
    }
}
