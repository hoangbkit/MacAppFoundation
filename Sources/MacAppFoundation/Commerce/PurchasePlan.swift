import Foundation

/// A normalized purchase-plan classification used by paywalls and app UI.
public enum PurchasePlanKind: Sendable, Equatable {
    /// An auto-renewing StoreKit subscription.
    case recurring(StoreProduct.SubscriptionPeriod)

    /// A one-time entitlement product, normally a StoreKit non-consumable.
    case lifetime

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
        }
    }

    public var billingDescription: String {
        switch self {
        case .recurring(let period):
            return "Billed every \(period.shortLabel)"
        case .lifetime:
            return "One-time purchase, lifetime access"
        }
    }
}

public extension StoreProduct {
    var planKind: PurchasePlanKind {
        subscriptionPeriod.map(PurchasePlanKind.recurring) ?? .lifetime
    }

    var isRecurring: Bool { planKind.isRecurring }
    var isLifetime: Bool { planKind.isLifetime }
    var planLabel: String { planKind.label }
    var billingDescription: String { planKind.billingDescription }
}

/// Produces accurate legal copy for recurring, lifetime, or mixed catalogs.
public enum PurchasePlanDisclosure {
    public static func text(for products: [StoreProduct]) -> String {
        let hasRecurring = products.contains(where: \.isRecurring)
        let hasLifetime = products.contains(where: \.isLifetime)

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
