# Offline-Safe Entitlement Persistence Proposal

## Status

Implemented on this branch. This document remains the design rationale and risk checklist for the implementation.

Chosen implementation decisions:

- live StoreKit state remains available as `PurchaseManager.entitlementState`
- effective authorization is exposed as `PurchaseManager.accessState`
- `hasPro` derives from effective access
- verified offline persistence is opt-in and disabled by default
- verified cache data is stored in Keychain
- entitlement caches are scoped by bundle ID, StoreKit environment, and `appTransactionID`
- the last verified StoreKit account identity is persisted separately, including for Free accounts
- directly purchased Lifetime access is durable offline
- subscriptions are bounded by their verified expiration or grace-period expiration
- family-shared non-consumables use a bounded offline window
- ambiguous empty entitlement results are reconciled with `Transaction.latest(for:)`
- current sellable product IDs are independent from historical entitlement-granting IDs

Target: MacAppFoundation commerce layer  
Base: develop  
Motivating consumer: offline-first macOS apps such as Spokio

## Problem

PurchaseManager currently starts with entitlementState set to checking, while hasPro is derived from entitlementState.isActive.

That means checking projects to false.

For online-first apps this can be acceptable because StoreKit can normally resolve current entitlements quickly. For an offline-first app, a previously verified paid user can launch without connectivity while PurchaseManager is still unresolved. Treating unresolved as Free can temporarily or persistently lock features that the user already paid for.

The goal is to preserve trustworthy, previously verified entitlement access across launches without turning a local cache into an unbounded source of truth.

## Design goals

1. Preserve paid access across offline launches when MAF has trustworthy prior entitlement evidence.
2. Keep StoreKit authoritative whenever it produces a definitive live result.
3. Never equate checking with a confirmed Free user.
4. Keep lifetime and subscription policies distinct.
5. Scope cached entitlement state to the correct Apple Account and app identity.
6. Prevent a stale subscription cache from behaving like lifetime access.
7. Keep product merchandising and catalog loading separate from entitlement validity.
8. Make persistence opt-in so existing MAF consumers do not silently change behavior.
9. Preserve the current meaning of entitlementState as live StoreKit-derived state.
10. Provide deterministic testability through the existing simulated purchase infrastructure.

## Non-goals

This proposal does not:

- replace StoreKit as the entitlement authority
- provide server-side receipt validation
- provide perfect DRM for permanently offline machines
- change existing product identifiers
- change App Store subscription policy
- alter pricing or paywall presentation
- automatically enable persistent entitlement caching for every MAF consumer
- require online revalidation for directly purchased lifetime products

## Current MAF model

Today the manager effectively exposes live StoreKit entitlement state as checking, inactive, or active, and hasPro is a Boolean projection of that state.

The live service obtains entitlement records from Transaction.currentEntitlements. MAF already intentionally trusts StoreKit's current-entitlement set instead of independently expiring those records again. This matters because StoreKit may continue to consider a subscription entitled during Billing Grace Period.

The missing piece is launch-to-launch continuity when live entitlement state is unavailable or unresolved.

## Proposed model

Keep live StoreKit state and effective app access as separate concepts.

Flow:

StoreKit -> live entitlement state -> effective access resolver

The effective access resolver also consumes an account-scoped verified entitlement cache.

Live entitlement state remains:

- checking
- inactive
- active

Effective app access should distinguish:

- checking
- unresolved
- inactive
- active from StoreKit
- active from verified cache

Exact type names can be decided during implementation review.

The important semantic separation is:

- entitlementState means what the current StoreKit refresh says
- accessState means what the app may safely authorize right now

## Persistent cache representation

Do not persist the current EntitlementSnapshot directly. It is intentionally compact and does not carry enough information for durable offline policy.

A future versioned cache should conceptually include:

- schema version
- bundle identifier
- StoreKit environment
- app transaction ID
- verification time
- a set of persisted entitlement records

Each persisted entitlement record should be able to represent:

- product ID
- product kind: non-consumable or auto-renewable
- ownership: directly purchased or family shared
- transaction ID
- original transaction ID
- normal expiration date
- grace-period expiration date when available
- revocation date
- upgraded state

This is an illustrative schema, not a frozen API.

## Account scoping

The cache must not be keyed only by bundle ID or product ID.

A previously verified purchase from Apple Account A must not automatically unlock Apple Account B after an account switch.

Use StoreKit's app/account identity where available, especially appTransactionID, as part of the cache namespace.

Conceptually:

bundle ID + StoreKit environment + appTransactionID -> verified entitlement cache

Persist the last verified StoreKit account identity separately from entitlement caches, including when that account has no Pro entitlement.

When live account identity cannot be established during an offline launch, MAF should use that last verified identity to select only the matching account cache. It must never scan paid caches and choose another account merely because that cache is the only paid one available.

This prevents a previously paid Account A from unlocking an offline launch after the user has switched to a verified Free Account B.

The first launch after upgrading from a version that did not persist account-scoped identity still needs explicit migration behavior and tests.

## Storage

Prefer Keychain-backed persistence instead of plain UserDefaults.

Reasons:

- entitlement data is authorization state, not presentation preference
- plain defaults are trivial to edit
- Keychain is a better fit for durable security-sensitive local state
- the cache should survive normal app upgrades

The cache is still an offline continuity mechanism, not tamper-proof DRM.

## Opt-in configuration

Persistent entitlement support should be opt-in.

A future PurchaseConfiguration option can conceptually expose an offline entitlement policy with disabled as the default.

This avoids silently changing authorization semantics for existing MAF consumers.

## Lifetime policy

A directly purchased non-consumable Lifetime product is the strongest candidate for durable offline access.

After MAF successfully verifies it:

1. persist an account-scoped verified lifetime record
2. allow Pro from that record while live StoreKit state is unresolved
3. refresh the record when StoreKit confirms the entitlement again
4. invalidate it when StoreKit later produces an explicit verified revocation

A permanently offline Mac cannot learn about a refund that happened elsewhere. That is an unavoidable offline-first trade-off.

For apps whose core value is offline local functionality, durable Lifetime access is preferable to forcing periodic network validation.

## Subscription policy

Subscriptions must not inherit the Lifetime policy.

Persist enough information to bound offline validity:

- product ID
- verification time
- known entitlement expiration
- grace-period expiration when available
- ownership
- account identity

Offline behavior should be bounded:

- if the cached subscription remains inside a trustworthy entitlement window, allow cached Pro
- if the trustworthy window has ended, move to unresolved or require live confirmation
- never use a persisted hasPro Boolean indefinitely for recurring products

The exact grace policy must be finalized before implementation.

## Billing Grace Period

Do not independently revoke a live current entitlement merely because the transaction's normal billing expiration date is in the past.

MAF already follows this principle for live currentEntitlements.

For persistence, the cache needs enough subscription-status metadata to avoid converting a valid grace-period customer to Free prematurely.

If StoreKit provides a later grace-period expiration date, that should bound cached access more accurately than the ordinary billing expiration.

## Billing retry

Billing retry without entitlement or grace must not be treated as active simply because a previous subscription transaction exists.

Cached subscription authorization must represent entitlement, not purchase history.

## Explicit revocation and refund

Explicit verified revocation always wins over cached access.

When MAF observes a revocation:

1. recompute live entitlement state
2. remove or invalidate the corresponding cached entitlement
3. atomically persist the new cache
4. publish the updated effective access state

## Empty currentEntitlements

This is the hardest policy boundary.

Normally an empty Transaction.currentEntitlements sequence means no current entitlement. However, an offline-first foundation should avoid deleting strong previously verified Lifetime state solely because one refresh produced an ambiguous empty result during a StoreKit or account anomaly.

For cached non-consumables, consider a secondary resolution step using the latest transaction for the cached product ID before destructive invalidation.

Conceptual behavior:

- currentEntitlements contains cached Lifetime -> active and refresh cache
- currentEntitlements empty + latest verified transaction is revoked -> invalidate cache
- currentEntitlements empty + latest verified transaction still supports ownership -> preserve
- currentEntitlements empty + latest lookup unavailable or ambiguous -> preserve verified cached Lifetime rather than manufacture a revocation

This behavior must be narrowly scoped to previously verified strong entitlement evidence and must never promote a fresh install to Pro.

## Fresh install while offline

A fresh installation has no trustworthy local entitlement cache.

If StoreKit cannot establish entitlement, effective access should remain unresolved rather than fabricating Pro or presenting the user as definitively Free merely because verification did not finish.

The consuming app can decide how to present unresolved access.

## Product catalog independence

Loading products for sale is separate from determining whether an existing purchase grants access.

These states must remain independently observable:

- product loading state
- live entitlement state
- effective access state

Failure to load product names, localized prices, introductory offers, or paywall metadata must never revoke a cached or live entitlement.

## Historical entitlement IDs

PurchaseConfiguration currently normalizes entitledProductIDs so they must also exist in productIDs.

That couples what the app sells now with what historical purchases still grant Pro.

A long-lived app may eventually have current v2 products for sale while v1 products remain valid entitlements for prior customers.

The foundation should support:

- productIDs: products to load, show, and sell now
- entitledProductIDs: every current or historical SKU that grants entitlement

Do not require the latter to be a subset of the former.

This is related to, but can be implemented separately from, offline persistence.

## Family Sharing

Generic MAF should account for family-shared entitlements even if a given app has sharing disabled.

Persist ownership and provenance.

A family-shared non-consumable should not automatically inherit an unconditional forever-offline policy because the user may leave the family group or sharing may stop.

A conservative policy could be:

- directly purchased Lifetime -> durable offline cache
- family-shared Lifetime -> bounded cache or periodic live confirmation

Exact behavior should be configurable or conservative by default.

## Subscription upgrades and plan changes

Do not append entitlement records forever.

When StoreKit indicates an upgraded transaction or a new current product in the same subscription relationship:

- recompute from current verified records
- replace the effective snapshot atomically
- do not retain the superseded product as an independent entitlement unless StoreKit still returns it as entitled

This prevents stale Monthly or Yearly records from outliving the actual active plan.

## Multiple simultaneous entitlements

Offline persistence should preserve the active set, not collapse to one product.

Presentation may still prefer Lifetime over recurring plans, but authorization should derive from the full verified set.

A Lifetime entitlement must not be lost merely because a concurrent subscription later expires.

## System clock manipulation

Recurring offline access introduces clock risk.

If validity is based on local dates, moving the system clock backward could extend cached subscription access.

Mitigations to consider:

- persist verifiedAt
- persist last observed wall-clock time
- detect significant backward clock movement
- if suspicious and a recurring entitlement depends on local expiry, move effective access to unresolved until StoreKit can confirm
- directly purchased Lifetime should not depend on wall-clock validity

The goal is reasonable abuse resistance without turning an offline app into strict DRM.

## Cache atomicity

Write the entire verified entitlement cache atomically.

A crash during persistence must leave either the previous valid cache or the new complete cache, never a partially updated authorization record.

## Cache versioning

Include an explicit schema version.

On decode or migration failure:

- do not crash
- do not silently manufacture Free from corrupted state
- prefer unresolved or live verification
- retain useful Debug diagnostics
- allow future schema migration

## Environment isolation

Never share cache state across:

- production StoreKit
- StoreKit configuration testing
- sandbox
- simulated purchase service
- different bundle identifiers

Debug simulation must never write entitlement state that a Release build can later consume as real access.

## Purchase lifecycle integration

Every entitlement-changing path should converge on one internal resolver.

This includes:

- initial prepare
- explicit entitlement refresh
- purchase success
- restore success
- transaction updates
- subscription-status updates
- offer-code redemption refresh
- Debug simulated entitlement changes

No UI or purchase path should maintain a separate entitlement cache.

## Proposed state resolution

Illustrative priority:

1. explicit live active StoreKit entitlement -> active from StoreKit and refresh cache
2. explicit verified revocation or sufficiently definitive inactive result -> inactive and update or invalidate cache
3. live state unresolved or ambiguous + valid account-matching verified cache -> active from verified cache
4. live unresolved + no trustworthy cache -> unresolved or checking
5. definitive live inactive + no applicable cache -> inactive

Implementation must define what constitutes definitive versus ambiguous for destructive cache invalidation.

## Risk assessment

| Scenario | Risk | Naive failure | Required behavior |
| --- | --- | --- | --- |
| Existing Lifetime user launches offline | High | checking becomes Free | Use verified lifetime cache |
| Existing subscription launches offline | High | False Free or indefinite Pro | Use bounded cached validity |
| Subscription expires while permanently offline | High | Cached Bool becomes Lifetime | Stop cached authorization at policy boundary |
| User disables auto-renew | Medium | Revoke too early | Preserve paid access until entitlement ends |
| Billing Grace Period | High | Expiration comparison revokes valid user | Respect StoreKit grace entitlement |
| Billing retry without entitlement | High | Over-grant access | Do not treat purchase history as active |
| Lifetime refund | Medium | Offline cache remains active | Explicit revocation invalidates on next authoritative refresh |
| Subscription refund or revocation | High | Cached access outlives refund | Explicit revocation wins |
| Empty StoreKit entitlement anomaly | High | Delete valid Lifetime cache | Defensive secondary resolution |
| Apple Account switch | High | Account A unlocks account B | Scope cache by app/account identity |
| Fresh install offline | Medium | Fabricated Free or Pro | Publish unresolved |
| Family Sharing ends | High | Shared Lifetime remains forever | Preserve ownership and use bounded policy |
| Subscription upgrade | Medium | Old plan remains active in cache | Replace snapshot atomically |
| Product metadata fails | High | Existing paid user loses Pro | Catalog failure must not affect entitlement |
| Historical SKU removed from sale | High | Legacy customers lose Pro | Decouple sellable IDs from entitled IDs |
| Pending purchase | Medium | Cache written before entitlement exists | Persist only verified entitlement |
| User cancels purchase | Low | Existing state overwritten | Preserve prior access state |
| Crash during cache write | Medium | Corrupt authorization state | Atomic writes |
| Local cache edited | Medium | User unlocks Pro | Keychain storage and validation metadata |
| Clock moved backward | High for subscriptions | Extends subscription | Detect rollback or fall back to unresolved |
| Clock moved forward | Medium | Premature expiry | Live StoreKit overrides cache |
| Simulator leaks into Release | High | Fake Pro persists | Environment and bundle namespace |
| Cache schema changes | Medium | Upgrade loses access | Versioning and safe migration |
| Foreground transaction update | High | Refund or renewal not reflected | Recompute and persist through one pipeline |

## Testing requirements

Deterministic tests should cover at least:

- no cache + checking
- no cache + inactive
- no cache + active Lifetime
- cached Lifetime + checking
- cached Lifetime + live active
- cached Lifetime + explicit revocation
- cached subscription inside known validity
- cached subscription after known validity
- grace-period subscription
- billing retry without entitlement
- account identity match
- account identity mismatch
- bundle or environment mismatch
- clock rollback
- corrupted cache
- old cache schema
- current and historical entitlement IDs
- subscription upgrade replacement
- multiple simultaneous entitlements
- product-load failure while paid access remains active
- pending, cancelled, and failed purchase preserving prior entitlement
- restore feeding the same resolver
- simulated purchases never populating production cache

Integration tests should exercise manager preparation, refresh concurrency, transaction updates, subscription-status updates, purchase success, restore success, Debug service switching, and cache read/write lifecycle.

Manual StoreKit verification should cover direct Lifetime, Monthly, Yearly, cancellation within paid period, expiration, restore, refund or revocation where testable, offline relaunch after prior verification, Apple Account changes, product-catalog failure, and foreground renewal or revocation refresh.

## Logging and diagnostics

Do not log transaction payloads or sensitive account identifiers.

Useful diagnostics include:

- access source: StoreKit or verified cache
- cache schema version
- whether account identity matched
- whether cache was rejected for environment or bundle mismatch
- whether recurring cached validity remains usable
- whether explicit revocation invalidated cache
- whether destructive invalidation was skipped because StoreKit state was ambiguous

Keep identifiers private or redacted in production logs.

## Suggested implementation phases

### Phase 1 — Model and storage

- define persistent cache schema
- define access state and source
- add secure store abstraction
- add versioning, environment, and account namespace
- unit-test serialization and identity matching

### Phase 2 — Resolver

- centralize live plus cached access resolution
- preserve existing entitlementState meaning
- derive effective access independently
- add Lifetime and subscription policies
- add explicit revocation handling

### Phase 3 — PurchaseManager integration

- integrate resolver into prepare, refresh, purchase, restore, and update streams
- decide whether hasPro derives from effective access or a new property is introduced
- ensure product loading remains independent

### Phase 4 — Historical entitlement support

- decouple entitledProductIDs from current sellable productIDs
- add tests for legacy products no longer present in the paywall catalog

### Phase 5 — Hardening

- clock manipulation tests
- account-switch tests
- Family Sharing policy tests
- corrupted and old cache tests
- concurrency tests
- documentation and demo coverage

## API compatibility

Prefer additive API changes.

Existing consumers using PurchaseManager, entitlementState, and hasPro should continue compiling.

Offline persistence should require explicit configuration.

If hasPro changes semantics to use effective access, document that semantic change clearly. An alternative is to introduce a distinct effective-access property first and migrate consumers deliberately before changing hasPro behavior.

This decision should be made during implementation review.

## Security model

This feature is about reliable offline customer access, not perfect anti-piracy.

Trust hierarchy:

verified live StoreKit > account-matching verified local cache > unresolved > no entitlement

Explicit verified revocation outranks prior cached authorization.

Local cache must never be promoted from unverified StoreKit data.

## Unavoidable trade-off

A permanently offline machine cannot observe a refund, Family Sharing change, or account event that occurs elsewhere.

The package cannot simultaneously guarantee indefinite offline Lifetime access and immediate remote refund enforcement.

For directly purchased Lifetime products, the proposed default favors the legitimate offline customer and reconciles on the next authoritative StoreKit refresh.

For subscriptions and shared entitlements, use bounded validity rather than indefinite cached authorization.

## Apple concepts to re-check during implementation

Implementation should verify current SDK semantics and availability for:

- Transaction.currentEntitlements
- Transaction.latest(for:)
- Transaction.revocationDate
- Transaction.isUpgraded
- Transaction.ownershipType
- AppTransaction.appTransactionID
- Product.SubscriptionInfo.Status
- renewal states including subscribed, inGracePeriod, inBillingRetryPeriod, expired, and revoked

Do not rely solely on this proposal text when coding against a future SDK.

## Resolved implementation decisions

The implementation resolves the former ready-to-build questions as follows:

- effective access uses the additive `PurchaseAccessState` API
- persistence is opt-in through `PurchaseConfiguration.offlineEntitlements`
- entitlement cache namespace uses bundle ID + StoreKit environment + `appTransactionID`
- last verified StoreKit identity is persisted independently from entitlement state, so Free account switches survive relaunch
- directly purchased Lifetime access remains usable offline until authoritative revocation is observed
- recurring access is bounded by verified expiration/grace data and guarded against wall-clock rollback
- Family Sharing uses a bounded offline window, configurable by policy
- empty current entitlement results use latest-transaction reconciliation; unavailable verification remains unresolved rather than fabricating Free
- `hasPro` reflects effective access while `entitlementState` continues to expose live StoreKit state
- cache storage uses Keychain
- historical entitlement IDs may exist outside the current sellable product catalog

## Definition of done for a future implementation

The feature is complete when:

- live StoreKit state remains independently observable
- effective access survives offline relaunch from previously verified evidence
- account-switch cache reuse is prevented
- Lifetime and recurring products follow distinct offline policies
- subscriptions cannot become indefinite access accidentally
- grace-period users are not falsely revoked
- explicit revocation invalidates cached entitlement
- product-catalog failures cannot revoke Pro
- current and historical entitlement IDs can be represented independently
- cache is versioned, atomic, environment-isolated, and securely stored
- deterministic tests cover the risk matrix
- existing MAF consumers remain source compatible
