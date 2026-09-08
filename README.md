# MacAppFoundation

A focused macOS foundation package for StoreKit 2 commerce, Pro experiences, reusable app theming, BYOKchat-style Settings, and debug purchase tooling.

> [!IMPORTANT]
> **Public source, not a community-maintained OSS project.**
>
> This repository is published primarily for transparency and reference. It is maintained for the author's own apps and priorities, not as a community project. Issues, pull requests, feature requests, support requests, and roadmap commitments should not be expected to receive a response or be accepted. Forking or other use of the source is subject to whatever license terms are provided by the repository.

MacAppFoundation owns reusable macOS infrastructure and visual primitives. Host apps keep ownership of product/domain behavior, app-specific settings content, navigation/window presentation, branding, and which themes/settings panes they expose.

## Requirements

- macOS 15+
- Swift 6.2+
- Swift Package Manager

## Demo app

`Examples/Demo` is a macOS 15 XcodeGen app wired against the local package checkout. It demonstrates the complete architecture: StoreKit + simulation, paywall/gating/upsells, one shared theme store across scenes, built-in + custom themes, reusable Settings with Appearance/Plan plus app-injected panes, and the separate Developer Tools window/menu.

```sh
cd Examples/Demo
make open
```

The Debug build starts with in-process simulated purchases. The included StoreKit configuration is available when simulation is turned off.

## Current scope

MacAppFoundation now has five main areas:

1. **Commerce + simulation** — verified StoreKit 2 entitlement state, product loading, purchase/restore, transaction observation, foreground refresh, and a Debug-only in-process simulator.
2. **Pro experience** — theme-aware paywall, trials/introductory offers, Pro gates, badges, locked-feature UI, compact plan control, and reusable upsells.
3. **Theme foundation** — semantic macOS palettes, 13 built-in themes, app-selected subsets, custom themes, persistence, root environment injection, and reusable theme preview/picker UI.
4. **Settings foundation** — a reusable BYOKchat-inspired custom Settings shell with open pane/section IDs, flat panes by default, optional grouped sections, app-injected content, built-in Appearance/Plan panes, and selection routing.
5. **Developer Tools** — a separate Debug-only developer console for StoreKit simulation, diagnostics, replays, and app-defined developer actions.

Verified StoreKit transactions remain the production authorization source of truth. MacAppFoundation does not persist a `hasPro` flag for entitlement decisions.

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
        )
    ]
)
```

Create one `PurchaseManager` for the app and attach lifecycle management near the main root:

```swift
@State private var purchases = PurchaseManager(
    configuration: purchaseConfiguration
)

WindowGroup {
    ContentView()
        .managesPurchases(purchases)
}
```

Normal feature checks use `purchases.hasPro`. Richer commerce surfaces can also read loaded products, loading/activity state, preferred/active product, restore state, and entitlement refresh APIs.

## 2. Configure app theming

Create one shared `MacAppThemeStore`. Apps may expose all built-ins, a selected subset, and arbitrary custom themes in any order.

```swift
@State private var themeStore = MacAppThemeStore(
    configuration: .builtIns([
        .system,
        .midnight,
        .ocean,
        .porcelain,
        .githubLight
    ])
)
```

Apply the same store to every SwiftUI scene root that should stay synchronized:

```swift
WindowGroup {
    RootView()
        .macAppTheme(themeStore)
}

Window("Pro", id: "pro") {
    ProPaywallView(...)
        .macAppTheme(themeStore)
}

Settings {
    SettingsView(...)
        .macAppTheme(themeStore)
}
```

MAF visual components read `@Environment(\.macAppTheme)`. The modifier also applies accent tint and the theme's preferred System/Light/Dark appearance. SwiftUI scene environments do not cross separate scenes automatically, so each root should receive the shared store.

The built-in catalog contains System, GitHub Dark Dimmed, Midnight, Ocean, Aurora, Ember, Graphite, Porcelain, Blossom, Morning Mist, Soft Sage, Sunrise, and GitHub Light.

See `Documentation/Theming.md` for semantic palette roles, custom themes, the reusable picker/cards, and BYOKchat/Onlink migration guidance.

## 3. Use the reusable Settings shell

`MacAppSettingsView` provides the custom macOS shell: themed sidebar, detail header, surfaces, inherited group-box treatment, and optional labeled sections. For the common small-app case, **flat panes are the default**.

A standard Appearance + Plan setup is:

```swift
@State private var settingsRouter = MacAppSettingsRouter()

Settings {
    MacAppSettingsView(
        themeStore: themeStore,
        purchaseManager: purchases,
        planConfiguration: ProPlanPaneConfiguration(appName: "Example"),
        router: settingsRouter,
        onUpgrade: {
            openWindow(id: "pro-paywall")
        }
    )
    .macAppTheme(themeStore)
}
.windowStyle(.hiddenTitleBar)
```

That produces a simple sidebar:

```text
Appearance
Plan
```

For a typical app with a few custom destinations, compose panes directly:

```swift
let panes = [
    MacAppSettingsPane(
        id: "general",
        title: "General",
        subtitle: "Application behavior and defaults.",
        systemImage: "gearshape"
    ) {
        GeneralSettingsView()
    },
    .appearance(themeStore: themeStore),
    .plan(
        purchaseManager: purchases,
        configuration: ProPlanPaneConfiguration(appName: "Example"),
        onUpgrade: openPaywall
    ),
    aboutPane
]

MacAppSettingsView(
    panes: panes,
    initialSelection: "general",
    router: settingsRouter
)
```

Use `sections:` only when a larger Settings surface genuinely benefits from labeled groups such as Application, Account, and Advanced. The grouped BYOKchat-style layout remains fully supported.

The router controls pane selection only; the host app still opens Settings:

```swift
settingsRouter.request(.plan)
openSettings()
```

See `Documentation/Settings.md` for flat composition, built-in pane disabling, optional grouped sections, app-only Settings, and routing patterns.

## 4. Present and gate Pro features

The app owns paywall presentation, copy, and legal URLs. StoreKit owns prices and offer eligibility.

```swift
ProPaywallView(
    purchaseManager: purchases,
    configuration: paywallConfiguration,
    onPurchased: { _ in closePaywall() },
    onRestored: closePaywall,
    onClose: closePaywall
)
```

For simple actions use `ProGateButton` or `purchases.hasPro`. For whole content regions use `ProGate`, `ProLockedOverlay`, or `ProLockPopover`. Use `ProBadge` and `ProUpsellView` for smaller premium surfaces.

`ProPlanButton` is a compact header/title-bar-adjacent control. Free users can route to the paywall; Pro users can route to Settings → Plan through `MacAppSettingsRouter`.

## 5. Debug purchase simulation and Developer Tools

The in-process simulator is compiled only in Debug builds. It never replaces production StoreKit behavior in Release builds.

Developer Tools deliberately stay outside Settings:

```swift
#if DEBUG
Window(
    MacAppFoundationDeveloperTools.windowTitle,
    id: MacAppFoundationDeveloperTools.windowID
) {
    FoundationDeveloperView(
        purchaseManager: purchases,
        configuration: developerConfiguration
    )
    .macAppTheme(themeStore)
}
#endif
```

The developer console includes simulator/live switching, entitlement selection, editable plans/prices/order, entitlement mapping, preferred plan, free-trial/introductory-offer configuration, failures, latency, reset/reload/refresh, diagnostics, replays, and app-defined developer sections.

See `Documentation/DeveloperTools.md` for app-specific actions/toggles/values and replay examples.

## Architecture boundaries

MacAppFoundation intentionally does **not** own:

- app/domain persistence models
- general app navigation or a universal window framework
- branding assets or product-specific copy
- app-specific Settings pane content
- which themes/panes a host app chooses to expose
- backup/export/media workflows
- launch-at-login or general notification management
- AI/provider/domain features

Themes and Settings are reusable infrastructure, but host apps remain in control of configuration and composition.

## Project policy

MacAppFoundation is developed primarily as shared infrastructure for the author's own applications. The repository being public does not imply a community roadmap, guaranteed maintenance for third-party use cases, support SLA, or an obligation to review external contributions.

External users should treat releases as snapshots, pin versions they depend on, and be prepared to maintain their own changes when their requirements diverge, subject to the repository's license terms.

See `CONTRIBUTING.md` for the contribution policy.
