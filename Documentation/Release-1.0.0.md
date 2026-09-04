# MacAppFoundation 1.0.0

## Release summary

MacAppFoundation 1.0.0 packages the reusable macOS monetization pieces proven across AppFoundation, PaywallKit, and Spokio into one focused Swift package.

Minimum deployment target: **macOS 15.0**.

The release has three pillars:

### Commerce + simulation

- StoreKit 2 product loading and ordering
- verified entitlement evaluation
- purchase and restore flows
- transaction update observation
- foreground entitlement refresh
- recurring and lifetime products
- normalized plan/billing metadata
- trial and introductory-offer eligibility/copy
- Debug-only in-process purchase simulator
- simulated catalog, ordering, preferred plan, entitlement mapping, outcomes, failures, latency, and reset controls

### Pro experience

- native two-column macOS `ProPaywallView`
- app-owned paywall copy/legal links/presentation
- trial-aware CTA and disclosure
- automatic monthly-vs-yearly savings badge
- restore and Redeem Code support
- `ProGate`, `ProGateButton`, `ProBadge`, `ProLockedOverlay`, and `ProUpsellView`
- access policy that can keep existing user-created content accessible after entitlement expiry

### Settings + Developer Tools

- generalized direct adaptation of Spokio's Plan pane
- Free/Pro status card and active-plan label
- recurring-subscription management action
- registered Pro feature list
- app-owned native `Settings` scene composition
- Debug-only developer console in a separate macOS window
- Spokio-style `CommandMenu("Developer")` + `openWindow(id:)` presentation pattern
- editable simulated plans, prices, ordering, entitlement mapping, preferred plan, and introductory offers
- failure/latency controls, diagnostics, replays, and app-specific developer sections

### Demo app

- macOS 15 XcodeGen project under `Examples/Demo`
- local-package dependency on MacAppFoundation
- StoreKit Testing configuration with Monthly, Yearly + 7-day trial, and Lifetime products
- Debug simulator enabled by default
- showcase navigation for commerce, paywall, gating, upsells, Settings/Plan, and Developer Tools
- real app-owned paywall and upsell windows
- app-owned General / Plan / About Settings scene
- dedicated Debug Developer Tools window and `CommandMenu("Developer")`

## v1 public API direction

The canonical app-facing names are:

- `PurchaseConfiguration`
- `PurchaseFeature`
- `PurchaseManager`
- `StoreProduct`
- `ProPaywallConfiguration`
- `ProPaywallView`
- `PremiumFeature` / `PremiumAccessPolicy`
- `ProGate` / `ProGateButton` / `ProBadge` / `ProUpsellView`
- `ProPlanPaneConfiguration`
- `ProPlanPane`
- Debug-only `FoundationDeveloperView` + developer configuration models

`PurchaseManager.hasPro` is the normal authorization check. Verified StoreKit transaction state remains the production source of truth.

The v1 API intentionally does not carry PaywallKit's persisted `hasPro` entitlement model, legacy paid-app migration, or an old `PurchaseController` compatibility alias.

## Release checklist

### Source/API

- [ ] Confirm `master` contains only the intended Commerce, Premium, Settings, and Developer source areas.
- [ ] Confirm there is no `PurchaseController` public alias or duplicate manager implementation.
- [ ] Confirm `StoreProduct` is the single public normalized product model.
- [ ] Confirm `ProPlanPane` is the single package-owned Plan settings surface.
- [ ] Confirm Developer Tools are wrapped in `#if DEBUG` and remain outside Settings.
- [ ] Confirm no UIKit or iOS-only view modifiers remain in the macOS package.
- [ ] Confirm public package deployment target is macOS 15.0.

### Commerce

- [ ] Validate monthly, yearly, and lifetime product catalogs.
- [ ] Validate verified purchase -> `hasPro` transition.
- [ ] Validate cancelled and pending purchases do not unlock Pro.
- [ ] Validate restore: restored, nothing-to-restore, and failure cases.
- [ ] Validate foreground entitlement refresh.
- [ ] Validate active product and preferred product behavior.

### Trial / introductory offers

- [ ] Validate eligible free-trial CTA and disclosure.
- [ ] Validate ineligible free trial falls back to normal paid copy.
- [ ] Validate pay-as-you-go and pay-up-front introductory copy.
- [ ] Validate lifetime products never present introductory offers.
- [ ] Validate Developer Tools can edit eligibility, period, period count, and paid offer price.

### Simulator

- [ ] Validate live <-> simulated runtime switching in Debug.
- [ ] Validate simulated product ordering and preferred plan.
- [ ] Validate product-to-entitlement mapping.
- [ ] Validate forced Free/Pro entitlement.
- [ ] Validate success, pending, cancellation, and injected failure outcomes.
- [ ] Validate product-load and restore failures.
- [ ] Validate latency controls.
- [ ] Validate simulator edits never mutate production `PurchaseConfiguration`.
- [ ] Validate Release builds always resolve to live StoreKit.

### Paywall / gating

- [ ] Validate product loading/retry states.
- [ ] Validate highlighted plan and computed yearly savings badge.
- [ ] Validate successful purchase callback only fires when the purchase newly unlocks Pro.
- [ ] Validate restore feedback and callback.
- [ ] Validate Redeem Code flow and entitlement refresh on macOS 15+.
- [ ] Validate Terms and Privacy links.
- [ ] Validate `ProGate`, `ProGateButton`, locked overlay, and upsell presentation.
- [ ] Validate existing-content access policy behavior after entitlement expiry.

### Settings / Plan

- [ ] Validate compact Spokio-style `TabView` integration at the app level.
- [ ] Validate Free and Pro status presentation.
- [ ] Validate MONTHLY / YEARLY / LIFETIME / PRO label derivation.
- [ ] Validate Manage Subscription only appears for an active recurring product.
- [ ] Validate Upgrade to Pro remains an app-owned presentation action.
- [ ] Validate manager-provided features and app-overridden features.
- [ ] Confirm General and About panes remain app-owned.

### Developer Tools

- [ ] Validate dedicated Debug-only `Window` scene.
- [ ] Validate `CommandMenu("Developer")` opens that window with `openWindow(id:)`.
- [ ] Validate replay of the real app paywall/upsell.
- [ ] Validate app-specific action/toggle/value/destination sections.
- [ ] Validate diagnostics copy to the macOS pasteboard.
- [ ] Confirm Developer Tools are not exposed from Settings.

### Demo app

- [ ] From `Examples/Demo`, generate with XcodeGen 2.45.4+.
- [ ] Confirm the generated target deployment target is macOS 15.0.
- [ ] Confirm the demo resolves the local `../..` MacAppFoundation package.
- [ ] Validate simulated purchases at launch.
- [ ] Switch to StoreKit Testing and validate the included `.storekit` catalog.
- [ ] Open every showcase section and every app-owned window.
- [ ] Open General / Plan / About Settings.
- [ ] Open Developer Tools from the Developer menu and exercise replay/custom sections.

### Privacy / release packaging

- [ ] Confirm the package does not collect user data or contact tracking domains.
- [ ] Re-check privacy-manifest requirements if release scope or platform support changes.
- [ ] Current `UserDefaults` access is confined to the Debug-only purchase simulator; do not copy PaywallKit's production `hasPro` persistence/privacy declaration into MacAppFoundation without an actual release-build need.
- [ ] Confirm `Package.swift` platform/toolchain requirements match the consuming apps.

### Documentation/tag

- [ ] Review `README.md` examples against the final public API.
- [ ] Review `Documentation/Settings.md`.
- [ ] Review `Documentation/DeveloperTools.md`.
- [ ] Review `Examples/Demo/README.md` and `project.yml`.
- [ ] Review this release note/checklist.
- [ ] Create tag `1.0.0` only after the final source/API review.
- [ ] Use the Release summary above as the GitHub release body, trimming checklist details.

## Explicitly deferred beyond 1.0.0

- legacy paid-app entitlement migration
- startup resilience/recovery
- general app/window lifecycle framework
- launch at login
- general menu bar management
- notification management
- themes/design systems
- backup/export/screenshot/promo/widget subsystems
- AI features
- connectivity/network diagnostics
- reports/charts/persistence/domain models
