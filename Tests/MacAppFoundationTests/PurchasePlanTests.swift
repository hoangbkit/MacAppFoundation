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

    func testEligibleFreeTrialProducesTrialAwarePaywallCopy() {
        let product = StoreProduct(
            id: "pro.yearly",
            displayName: "Pro Yearly",
            description: "Annual access",
            displayPrice: "$39.99",
            price: 39.99,
            subscriptionPeriod: .init(value: 1, unit: .year),
            introductoryOffer: .init(
                paymentMode: .freeTrial,
                period: .init(value: 7, unit: .day),
                displayPrice: "$0.00",
                price: 0,
                isEligible: true
            )
        )

        XCTAssertEqual(product.eligibleFreeTrial?.durationDescription, "7 days")
        XCTAssertEqual(product.introductoryOfferHeadline, "7 days free")
        XCTAssertEqual(product.recurringPriceDescription, "$39.99/year")
        XCTAssertEqual(product.postIntroductoryOfferBillingDescription, "Then $39.99/year")
        XCTAssertEqual(product.purchaseActionTitle(defaultTitle: "Continue"), "Start Free Trial")
        XCTAssertEqual(
            product.introductoryOfferDisclosure,
            "7 days free, then $39.99/year. Renews automatically until cancelled."
        )
    }

    func testIneligibleFreeTrialFallsBackToNormalSubscriptionCopy() {
        let product = StoreProduct(
            id: "pro.yearly",
            displayName: "Pro Yearly",
            description: "Annual access",
            displayPrice: "$39.99",
            price: 39.99,
            subscriptionPeriod: .init(value: 1, unit: .year),
            introductoryOffer: .init(
                paymentMode: .freeTrial,
                period: .init(value: 7, unit: .day),
                displayPrice: "$0.00",
                price: 0,
                isEligible: false
            )
        )

        XCTAssertNil(product.eligibleIntroductoryOffer)
        XCTAssertNil(product.eligibleFreeTrial)
        XCTAssertNil(product.introductoryOfferHeadline)
        XCTAssertNil(product.postIntroductoryOfferBillingDescription)
        XCTAssertNil(product.introductoryOfferDisclosure)
        XCTAssertEqual(product.purchaseActionTitle(defaultTitle: "Continue"), "Continue with Yearly")
    }

    func testPayAsYouGoIntroductoryOfferUsesTotalDuration() {
        let offer = StoreProduct.IntroductoryOffer(
            paymentMode: .payAsYouGo,
            period: .init(value: 1, unit: .month),
            periodCount: 3,
            displayPrice: "$1.99",
            price: 1.99,
            isEligible: true
        )

        XCTAssertEqual(offer.durationDescription, "3 months")
        XCTAssertEqual(offer.headline, "$1.99/month for 3 months")
    }

    func testPayUpFrontIntroductoryOfferCopy() {
        let offer = StoreProduct.IntroductoryOffer(
            paymentMode: .payUpFront,
            period: .init(value: 3, unit: .month),
            displayPrice: "$9.99",
            price: 9.99,
            isEligible: true
        )

        XCTAssertEqual(offer.durationDescription, "3 months")
        XCTAssertEqual(offer.headline, "$9.99 for 3 months")
    }

    func testLifetimeProductIgnoresInjectedIntroductoryOffer() {
        let product = StoreProduct(
            id: "pro.lifetime",
            displayName: "Lifetime",
            description: "",
            displayPrice: "$79.99",
            price: 79.99,
            introductoryOffer: .init(
                paymentMode: .freeTrial,
                period: .init(value: 7, unit: .day),
                displayPrice: "$0.00",
                price: 0,
                isEligible: true
            )
        )

        XCTAssertNil(product.eligibleIntroductoryOffer)
        XCTAssertNil(product.eligibleFreeTrial)
        XCTAssertEqual(product.purchaseActionTitle(defaultTitle: "Continue"), "Continue with Lifetime")
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
