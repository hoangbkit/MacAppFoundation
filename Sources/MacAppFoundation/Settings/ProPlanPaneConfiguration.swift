import Foundation

/// App-owned copy and links for the Spokio-style macOS Pro plan pane.
public struct ProPlanPaneConfiguration: Sendable, Equatable {
    public let appName: String
    public let freeTitle: String
    public let proTitle: String
    public let freeDescription: String
    public let proDescription: String
    public let upgradeButtonTitle: String
    public let upgradeButtonHeight: CGFloat
    public let viewPlansButtonTitle: String
    public let manageSubscriptionTitle: String
    public let restorePurchasesTitle: String
    public let manageSubscriptionURL: URL
    public let features: [PurchaseFeature]?

    public init(
        appName: String,
        freeTitle: String = "Free",
        proTitle: String = "Pro",
        freeDescription: String? = nil,
        proDescription: String? = nil,
        upgradeButtonTitle: String = "Upgrade to Pro",
        upgradeButtonHeight: CGFloat = 32,
        viewPlansButtonTitle: String = "View Plans",
        manageSubscriptionTitle: String = "Manage Subscription",
        restorePurchasesTitle: String = "Restore Purchases",
        manageSubscriptionURL: URL = URL(string: "https://apps.apple.com/account/subscriptions")!,
        features: [PurchaseFeature]? = nil
    ) {
        self.appName = appName
        self.freeTitle = freeTitle
        self.proTitle = proTitle
        self.freeDescription = freeDescription
            ?? "Upgrade to unlock the full \(appName) experience."
        self.proDescription = proDescription
            ?? "You have access to \(appName) Pro features."
        self.upgradeButtonTitle = upgradeButtonTitle
        self.upgradeButtonHeight = max(0, upgradeButtonHeight)
        self.viewPlansButtonTitle = viewPlansButtonTitle
        self.manageSubscriptionTitle = manageSubscriptionTitle
        self.restorePurchasesTitle = restorePurchasesTitle
        self.manageSubscriptionURL = manageSubscriptionURL
        self.features = features
    }
}
