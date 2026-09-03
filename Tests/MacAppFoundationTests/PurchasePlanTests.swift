import XCTest
@testable import MacAppFoundation

final class PurchasePlanTests: XCTestCase {
    func testWeeklyPlanMetadata() {
        let product = StoreProduct(
            id: "pro.weekly",
            displayName: "Pro Weekly",
            description: "Weekly access",
            displayPrice: "$1.99",
            price: 1.99,
            subscriptionPeriod: .init(value: 1, unit: .week)
        )

        XCTAssertEqual(product.planKind, .recurring(.init(value: 1, unit: .week)))
        XCTAssertTrue(product.isRecurring)
        XCTAssertFalse(product.isLifetime)
        XCTAssertEqual(product.planLabel, "Weekly")
        XCTAssertEqual(product.billingDescription, "Billed every week")
    }

    func testMonthlyYearlyAndLifetimeLabels() {
        let monthly = StoreProduct(
            id: "pro.monthly",
            displayName: "Monthly",
            description: "",
            displayPrice: "$4.99",
            price: 4.99,
            subscriptionPeriod: .init(value: 1, unit: .month)
        )
        let yearly = StoreProduct(
            id: "pro.yearly",
            displayName: "Yearly",
            description: "",
            displayPrice: "$39.99",
            price: 39.99,
            subscriptionPeriod: .init(value: 1, unit: .year)
        )
        let lifetime = StoreProduct(
            id: "pro.lifetime",
            displayName: "Lifetime",
            description: "",
            displayPrice: "$79.99",
            price: 79.99
        )

        XCTAssertEqual(monthly.planLabel, "Monthly")
        XCTAssertEqual(yearly.planLabel, "Yearly")
        XCTAssertEqual(lifetime.planLabel, "Lifetime")
        XCTAssertTrue(lifetime.isLifetime)
    }

    func testMixedCatalogDisclosureMentionsRenewalAndOneTimePurchase() {
        let weekly = StoreProduct(
            id: "pro.weekly",
            displayName: "Weekly",
            description: "",
            displayPrice: "$1.99",
            price: 1.99,
            subscriptionPeriod: .init(value: 1, unit: .week)
        )
        let lifetime = StoreProduct(
            id: "pro.lifetime",
            displayName: "Lifetime",
            description: "",
            displayPrice: "$79.99",
            price: 79.99
        )

        XCTAssertEqual(
            PurchasePlanDisclosure.text(for: [weekly, lifetime]),
            "Subscriptions renew automatically unless cancelled in App Store settings. Lifetime access is a one-time purchase."
        )
    }

    func testFreeTrialNormalizesPriceToFree() {
        let offer = StoreProduct.IntroductoryOffer(
            paymentMode: .freeTrial,
            period: .init(value: 7, unit: .day),
            displayPrice: "$9.99",
            price: 9.99,
            isEligible: true
        )

        XCTAssertEqual(offer.displayPrice, "Free")
        XCTAssertEqual(offer.price, 0)
        XCTAssertTrue(offer.isEligible)
    }
}
