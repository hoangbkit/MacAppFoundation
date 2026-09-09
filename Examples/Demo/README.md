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
- flat `MacAppSettingsView` with app-defined General/About panes and built-in Appearance/Plan panes
- optional grouped Settings remains available for larger apps
- `MacAppSettingsRouter` routing the compact Pro control directly to the Plan pane
- live StoreKit path using `Configuration.storekit`
- Debug in-process purchase simulator
- Monthly with three months of paid introductory pricing, Yearly + 7-day free trial, and Lifetime products
- product loading, purchase outcomes, restore, entitlement refresh, and foreground lifecycle refresh
- `ProPaywallView` including trial/intro copy, restore, legal links, and Redeem Code
- `ProBadge`, `ProGate`, `ProLockedOverlay`, `ProGateButton`, and `ProLockPopover`
- existing-content premium access policy
- `ProUpsellView`
- Debug-only `FoundationDeveloperView`
- separate Developer Tools window opened from `CommandMenu("Developer")`
- developer replays, actions, toggles, values, and custom destinations
- full simulated-plan editor, entitlement forcing, failures, latency, trials, and introductory offers through Developer Tools

The Demo deliberately applies the same `MacAppThemeStore` to the main window, onboarding, paywall, upsell, Developer Tools, and Settings roots. This demonstrates the required multi-scene integration pattern: SwiftUI scene environments do not automatically cross scene boundaries, but all scenes stay synchronized when they share the same observable store.

The Appearance pane exposes every built-in in catalog order:

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
Appearance   (MAF)
Plan         (MAF)
About        (Demo)
```

Apps with larger Settings surfaces can opt into `MacAppSettingsSection` and the `sections:` initializer to add labeled groups.

The app launches in simulated purchase mode in Debug so every purchase flow works without an App Store account. Turn simulation off in Developer Tools or Commerce to exercise the matching StoreKit-testing catalog instead.
