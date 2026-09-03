import SwiftUI

/// Switches between premium content and an app-supplied locked presentation.
///
/// Access is always derived from the shared ``PurchaseManager`` entitlement state.
public struct ProGate<ProContent: View, LockedContent: View>: View {
    private let purchaseManager: PurchaseManager
    private let feature: PremiumFeature
    private let requirement: PremiumAccessRequirement
    private let isExistingContent: Bool
    private let policy: PremiumAccessPolicy
    private let proContent: ProContent
    private let lockedContent: (PremiumFeature) -> LockedContent

    public init(
        purchaseManager: PurchaseManager,
        feature: PremiumFeature,
        requirement: PremiumAccessRequirement = .pro,
        isExistingContent: Bool = false,
        policy: PremiumAccessPolicy = .init(),
        @ViewBuilder proContent: () -> ProContent,
        @ViewBuilder lockedContent: @escaping (PremiumFeature) -> LockedContent
    ) {
        self.purchaseManager = purchaseManager
        self.feature = feature
        self.requirement = requirement
        self.isExistingContent = isExistingContent
        self.policy = policy
        self.proContent = proContent()
        self.lockedContent = lockedContent
    }

    public var body: some View {
        switch decision {
        case .allowed:
            proContent
        case .requiresPro(let feature):
            lockedContent(feature)
        }
    }

    private var decision: PremiumAccessDecision {
        policy.decision(
            for: feature,
            requirement: requirement,
            hasPro: purchaseManager.hasPro,
            isExistingContent: isExistingContent
        )
    }
}

/// A native macOS locked-content surface that delegates upgrade presentation to the app.
public struct ProLockedOverlay: View {
    private let feature: PremiumFeature
    private let message: String
    private let actionTitle: String
    private let onUpgrade: () -> Void

    public init(
        feature: PremiumFeature,
        message: String = "Unlock this feature with Pro.",
        actionTitle: String = "Upgrade to Pro",
        onUpgrade: @escaping () -> Void
    ) {
        self.feature = feature
        self.message = message
        self.actionTitle = actionTitle
        self.onUpgrade = onUpgrade
    }

    public var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            Text(feature.title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(actionTitle, action: onUpgrade)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(.regularMaterial)
        .accessibilityIdentifier("premium.locked.\(feature.id)")
    }
}
