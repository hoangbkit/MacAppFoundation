#if DEBUG
import Foundation

enum DeveloperPurchaseOutcome: String, CaseIterable, Identifiable {
    case success
    case pending
    case userCancelled
    case networkFailure
    case productUnavailable
    case systemFailure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .success: "Success"
        case .pending: "Pending"
        case .userCancelled: "User Cancelled"
        case .networkFailure: "Network Failure"
        case .productUnavailable: "Product Unavailable"
        case .systemFailure: "System Failure"
        }
    }

    var failure: PurchaseFailure? {
        switch self {
        case .networkFailure:
            PurchaseFailure(
                code: .networkUnavailable,
                message: "Simulated network failure."
            )
        case .productUnavailable:
            .productUnavailable
        case .systemFailure:
            PurchaseFailure(
                code: .system,
                message: "Simulated App Store system failure."
            )
        case .success, .pending, .userCancelled:
            nil
        }
    }

    var result: SimulatedPurchaseResult {
        switch self {
        case .success: .success
        case .pending: .pending
        case .userCancelled: .userCancelled
        case .networkFailure, .productUnavailable, .systemFailure:
            .failure(failure ?? .unknown)
        }
    }
}

enum DeveloperPurchaseLatency: String, CaseIterable, Identifiable {
    case instant
    case normal
    case oneSecond
    case threeSeconds

    var id: String { rawValue }

    var title: String {
        switch self {
        case .instant: "Instant"
        case .normal: "250 ms"
        case .oneSecond: "1 second"
        case .threeSeconds: "3 seconds"
        }
    }

    var duration: Duration {
        switch self {
        case .instant: .milliseconds(0)
        case .normal: .milliseconds(250)
        case .oneSecond: .seconds(1)
        case .threeSeconds: .seconds(3)
        }
    }
}

enum DeveloperPlanPeriod: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case yearly
    case lifetime

    var id: String { rawValue }

    init(_ period: StoreProduct.SubscriptionPeriod?) {
        guard let period else {
            self = .lifetime
            return
        }
        switch period.unit {
        case .day: self = .daily
        case .week: self = .weekly
        case .month: self = .monthly
        case .year: self = .yearly
        case .unknown: self = .monthly
        }
    }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        case .lifetime: "Lifetime"
        }
    }

    var subscriptionPeriod: StoreProduct.SubscriptionPeriod? {
        switch self {
        case .daily: .init(value: 1, unit: .day)
        case .weekly: .init(value: 1, unit: .week)
        case .monthly: .init(value: 1, unit: .month)
        case .yearly: .init(value: 1, unit: .year)
        case .lifetime: nil
        }
    }
}

enum DeveloperIntroductoryOfferMode: String, CaseIterable, Identifiable {
    case none
    case freeTrial
    case payAsYouGo
    case payUpFront
    case unknown

    var id: String { rawValue }

    init(_ mode: StoreProduct.IntroductoryOffer.PaymentMode?) {
        switch mode {
        case .freeTrial: self = .freeTrial
        case .payAsYouGo: self = .payAsYouGo
        case .payUpFront: self = .payUpFront
        case .unknown: self = .unknown
        case nil: self = .none
        }
    }

    var title: String {
        switch self {
        case .none: "None"
        case .freeTrial: "Free Trial"
        case .payAsYouGo: "Pay As You Go"
        case .payUpFront: "Pay Up Front"
        case .unknown: "Unknown"
        }
    }

    var paymentMode: StoreProduct.IntroductoryOffer.PaymentMode? {
        switch self {
        case .none: nil
        case .freeTrial: .freeTrial
        case .payAsYouGo: .payAsYouGo
        case .payUpFront: .payUpFront
        case .unknown: .unknown
        }
    }
}

enum DeveloperIntroductoryOfferPeriodUnit: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case year
    case unknown

    var id: String { rawValue }

    init(_ unit: StoreProduct.SubscriptionPeriod.Unit) {
        switch unit {
        case .day: self = .day
        case .week: self = .week
        case .month: self = .month
        case .year: self = .year
        case .unknown: self = .unknown
        }
    }

    var title: String {
        switch self {
        case .day: "Days"
        case .week: "Weeks"
        case .month: "Months"
        case .year: "Years"
        case .unknown: "Unknown"
        }
    }

    var storeUnit: StoreProduct.SubscriptionPeriod.Unit {
        switch self {
        case .day: .day
        case .week: .week
        case .month: .month
        case .year: .year
        case .unknown: .unknown
        }
    }
}

struct DeveloperPlanDraft: Identifiable {
    let id: UUID
    var productID: String
    var displayName: String
    var productDescription: String
    var displayPrice: String
    var price: Double
    var period: DeveloperPlanPeriod
    var enabled: Bool
    var unlocksEntitlement: Bool
    var introductoryOfferMode: DeveloperIntroductoryOfferMode
    var introductoryOfferEligible: Bool
    var introductoryOfferPeriodValue: Int
    var introductoryOfferPeriodUnit: DeveloperIntroductoryOfferPeriodUnit
    var introductoryOfferPeriodCount: Int
    var introductoryOfferDisplayPrice: String
    var introductoryOfferPrice: Double

    init(
        id: UUID = UUID(),
        product: StoreProduct,
        enabled: Bool,
        unlocksEntitlement: Bool
    ) {
        let offer = product.introductoryOffer
        self.id = id
        self.productID = product.id
        self.displayName = product.displayName
        self.productDescription = product.description
        self.displayPrice = product.displayPrice
        self.price = product.price
        self.period = DeveloperPlanPeriod(product.subscriptionPeriod)
        self.enabled = enabled
        self.unlocksEntitlement = unlocksEntitlement
        self.introductoryOfferMode = DeveloperIntroductoryOfferMode(offer?.paymentMode)
        self.introductoryOfferEligible = offer?.isEligible ?? true
        self.introductoryOfferPeriodValue = max(1, offer?.period.value ?? 7)
        self.introductoryOfferPeriodUnit = DeveloperIntroductoryOfferPeriodUnit(
            offer?.period.unit ?? .day
        )
        self.introductoryOfferPeriodCount = max(1, offer?.periodCount ?? 1)
        self.introductoryOfferDisplayPrice = offer?.displayPrice ?? "$0.00"
        self.introductoryOfferPrice = max(0, offer?.price ?? 0)
    }

    private init(
        id: UUID = UUID(),
        productID: String,
        displayName: String,
        productDescription: String,
        displayPrice: String,
        price: Double,
        period: DeveloperPlanPeriod,
        enabled: Bool,
        unlocksEntitlement: Bool,
        introductoryOfferMode: DeveloperIntroductoryOfferMode = .none,
        introductoryOfferEligible: Bool = true,
        introductoryOfferPeriodValue: Int = 7,
        introductoryOfferPeriodUnit: DeveloperIntroductoryOfferPeriodUnit = .day,
        introductoryOfferPeriodCount: Int = 1,
        introductoryOfferDisplayPrice: String = "$0.00",
        introductoryOfferPrice: Double = 0
    ) {
        self.id = id
        self.productID = productID
        self.displayName = displayName
        self.productDescription = productDescription
        self.displayPrice = displayPrice
        self.price = price
        self.period = period
        self.enabled = enabled
        self.unlocksEntitlement = unlocksEntitlement
        self.introductoryOfferMode = introductoryOfferMode
        self.introductoryOfferEligible = introductoryOfferEligible
        self.introductoryOfferPeriodValue = max(1, introductoryOfferPeriodValue)
        self.introductoryOfferPeriodUnit = introductoryOfferPeriodUnit
        self.introductoryOfferPeriodCount = max(1, introductoryOfferPeriodCount)
        self.introductoryOfferDisplayPrice = introductoryOfferDisplayPrice
        self.introductoryOfferPrice = max(0, introductoryOfferPrice)
    }

    static func new(index: Int) -> DeveloperPlanDraft {
        DeveloperPlanDraft(
            productID: "com.example.app.pro.plan\(index)",
            displayName: "Pro Plan \(index)",
            productDescription: "Simulated premium access.",
            displayPrice: "$9.99",
            price: 9.99,
            period: .monthly,
            enabled: true,
            unlocksEntitlement: true
        )
    }

    var introductoryOfferSummary: String? {
        guard let offer = product.introductoryOffer else { return nil }
        return "\(offer.headline) · \(offer.isEligible ? "Eligible" : "Ineligible")"
    }

    var product: StoreProduct {
        StoreProduct(
            id: productID.trimmingCharacters(in: .whitespacesAndNewlines),
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: productDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            displayPrice: displayPrice.trimmingCharacters(in: .whitespacesAndNewlines),
            price: max(0, price),
            subscriptionPeriod: period.subscriptionPeriod,
            introductoryOffer: introductoryOffer
        )
    }

    private var introductoryOffer: StoreProduct.IntroductoryOffer? {
        guard period != .lifetime,
              let paymentMode = introductoryOfferMode.paymentMode
        else { return nil }

        return StoreProduct.IntroductoryOffer(
            paymentMode: paymentMode,
            period: .init(
                value: max(1, introductoryOfferPeriodValue),
                unit: introductoryOfferPeriodUnit.storeUnit
            ),
            periodCount: max(1, introductoryOfferPeriodCount),
            displayPrice: introductoryOfferDisplayPrice.trimmingCharacters(in: .whitespacesAndNewlines),
            price: max(0, introductoryOfferPrice),
            isEligible: introductoryOfferEligible
        )
    }
}
#endif
