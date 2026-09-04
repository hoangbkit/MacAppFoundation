import Foundation

/// A normalized purchase-plan classification used by paywalls and app UI.
public enum PurchasePlanKind: Sendable, Equatable {
    /// An auto-renewing StoreKit subscription.
    case recurring(StoreProduct.SubscriptionPeriod)

    /// A one-time entitlement product, normally a StoreKit non-consumable.
    case lifetime

    /// A StoreKit type MacAppFoundation doesn't manage as a Pro entitlement.
    case unsupported

    public var isRecurring: Bool {
        if case .recurring = self { return true }
        return false
    }

    public var isLifetime: Bool {
        if case .lifetime = self { return true }
        return false
    }

    public var label: String {
        switch self {
        case .lifetime:
            return "Lifetime"
        case .recurring(let period):
            guard period.value == 1 else {
                return period.shortLabel.capitalized
            }

            switch period.unit {
            case .day:
                return "Daily"
            case .week:
                return "Weekly"
            case .month:
                return "Monthly"
            case .year:
                return "Yearly"
            case .unknown:
                return "Recurring"
            }
        case .unsupported:
            return "Unsupported"
        }
    }

    public var billingDescription: String {
        switch self {
        case .recurring(let period):
            return "Billed every \(period.shortLabel)"
        case .lifetime:
            return "One-time purchase, lifetime access"
        case .unsupported:
            return "Unsupported product type"
        }
    }
}

public extension StoreProduct.IntroductoryOffer {
    var isFreeTrial: Bool { paymentMode == .freeTrial }

    var durationDescription: String {
        let totalPeriods = period.value * periodCount
        return StoreProduct.SubscriptionPeriod(
            value: totalPeriods,
            unit: period.unit
        ).shortLabel
    }

    var headline: String {
        switch paymentMode {
        case .freeTrial:
            return "\(durationDescription) free"
        case .payAsYouGo:
            let cadence = period.value == 1
                ? "\(displayPrice)/\(period.shortLabel)"
                : "\(displayPrice) every \(period.shortLabel)"
            return periodCount == 1 ? cadence : "\(cadence) for \(durationDescription)"
        case .payUpFront:
            return "\(displayPrice) for \(durationDescription)"
        case .unknown:
            return "Introductory offer available"
        }
    }
}

public extension StoreProduct {
    /// Whether this StoreKit product type is supported by the package's Pro entitlement flow.
    var isSupportedProProduct: Bool {
        type == .autoRenewable || type == .nonConsumable
    }

    var planKind: PurchasePlanKind {
        switch type {
        case .autoRenewable:
            guard let subscriptionPeriod else { return .unsupported }
            return .recurring(subscriptionPeriod)
        case .nonConsumable:
            return .lifetime
        case .consumable, .nonRenewable, .unknown:
            return .unsupported
        }
    }

    var isRecurring: Bool { planKind.isRecurring }
    var isLifetime: Bool { planKind.isLifetime }
    var planLabel: String { planKind.label }
    var billingDescription: String { planKind.billingDescription }

    /// Returns the configured introductory offer only when StoreKit says the
    /// current customer is eligible to redeem it.
    var eligibleIntroductoryOffer: IntroductoryOffer? {
        guard type == .autoRenewable,
              let introductoryOffer,
              introductoryOffer.isEligible
        else { return nil }
        return introductoryOffer
    }

    /// The eligible introductory offer when it is specifically a free trial.
    var eligibleFreeTrial: IntroductoryOffer? {
        guard let offer = eligibleIntroductoryOffer, offer.isFreeTrial else { return nil }
        return offer
    }

    /// Localized recurring price plus a compact billing cadence, such as
    /// "$39.99/year" or "$5.99 every 3 months".
    var recurringPriceDescription: String? {
        guard type == .autoRenewable, let period = subscriptionPeriod else { return nil }
        if period.value == 1 {
            return "\(displayPrice)/\(period.shortLabel)"
        }
        return "\(displayPrice) every \(period.shortLabel)"
    }

    /// Highlighted introductory-offer copy suitable for a plan option.
    var introductoryOfferHeadline: String? {
        eligibleIntroductoryOffer?.headline
    }

    /// Regular billing copy shown immediately after an introductory offer.
    var postIntroductoryOfferBillingDescription: String? {
        guard eligibleIntroductoryOffer != nil,
              let recurringPriceDescription
        else { return nil }
        return "Then \(recurringPriceDescription)"
    }

    /// Trial-aware primary action title while preserving the app's configured
    /// CTA for products without an eligible free trial.
    func purchaseActionTitle(defaultTitle: String) -> String {
        if eligibleFreeTrial != nil {
            return "Start Free Trial"
        }
        return "\(defaultTitle) with \(planLabel)"
    }

    /// Selected-plan disclosure for eligible introductory offers. The generic
    /// catalog disclosure remains responsible for lifetime and renewal policy.
    var introductoryOfferDisclosure: String? {
        guard let offer = eligibleIntroductoryOffer,
              let recurringPriceDescription
        else { return nil }
        return "\(offer.headline), then \(recurringPriceDescription). Renews automatically until cancelled."
    }
}

/// Produces accurate legal copy for recurring, lifetime, or mixed catalogs.
public enum PurchasePlanDisclosure {
    public static func text(for products: [StoreProduct]) -> String {
        let supportedProducts = products.filter(\.isSupportedProProduct)
        let hasRecurring = supportedProducts.contains(where: \.isRecurring)
        let hasLifetime = supportedProducts.contains(where: \.isLifetime)

        switch (hasRecurring, hasLifetime) {
        case (true, true):
            return "Subscriptions renew automatically unless cancelled in App Store settings. Lifetime access is a one-time purchase."
        case (true, false):
            return "Subscriptions renew automatically unless cancelled in App Store settings."
        case (false, true):
            return "Lifetime access is a one-time purchase charged to your Apple ID."
        case (false, false):
            return "Payment is charged to your Apple ID at confirmation."
        }
    }
}
