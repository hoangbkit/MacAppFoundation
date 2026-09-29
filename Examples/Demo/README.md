# MacAppFoundation Demo

A macOS 15 XcodeGen app that exercises the current MacAppFoundation surface against the local package checkout.

## Generate

```sh
cd Examples/Demo
make generate
open MacAppFoundationDemo.xcodeproj
```

Or run `make open`.

XcodeGen 2.45.4+ is required.

## What it showcases

- one shared `PurchaseManager`
- one shared `MacAppThemeStore` injected into every Demo scene root
- the complete MAF built-in theme catalog: System plus all 12 named BYOKchat themes
- the app-defined **Demo Violet** theme appended after the built-ins to demonstrate custom-theme extension
- live theme switching through the reusable `MacAppThemePicker`
- flat `MacAppSettingsView` with app-defined General/About panes and built-in Theme/Plan panes
- optional grouped Settings remains available for larger apps
- `MacAppSettingsRouter` routing the compact Pro control directly to the Plan pane
- live StoreKit path using `Configuration.storekit`
- Debug in-process purchase simulator
- Monthly with three months of paid introductory pricing, Yearly + 7-day free trial, and Lifetime products
- production-facing product presentation, purchase, and restore in the main Commerce showcase
- `ProPaywallView` including trial/intro copy, restore, legal links, and Redeem Code
- `ProBadge`, `ProGate`, `ProLockedOverlay`, `ProGateButton`, and `ProLockPopover`
- existing-content premium access policy
- `ProUpsellView`
- Debug-only `FoundationDeveloperView`
- separate Developer Tools window opened from `CommandMenu("Developer")`
- developer replays, actions, toggles, values, and custom destinations
- full simulated-plan editor, entitlement forcing, failures, latency, trials, and introductory offers through Developer Tools
- one shared app-scoped `AppAnalyticsClient` reused across Demo scenes through `.managesAnalytics`
- Demo analytics configured for app ID `maf` at `analytics.133043.xyz`, using `Bundle.main.bundleIdentifier` (`com.hoangbkit.maf`) as the native app key
- built-in Developer Tools Analytics inspector for configuration, live activity, persisted counters, flush, and reset
- automatic `ProPaywallView` commerce funnel events through the shared analytics environment

The Demo deliberately keeps production-facing examples in the main window and centralizes debug-only behavior in the separate Developer Tools window. The same `MacAppThemeStore` and shared analytics client are injected into scene roots that need them.

The Theme pane exposes every built-in in catalog order:

```text
System
GitHub Dark Dimmed
Midnight
Ocean
Aurora
Ember
Graphite
Porcelain
Blossom
Morning Mist
Soft Sage
Sunrise
GitHub Light
Demo Violet   (custom host-app theme)
```

With only four Settings destinations, the Demo uses the recommended flat layout:

```text
General      (Demo)
Theme        (MAF)
Plan         (MAF)
About        (Demo)
```

Apps with larger Settings surfaces can opt into `MacAppSettingsSection` and the `sections:` initializer to add labeled groups.

The app launches in simulated purchase mode in Debug so every purchase flow works without an App Store account. Use Developer Tools to switch to StoreKit Testing, edit simulated plans, force entitlements, inject failures, inspect analytics/logs, and reset debug state.
