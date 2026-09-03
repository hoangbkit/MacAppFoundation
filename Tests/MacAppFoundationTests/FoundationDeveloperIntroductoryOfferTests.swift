#if DEBUG
import XCTest
@testable import MacAppFoundation

final class FoundationDeveloperIntroductoryOfferTests: XCTestCase {
    func testDeveloperPlanDraftPreservesFreeTrialMetadata() {
        let offer = StoreProduct.IntroductoryOffer(
            paymentMode: .freeTrial,
            period: .init(value: 7, unit: .day),
            displayPrice: "$0.00",
            price: 0,
            isEligible: true
        )
        let product = StoreProduct(
            id: "pro.yearly",
            displayName: "Yearly",
            description: "Yearly access",
            displayPrice: "$7.99",
            price: 7.99,
            subscriptionPeriod: .init(value: 1, unit: .year),
            introductoryOffer: offer
        )

        let draft = DeveloperPlanDraft(
            product: product,
            enabled: true,
            unlocksEntitlement: true
        )

        XCTAssertEqual(draft.introductoryOfferMode, .freeTrial)
        XCTAssertTrue(draft.introductoryOfferEligible)
        XCTAssertEqual(draft.introductoryOfferPeriodValue, 7)
        XCTAssertEqual(draft.introductoryOfferPeriodUnit, .day)
        XCTAssertEqual(draft.product.introductoryOffer, offer)
    }

    func testDeveloperPlanDraftCanSimulateIneligibleTrial() {
        let product = StoreProduct(
            id: "pro.yearly",
            displayName: "Yearly",
            description: "Yearly access",
            displayPrice: "$7.99",
            price: 7.99,
            subscriptionPeriod: .init(value: 1, unit: .year),
            introductoryOffer: .init(
                paymentMode: .freeTrial,
                period: .init(value: 7, unit: .day),
                displayPrice: "$0.00",
                price: 0,
                isEligible: true
            )
        )
        var draft = DeveloperPlanDraft(
            product: product,
            enabled: true,
            unlocksEntitlement: true
        )

        draft.introductoryOfferEligible = false

        XCTAssertEqual(draft.product.introductoryOffer?.isEligible, false)
        XCTAssertNil(draft.product.eligibleFreeTrial)
        XCTAssertEqual(
            draft.product.purchaseActionTitle(defaultTitle: "Continue"),
            "Continue with Yearly"
        )
    }

    func testDeveloperPlanDraftCanConfigurePaidIntroductoryOffer() {
        let product = StoreProduct(
            id: "pro.monthly",
            displayName: "Monthly",
            description: "Monthly access",
            displayPrice: "$4.99",
            price: 4.99,
            subscriptionPeriod: .init(value: 1, unit: .month)
        )
        var draft = DeveloperPlanDraft(
            product: product,
            enabled: true,
            unlocksEntitlement: true
        )

        draft.introductoryOfferMode = .payAsYouGo
        draft.introductoryOfferEligible = true
        draft.introductoryOfferPeriodValue = 1
        draft.introductoryOfferPeriodUnit = .month
        draft.introductoryOfferPeriodCount = 3
        draft.introductoryOfferDisplayPrice = "$0.99"
        draft.introductoryOfferPrice = 0.99

        XCTAssertEqual(
            draft.product.introductoryOffer,
            StoreProduct.IntroductoryOffer(
                paymentMode: .payAsYouGo,
                period: .init(value: 1, unit: .month),
                periodCount: 3,
                displayPrice: "$0.99",
                price: 0.99,
                isEligible: true
            )
        )
    }

    func testSwitchingPaidOfferToFreeTrialNormalizesPriceToFree() {
        let product = StoreProduct(
            id: "pro.yearly",
            displayName: "Yearly",
            description: "Yearly access",
            displayPrice: "$7.99",
            price: 7.99,
            subscriptionPeriod: .init(value: 1, unit: .year)
        )
        var draft = DeveloperPlanDraft(
            product: product,
            enabled: true,
            unlocksEntitlement: true
        )
        draft.introductoryOfferMode = .payAsYouGo
        draft.introductoryOfferDisplayPrice = "$0.99"
        draft.introductoryOfferPrice = 0.99

        draft.introductoryOfferMode = .freeTrial
        let offer = draft.product.introductoryOffer

        XCTAssertEqual(offer?.paymentMode, .freeTrial)
        XCTAssertEqual(offer?.displayPrice, "Free")
        XCTAssertEqual(offer?.price, 0)
    }

    func testLifetimePlanCannotRetainIntroductoryOffer() {
        let product = StoreProduct(
            id: "pro.yearly",
            displayName: "Yearly",
            description: "Yearly access",
            displayPrice: "$7.99",
            price: 7.99,
            subscriptionPeriod: .init(value: 1, unit: .year),
            introductoryOffer: .init(
                paymentMode: .freeTrial,
                period: .init(value: 7, unit: .day),
                displayPrice: "$0.00",
                price: 0,
                isEligible: true
            )
        )
        var draft = DeveloperPlanDraft(
            product: product,
            enabled: true,
            unlocksEntitlement: true
        )

        draft.period = .lifetime

        XCTAssertNil(draft.product.introductoryOffer)
        XCTAssertTrue(draft.product.isLifetime)
    }
}
#endif
