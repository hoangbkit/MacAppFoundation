# MacAppFoundation v1.0.0 Source Reuse Inventory

MacAppFoundation v1.0.0 is intentionally a consolidation/porting project, not a clean-room rewrite.

The rule for every later phase is:

1. copy proven code when it already fits the new package,
2. adapt only platform/API boundaries that differ on macOS,
3. merge overlapping implementations only when AppFoundation has newer semantics and PaywallKit/Spokio has the better macOS presentation,
4. do not introduce a new abstraction until the existing implementations have been evaluated first.

## Reference branches

| Repository | Branch | Role |
| --- | --- | --- |
| `hoangbkit/AppFoundation` | `develop` | Current commerce architecture, simulator, canonical Pro APIs, developer tools |
| `hoangbkit/PaywallKit` | `master` | Existing macOS paywall and premium UI primitives |
| `hoangbkit/Spokio` | `develop` | Production macOS Settings/Plan presentation and embedded PaywallKit usage |
| `hoangbkit/Onlink` | `master` | Optional reference for app-facing macOS paywall wrapping only; legacy entitlement migration is excluded |

Re-fetch these branches before implementing the phase that consumes them; this inventory records the intended source ownership, not frozen vendor copies.

---

## 1. Commerce + simulation

### AppFoundation — primary source

Source directory: `Sources/AppFoundation/Purchases/`

| Source | Intended MacAppFoundation destination | Reuse mode | Notes |
| --- | --- | --- | --- |
| `Sources/AppFoundation/Purchases/CommerceFoundation.swift` | `Sources/MacAppFoundation/Commerce/CommerceFoundation.swift` | adapt/copy | Preserve current configuration and shared commerce semantics where they fit macOS. |
| `Sources/AppFoundation/Purchases/PurchaseController.swift` | `Sources/MacAppFoundation/Commerce/PurchaseManager.swift` | adapt/rename | Use the current implementation as the source of truth; v1 public naming should converge on `PurchaseManager` rather than carrying unnecessary compatibility naming. |
| `Sources/AppFoundation/Purchases/PurchaseService.swift` | `Sources/MacAppFoundation/Commerce/PurchaseService.swift` | direct copy first | Preserve StoreKit 2 service behavior, verified transactions, product metadata, and purchase results unless a macOS API difference requires adjustment. |
| `Sources/AppFoundation/Purchases/PurchaseServiceFactory.swift` | `Sources/MacAppFoundation/Commerce/PurchaseServiceFactory.swift` | direct copy/adapt | Preserve live-vs-simulated service creation and configuration. |
| `Sources/AppFoundation/Purchases/SimulatedPurchaseService.swift` | `Sources/MacAppFoundation/Commerce/SimulatedPurchaseService.swift` | direct copy first | Primary source for simulated products, outcomes, entitlement state, latency, failures, reset/reload, and introductory offers. |
| `Sources/AppFoundation/Purchases/PurchaseLifecycleModifier.swift` | `Sources/MacAppFoundation/Commerce/PurchaseLifecycleModifier.swift` | adapt | Retain only lifecycle refresh behavior that is appropriate on macOS. |
| `Sources/AppFoundation/Purchases/PurchaseFeatureCatalog.swift` | evaluate during premium phase | selective reuse | Only retain generic feature-description data if it is still needed after adopting Spokio's Plan presentation. |

### PaywallKit — behavior reference, not entitlement authority

| Source | Reuse mode | Notes |
| --- | --- | --- |
| `Sources/PaywallKit/PaywallManager.swift` | inspect/merge selectively | Reuse proven macOS-specific StoreKit behavior if AppFoundation lacks an equivalent. Do **not** carry forward `UserDefaults` as the authorization source for `hasPro`. |
| `Sources/PaywallKit/PaywallPlan.swift` or equivalent plan model in current source | compare/merge | Prefer AppFoundation's newer plan/trial model when semantics overlap. |
| `Sources/PaywallKit/PrivacyInfo.xcprivacy` | inspect before release | Reconcile with actual MacAppFoundation API usage rather than blindly copying. |

Spokio's embedded copy under `Packages/PaywallKit/Sources/PaywallKit/` should be checked alongside standalone PaywallKit when a phase begins; where files are identical, standalone PaywallKit remains the source reference.

### Explicit commerce exclusion

Do not port Onlink's `OnlinkLegacyEntitlementPolicy`, `AppTransaction.originalAppVersion` migration logic, legacy-paid caching, or legacy entitlement source states. v1.0.0 supports current StoreKit products only.

---

## 2. Paywall / Pro gating / upsells

### PaywallKit — primary macOS UI source

| Source | Intended destination | Reuse mode | Notes |
| --- | --- | --- | --- |
| `Sources/PaywallKit/PaywallView_macOS.swift` | `Sources/MacAppFoundation/Premium/ProPaywallView.swift` | copy + merge | Preserve the proven desktop layout and interactions; merge in AppFoundation's newer trial/introductory-offer and purchase-state semantics. |
| `Sources/PaywallKit/PaywallGate.swift` | `Sources/MacAppFoundation/Premium/ProGate.swift` | copy/adapt | Keep lightweight gating behavior but bind it to the shared verified commerce state. |
| `Sources/PaywallKit/ProBadge.swift` | `Sources/MacAppFoundation/Premium/ProBadge.swift` | copy/adapt | Remove app-specific visual assumptions if any. |
| `Sources/PaywallKit/ProGateButton.swift` | `Sources/MacAppFoundation/Premium/ProGateButton.swift` | copy/adapt | App continues to own paywall presentation/navigation. |
| `Sources/PaywallKit/ProLockInfoProvider.swift` | `Sources/MacAppFoundation/Premium/ProLockInfoProvider.swift` | copy if still useful | Keep only if it remains simpler than AppFoundation's newer access-policy approach. |
| `Sources/PaywallKit/ProLockPopover.swift` | `Sources/MacAppFoundation/Premium/ProLockPopover.swift` | copy/adapt | Preserve native macOS popover behavior. |
| `Sources/PaywallKit/UpsellView.swift` | `Sources/MacAppFoundation/Premium/ProUpsellView.swift` | copy + merge | Compare against AppFoundation's current `ProUpsellView` and retain the best reusable structure without duplicate public types. |
| `Sources/PaywallKit/AdaptiveButtonStyle.swift` | evaluate, likely exclude | selective reuse | Do not introduce a package-wide custom design system solely for this helper. Keep only if a copied component genuinely requires it. |

### AppFoundation — semantics/API source

| Source | Intended use | Reuse mode |
| --- | --- | --- |
| `Sources/AppFoundation/UI/ProPaywallView.swift` | Current canonical paywall behavior, configuration, trial/intro offer semantics | merge into macOS paywall |
| `Sources/AppFoundation/UI/ProPlanSettingsSection.swift` | Current-plan/restore/manage/redeem semantics | mine for behavior, not primary macOS Plan layout |
| AppFoundation Pro gate/badge/upsell files under `Sources/AppFoundation/UI/` | Compare with PaywallKit equivalents | selectively merge newer APIs/semantics |

Do not port AppFoundation's theme system just to support these views. MacAppFoundation v1 uses native macOS styling with small app-supplied branding hooks.

### Production wrapper pattern

Onlink's `Sources/Onlink/OnlinkProPaywallView.swift` may be consulted only as an integration-pattern reference for keeping framework mechanics separate from app-owned copy, features, legal URLs, dismissal, and post-purchase refresh. Do not pull in its entitlement store or legacy migration behavior.

---

## 3. Settings

### Spokio — primary Settings source

Spokio is the desired macOS product shape for v1.0.0.

| Source | Intended MacAppFoundation use | Reuse mode |
| --- | --- | --- |
| `Spokio/Views/Settings/SettingsView.swift` | Reference for native `Settings` scene composition, compact `TabView`, tab items, fixed-size desktop layout, `GroupBox` rows/dividers | pattern + selective extraction |
| `Spokio/Views/Settings/PlanPane.swift` | `Sources/MacAppFoundation/Settings/ProPlanPane.swift` | **copy/adapt as primary implementation** |
| `Spokio/App.swift` | Reference for app-owned `Settings { ... }` scene wiring | pattern only |

### Plan tab adaptation rules

Start from Spokio `PlanPane.swift`, preserving its product structure:

- Free/Pro hero status card,
- active-plan badge,
- upgrade action for free users,
- Manage Subscription action for Pro users,
- Pro feature list below the status card,
- compact `GroupBox`-based macOS presentation.

Generalize only what is app-specific:

- `Color.sp*` values -> native/system styling or small injected styling hooks,
- `Spokio` copy -> configuration,
- `Container.shared.paywallManager()` -> shared MacAppFoundation `PurchaseManager`,
- `@Default(.hasPro)` -> verified entitlement state from `PurchaseManager`,
- `AppConfig.paywallWindowID` -> app-owned upgrade callback/presentation action,
- `ProFeatureCatalog.all` -> app-supplied feature list/catalog.

Do not replace the Spokio Plan tab with AppFoundation's iOS-oriented settings presentation merely because AppFoundation has `ProPlanSettingsSection`; reuse its commerce behavior where useful while retaining Spokio's macOS structure.

### Settings ownership boundary

MacAppFoundation should supply reusable Plan/commerce pieces. The consuming app continues to own:

- the `Settings` scene,
- settings tab enum/selection,
- General preferences,
- About copy/links/credits,
- app-specific settings sections,
- app navigation/state.

Developer Tools are not a Settings section.

---

## 4. Developer Tools

### AppFoundation — primary developer-console source

| Source | Intended destination | Reuse mode | Notes |
| --- | --- | --- | --- |
| `Sources/AppFoundation/UI/FoundationDeveloperView.swift` | `Sources/MacAppFoundation/Developer/FoundationDeveloperView.swift` | copy/adapt | Keep the existing configuration/replay/additional-section model and commerce simulator controls. Adapt layout for a resizable macOS window. |
| `Documentation/DeveloperTools.md` | MacAppFoundation developer-tools documentation | adapt later | Preserve the philosophy of replaying real production flows rather than fake debug versions. |
| `Examples/Demo/Demo/DemoDeveloperView.swift` | integration reference | pattern only | Useful for registering paywall/upsell replay and app-specific sections. |

`FoundationDeveloperConfiguration`, `FoundationDeveloperReplay`, developer actions, and additional-section models currently live with `FoundationDeveloperView.swift`; keep them together initially unless a later implementation phase demonstrates a clear reason to split them.

### Spokio — window/menu presentation source

| Source | Intended use | Reuse mode |
| --- | --- | --- |
| `Spokio/App.swift` | Dedicated debug `Window(..., id:)` plus `CommandMenu("Developer")` + `openWindow(id:)` pattern | copy pattern, app-owned scene wiring |

Required v1 behavior:

- Developer Tools is a separate debug-only window.
- It opens from the macOS `Developer` menu.
- It is not embedded in Settings.
- MacAppFoundation provides the reusable developer view; the consuming app owns the actual `Window` scene and menu command.

---

## 5. Explicitly excluded source areas for v1.0.0

Do not copy these while implementing the three selected pillars:

### AppFoundation

- `Sources/AppFoundation/AI/`
- `Sources/AppFoundation/Backup/`
- `Sources/AppFoundation/Export/`
- `Sources/AppFoundation/ScreenshotStudio/`
- `Sources/AppFoundation/PromoVideoStudio/`
- `Sources/AppFoundation/WidgetShowcase/`
- full Themes subsystem
- startup resilience/recovery
- unrelated platform helpers

### Onlink

- legacy paid-app entitlement migration
- `AppTransaction.originalAppVersion` policy
- legacy entitlement caching/source models
- connectivity/network monitoring
- speed tests
- diagnostics/history/reports
- charts
- persistence/domain models
- general settings implementation
- launch-at-login/menu-bar infrastructure

### Spokio

- TTS/audio/model/domain code
- app state/navigation implementation
- custom theme/design system
- logging/data/cache systems
- General/About settings content except as layout reference

---

## Phase ownership summary

| MacAppFoundation phase | Primary code source | Secondary source |
| --- | --- | --- |
| Phase 1 Commerce core | AppFoundation | PaywallKit macOS behavior where needed |
| Phase 2 Purchase simulation | AppFoundation | — |
| Phase 3 macOS Pro paywall | PaywallKit/Spokio embedded PaywallKit | AppFoundation canonical paywall semantics |
| Phase 4 Pro gating/upsells | PaywallKit | AppFoundation newer Pro APIs |
| Phase 5 Settings/Plan | **Spokio SettingsView + PlanPane** | AppFoundation commerce/settings behavior |
| Phase 6 Developer Tools | AppFoundation FoundationDeveloperView | Spokio window/menu presentation |
| Phase 7 hardening | MacAppFoundation result | reference integrations |

This mapping is the guardrail for v1.0.0: if a later phase starts implementing a feature from scratch, first verify that the relevant source above cannot be copied or adapted.