# MacAppFoundation

A focused macOS foundation package for StoreKit 2 commerce, Pro paywalls/gating, a Spokio-style Plan settings pane, and debug purchase tooling.

MacAppFoundation intentionally stays small. The app keeps ownership of navigation, branding, general settings, About content, product copy, and domain behavior.

## Requirements

- macOS 26+
- Swift 6.2+
- Swift Package Manager

## v1.0.0 scope

MacAppFoundation has three pillars:

1. **Commerce + simulation** — verified StoreKit 2 entitlement state, product loading, purchase/restore, transaction observation, foreground refresh, and a Debug-only in-process simulator.
2. **Pro experience** — native macOS paywall, trial/introductory-offer presentation, Pro gates, badges, locked-feature UI, and reusable upsells.
3. **Settings + Developer Tools** — a generalized copy of Spokio's Plan pane plus a separate Debug-only developer console designed for a macOS `Developer` menu/window.

Verified StoreKit transactions are the authorization source of truth. MacAppFoundation does not persist a `hasPro` flag for production entitlement decisions.

## Installation

Add MacAppFoundation as a Swift Package dependency and link the `MacAppFoundation` library product.

```swift
.package(
    url: "https://github.com/hoangbkit/MacAppFoundation.git",
    from: "1.0.0"
)
```

## 1. Configure commerce

Define products once. Product order is also the default display order used by purchase surfaces.

```swift
import MacAppFoundation

let purchaseConfiguration = PurchaseConfiguration(
    productIDs: [
        "com.example.app.pro.monthly",
        "com.example.app.pro.yearly",
        "com.example.app.pro.lifetime"
    ],
    preferredProductID: "com.example.app.pro.yearly",
    features: [
        PurchaseFeature(
            id: "unlimited",
            systemImage: "infinity",
            title: "Unlimited usage",
            message: "Remove the free-plan limit.",
            freeValue: "Limited",
            proValue: "Unlimited"
        ),
        PurchaseFeature(
            id: "batch",
            systemImage: "square.stack.3d.up",
            title: "Batch workflows",
            message: "Process multiple items at once.",
            freeValue: "Single item",
            proValue: "Batch"
        )
    ]
)
```

By default every configured product grants Pro. Supply `entitledProductIDs` only when the catalog also contains products that should not unlock the main entitlement.

Create one `PurchaseManager` for the app and attach lifecycle management near the root view:

```swift
import MacAppFoundation
import SwiftUI

@main
struct ExampleApp: App {
    @State private var purchases = PurchaseManager(
        configuration: purchaseConfiguration
    )

    var body: some Scene {
        WindowGroup {
            ContentView(purchases: purchases)
                .managesPurchases(purchases)
        }
    }
}
```

Normal feature checks use one property:

```swift
if purchases.hasPro {
    runPremiumAction()
}
```

`PurchaseManager` also exposes loaded products, loading/activity state, the preferred product, active product, restore, and entitlement refresh APIs when a screen needs richer commerce state.

## 2. Present the Pro paywall

The app owns copy, legal URLs, and presentation. StoreKit owns prices and eligibility.

```swift
let paywallConfiguration = ProPaywallConfiguration(
    title: "Example Pro",
    subtitle: "Unlock every premium workflow.",
    highlightedProductID: "com.example.app.pro.yearly",
    highlightedProductBadge: "BEST VALUE",
    termsURL: URL(string: "https://example.com/terms")!,
    privacyURL: URL(string: "https://example.com/privacy")!
)
```

Use `ProPaywallView` inside the app's own window, sheet, or other presentation:

```swift
ProPaywallView(
    purchaseManager: purchases,
    configuration: paywallConfiguration,
    onPurchased: { product in
        closePaywall()
    },
    onRestored: {
        closePaywall()
    },
    onClose: {
        closePaywall()
    }
)
```

The paywall supports recurring and lifetime products, preferred/highlighted plans, automatic monthly-vs-yearly savings badges, free trials and paid introductory offers, loading/retry, purchase errors, restore, Redeem Code, and catalog-aware legal disclosure.

Eligible StoreKit introductory offers automatically change the plan copy and CTA. For example, an eligible free trial becomes `Start Free Trial`; an ineligible trial falls back to normal paid-plan copy.

## 3. Gate Pro features

For a simple action, use `ProGateButton` or check `purchases.hasPro` directly. For whole content regions, use `ProGate`:

```swift
let exportFeature = PremiumFeature(
    id: "batch-export",
    title: "Batch Export"
)

ProGate(
    purchaseManager: purchases,
    feature: exportFeature
) {
    BatchExportView()
} lockedContent: { feature in
    ProLockedOverlay(feature: feature) {
        openPaywall()
    }
}
```

`PremiumAccessPolicy` keeps existing user-created content accessible by default after Pro expires while still allowing apps to gate creation or premium editing. Apps can opt into stricter behavior when their product requires it.

Use `ProBadge`, `ProGateButton`, and `ProUpsellView` for smaller premium surfaces without introducing another entitlement store.

## 4. Spokio-style Settings + Plan tab

The app owns the native `Settings` scene and its General/About tabs. MacAppFoundation provides only the reusable Plan pane.

```swift
struct SettingsView: View {
    @State private var selectedTab = SettingsTab.general
    let purchases: PurchaseManager
    let openPaywall: () -> Void

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            ProPlanPane(
                purchaseManager: purchases,
                configuration: ProPlanPaneConfiguration(appName: "Example"),
                onUpgrade: openPaywall
            )
            .tabItem { Label("Plan", systemImage: "creditcard") }
            .tag(SettingsTab.plan)

            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .padding()
        .frame(width: 500, alignment: .top)
        .fixedSize()
    }
}
```

Then keep the scene app-owned:

```swift
Settings {
    SettingsView(
        purchases: purchases,
        openPaywall: { openWindow(id: "pro-paywall") }
    )
}
```

`ProPlanPane` preserves the Spokio structure: Free/Pro status card, active MONTHLY/YEARLY/LIFETIME/PRO badge, upgrade action, subscription-management action for active recurring plans, and a lower Pro feature `GroupBox`.

See `Documentation/Settings.md` for the full composition pattern.

## 5. Debug purchase simulation

The simulator is compiled only in Debug builds. It never contacts App Store Connect and never replaces production StoreKit behavior in Release builds.

A manager can start in simulation mode:

```swift
#if DEBUG
let purchases = PurchaseManager(
    configuration: purchaseConfiguration,
    simulated: true,
    simulatedProducts: [
        StoreProduct(
            id: "com.example.app.pro.yearly",
            displayName: "Yearly",
            description: "Yearly Pro",
            displayPrice: "$39.99",
            price: 39.99,
            subscriptionPeriod: .init(value: 1, unit: .year),
            introductoryOffer: .init(
                paymentMode: .freeTrial,
                period: .init(value: 7, unit: .day),
                displayPrice: "$0.00",
                price: 0,
                isEligible: true
            )
        )
    ]
)
#endif
```

The Debug API can switch live/simulated mode at runtime, replace the simulated catalog, force entitlement, set purchase outcomes, inject product-loading/restore failures, change operation latency, and reset simulator state.

## 6. Developer Tools window + menu

Developer Tools deliberately stay outside Settings. Follow the normal macOS SwiftUI scene pattern:

```swift
@main
struct ExampleApp: App {
    @Environment(\.openWindow) private var openWindow
    @State private var purchases = PurchaseManager(
        configuration: purchaseConfiguration
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .managesPurchases(purchases)
        }

        #if DEBUG
        Window(
            MacAppFoundationDeveloperTools.windowTitle,
            id: MacAppFoundationDeveloperTools.windowID
        ) {
            FoundationDeveloperView(
                purchaseManager: purchases,
                configuration: developerConfiguration
            )
        }
        .defaultSize(
            width: MacAppFoundationDeveloperTools.defaultWidth,
            height: MacAppFoundationDeveloperTools.defaultHeight
        )

        .commands {
            CommandMenu("Developer") {
                Button("Developer Tools…") {
                    openWindow(id: MacAppFoundationDeveloperTools.windowID)
                }
            }
        }
        #endif
    }

    #if DEBUG
    private var developerConfiguration: FoundationDeveloperConfiguration {
        FoundationDeveloperConfiguration(
            replays: [
                FoundationDeveloperReplay(
                    id: "paywall",
                    title: "Pro Paywall",
                    systemImage: "crown.fill"
                ) { dismiss in
                    ProPaywallView(
                        purchaseManager: purchases,
                        configuration: paywallConfiguration,
                        onPurchased: { _ in dismiss() },
                        onRestored: dismiss,
                        onClose: dismiss
                    )
                }
            ]
        )
    }
    #endif
}
```

The developer console includes simulator/live switching, entitlement selection, editable plans/prices/order, entitlement mapping, preferred plan, free-trial/introductory-offer configuration, failures, latency, reset/reload/refresh, diagnostics, replays, and app-defined developer sections.

See `Documentation/DeveloperTools.md` for app-specific actions/toggles/values and replay examples.

## Design boundaries

MacAppFoundation v1.0.0 intentionally does **not** include:

- legacy paid-app migration
- startup recovery/resilience
- a general window/menu framework
- launch at login
- notification management
- a theme/design system
- backup/export/media tooling
- app persistence/domain models
- AI features

This keeps the package focused on reusable macOS monetization infrastructure.

## Release

See `Documentation/Release-1.0.0.md` for the v1.0.0 release notes and tag checklist.
