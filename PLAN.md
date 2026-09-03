# MacAppFoundation v1.0.0 Implementation Plan

## Goal

Build a focused macOS foundation package around three areas only:

1. Commerce + simulation
2. Paywall / Pro gating / upsells
3. Settings + developer tools

The primary implementation rule for v1.0.0 is **reuse before invention**. Port or adapt proven implementation from `hoangbkit/AppFoundation` (`develop`), `hoangbkit/PaywallKit` (`master`), Spokio's embedded `Packages/PaywallKit`, and `hoangbkit/Onlink` (`master`) wherever possible. New abstractions should only be introduced when the existing implementations cannot cleanly support macOS reuse.

## Source priority

Use the existing repositories in this order:

1. **AppFoundation / develop** — source of truth for current commerce architecture, StoreKit entitlement semantics, purchase simulation, developer tools, introductory offers, and reusable configuration models.
2. **PaywallKit / master** and **Spokio embedded PaywallKit** — source of truth for proven macOS paywall presentation, Pro gates, badges, lock popovers, upsell UI, and desktop purchase interaction patterns.
3. **Onlink / master** — source of truth for real-world macOS integration and app-facing wrappers, including paywall presentation and legacy paid-app entitlement migration.

Do not preserve older behavior merely for source compatibility when AppFoundation already has a safer/newer implementation. In particular, verified StoreKit transactions remain the source of truth for authorization; do not use a persisted `UserDefaults.hasPro` flag as the entitlement authority.

---

## Phase 0 — Package bootstrap and source inventory

Create the Swift package foundation and establish explicit mappings from existing source files to their MacAppFoundation destinations before feature work begins.

### Work

- Create `Package.swift` for macOS with the same modern Swift/toolchain baseline used by AppFoundation where practical.
- Create the initial `Sources/MacAppFoundation` and `Tests/MacAppFoundationTests` layout.
- Inventory the relevant Commerce, Paywall/Premium, Settings, and Developer files in the four reference codebases.
- Record each reused component as one of: direct copy, macOS adaptation, merge of existing implementations, or intentionally excluded.
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

## Phase 6 — Foundation settings components

Port only reusable macOS settings pieces needed by commerce and developer tooling; do not turn MacAppFoundation into an app-specific settings framework.

### Reuse

Use AppFoundation's settings/developer-section patterns and Onlink's real macOS Settings integration as references.

### Requirements

- Reusable Pro/subscription status settings section.
- Purchase/restore entry points appropriate for Settings.
- Reusable developer-section entry point.
- Small settings section/container helpers only where they remove repeated app code.
- Native macOS presentation and controls.
- App owns its Settings scene, navigation, unrelated preferences, and visual identity.

### Exit criteria

- An app can compose MacAppFoundation's commerce/developer sections into its own Settings UI without adopting a framework-owned settings architecture.

---

## Phase 7 — Developer tools

Port AppFoundation's `FoundationDeveloperView` capability to macOS and connect it directly to the commerce simulator from Phase 2.

### Reuse

Copy/adapt AppFoundation's existing developer-tool implementation and replay registration model rather than inventing a new debug console.

### Requirements

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
- Debug/developer-only behavior must remain straightforward to exclude from production UI.

### Exit criteria

- A consuming macOS app can inspect and exercise its complete commerce/paywall behavior from one reusable developer surface.

---

## Phase 8 — Integration hardening and v1.0.0 API cleanup

Treat the reference apps as compatibility scenarios, remove accidental duplication introduced during porting, and freeze a small public API suitable for v1.0.0.

### Work

- Validate the API against the PaywallKit/Spokio use case: standard subscription/lifetime paywall and Pro gating.
- Validate against Onlink: macOS paywall plus optional legacy-paid entitlement migration.
- Ensure simulator and live StoreKit paths expose consistent app-facing state.
- Remove copied compatibility layers that are unnecessary in a greenfield package.
- Minimize `public` surface area.
- Normalize naming around `PurchaseManager` rather than carrying old controller/manager duplication unless compatibility is genuinely needed.
- Add focused tests around entitlement derivation, product configuration, simulation outcomes, introductory offers, and legacy migration policy.
- Write README integration examples for standard commerce, paywall presentation, simulation, developer tools, and legacy-paid migration.
- Prepare `1.0.0` release notes/tag checklist.

### Exit criteria

- The three v1.0.0 pillars are cohesive and reusable.
- Spokio/PaywallKit-style and Onlink-style commerce flows can migrate without rebuilding framework functionality.
- No unrelated framework scope has leaked into v1.0.0.

---

## Explicitly out of scope for v1.0.0

Do not add these merely because they exist in AppFoundation or Onlink:

- startup resilience/recovery
- app/window lifecycle helpers
- launch at login
- menu bar management
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

MacAppFoundation 1.0.0 is complete when a macOS app can adopt one package to configure StoreKit products, determine verified Pro entitlement, purchase/restore, simulate the full commerce flow, present a native trial-aware Pro paywall, gate/upsell premium features, expose commerce settings, and use a reusable developer console — while retaining ownership of app navigation, product copy, branding, and domain behavior.