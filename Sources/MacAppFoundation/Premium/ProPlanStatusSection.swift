import SwiftUI

public struct ProPlanStatusConfiguration: Sendable, Equatable {
    public var sectionTitle: String
    public var freePlanTitle: String
    public var activePlanTitle: String
    public var upgradeTitle: String
    public var manageSubscriptionTitle: String
    public var restorePurchasesTitle: String
    public var manageSubscriptionsURL: URL?

    public init(
        sectionTitle: String = "Pro",
        freePlanTitle: String = "Free",
        activePlanTitle: String = "Pro",
        upgradeTitle: String = "Upgrade to Pro",
        manageSubscriptionTitle: String = "Manage Subscription",
        restorePurchasesTitle: String = "Restore Purchases",
        manageSubscriptionsURL: URL? = URL(string: "https://apps.apple.com/account/subscriptions")
    ) {
        self.sectionTitle = sectionTitle
        self.freePlanTitle = freePlanTitle
        self.activePlanTitle = activePlanTitle
        self.upgradeTitle = upgradeTitle
        self.manageSubscriptionTitle = manageSubscriptionTitle
        self.restorePurchasesTitle = restorePurchasesTitle
        self.manageSubscriptionsURL = manageSubscriptionsURL
    }
}

/// Compact Settings-friendly status/actions for apps that do not need the full Plan pane.
///
/// The full Spokio-style Plan tab is a separate higher-level component; this
/// section stays intentionally small for apps that only need status and actions.
public struct ProPlanStatusSection: View {
    @Environment(\.openURL) private var openURL

    private let purchaseManager: PurchaseManager
    private let configuration: ProPlanStatusConfiguration
    private let onUpgrade: () -> Void

    @State private var restoreMessage: String?

    public init(
        purchaseManager: PurchaseManager,
        configuration: ProPlanStatusConfiguration = .init(),
        onUpgrade: @escaping () -> Void
    ) {
        self.purchaseManager = purchaseManager
        self.configuration = configuration
        self.onUpgrade = onUpgrade
    }

    public var body: some View {
        Section(configuration.sectionTitle) {
            LabeledContent("Current Plan") {
                Text(currentPlanTitle)
                    .fontWeight(.medium)
            }

            if let subtitle = currentPlanSubtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if purchaseManager.hasPro {
                if purchaseManager.activeProduct?.isRecurring == true,
                   let url = configuration.manageSubscriptionsURL {
                    Button(configuration.manageSubscriptionTitle) {
                        openURL(url)
                    }
                }
            } else {
                Button(configuration.upgradeTitle, action: onUpgrade)
            }

            Button {
                restore()
            } label: {
                HStack(spacing: 6) {
                    if purchaseManager.isRestoring {
                        ProgressView().controlSize(.small)
                    }
                    Text(
                        purchaseManager.isRestoring
                            ? "Restoring…"
                            : configuration.restorePurchasesTitle
                    )
                }
            }
            .disabled(purchaseManager.isBusy)

            if let restoreMessage {
                Text(restoreMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var currentPlanTitle: String {
        guard purchaseManager.hasPro else {
            return configuration.freePlanTitle
        }

        guard let activeProduct = purchaseManager.activeProduct else {
            return configuration.activePlanTitle
        }

        return "\(configuration.activePlanTitle) \(activeProduct.planLabel)"
    }

    private var currentPlanSubtitle: String? {
        guard purchaseManager.hasPro else {
            return nil
        }

        guard let activeProduct = purchaseManager.activeProduct else {
            return "Pro is active."
        }

        return activeProduct.isLifetime
            ? "Lifetime access"
            : activeProduct.billingDescription
    }

    private func restore() {
        guard !purchaseManager.isBusy else { return }
        restoreMessage = nil

        Task {
            switch await purchaseManager.restorePurchases() {
            case .restored:
                restoreMessage = "Purchases restored."
            case .nothingToRestore:
                restoreMessage = "No previous purchases were found."
            case .failed(let failure):
                restoreMessage = failure.message
                purchaseManager.clearActivity()
            }
        }
    }
}
