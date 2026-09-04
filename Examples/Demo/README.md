# MacAppFoundation Demo

A macOS 15 XcodeGen app that exercises the full MacAppFoundation v1 surface against the local package checkout.

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
- live StoreKit path using `Configuration.storekit`
- Debug in-process purchase simulator
- monthly, yearly + 7-day trial, and lifetime products
- product loading, purchase, restore, entitlement refresh, and foreground lifecycle refresh
- `ProPaywallView` including trial/intro copy, restore, legal links, and Redeem Code
- `ProBadge`, `ProGate`, `ProLockedOverlay`, `ProGateButton`, and `ProLockPopover`
- existing-content premium access policy
- `ProUpsellView`
- Spokio-style `ProPlanPane` inside an app-owned General / Plan / About Settings scene
- Debug-only `FoundationDeveloperView`
- separate Developer Tools window opened from `CommandMenu("Developer")`
- developer replays, actions, toggles, values, and custom destinations
- full simulated-plan editor, entitlement forcing, failures, latency, trials, and introductory offers through Developer Tools

The app launches in simulated purchase mode in Debug so every purchase flow works without an App Store account. Turn simulation off in Developer Tools or Commerce to exercise the StoreKit-testing configuration instead.
