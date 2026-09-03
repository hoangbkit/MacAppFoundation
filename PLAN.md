# MacAppFoundation v1.0.0 Implementation Plan

## Goal

Build a focused macOS foundation package around three areas only:

1. Commerce + simulation
2. Paywall / Pro gating / upsells
3. Settings + developer tools

The primary implementation rule for v1.0.0 is **reuse before invention**. Port or adapt proven implementation from `hoangbkit/AppFoundation` (`develop`), `hoangbkit/PaywallKit` (`master`), Spokio's embedded `Packages/PaywallKit`, and `hoangbkit/Onlink` (`master`) wherever possible. New abstractions should only be introduced when the existing implementations cannot cleanly support macOS reuse.

For pillar 3, the intended macOS product shape is explicit:

- **Settings** should follow Spokio's macOS Settings design: a native `Settings` scene using a compact tabbed `SettingsView` with app-owned tabs such as General, Plan, and About.
- **Plan tab** should be copied/adapted directly from Spokio's current `PlanPane` implementation as much as possible, then generalized only where app-specific names, colors, URLs, or feature data must be supplied by the consuming app.
- **Developer Tools** must **not** live inside Settings. They should be presented in a dedicated debug-only window opened from a `Developer` menu in the macOS menu bar, following the same `Window(id:)` + `openWindow(id:)` pattern already used by Spokio for developer windows.

## Source priority

Use the existing repositories in this order:

1. **AppFoundation / develop** — source of truth for current commerce architecture, StoreKit entitlement semantics, purchase simulation, developer tools, introductory offers, and reusable configuration models.
2. **PaywallKit / master** and **Spokio embedded PaywallKit** — source of truth for proven macOS paywall presentation, Pro gates, badges, lock popovers, upsell UI, and desktop purchase interaction patterns.
3. **Spokio / develop** — source of truth for the desired macOS Settings scene/layout, the Plan tab implementation, and menu-driven developer-window presentation.
4. **Onlink / master** — source of truth for real-world macOS integration and app-facing wrappers, including paywall presentation and legacy paid-app entitlement migration.

Do not preserve older behavior merely for source compatibility when AppFoundation already has a safer/newer implementation. In particular, verified StoreKit transactions remain the source of truth for authorization; do not use a persisted `UserDefaults.hasPro` flag as the entitlement authority.

---

## Phase 0 — Package bootstrap and source inventory

Create the Swift package foundation and establish explicit mappings from existing source files to their MacAppFoundation destinations before feature work begins.

### Work

- Create `Package.swift` for macOS with the same modern Swift/toolchain baseline used by AppFoundation where practical.
- Create the initial `Sources/MacAppFoundation` and `Tests/MacAppFoundationTests` layout.
- Inventory the relevant Commerce, Paywall/Premium, Settings, Plan, and Developer files in the reference codebases.
- Record each reused component as one of: direct copy, macOS adaptation, merge of existing implementations, or intentionally excluded.
- Treat Spokio's `SettingsView.swift` and `PlanPane.swift` as concrete UI source files to port, not merely visual references.
- Keep v1.0.0 strictly scoped to the three selected pillars.

### Exit criteria

- Package structure exists.
- Reuse mapping is documented.
- No unrelated AppFoundation/Onlink subsystems are pulled in.

---

## Phase 1 — Commerce core

Port AppFoundation's current commerce architecture to macOS, using PaywallKit only where it contains macOS-specific StoreKit behavior that is still useful.

### Reuse

Prefer direct/adapted copies of AppFoundation's:

- `PurchaseManager`
- `PurchaseConfiguration`
- purchase service/protocol abstractions
- StoreKit purchase service
- product/plan models
- entitlement refresh and transaction observation
- purchase/restore result handling
- subscription plan support
- introductory-offer/trial metadata and eligibility support

Use PaywallKit/Spokio implementations as a macOS behavior reference rather than retaining their older persisted entitlement model.

### Requirements

- StoreKit 2 product loading.
- Purchase and restore.
- Verified current-entitlement evaluation.
- Transaction update observation.
- Foreground entitlement refresh where appropriate for the package API.
- Weekly, monthly, yearly, and lifetime plan support.
- Introductory offers/trials supported by the commerce model.
- Clear app-owned product configuration; no hard-coded app product IDs.

### Exit criteria

- A macOS app can configure products, load them, purchase, restore, and derive Pro status from verified StoreKit state using MacAppFoundation alone.

---

## Phase 2 — Purchase simulation

Port AppFoundation's purchase simulator and developer-configurable StoreKit replacement with minimal redesign.

### Reuse

Copy/adapt AppFoundation's existing simulated purchase service, simulated products/configuration, outcome injection, entitlement mapping, preferred-plan behavior, latency, reset, refresh, and failure controls.

Include the introductory-offer simulation work already present in AppFoundation rather than creating a separate macOS simulator design.

### Requirements

- Runtime selection between live StoreKit and simulated purchase services in debug/developer flows.
- Editable simulated products and ordering.
- Prices and billing periods.
- Introductory offers/trials.
- Product-to-entitlement mapping.
- Preferred/default plan.
- Purchase outcomes: success, pending, cancellation, network failure, unavailable, system/error cases already supported by AppFoundation.
- Product-load and restore failure injection.
- Configurable latency.
- Reset/reload/refresh behavior.

### Exit criteria

- Commerce flows can be exercised without App Store Connect using the same conceptual simulator model as AppFoundation.

---

## Phase 3 — Legacy paid-app entitlement policy

Extract the proven legacy-paid migration behavior from Onlink into a small reusable commerce policy instead of copying Onlink-specific entitlement-store code wholesale.

### Reuse

Adapt Onlink's verified `AppTransaction` / `originalAppVersion` migration logic.

### Requirements

- Optional policy; apps that do not need migration pay no configuration cost.
- App-configurable business-model transition version.
- Verified AppTransaction only.
- Bundle identity validation where applicable.
- Existing paid customers before the configured transition can receive the appropriate Pro entitlement.
- Keep migration state separate from normal StoreKit subscription/non-consumable authorization.
- Avoid Onlink names and domain-specific assumptions in the public API.

### Exit criteria

- Onlink's legacy-paid use case can be expressed through MacAppFoundation configuration without a custom entitlement-store implementation.

---

## Phase 4 — macOS Pro paywall

Combine AppFoundation's current commerce/paywall model with PaywallKit's already-proven `PaywallView_macOS` presentation rather than designing a new paywall from scratch.

### Reuse

- Start from PaywallKit/Spokio `PaywallView_macOS` structure and desktop interaction patterns.
- Port AppFoundation's current canonical paywall semantics, plan configuration, trial/introductory-offer presentation, purchase states, and simulator compatibility.
- Use Onlink's `OnlinkProPaywallView` as the reference for keeping app-specific copy, features, legal links, and post-purchase actions outside the framework.

### Requirements

- Native macOS layout.
- Configurable title, subtitle, feature list, legal links, and branding hooks.
- Selectable plan rows/cards.
- Preferred/featured plan presentation.
- Trial/introductory-offer aware copy and primary action.
- Purchase progress/error states.
- Restore purchases.
- Redeem-code action when supported.
- Purchase/restored callbacks so apps can dismiss or refresh their own state.
- No app-specific product IDs or copy in the framework.

### Exit criteria

- Apps can present a production-ready macOS Pro paywall by supplying configuration and copy, without rebuilding commerce UI.

---

## Phase 5 — Pro gating and upsells

Port the small reusable premium UI primitives from PaywallKit and reconcile them with AppFoundation's newer gating APIs.

### Reuse

Prefer adapting existing implementations of:

- `PaywallGate`
- `ProBadge`
- `ProGateButton`
- `ProLockPopover`
- `UpsellView`
- AppFoundation premium gates/locked overlays/settings sections/limit-reached upsells where they improve the older PaywallKit implementation.

### Requirements

- Lightweight Pro badge.
- Locked-content presentation.
- Gate/button helpers that route free users to an app-supplied paywall action.
- Reusable upsell view.
- Settings-friendly Pro plan/status section.
- Components consume the shared commerce entitlement state rather than maintaining their own Pro flag.
- Apps retain ownership of navigation/presentation decisions.

### Exit criteria

- Common premium gating scenarios require composition/configuration, not custom entitlement plumbing.

---

## Phase 6 — Spokio-style macOS Settings + Plan tab

Port Spokio's current macOS Settings structure and **copy/adapt its `PlanPane` implementation directly** rather than designing a new Plan settings experience.

### Reuse

Use these Spokio files as the primary implementation source:

- `Spokio/Views/Settings/SettingsView.swift`
- `Spokio/Views/Settings/PlanPane.swift`

Preserve the useful Plan tab structure already proven in Spokio:

- top plan-status `GroupBox`
- Free vs Pro state
- status icon in the top-right
- current plan label such as MONTHLY / YEARLY / LIFETIME / PRO
- short entitlement/status description
- `Manage Subscription` action for Pro users
- `Upgrade to Pro` action for free users
- lower `GroupBox` containing the Pro feature list
- compact macOS Settings sizing and native grouping

### Generalization rules

Copy the implementation first, then remove only Spokio-specific coupling:

- replace `Color.sp*` values with native/default styling or lightweight configurable style hooks
- replace hard-coded `"Spokio"` copy with app-supplied app name/copy
- replace `AppConfig.paywallWindowID` with an app-supplied paywall action/window hook
- replace Spokio's `ProFeatureCatalog.all` with app-supplied feature data
- replace direct `Defaults.hasPro` usage with the shared MacAppFoundation commerce entitlement state
- replace direct `Container.shared.paywallManager()` access with the package's `PurchaseManager`
- keep the standard App Store subscription-management URL behavior
- derive the current plan label from the shared purchase state

Do **not** redesign the Plan tab into a generic form/list or a new visual system unless required by platform/API constraints.

### Settings requirements

- Native app-owned `Settings { ... }` scene.
- Compact `TabView` matching Spokio's structure.
- App-owned tabs such as General, Plan, and About.
- MacAppFoundation provides the reusable Plan view suitable for direct use as the Plan tab.
- General preferences and About content remain app-owned.
- **No Developer Tools section or developer entry point inside Settings.**

### Exit criteria

- A consuming app can build the same Settings structure as Spokio and drop in a generalized version of Spokio's current Plan tab with minimal configuration.
- Visual/interaction behavior of the Plan tab remains recognizably the same as Spokio's existing implementation rather than being newly invented.

---

## Phase 7 — Developer Tools window + menu command

Port AppFoundation's `FoundationDeveloperView` capability to macOS, but present it as a dedicated debug-only window opened from the macOS menu bar instead of embedding it in Settings.

### Reuse

- Copy/adapt AppFoundation's existing `FoundationDeveloperView`, commerce simulator controls, diagnostics, and replay registration model rather than inventing a new debug console.
- Follow Spokio's `App.swift` developer-window pattern: declare a debug-only `Window(..., id:)`, then expose a `CommandMenu("Developer")` command that calls `openWindow(id:)`.
- Generalize only the tiny amount needed so consuming apps can wire the provided view/window into their own `App` scene cleanly.

### Window/presentation requirements

- Developer Tools is a **separate window**, not a Settings tab, sheet, or embedded settings section.
- Intended scene shape is an app-owned debug-only `Window("Developer Tools", id: ...)` containing MacAppFoundation's developer view.
- Intended menu shape is an app-owned debug-only `CommandMenu("Developer")` with a `Developer Tools…` action that opens that window using `openWindow(id:)`.
- Provide small reusable constants/helpers if useful, but do not hide normal SwiftUI scene composition behind a heavy window manager.
- The window should have a sensible minimum/default desktop size and support the richer controls needed by the developer console.
- Debug/developer-only use should be obvious and easy to wrap in `#if DEBUG`.

### Developer tools requirements

- Live StoreKit vs simulated purchase switching.
- Current entitlement state.
- Product loading state.
- Simulated product editor.
- Product ordering and entitlement mapping.
- Preferred plan.
- Price, billing-period, trial, and introductory-offer configuration.
- Purchase outcome and failure injection.
- Latency controls.
- Reset/refresh/reload actions.
- Copyable commerce diagnostics.
- Replay hooks for app-owned paywall and upsell presentations.
- Extensible developer sections so apps can register their own debug controls.

### Exit criteria

- A consuming app can add one dedicated Developer Tools window and one Developer menu command, and use the full AppFoundation-derived commerce simulator/debug UI without putting any developer controls in Settings.

---

## Phase 8 — Integration hardening and v1.0.0 API cleanup

Treat the reference apps as compatibility scenarios, remove accidental duplication introduced during porting, and freeze a small public API suitable for v1.0.0.

### Work

- Validate the API against the PaywallKit/Spokio use case: standard subscription/lifetime paywall and Pro gating.
- Validate the Settings composition and generalized Plan tab against Spokio's current `SettingsView` + `PlanPane` behavior.
- Validate the dedicated Developer Tools window/menu integration against Spokio's existing debug window + `CommandMenu("Developer")` pattern.
- Validate against Onlink: macOS paywall plus optional legacy-paid entitlement migration.
- Ensure simulator and live StoreKit paths expose consistent app-facing state.
- Remove copied compatibility layers that are unnecessary in a greenfield package.
- Minimize `public` surface area.
- Normalize naming around `PurchaseManager` rather than carrying old controller/manager duplication unless compatibility is genuinely needed.
- Add focused tests around entitlement derivation, product configuration, simulation outcomes, introductory offers, and legacy migration policy.
- Write README integration examples for standard commerce, paywall presentation, Spokio-style Settings/Plan composition, Developer Tools window/menu wiring, simulation, and legacy-paid migration.
- Prepare `1.0.0` release notes/tag checklist.

### Exit criteria

- The three v1.0.0 pillars are cohesive and reusable.
- Spokio/PaywallKit-style and Onlink-style commerce flows can migrate without rebuilding framework functionality.
- Settings and Developer Tools have clearly separate macOS presentation responsibilities.
- No unrelated framework scope has leaked into v1.0.0.

---

## Explicitly out of scope for v1.0.0

Do not add these merely because they exist in AppFoundation or Onlink:

- startup resilience/recovery
- general app/window lifecycle framework
- launch at login
- general menu bar management beyond the minimal Developer Tools integration pattern
- notification management
- themes/design systems
- BackupKit
- ExportKit
- Screenshot Studio
- Promo Video Studio
- Widget Showcase
- AI features
- Onlink connectivity/network diagnostics
- Onlink reports/charts/persistence/domain models

These can be evaluated after v1.0.0 based on actual reuse needs.

## v1.0.0 completion definition

MacAppFoundation 1.0.0 is complete when a macOS app can adopt one package to configure StoreKit products, determine verified Pro entitlement, purchase/restore, simulate the full commerce flow, present a native trial-aware Pro paywall, gate/upsell premium features, compose a Spokio-style native Settings scene with a generalized copy of Spokio's Plan tab, and expose a full developer console in a separate debug-only window opened from the macOS Developer menu — while retaining ownership of app navigation, product copy, branding, general settings, and domain behavior.