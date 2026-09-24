import SwiftUI

/// A reusable macOS Plan pane adapted directly from Spokio's Settings UI.
///
/// The consuming app owns its `Settings` scene, tab selection, General/About
/// panes, and paywall presentation. MacAppFoundation owns only this reusable
/// commerce-backed Plan content.
@MainActor
public struct ProPlanPane: View {
    @Environment(\.macAppTheme) private var theme

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
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: purchaseManager.hasPro
                        ? [theme.accentSoft, theme.surface]
                        : [theme.surfaceRaised, theme.surface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: purchaseManager.hasPro ? "checkmark.seal.fill" : "sparkles")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        purchaseManager.hasPro ? theme.accent : theme.textSecondary
                    )
                    .padding(18)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 10) {
                        Text(purchaseManager.hasPro ? configuration.proTitle : configuration.freeTitle)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.textPrimary)

                        if purchaseManager.hasPro {
                            Text(currentPlanLabel)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(theme.surfaceRaised, in: Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(theme.border, lineWidth: 0.5)
                                }
                                .foregroundStyle(theme.accent)
                        }
                    }

                    Text(
                        purchaseManager.hasPro
                            ? configuration.proDescription
                            : configuration.freeDescription
                    )
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textSecondary)

                    HStack(spacing: 10) {
                        if actionState.showsUpgrade {
                            Button(configuration.upgradeButtonTitle, action: onUpgrade)
                                .buttonStyle(MacAppButtonStyle(.primary))
                        }

                        if actionState.showsViewPlans {
                            Button(configuration.viewPlansButtonTitle, action: onUpgrade)
                                .buttonStyle(MacAppButtonStyle(.secondary))
                        }

                        if actionState.showsManageSubscription {
                            Link(
                                configuration.manageSubscriptionTitle,
                                destination: configuration.manageSubscriptionURL
                            )
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.accent)
                        }

                        Button {
                            Task {
                                _ = await purchaseManager.restorePurchases()
                            }
                        } label: {
                            if purchaseManager.isRestoring {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Restoring…")
                                }
                            } else {
                                Text(configuration.restorePurchasesTitle)
                            }
                        }
                        .buttonStyle(MacAppButtonStyle(.quiet))
                        .disabled(purchaseManager.isBusy || purchaseManager.isPurchasePending)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            }

            if !resolvedFeatures.isEmpty {
                ProPlanFeatureList(
                    features: resolvedFeatures,
                    isPro: purchaseManager.hasPro
                )
                .padding(14)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                }
            }
        }
        .task {
            await purchaseManager.prepare()
        }
    }

    private var actionState: ProPlanPaneActionState {
        ProPlanPaneActionState(
            hasPro: purchaseManager.hasPro,
            activeProduct: purchaseManager.activeProduct,
            activeSubscriptionProduct: purchaseManager.activeSubscriptionProduct
        )
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
    @Environment(\.macAppTheme) private var theme

    let features: [PurchaseFeature]
    let isPro: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(features) { feature in
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isPro ? theme.accentSoft : theme.surfaceRaised)
                        .frame(width: 26, height: 26)
                        .overlay {
                            Image(systemName: feature.systemImage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isPro ? theme.accent : theme.textSecondary)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(theme.border, lineWidth: 0.5)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.textPrimary)

                        Text(feature.message)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


struct ProPlanPaneActionState: Equatable {
    let showsUpgrade: Bool
    let showsViewPlans: Bool
    let showsManageSubscription: Bool

    init(
        hasPro: Bool,
        activeProduct: StoreProduct?,
        activeSubscriptionProduct: StoreProduct?
    ) {
        showsUpgrade = !hasPro
        showsViewPlans = hasPro && activeProduct?.isRecurring == true
        showsManageSubscription = activeSubscriptionProduct != nil
    }
}
