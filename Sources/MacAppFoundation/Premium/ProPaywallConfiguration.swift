import Foundation

/// One app-owned benefit shown on the macOS Pro paywall.
public struct ProPaywallFeature: Identifiable, Hashable, Sendable {
    public let id: String
    public let systemImage: String
    public let title: String
    public let message: String

    public init(
        id: String,
        systemImage: String,
        title: String,
        message: String
    ) {
        self.id = id
        self.systemImage = systemImage
        self.title = title
        self.message = message
    }

    public init(_ feature: PurchaseFeature) {
        self.init(
            id: feature.id,
            systemImage: feature.systemImage,
            title: feature.title,
            message: feature.message
        )
    }
}

/// App-owned copy and presentation choices for ``ProPaywallView``.
///
/// Product identifiers, prices, trial eligibility, and entitlement state come
/// from ``PurchaseManager``. The consuming app supplies product copy, legal
/// destinations, and the features it wants to communicate.
public struct ProPaywallConfiguration: Sendable, Equatable {
    public let title: String
    public let subtitle: String
    public let features: [ProPaywallFeature]
    public let purchaseButtonTitle: String
    public let highlightedProductID: String?
    public let highlightedProductBadge: String
    public let termsURL: URL
    public let privacyURL: URL
    public let showsRedeemCode: Bool

    public init(
        title: String,
        subtitle: String,
        features: [ProPaywallFeature] = [],
        purchaseButtonTitle: String = "Continue",
        highlightedProductID: String? = nil,
        highlightedProductBadge: String = "BEST VALUE",
        termsURL: URL,
        privacyURL: URL,
        showsRedeemCode: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.features = features
        self.purchaseButtonTitle = purchaseButtonTitle
        self.highlightedProductID = highlightedProductID
        self.highlightedProductBadge = highlightedProductBadge
        self.termsURL = termsURL
        self.privacyURL = privacyURL
        self.showsRedeemCode = showsRedeemCode
    }
}
