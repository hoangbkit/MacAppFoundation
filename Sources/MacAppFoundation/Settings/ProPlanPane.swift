import SwiftUI

/// A reusable macOS Plan pane adapted directly from Spokio's Settings UI.
///
/// The consuming app owns its `Settings` scene, tab selection, General/About
/// panes, and paywall presentation. MacAppFoundation owns only this reusable
/// commerce-backed Plan content.
@MainActor
public struct ProPlanPane: View {
    private let purchaseManager: PurchaseManager
    private let configuration: ProPlanPaneConfiguration
    private let onUpgrade: () -> Void

    public init(
        purchaseManager: PurchaseManager,
        configuration: ProPlanPaneConfiguration,
        onUpgrade: @escaping () -> Void
    ) {
        self.purchaseManager = purchaseManager
        self.configuration = configuration
        self.onUpgrade = onUpgrade
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                ZStack(alignment: .topTrailing) {
                    LinearGradient(
                        colors: purchaseManager.hasPro
                            ? [Color.accentColor.opacity(0.16), Color.primary.opacity(0.025)]
                            : [Color.primary.opacity(0.045), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: purchaseManager.hasPro ? "checkmark.seal.fill" : "sparkles")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            purchaseManager.hasPro ? Color.accentColor : Color.secondary
                        )
                        .padding(18)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .center, spacing: 10) {
                            Text(purchaseManager.hasPro ? configuration.proTitle : configuration.freeTitle)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)

                            if purchaseManager.hasPro {
                                Text(currentPlanLabel)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.primary.opacity(0.055), in: Capsule())
                                    .overlay {
                                        Capsule()
                                            .stroke(Color.primary.opacity(0.14), lineWidth: 0.5)
                                    }
                                    .foregroundStyle(Color.accentColor)
                            }
                        }

                        Text(
                            purchaseManager.hasPro
                                ? configuration.proDescription
                                : configuration.freeDescription
                        )
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                        if purchaseManager.hasPro {
                            Link(
                                configuration.manageSubscriptionTitle,
                                destination: configuration.manageSubscriptionURL
                            )
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.accentColor)
                        } else {
                            Button(configuration.upgradeButtonTitle, action: onUpgrade)
                                .buttonStyle(.plain)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .frame(height: 32)
                                .background(Color.accentColor)
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                }
            }

            if !resolvedFeatures.isEmpty {
                GroupBox {
                    ProPlanFeatureList(
                        features: resolvedFeatures,
                        isPro: purchaseManager.hasPro
                    )
                }
            }
        }
        .task {
            await purchaseManager.prepare()
        }
    }

    private var resolvedFeatures: [PurchaseFeature] {
        configuration.features ?? purchaseManager.features
    }

    private var currentPlanLabel: String {
        purchaseManager.activeProduct?.planLabel.uppercased() ?? "PRO"
    }
}

@MainActor
private struct ProPlanFeatureList: View {
    let features: [PurchaseFeature]
    let isPro: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(features) { feature in
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            isPro
                                ? Color.accentColor.opacity(0.12)
                                : Color.primary.opacity(0.045)
                        )
                        .frame(width: 26, height: 26)
                        .overlay {
                            Image(systemName: feature.systemImage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isPro ? Color.accentColor : Color.secondary)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.primary.opacity(0.14), lineWidth: 0.5)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text(feature.message)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
