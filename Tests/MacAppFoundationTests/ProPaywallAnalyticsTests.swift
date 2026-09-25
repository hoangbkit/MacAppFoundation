import Foundation
import XCTest
@testable import MacAppFoundation

final class ProPaywallAnalyticsTests: XCTestCase {
    func testPlanDimensionsAreBoundedAndStable() {
        let monthly = product(
            id: "pro.monthly",
            period: .init(value: 1, unit: .month)
        )
        let yearly = product(
            id: "pro.yearly",
            period: .init(value: 1, unit: .year)
        )
        let twelveMonths = product(
            id: "pro.twelve-months",
            period: .init(value: 12, unit: .month)
        )
        let weekly = product(
            id: "pro.weekly",
            period: .init(value: 1, unit: .week)
        )
        let lifetime = product(id: "pro.lifetime")

        XCTAssertEqual(ProPaywallAnalytics.planDimension(for: monthly), "monthly")
        XCTAssertEqual(ProPaywallAnalytics.planDimension(for: yearly), "yearly")
        XCTAssertEqual(ProPaywallAnalytics.planDimension(for: twelveMonths), "yearly")
        XCTAssertEqual(ProPaywallAnalytics.planDimension(for: weekly), "recurring")
        XCTAssertEqual(ProPaywallAnalytics.planDimension(for: lifetime), "lifetime")
    }

    func testPurchaseEventsUsePlanDimension() {
        let yearly = product(
            id: "pro.yearly",
            period: .init(value: 1, unit: .year)
        )

        XCTAssertEqual(
            ProPaywallAnalytics.planSelected(yearly),
            ProPaywallAnalyticsEvent("paywall_plan_selected", dimension: "yearly")
        )
        XCTAssertEqual(
            ProPaywallAnalytics.purchaseStarted(yearly),
            ProPaywallAnalyticsEvent("purchase_started", dimension: "yearly")
        )
        XCTAssertEqual(
            ProPaywallAnalytics.purchaseSucceeded(yearly),
            ProPaywallAnalyticsEvent("purchase_succeeded", dimension: "yearly")
        )
        XCTAssertEqual(
            ProPaywallAnalytics.purchasePending(yearly),
            ProPaywallAnalyticsEvent("purchase_pending", dimension: "yearly")
        )
        XCTAssertEqual(
            ProPaywallAnalytics.purchaseCancelled(yearly),
            ProPaywallAnalyticsEvent("purchase_cancelled", dimension: "yearly")
        )
    }

    func testFailuresUseOnlyStableBoundedCodes() {
        let lifetime = product(id: "pro.lifetime")
        let failure = PurchaseFailure(
            code: .verificationFailed,
            message: "Localized text that must not enter analytics"
        )

        XCTAssertEqual(
            ProPaywallAnalytics.purchaseFailed(lifetime, failure: failure),
            ProPaywallAnalyticsEvent(
                "purchase_failed",
                dimension: "lifetime:verificationFailed"
            )
        )
        XCTAssertEqual(
            ProPaywallAnalytics.restoreFailed(failure),
            ProPaywallAnalyticsEvent(
                "restore_failed",
                dimension: "verificationFailed"
            )
        )
        XCTAssertEqual(
            ProPaywallAnalytics.offerCodeFailed(NSError(domain: "test", code: 7)),
            ProPaywallAnalyticsEvent(
                "offer_code_failed",
                dimension: "unknown"
            )
        )
    }

    func testNonProductEventsHaveNoDimension() {
        XCTAssertEqual(
            ProPaywallAnalytics.paywallViewed,
            ProPaywallAnalyticsEvent("paywall_viewed")
        )
        XCTAssertEqual(
            ProPaywallAnalytics.paywallClosed,
            ProPaywallAnalyticsEvent("paywall_closed")
        )
        XCTAssertEqual(
            ProPaywallAnalytics.restoreStarted,
            ProPaywallAnalyticsEvent("restore_started")
        )
        XCTAssertEqual(
            ProPaywallAnalytics.restoreSucceeded,
            ProPaywallAnalyticsEvent("restore_succeeded")
        )
        XCTAssertEqual(
            ProPaywallAnalytics.restoreNothingToRestore,
            ProPaywallAnalyticsEvent("restore_nothing_to_restore")
        )
        XCTAssertEqual(
            ProPaywallAnalytics.offerCodeOpened,
            ProPaywallAnalyticsEvent("offer_code_opened")
        )
        XCTAssertEqual(
            ProPaywallAnalytics.offerCodeSucceeded,
            ProPaywallAnalyticsEvent("offer_code_succeeded")
        )
    }

    private func product(
        id: String,
        period: StoreProduct.SubscriptionPeriod? = nil
    ) -> StoreProduct {
        StoreProduct(
            id: id,
            displayName: id,
            description: "",
            displayPrice: "$1.00",
            price: 1,
            subscriptionPeriod: period
        )
    }
}
