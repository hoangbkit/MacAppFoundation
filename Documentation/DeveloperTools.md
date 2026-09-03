# Developer Tools

MacAppFoundation's developer console is debug-only and is intended to live in a dedicated macOS window opened from a `Developer` menu. Do not embed it in the app's Settings scene.

The presentation pattern follows Spokio: the consuming app owns the `Window` scene and `CommandMenu`, while MacAppFoundation supplies the reusable `FoundationDeveloperView`.

## Window and menu

```swift
import MacAppFoundation
import SwiftUI

@main
struct MyApp: App {
    @Environment(\.openWindow) private var openWindow
    private let purchases = PurchaseManager(configuration: AppPurchases.configuration)

    var body: some Scene {
        Window("My App", id: "main") {
            ContentView()
        }

        Settings {
            SettingsView()
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
        FoundationDeveloperConfiguration()
    }
    #endif
}
```

The app may use its own window identifier and title instead of the provided defaults.

## Built-in commerce controls

`FoundationDeveloperView` exposes the MacAppFoundation purchase simulator without requiring App Store Connect:

- live StoreKit vs simulated purchases
- current entitlement and product loading state
- loaded product prices
- simulated Free/Pro entitlement selection
- simulated product enablement and ordering
- product identifiers, names, descriptions, and prices
- daily, weekly, monthly, yearly, and lifetime billing periods
- product-to-entitlement mapping
- preferred/default plan
- introductory offer mode: none, free trial, pay as you go, pay up front, or unknown
- introductory-offer eligibility, period, period count, displayed price, and numeric price
- purchase success, pending, cancellation, network failure, product unavailable, and system failure outcomes
- product-load and restore failure injection
- operation latency
- reset, reload, and entitlement refresh actions
- copyable commerce diagnostics

All simulator changes stay isolated from the app's production `PurchaseConfiguration`.

## Replay real app flows

Register real app-owned paywall or upsell views instead of building fake developer versions:

```swift
#if DEBUG
let developerConfiguration = FoundationDeveloperConfiguration(
    replays: [
        FoundationDeveloperReplay(
            id: "pro-paywall",
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
        },
        FoundationDeveloperReplay(
            id: "limit-upsell",
            title: "Limit Upsell",
            systemImage: "arrow.up.circle"
        ) { dismiss in
            ProUpsellView(
                title: "Free limit reached",
                message: "Upgrade to continue.",
                benefits: purchases.features.map(ProUpsellBenefit.init),
                onPrimaryAction: {
                    dismiss()
                    // Present the app's normal Pro flow here.
                },
                onSecondaryAction: dismiss
            )
        }
    ]
)
#endif
```

A replay is presented from the Developer Tools window as a sheet. If an app needs to exercise its exact production `Window` scene instead, register a `FoundationDeveloperAction` in an additional section and call the app's normal `openWindow(id:)` path from that action.

## App-specific controls

Apps can append structured sections without modifying MacAppFoundation:

```swift
#if DEBUG
let section = FoundationDeveloperSection(
    title: "Demo Data",
    items: [
        .action(
            FoundationDeveloperAction(
                title: "Seed Data",
                systemImage: "plus.square"
            ) {
                try await seedData()
            }
        ),
        .toggle(
            FoundationDeveloperToggle(
                title: "Use Mock Backend",
                value: { debugState.usesMockBackend },
                setValue: { debugState.usesMockBackend = $0 }
            )
        ),
        .value(
            FoundationDeveloperValue(
                title: "Cached Items",
                value: { "\(debugState.cachedItemCount)" }
            )
        )
    ]
)
#endif
```

Keep all developer scene/menu wiring inside `#if DEBUG` so it never ships in release builds.
