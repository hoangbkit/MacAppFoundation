import Foundation

public struct StoreProduct: Identifiable, Sendable, Equatable {
    public struct SubscriptionPeriod: Sendable, Equatable {
        public enum Unit: String, Sendable, Equatable {
            case day
            case week
            case month
            case year
            case unknown
        }

        public let value: Int
        public let unit: Unit

        public init(value: Int, unit: Unit) {
            self.value = max(1, value)
            self.unit = unit
        }

        public var shortLabel: String {
            let singular: String
            switch unit {
            case .day:
                singular = "day"
            case .week:
                singular = "week"
            case .month:
                singular = "month"
            case .year:
                singular = "year"
            case .unknown:
                singular = "period"
            }

            return value == 1 ? singular : "\(value) \(singular)s"
        }
    }

    public struct IntroductoryOffer: Sendable, Equatable {
        public enum PaymentMode: String, Sendable, Equatable {
            case freeTrial
            case payAsYouGo
            case payUpFront
            case unknown
        }

        public let paymentMode: PaymentMode
        public let period: SubscriptionPeriod
        public let periodCount: Int
        public let displayPrice: String
        public let price: Double
        public let isEligible: Bool

        public init(
            paymentMode: PaymentMode,
            period: SubscriptionPeriod,
            periodCount: Int = 1,
            displayPrice: String,
            price: Double,
            isEligible: Bool
        ) {
            self.paymentMode = paymentMode
            self.period = period
            self.periodCount = max(1, periodCount)
            self.displayPrice = paymentMode == .freeTrial ? "Free" : displayPrice
            self.price = paymentMode == .freeTrial ? 0 : price
            self.isEligible = isEligible
        }
    }

    public let id: String
    public let displayName: String
    public let description: String
    public let displayPrice: String
    public let price: Double
    public let subscriptionPeriod: SubscriptionPeriod?
    public let introductoryOffer: IntroductoryOffer?

    public init(
        id: String,
        displayName: String,
        description: String,
        displayPrice: String,
        price: Double,
        subscriptionPeriod: SubscriptionPeriod? = nil,
        introductoryOffer: IntroductoryOffer? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.displayPrice = displayPrice
        self.price = price
        self.subscriptionPeriod = subscriptionPeriod
        self.introductoryOffer = introductoryOffer
    }
}

/// Preferred neutral name for a StoreKit product exposed by MacAppFoundation.
public typealias PurchaseProduct = StoreProduct

public enum ProductCatalog {
    public static func ordered(
        _ products: [StoreProduct],
        using productIDs: [String]
    ) -> [StoreProduct] {
        let positions = Dictionary(uniqueKeysWithValues: productIDs.enumerated().map { ($1, $0) })

        return products.sorted { lhs, rhs in
            let lhsPosition = positions[lhs.id] ?? .max
            let rhsPosition = positions[rhs.id] ?? .max

            if lhsPosition == rhsPosition {
                return lhs.price < rhs.price
            }
            return lhsPosition < rhsPosition
        }
    }
}
