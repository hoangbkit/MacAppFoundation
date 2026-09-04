import MacAppFoundation
import SwiftUI

@MainActor
struct PaywallShowcaseView: View {
    let purchaseManager: PurchaseManager

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pro Paywall")
                        .font(.system(size: 30, weight: .bold))
                    Text("The production paywall is app-configured but fully driven by PurchaseManager products, offers, state, restore, and entitlement.")
                        .foregroundStyle(.secondary)
                }

                Button("Open Production Paywall") {
                    openWindow(id: DemoWindowID.paywall)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                GroupBox("What this paywall demonstrates") {
                    VStack(alignment: .leading, spacing: 11) {
                        bullet("Native two-column macOS layout")
                        bullet("Preferred/highlighted plan selection")
                        bullet("7-day free-trial CTA and disclosure on Yearly")
                        bullet("Paid introductory pricing on Monthly in simulated mode")
                        bullet("Automatic Monthly vs Yearly savings badge")
                        bullet("Lifetime purchase presentation")
                        bullet("Restore purchases and Redeem Code")
                        bullet("App-owned terms, privacy, and completion callbacks")
                    }
                    .padding(6)
                }

                GroupBox("Current catalog") {
                    VStack(spacing: 0) {
                        ForEach(Array(purchaseManager.products.enumerated()), id: \.element.id) { index, product in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(product.planLabel)
                                        .fontWeight(.semibold)
                                    if let headline = product.introductoryOfferHeadline {
                                        Text(headline)
                                            .font(.caption)
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                Spacer()
                                Text(product.displayPrice)
                                    .fontWeight(.semibold)
                            }
                            .padding(.vertical, 10)

                            if index < purchaseManager.products.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                }
            }
            .padding(28)
            .frame(maxWidth: 780, alignment: .leading)
        }
        .navigationTitle("Pro Paywall")
    }

    private func bullet(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .foregroundStyle(.primary, Color.accentColor)
    }
}

@MainActor
struct GatingShowcaseView: View {
    let purchaseManager: PurchaseManager

    @Environment(\.openWindow) private var openWindow
    @Environment(DemoState.self) private var demoState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pro Gating")
                        .font(.system(size: 30, weight: .bold))
                    Text("Every gate reads the same verified PurchaseManager entitlement and leaves paywall navigation to the app.")
                        .foregroundStyle(.secondary)
                }

                GroupBox("Badges") {
                    HStack(spacing: 14) {
                        Text("Filled").proBadge(style: .filled)
                        Text("Outline").proBadge(style: .outline)
                        Text("Icon").proBadge(style: .icon)
                        Spacer()
                    }
                    .padding(8)
                }

                GroupBox("ProGate + ProLockedOverlay") {
                    ProGate(
                        purchaseManager: purchaseManager,
                        feature: DemoCommerce.batchFeature
                    ) {
                        allowedCard(
                            title: "Batch workspace unlocked",
                            message: "This is the Pro content branch of ProGate."
                        )
                    } lockedContent: { feature in
                        ProLockedOverlay(
                            feature: feature,
                            message: "The same content switches automatically when entitlement changes.",
                            onUpgrade: { openWindow(id: DemoWindowID.paywall) }
                        )
                    }
                    .frame(height: 180)
                }

                GroupBox("Existing-content policy") {
                    ProGate(
                        purchaseManager: purchaseManager,
                        feature: DemoCommerce.automationFeature,
                        isExistingContent: true,
                        policy: PremiumAccessPolicy(existingContentRemainsAccessible: true)
                    ) {
                        allowedCard(
                            title: "Existing project stays accessible",
                            message: "This remains available even when Pro expires; creation can still be gated separately."
                        )
                    } lockedContent: { feature in
                        ProLockedOverlay(feature: feature, onUpgrade: {
                            openWindow(id: DemoWindowID.paywall)
                        })
                    }
                    .frame(height: 130)
                }

                GroupBox("ProGateButton + ProLockPopover") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("When Free, this button first shows the package's comparison popover. The popover upgrade action opens the app's paywall window.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ProGateButton(
                            purchaseManager: purchaseManager,
                            feature: DemoCommerce.batchFeature,
                            lockInfo: ProLockInfo(
                                title: "Batch workflows",
                                reason: "Batch processing is a Pro workflow.",
                                freeTierDescription: "Process one item at a time.",
                                proTierDescription: "Process unlimited items in one run."
                            ),
                            onAction: {
                                demoState.record("Ran gated batch action")
                            },
                            onUpgrade: {
                                openWindow(id: DemoWindowID.paywall)
                            }
                        ) {
                            Label("Run Batch Workflow", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(8)
                }
            }
            .padding(28)
            .frame(maxWidth: 800, alignment: .leading)
        }
        .navigationTitle("Gating")
    }

    private func allowedCard(title: String, message: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(Color.green)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

@MainActor
struct UpsellShowcaseView: View {
    let purchaseManager: PurchaseManager

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Upsells")
                        .font(.system(size: 30, weight: .bold))
                    Text("Use the reusable surface for limits and locked workflows while keeping navigation app-owned.")
                        .foregroundStyle(.secondary)
                }

                Button("Open Upsell Window") {
                    openWindow(id: DemoWindowID.upsell)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                ProUpsellView(
                    title: "Unlock the complete workflow",
                    message: "This embedded instance is the exact package view used in the separate demo window.",
                    features: Array(purchaseManager.features.prefix(3)),
                    primaryActionTitle: "Show Pro Paywall",
                    secondaryActionTitle: "Not Now",
                    onPrimaryAction: {
                        openWindow(id: DemoWindowID.paywall)
                    },
                    onSecondaryAction: {}
                )
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .navigationTitle("Upsells")
    }
}

@MainActor
struct SettingsShowcaseView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 46))
                .foregroundStyle(Color.accentColor)
            Text("App-owned Settings")
                .font(.title.bold())
            Text("The demo uses a native General / Plan / About Settings scene. Only the Plan content comes from MacAppFoundation.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)

            Button("Open Settings") {
                openSettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
        .navigationTitle("Settings / Plan")
    }
}

@MainActor
struct DeveloperToolsShowcaseView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 46))
                .foregroundStyle(Color.accentColor)
            Text("Developer Tools")
                .font(.title.bold())

            #if DEBUG
            Text("A separate debug-only window exposes the complete purchase simulator, product/offer editor, failures, latency, diagnostics, replays, and app-specific controls.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 560)

            Button("Open Developer Tools") {
                openWindow(id: MacAppFoundationDeveloperTools.windowID)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("Also available from Developer → Developer Tools…")
                .font(.caption)
                .foregroundStyle(.secondary)
            #else
            Text("Developer Tools are intentionally excluded from Release builds.")
                .foregroundStyle(.secondary)
            #endif
        }
        .padding(40)
        .navigationTitle("Developer Tools")
    }
}
