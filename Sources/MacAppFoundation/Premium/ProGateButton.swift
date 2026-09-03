import SwiftUI

/// Describes why a feature is locked and what upgrading unlocks.
public protocol ProLockInfoProvider {
    var title: String { get }
    var reason: String { get }
    var freeTierDescription: String { get }
    var proTierDescription: String { get }
    var upgradeButtonTitle: String { get }
}

public extension ProLockInfoProvider {
    var upgradeButtonTitle: String { "Upgrade to Pro" }
}

/// Ready-to-use lock copy for ``ProGateButton`` and ``ProLockPopover``.
public struct ProLockInfo: ProLockInfoProvider, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let reason: String
    public let freeTierDescription: String
    public let proTierDescription: String
    public let upgradeButtonTitle: String

    public init(
        id: UUID = UUID(),
        title: String,
        reason: String,
        freeTierDescription: String,
        proTierDescription: String,
        upgradeButtonTitle: String = "Upgrade to Pro"
    ) {
        self.id = id
        self.title = title
        self.reason = reason
        self.freeTierDescription = freeTierDescription
        self.proTierDescription = proTierDescription
        self.upgradeButtonTitle = upgradeButtonTitle
    }
}

/// Native macOS explanation popover for a locked Pro feature.
public struct ProLockPopover<Info: ProLockInfoProvider>: View {
    private let info: Info
    private let onUpgrade: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    public init(info: Info, onUpgrade: (() -> Void)? = nil) {
        self.info = info
        self.onUpgrade = onUpgrade
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(info.title)
                    .font(.headline)
                Text(info.reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                tierRow(
                    icon: "circle",
                    tierName: "Free",
                    description: info.freeTierDescription,
                    tint: .secondary
                )
                tierRow(
                    icon: "star.fill",
                    tierName: "Pro",
                    description: info.proTierDescription,
                    tint: .accentColor
                )
            }

            Button {
                if let onUpgrade {
                    onUpgrade()
                } else {
                    dismiss()
                }
            } label: {
                Text(info.upgradeButtonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 280)
    }

    private func tierRow(
        icon: String,
        tierName: String,
        description: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 16)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(tierName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A drop-in button that routes locked users to app-owned Pro presentation.
public struct ProGateButton<Label: View>: View {
    private let purchaseManager: PurchaseManager
    private let feature: PremiumFeature
    private let requirement: PremiumAccessRequirement
    private let isExistingContent: Bool
    private let policy: PremiumAccessPolicy
    private let lockInfo: ProLockInfo?
    private let badgeStyle: ProBadge.Style?
    private let onAction: () -> Void
    private let onUpgrade: () -> Void
    private let label: Label

    @State private var showsLockPopover = false

    public init(
        purchaseManager: PurchaseManager,
        feature: PremiumFeature,
        requirement: PremiumAccessRequirement = .pro,
        isExistingContent: Bool = false,
        policy: PremiumAccessPolicy = .init(),
        lockInfo: ProLockInfo? = nil,
        badgeStyle: ProBadge.Style? = .filled,
        onAction: @escaping () -> Void,
        onUpgrade: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.purchaseManager = purchaseManager
        self.feature = feature
        self.requirement = requirement
        self.isExistingContent = isExistingContent
        self.policy = policy
        self.lockInfo = lockInfo
        self.badgeStyle = badgeStyle
        self.onAction = onAction
        self.onUpgrade = onUpgrade
        self.label = label()
    }

    public var body: some View {
        Button {
            switch decision {
            case .allowed:
                onAction()
            case .requiresPro:
                if lockInfo != nil {
                    showsLockPopover = true
                } else {
                    onUpgrade()
                }
            }
        } label: {
            HStack(spacing: 6) {
                label
                if case .requiresPro = decision, let badgeStyle {
                    ProBadge(style: badgeStyle)
                }
            }
        }
        .popover(isPresented: $showsLockPopover) {
            if let lockInfo {
                ProLockPopover(info: lockInfo) {
                    showsLockPopover = false
                    onUpgrade()
                }
            }
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
