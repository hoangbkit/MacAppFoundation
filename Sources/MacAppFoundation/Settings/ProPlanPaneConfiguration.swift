import Foundation

/// App-owned copy and links for the Spokio-style macOS Pro plan pane.
public struct ProPlanPaneConfiguration: Sendable, Equatable {
    public let appName: String
    public let freeTitle: String
    public let proTitle: String
    public let freeDescription: String
    public let proDescription: String
    public let upgradeButtonTitle: String
    public let manageSubscriptionTitle: String
    public let manageSubscriptionURL: URL
    public let features: [PurchaseFeature]?

    public init(
        appName: String,
        freeTitle: String = "Free",
        proTitle: String = "Pro",
        freeDescription: String? = nil,
        proDescription: String? = nil,
        upgradeButtonTitle: String = "Upgrade to Pro",
        manageSubscriptionTitle: String = "Manage Subscription",
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
        self.manageSubscriptionTitle = manageSubscriptionTitle
        self.manageSubscriptionURL = manageSubscriptionURL
        self.features = features
    }
}
