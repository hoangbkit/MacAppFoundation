import MacAppFoundation
import SwiftUI

private enum DemoSection: String, CaseIterable, Identifiable {
    case overview
    case commerce
    case paywall
    case gating
    case upsell
    case settings
    case developer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .commerce: "Commerce"
        case .paywall: "Pro Paywall"
        case .gating: "Gating"
        case .upsell: "Upsells"
        case .settings: "Settings / Plan"
        case .developer: "Developer Tools"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .commerce: "creditcard"
        case .paywall: "crown.fill"
        case .gating: "lock.open"
        case .upsell: "arrow.up.circle"
        case .settings: "gearshape"
        case .developer: "hammer"
        }
    }
}

@MainActor
struct ContentView: View {
    let purchaseManager: PurchaseManager
    let settingsRouter: MacAppSettingsRouter

    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var selection: DemoSection? = .overview

    var body: some View {
        NavigationSplitView {
            List(DemoSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("Foundation Demo")
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        ProPlanButton(
                            purchaseManager: purchaseManager,
                            onUpgrade: {
                                openWindow(id: DemoWindowID.paywall)
                            },
                            onManagePlan: {
                                settingsRouter.request(.plan)
                                openSettings()
                            }
                        )
                    }
                }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .overview {
        case .overview:
            OverviewView(purchaseManager: purchaseManager)
        case .commerce:
            CommerceShowcaseView(purchaseManager: purchaseManager)
        case .paywall:
            PaywallShowcaseView(purchaseManager: purchaseManager)
        case .gating:
            GatingShowcaseView(purchaseManager: purchaseManager)
        case .upsell:
            UpsellShowcaseView(purchaseManager: purchaseManager)
        case .settings:
            SettingsShowcaseView()
        case .developer:
            DeveloperToolsShowcaseView()
        }
    }
}

@MainActor
private struct OverviewView: View {
    let purchaseManager: PurchaseManager

    @Environment(DemoState.self) private var demoState
    @Environment(\.macAppTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("MacAppFoundation")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(theme.textPrimary)
                    Text("A live macOS 15 showcase of every reusable package surface.")
                        .font(.title3)
                        .foregroundStyle(theme.textSecondary)
                }

                HStack(spacing: 14) {
                    statusCard(
                        title: "Entitlement",
                        value: purchaseManager.hasPro ? "Pro" : "Free",
                        systemImage: purchaseManager.hasPro ? "checkmark.seal.fill" : "person"
                    )
                    statusCard(
                        title: "Products",
                        value: "\(purchaseManager.products.count)",
                        systemImage: "cart"
                    )
                    #if DEBUG
                    statusCard(
                        title: "Purchase Mode",
                        value: purchaseManager.isUsingSimulatedPurchases ? "Simulated" : "StoreKit",
                        systemImage: purchaseManager.isUsingSimulatedPurchases ? "testtube.2" : "apple.logo"
                    )
                    #endif
                }

                GroupBox("Reusable plan button") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("The toolbar uses ProPlanButton: Free opens the paywall, while Pro opens Settings directly on the Plan pane.")
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                        Text("Its label automatically follows the active entitlement: Unlock Pro, Pro Monthly, Pro Yearly, or Pro Lifetime.")
                            .font(.caption)
                            .foregroundStyle(theme.textMuted)
                    }
                    .padding(6)
                }

                GroupBox("Theme + Settings foundation") {
                    VStack(alignment: .leading, spacing: 14) {
                        pillar(
                            "Shared theme environment",
                            "One MacAppThemeStore drives the main window, onboarding, paywall, upsell, Developer Tools, and Settings scenes.",
                            "paintpalette"
                        )
                        Divider()
                        pillar(
                            "Reusable Settings shell",
                            "General and About are app-defined panes; Appearance and Plan are MacAppFoundation built-ins.",
                            "gearshape"
                        )
                        Divider()
                        pillar(
                            "Open extension points",
                            "The Demo mixes selected built-in themes with its own Demo Violet theme and routes directly to any settings pane.",
                            "square.stack.3d.up"
                        )
                    }
                    .padding(6)
                }

                GroupBox("Three foundation pillars") {
                    VStack(alignment: .leading, spacing: 14) {
                        pillar(
                            "Commerce + simulation",
                            "Verified StoreKit entitlement state, purchases, restore, lifecycle refresh, and an in-process simulator.",
                            "creditcard"
                        )
                        Divider()
                        pillar(
                            "Pro experience",
                            "Trial-aware paywall, badges, gates, locked content, buttons, popovers, and upsells.",
                            "crown.fill"
                        )
                        Divider()
                        pillar(
                            "Settings + Developer Tools",
                            "Theme-aware custom Settings plus a separate debug console window and Developer menu.",
                            "hammer"
                        )
                    }
                    .padding(6)
                }

                GroupBox("Registered Pro features") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(purchaseManager.features) { feature in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: feature.systemImage)
                                    .foregroundStyle(theme.accent)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(feature.title)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(theme.textPrimary)
                                        ProBadge(style: .outline)
                                    }
                                    Text(feature.message)
                                        .font(.subheadline)
                                        .foregroundStyle(theme.textSecondary)
                                    Text("Free: \(feature.freeValue) · Pro: \(feature.proValue)")
                                        .font(.caption)
                                        .foregroundStyle(theme.textMuted)
                                }
                            }
                        }
                    }
                    .padding(6)
                }

                LabeledContent("Last demo action", value: demoState.lastAction)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(28)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .background(theme.canvas)
        .navigationTitle("Overview")
    }

    private func statusCard(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(theme.accent)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(theme.textPrimary)
            Text(title)
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.separator.opacity(0.82), lineWidth: 1)
        }
    }

    private func pillar(_ title: String, _ message: String, _ icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(theme.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.textPrimary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }
}
