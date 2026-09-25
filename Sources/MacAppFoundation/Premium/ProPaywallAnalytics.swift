#if os(macOS)
import Foundation

struct ProPaywallAnalyticsEvent: Sendable, Equatable {
    let name: String
    let dimension: String?

    init(_ name: String, dimension: String? = nil) {
        self.name = name
        self.dimension = dimension
    }
}

enum ProPaywallAnalytics {
    static let paywallViewed = ProPaywallAnalyticsEvent("paywall_viewed")
    static let paywallClosed = ProPaywallAnalyticsEvent("paywall_closed")
    static let restoreStarted = ProPaywallAnalyticsEvent("restore_started")
    static let restoreSucceeded = ProPaywallAnalyticsEvent("restore_succeeded")
    static let restoreNothingToRestore = ProPaywallAnalyticsEvent("restore_nothing_to_restore")
    static let offerCodeOpened = ProPaywallAnalyticsEvent("offer_code_opened")
    static let offerCodeSucceeded = ProPaywallAnalyticsEvent("offer_code_succeeded")

    static func planSelected(_ product: StoreProduct) -> ProPaywallAnalyticsEvent {
        ProPaywallAnalyticsEvent(
            "paywall_plan_selected",
            dimension: planDimension(for: product)
        )
    }

    static func purchaseStarted(_ product: StoreProduct) -> ProPaywallAnalyticsEvent {
        ProPaywallAnalyticsEvent(
            "purchase_started",
            dimension: planDimension(for: product)
        )
    }

    static func purchaseSucceeded(_ product: StoreProduct) -> ProPaywallAnalyticsEvent {
        ProPaywallAnalyticsEvent(
            "purchase_succeeded",
            dimension: planDimension(for: product)
        )
    }

    static func purchasePending(_ product: StoreProduct) -> ProPaywallAnalyticsEvent {
        ProPaywallAnalyticsEvent(
            "purchase_pending",
            dimension: planDimension(for: product)
        )
    }

    static func purchaseCancelled(_ product: StoreProduct) -> ProPaywallAnalyticsEvent {
        ProPaywallAnalyticsEvent(
            "purchase_cancelled",
            dimension: planDimension(for: product)
        )
    }

    static func purchaseFailed(
        _ product: StoreProduct,
        failure: PurchaseFailure
    ) -> ProPaywallAnalyticsEvent {
        ProPaywallAnalyticsEvent(
            "purchase_failed",
            dimension: "\(planDimension(for: product)):\(failure.code.rawValue)"
        )
    }

    static func restoreFailed(_ failure: PurchaseFailure) -> ProPaywallAnalyticsEvent {
        ProPaywallAnalyticsEvent(
            "restore_failed",
            dimension: failure.code.rawValue
        )
    }

    static func offerCodeFailed(_ error: Error) -> ProPaywallAnalyticsEvent {
        let failureCode = (error as? PurchaseFailure)?.code.rawValue ?? "unknown"
        return ProPaywallAnalyticsEvent(
            "offer_code_failed",
            dimension: failureCode
        )
    }

    static func planDimension(for product: StoreProduct) -> String {
        switch product.planKind {
        case .lifetime:
            return "lifetime"

        case .recurring(let period):
            if period.value == 1 && period.unit == .month {
                return "monthly"
            }
            if (period.value == 1 && period.unit == .year)
                || (period.value == 12 && period.unit == .month) {
                return "yearly"
            }
            return "recurring"

        case .unsupported:
            return "unsupported"
        }
    }
}
#endif
