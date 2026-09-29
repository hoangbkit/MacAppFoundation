# Developer Tools

MacAppFoundation's developer console is debug-only and is intended to live in a dedicated macOS window opened from a `Developer` menu. Do not embed it in the app's Settings scene.

The presentation pattern follows Spokio: the consuming app owns the `Window` scene and `CommandMenu`, while MacAppFoundation supplies the reusable `FoundationDeveloperView`. The view is a full macOS `NavigationSplitView`: stable developer destinations live in the sidebar, deeper app-defined destinations push in the detail navigation stack, and the window exposes a normal toolbar with refresh actions.

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
            .managesAnalytics(analytics)
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

The app may use its own window identifier and title instead of the provided defaults. MacAppFoundation requires no global setup to use Developer Tools.

## Overview dashboard

The **Overview** destination provides a compact app/runtime dashboard without duplicating the deeper tabs. It shows app name, version/build, bundle ID, Debug configuration, CPU architecture, process ID, macOS version, MAF logging opt-in state, active theme, actual App Sandbox entitlement state, UserDefaults domain, bundle/executable/home-or-container paths, analytics configured/effective/override state plus existing installation ID, and a concise commerce status summary.

Paths and installation identifiers are selectable for copying. Analytics status refreshes while Overview is visible and does not create an installation identity.

## Built-in logs

The **Logs** destination is always available under **General**, but MAF log capture is opt-in. Apps that want MAF to own SwiftLog should call `MacAppFoundationLogging.bootstrap()` before creating any `Logger` instances. Debug builds then capture SwiftLog output into a framework-owned bounded in-memory store in addition to normal console output. The inspector provides:

- the latest 500 entries
- timestamp, level, label, message, and deterministic metadata formatting
- live auto-scroll
- selectable monospaced rows
- whole-log copy
- per-row copy
- clear

The in-memory store and Logs UI are Debug-only. Release builds that opt into MAF logging keep the framework console handler without retaining developer log history. Apps that already bootstrap another SwiftLog backend should not call the MAF logging bootstrap, because SwiftLog supports only one process-wide bootstrap. Developer Tools otherwise remain fully usable without MAF logging.

## Built-in analytics inspector

The **Analytics** destination is enabled automatically under **General**. Give the Developer Tools scene the same app-scoped client with `.managesAnalytics(analytics)`; if no client is attached, the destination explains that analytics is not connected.

The inspector shows the real client configuration and runtime state directly, including:

- configured enabled state, effective enabled state, app ID, actual app key, server and batch endpoint
- configured/resolved app version, upload interval, retry count
- concrete transport and state-store implementation types
- UserDefaults storage key and Keychain service
- current installation ID when one already exists
- OS/build/device-family/architecture context
- active-session state and timestamps
- stored UTC-day count, last upload, next retry/backoff time
- automatic-upload task and in-flight state
- client limits for batching, retention, events, errors, sessions, body size, and session timeout
- every locally persisted UTC-day event/error/session cumulative counter

The view refreshes its state every second while visible. It also owns a Debug-only bounded live activity stream (latest 500 entries) hooked into the real `AppAnalyticsClient` path for event calls, error calls, lifecycle transitions, batch sends/acceptance, retries, explicit/automatic flushes, resets, and failures. Structured server failures include server error code/message and Retry-After when available.

The Configuration section also provides a Debug-only **Configured / On / Off** runtime override for analytics enablement. **Configured** follows the app's `AppAnalyticsConfiguration.enabled`; **On** and **Off** force the real client pipeline for the current process only. The override is not persisted. Force-enabling analytics intentionally allows tracking, lifecycle state, installation identity creation, and network uploads even when the shipping configuration is disabled.

Toolbar actions provide **Refresh**, **Flush**, and **Copy Snapshot**. Developer actions can clear only the live activity stream or reset local cumulative analytics state; reset preserves the installation identity.

## Built-in User Defaults inspector

The **User Defaults** destination under **General** inspects the running app's real `UserDefaults.standard` search result and its app persistent domain. It shows each key, detected type, current effective value, and whether that value is actually **Stored** in the app domain or only **Effective** through registration/inheritance.

Developer Tools supports:

- live refresh plus search by key, value, or type
- String, Bool, Integer, Double, Date, Data, Array, and Dictionary values
- click-to-edit sheets with explicit Cancel/Save
- adding new values with an explicit type
- app-domain overrides for registered/inherited values
- Base64 editing for Data
- XML property-list editing for arrays and dictionaries
- copy key/value actions
- delete of stored values with fallback visibility after deletion
- confirmed reset of the app's entire persistent UserDefaults domain

All mutations operate on the real running app defaults. A view using `@AppStorage` or otherwise observing UserDefaults can therefore react immediately. Reset removes only the app persistent domain; registered or inherited fallback values can remain visible.

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

The simulated-plan destination is navigation-only until an edit begins. Adding or editing a plan opens a sheet with explicit Cancel/Save actions; text fields, pricing inputs, billing period, entitlement mapping, preferred-plan selection, and introductory-offer inputs all live in that sheet. Reordering and deletion remain list actions, while Apply commits the staged catalog to the simulator.

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
