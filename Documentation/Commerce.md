# Commerce

This document is the authoritative behavior reference for MacAppFoundation commerce.

It describes the current contracts of `PurchaseConfiguration`, `PurchaseManager`, offline entitlement persistence, retries, purchase and restore flows, the Pro paywall, Plan surfaces, premium gating, analytics, lifecycle integration, and the Debug purchase simulator.

For implementation rationale and historical trade-offs behind offline persistence, see `OfflineEntitlementPersistenceProposal.md`. When that proposal and this document differ, this document describes the intended current behavior.

## Principles

MacAppFoundation follows these rules:

1. Verified StoreKit data is the primary production source of purchase truth.
2. `hasPro` is derived from effective authorization, never from a persisted Boolean.
3. Offline persistence is opt-in.
4. Product catalog availability and entitlement authorization are independent.
5. Access state and retry policy are independent.
6. When MAF cannot prove Pro, effective access is Free. Verification may continue or retry in the background without introducing a third user-visible access state.
7. Previously verified paid access is preserved only when the cached evidence remains safe for the product type and account context.
8. Explicit verified revocation or refund is authoritative.
9. The host app owns navigation, window presentation, product copy, legal URLs, and app-specific premium policy.

## Recommended integration

Create one shared `PurchaseManager` for the application:

```swift
let purchases = PurchaseManager(
    configuration: PurchaseConfiguration(
        productIDs: [
            "com.example.app.pro.monthly",
            "com.example.app.pro.yearly",
            "com.example.app.pro.lifetime"
        ],
        preferredProductID: "com.example.app.pro.yearly",
        offlineEntitlements: .verifiedCache(.init())
    )
)
```

Attach lifecycle management near the main app root:

```swift
WindowGroup {
    ContentView()
        .managesPurchases(purchases)
}
```

For ordinary feature gating, apps should normally use:

```swift
purchases.hasPro
```

Use `entitlementState` and `accessState` only when a surface needs to distinguish live StoreKit state from effective authorization.

## PurchaseConfiguration

`PurchaseConfiguration` defines both merchandising and entitlement behavior.

### productIDs

`productIDs` are the products currently offered for sale.

The initializer:

- trims whitespace
- removes empty values
- removes duplicates while preserving order

This order is also the default presentation order for loaded products.

### entitledProductIDs

`entitledProductIDs` are all product IDs allowed to grant Pro.

By default they are the same as `productIDs`.

They may also contain historical SKUs that are no longer sold. This allows old customers to keep access after a product is removed from the current catalog.

A historical entitlement ID does not need to appear in `productIDs`.

### preferredProductID

The preferred product is used as the normal default selection when it is present in the loaded catalog.

If the supplied ID is empty or not present in `productIDs`, it is ignored.

### features

`PurchaseFeature` entries describe capabilities shown by reusable Pro surfaces.

Duplicate feature IDs are removed.

### productLoadAttempts

Controls StoreKit catalog loading attempts. The minimum is one.

### offlineEntitlements

Offline entitlement persistence is disabled by default:

```swift
offlineEntitlements: .disabled
```

Enable verified persistence explicitly:

```swift
offlineEntitlements: .verifiedCache(.init())
```

The default verified-cache policy uses:

- Keychain service `com.macappfoundation.purchases.verified-entitlements`
- 7-day maximum offline window for shared non-consumable access
- 5-minute backwards-clock tolerance

## PurchaseManager state model

The manager exposes several independent state families.

### Product loading

`productLoadingState`:

- `.idle`
- `.loading`
- `.loaded`
- `.failed(PurchaseFailure)`

`products` contains the current sellable catalog.

### Live entitlement state

`entitlementState` represents what the current StoreKit entitlement refresh directly reports.

It is intentionally not the final offline authorization decision.

### Effective access state

`accessState` represents the final authorization result after combining StoreKit with the optional verified cache.

It is intentionally binary:

- `.inactive` — Free
- `.active(source:snapshot:)` — Pro

There is no checking or unresolved effective-access state. Live StoreKit diagnostics may still report `EntitlementState.checking`, but that does not put the app into a third authorization mode.

An active state records whether authorization came from:

- `.storeKit`
- `.verifiedCache`

### hasPro

`hasPro` is simply:

```swift
accessState.isActive
```

Apps should not maintain another Pro Boolean.

### Purchase activity

`activity` represents foreground commerce operations:

- `.idle`
- `.purchasing(productID:)`
- `.restoring`
- `.pending(productID:)`
- `.failed(PurchaseFailure)`

Convenience properties include `isBusy`, `isPurchasing`, `isRestoring`, `isPurchasePending`, and `pendingProductID`.

## Preparation and lifecycle

`prepare()` is safe to call repeatedly.

On first preparation it starts:

- transaction observation
- subscription-status observation

Every preparation then:

1. refreshes entitlements
2. loads products

`.managesPurchases(purchases)` calls preparation for the host view lifecycle and refreshes entitlements when the app becomes active.

Transaction updates and subscription-status updates also trigger entitlement refreshes automatically.

A transaction update matching a pending purchase clears that pending activity after entitlement refresh.

## Product loading

Catalog loading is separate from authorization.

A product-loading failure must not revoke or alter an already valid entitlement.

Normal `loadProducts()`:

- avoids duplicate loading when already loaded/loading unless forced
- retries according to `productLoadAttempts`
- preserves configured product order
- reports `.noProductsAvailable` when no usable products are returned

The paywall uses a stale-while-revalidate path:

- if no catalog exists, it loads normally
- if products are already present, it keeps them usable while refreshing metadata
- if that refresh fails, the existing catalog remains available

## Entitlement resolution

With offline persistence disabled, effective access follows live StoreKit entitlement state.

With verified caching enabled, resolution follows this model.

### 1. Live active entitlement wins

If current StoreKit entitlements contain a valid entitled product:

- access becomes active from StoreKit
- the verified cache is refreshed
- retry is not needed

### 2. Establish account context

For cached authorization MAF scopes data using:

- app bundle ID
- StoreKit environment
- `appTransactionID`

Context is obtained from verified entitlement records when possible.

If current records do not establish context, MAF asks the purchase service for verified account/app context.

If StoreKit cannot provide current context, MAF may use the last independently persisted verified context for that bundle and environment.

A paid cache from a different account is never selected merely because it exists.

### 3. Reconcile missing current entitlements

When current entitlement results do not contain an expected product, MAF may ask for the latest verified transaction for entitled product IDs.

A latest lookup can be:

- verified transaction
- not purchased
- unavailable

Verified latest transactions can recover paid access even when `currentEntitlements` is empty.

### 4. Free is the safe fallback

If MAF cannot produce trustworthy evidence that Pro should be granted, effective access is `.inactive` and the user is treated as Free.

This includes:

- no trustworthy account context
- no paid cache
- an expired cached subscription
- bounded shared access after its offline window
- suspicious clock rollback for time-bounded access

If the missing answer was caused by unavailable or incomplete StoreKit verification, retry may continue independently in the background.

This deliberately prefers a brief false-Free state over a persistent verification-limbo UI. Restore Purchases remains available as an explicit recovery path.

## Access and retry are separate

Authorization answers:

> What access should the app grant right now?

Retry answers:

> Should MAF ask StoreKit again because the verification result was incomplete or unavailable?

They are intentionally independent.

### Retry matrix

| Situation | Access now | Retry |
| --- | --- | --- |
| StoreKit confirms Pro | Pro | No |
| StoreKit confirms Free / not purchased | Free | No |
| No cache + verification unavailable | Free | Yes |
| No trustworthy account context | Free | Yes |
| Valid directly purchased Lifetime cache | Pro | No |
| Valid recurring cache within trusted validity | Pro | No |
| Expired/unsafe recurring cache + verification unavailable | Free | Yes |
| Shared entitlement past offline boundary + verification unavailable | Free | Yes |
| Account context cannot be established safely | Free | Yes |
| Explicit verified revocation/refund | Free | No |

### Retry schedule

The default retry schedule is:

```text
2 seconds
5 seconds
15 seconds
60 seconds
then every 5 minutes
```

Each retry runs a normal entitlement refresh.

Retry stops when the latest resolution says no retry is needed, including when:

- Pro is confirmed
- Free is confirmed
- valid cached authorization is sufficient
- the purchase service generation changes

Service replacement also cancels stale retry work.

## Offline entitlement persistence

MAF persists structured verified entitlement records in Keychain. It never stores a bare `hasPro = true` flag.

The cache records include identity and entitlement evidence such as:

- schema version
- bundle ID
- StoreKit environment
- `appTransactionID`
- verification timestamps
- last observation time
- product ID
- product kind
- ownership
- transaction/original transaction IDs
- expiration
- grace-period expiration
- revocation
- upgrade state
- subscription state

The last verified account identity is persisted separately from entitlement state. This includes verified Free accounts so that an offline relaunch does not accidentally fall back to another Apple Account's paid cache.

Corrupt or unreadable cache data never grants Pro.

Debug simulated purchases do not use the production verified entitlement cache.

## Product-specific offline rules

### Directly purchased Lifetime

A verified directly purchased non-consumable Lifetime entitlement is intended to remain usable offline.

Temporary StoreKit unavailability does not revoke it.

A missing latest transaction does not by itself destroy a previously verified directly purchased Lifetime cache.

Explicit verified revocation/refund does invalidate it.

### Auto-renewable subscriptions

Recurring access is time-bounded.

Cached recurring access is valid only while the verified subscription evidence remains active, including a verified Billing Grace Period.

Billing retry without an active/grace entitlement does not grant Pro merely because an old subscription transaction exists.

When the trusted recurring window has ended and StoreKit cannot currently resolve renewal state:

- access falls back to Free
- retry continues

### Family Sharing

Family-shared non-consumable access is not persisted indefinitely.

It uses the configured `sharedLifetimeMaxOfflineInterval`.

After that bounded window, live verification is required before continued authorization.

### Clock rollback

Time-bounded cached authorization tracks the last observed time.

If the wall clock moves backward beyond the configured tolerance, recurring/shared cached access is considered unsafe until StoreKit can confirm it.

Directly purchased Lifetime access is not converted into a time-limited entitlement by this rule.

### Upgraded and revoked records

Revoked records and upgraded-away records do not remain eligible entitlement evidence.

Explicit revocation wins over previously cached authorization.

## Active product helpers

`entitlementProducts` contains loaded products that:

- are in `entitledProductIDs`
- use supported Pro product types

`preferredEntitlementProduct` is the preferred product restricted to those entitlement-capable products.

`activeProduct` represents the best loaded product for the current effective active entitlement.

Selection priority:

1. Lifetime, when active
2. preferred active entitlement product
3. first active entitlement product

Lifetime intentionally wins plan display when both Lifetime and a recurring product are active.

`activeSubscriptionProduct` is separate. It returns an active recurring product even when Lifetime is the primary `activeProduct`, because a subscription may still need to be managed or cancelled.

## Purchasing

Call:

```swift
let outcome = await purchases.purchase(product)
```

A purchase does not start when another purchase/restore is busy or when a purchase is already pending.

The product must:

- be present in the active sellable `productIDs`
- be a supported Pro product

Unsupported/unavailable selections produce `.productUnavailable`.

### Outcomes

Success:

1. StoreKit returns success
2. MAF refreshes entitlements
3. activity returns to idle
4. the success outcome is returned

Pending:

- activity becomes `.pending(productID:)`
- the app remains pending until a matching transaction update arrives

User cancelled:

- activity returns to idle
- `.userCancelled` is returned

Failure:

- `activity` becomes `.failed(PurchaseFailure)`
- `purchase()` returns `nil`

The caller may use `clearActivity()` after presenting a failure.

## Restore Purchases

Call:

```swift
let outcome = await purchases.restorePurchases()
```

Restore:

1. syncs with the App Store
2. refreshes entitlements
3. evaluates effective access

Possible results:

- `.restored` when effective Pro access exists after refresh
- `.nothingToRestore` when no Pro access is found
- `.failed(PurchaseFailure)`

Concurrent restore calls coalesce into the same in-flight task.

Restore does not begin while a purchase is running or pending; it returns `.operationInProgress`.

An optional timeout can be supplied.

`cancelRestore()` stops waiting on the active restore without disturbing an unrelated purchase.

## Purchase failures

Stable failure codes include:

- `noProductsAvailable`
- `productUnavailable`
- `purchaseNotAllowed`
- `networkUnavailable`
- `verificationFailed`
- `storefrontUnavailable`
- `notEntitled`
- `operationInProgress`
- `system`
- `timeout`
- `userCancelled`
- `unknown`

StoreKit errors are mapped into these stable app-facing failures.

## ProPaywallView

`ProPaywallView` is MAF's native macOS purchase surface.

The host app supplies:

- title/subtitle
- feature copy
- purchase button copy
- highlighted product/badge
- Terms URL
- Privacy URL
- whether Redeem Code is shown
- completion/close callbacks
- window or sheet presentation

MAF supplies:

- StoreKit-backed products and prices
- trial/introductory-offer presentation
- product selection
- purchase flow
- restore flow
- offer-code redemption
- loading/error states
- entitlement refresh
- optional analytics

### Paywall appearance lifecycle

When presented, the paywall:

1. records `paywall_viewed` when analytics is available
2. refreshes product metadata using stale-while-revalidate behavior
3. refreshes entitlements
4. chooses a default plan when needed

Default plan selection uses this priority:

1. an already valid explicit selection
2. `highlightedProductID` when available
3. `preferredEntitlementProduct`
4. the first paywall product

Automatic default selection does not count as an explicit `paywall_plan_selected` analytics event.

### Product selection

Only loaded entitlement-capable products are shown as purchase choices.

Selection is disabled while a purchase/restore is busy or a purchase is pending.

### Purchase button

The paywall calls `PurchaseManager.purchase`.

On success:

- marks the commerce flow complete
- emits success analytics when available
- calls `onPurchased(product)`
- dismisses

On pending:

- remains open
- records pending state

On cancellation:

- remains open
- records cancellation

On failure:

- presents the stable failure message
- clears the manager's activity after capturing it

### Restore

The paywall exposes Restore Purchases.

A successful restore invokes `onRestored`.

Nothing-to-restore and failure states are surfaced without pretending a purchase exists.

### Redeem Code

When enabled, Redeem Code uses StoreKit's offer-code redemption presentation.

After successful redemption MAF refreshes entitlements.

### Closing

The host app may receive `onClose`.

A normal close without completing commerce records `paywall_closed` when analytics is available.

## Paywall analytics

Analytics is optional.

When the paywall is inside a hierarchy managed by `.managesAnalytics(analytics)`, MAF records bounded commerce funnel events.

If analytics is absent, commerce behaves identically and no analytics traffic occurs.

Events:

| Event | Dimension |
| --- | --- |
| `paywall_viewed` | none |
| `paywall_closed` | none |
| `paywall_plan_selected` | plan |
| `purchase_started` | plan |
| `purchase_succeeded` | plan |
| `purchase_pending` | plan |
| `purchase_cancelled` | plan |
| `purchase_failed` | plan + stable failure code |
| `restore_started` | none |
| `restore_succeeded` | none |
| `restore_nothing_to_restore` | none |
| `restore_failed` | stable failure code |
| `offer_code_opened` | none |
| `offer_code_succeeded` | none |
| `offer_code_failed` | stable failure code or unknown |

MAF does not send:

- prices
- transaction IDs
- receipts
- localized product names
- arbitrary StoreKit error text

Analytics is best effort and never controls purchase success, failure, timing, or entitlement state.

## Plan pane

`ProPlanPane` is the reusable Settings Plan surface.

It derives presentation directly from binary effective access:

| Effective state | Presentation |
| --- | --- |
| inactive | Free |
| active | Pro |

StoreKit verification can continue in the background without replacing the Plan UI with a checking state.

### Free

The pane shows the configured Free copy and Upgrade action.

### Pro

The pane shows Pro copy and the active plan label when available.

For recurring Pro access it can show View Plans.

If an active subscription exists, Manage Subscription is shown using the host-provided management URL.

### Restore

Restore Purchases is always available when no conflicting commerce operation is in progress.

The Plan pane calls `PurchaseManager.restorePurchases()` directly.

## ProPlanButton

`ProPlanButton` is intended for title bars and compact app headers.

Presentation:

- Free -> `Unlock Pro`
- Pro -> active plan label, such as `Pro Lifetime`, `Pro Monthly`, or `Pro Yearly`

The host app owns navigation:

- `onUpgrade` presents the purchase flow
- `onManagePlan` routes to Plan settings or another management surface

## Premium gating

For simple checks, `hasPro` is enough.

Reusable gating APIs use the same binary effective access state. If Pro is not currently proven, a Pro-only surface behaves as Free while background verification/retry continues independently.

`PremiumAccessPolicy` defaults to preserving access to existing user-created content after Pro expires:

```swift
PremiumAccessPolicy(
    existingContentRemainsAccessible: true
)
```

This allows apps to gate new creation or premium editing without making existing user data inaccessible merely because an entitlement ended.

The host app may choose a stricter policy when appropriate.

## Debug simulator

The in-process purchase simulator is Debug-only.

Release builds use live StoreKit even if simulation was requested by debug-oriented app code.

Developer Tools can modify simulated:

- products
- product ordering
- entitlement mapping
- preferred plan
- Free/Pro state
- recurring/lifetime periods
- introductory offers
- purchase outcomes
- restore failures
- catalog failures
- operation latency

Simulator edits do not mutate the production `PurchaseConfiguration`.

Simulated purchases are isolated from the production verified entitlement cache.

## Expected behavior matrix

| Situation | Expected result |
| --- | --- |
| Current verified paid entitlement | Pro from StoreKit |
| Current verified Free state | Free |
| Cacheless launch with known account + latest verified paid purchase | Pro and persist verified evidence |
| Cacheless launch with known account + not purchased | Free, no retry |
| Cacheless launch with known account + verification unavailable | Free, retry |
| Cacheless launch with no trustworthy account context | Free, retry |
| Valid directly purchased Lifetime cache + StoreKit unavailable | Pro from cache |
| Valid recurring cache + StoreKit unavailable | Pro until verified validity/grace boundary |
| Recurring cache expired + StoreKit unavailable | Free, retry |
| Billing retry with no active/grace entitlement | Free |
| Family-shared Lifetime within bounded offline window | Pro from cache |
| Family-shared Lifetime outside bounded window + unavailable verification | Free, retry |
| Clock rollback beyond tolerance for time-bounded cache | Free, retry |
| Explicit verified revocation/refund | Revoked entitlement is invalidated; Free if no other entitlement remains |
| Paid Account A cache, current verified Free Account B | Free for B; A cache is not reused |
| Offline relaunch after verified Account B context | Uses B context only |
| Product catalog fails while paid cache remains valid | Pro remains Pro |
| Historical entitlement SKU no longer sold | Still allowed to grant Pro |
| Lifetime + subscription active | Lifetime is primary plan display; subscription remains manageable |
| Corrupt local entitlement cache | Never grants Pro |
| Purchase pending | Pending until transaction update resolves it |
| Restore while purchase/pending | Operation-in-progress failure |

## Host-app responsibilities

MAF does not decide:

- when or where the paywall window opens
- app-specific pricing strategy
- product identifiers
- App Store Connect configuration
- Terms and Privacy destinations
- product/benefit marketing copy
- whether an app uses offline persistence
- which app features require Pro
- whether existing content stays accessible after expiry when overriding the default policy
- app-specific analytics beyond MAF's bounded paywall events

The consuming app should keep one shared `PurchaseManager` and route all commerce surfaces through it rather than maintaining parallel StoreKit state.

## Related documentation

- `OfflineEntitlementPersistenceProposal.md` — design rationale and risk analysis for verified offline persistence
- `Analytics.md` — analytics client and automatic paywall events
- `Settings.md` — Settings shell and Plan-pane composition
- `DeveloperTools.md` — Debug commerce simulation and diagnostics
