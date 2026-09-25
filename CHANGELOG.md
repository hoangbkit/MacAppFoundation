# Changelog

All notable changes to MacAppFoundation will be documented in this file.

## Unreleased

### Added

- `.managesAnalytics` now shares its optional app-scoped analytics client with MacAppFoundation-owned descendant views.
- `ProPaywallView` automatically records bounded paywall, purchase, restore, and offer-code funnel events when analytics is available, while remaining fully functional and silent when analytics is not configured.


## 1.2.0 - 2026-09-24

### Fixed

- Preserve Pro access during StoreKit Billing Grace Period by treating `Transaction.currentEntitlements` as authoritative instead of independently expiring returned transactions.
- Keep Lifetime as the primary displayed plan when Lifetime and a recurring subscription are both active.
- Keep subscription management available when a recurring subscription remains active alongside Lifetime access.
- Prevent duplicate purchase attempts while a StoreKit purchase is pending approval.
- Keep unrelated transaction updates from clearing the pending state of another product.
- Limit StoreKit transaction observation to products that actually grant Pro, leaving non-Pro catalog transactions for their owning subsystem.
- Refresh Pro entitlement state when StoreKit subscription status changes, so grace-period, billing-retry, expiration, and revocation transitions are reflected while the app remains open.

### Changed

- Added a separate active recurring-subscription lookup so plan display and subscription-management state are represented independently.
- Clarified the `PurchaseServing.currentEntitlements()` contract: returned records are already considered current by the backing store.
- Transaction update streams now identify the updated product so pending purchases are resolved only by their matching StoreKit transaction.
- Pro paywalls now refresh StoreKit product metadata and introductory-offer eligibility on presentation while keeping cached plans visible if the refresh fails.
- Pro paywalls now dismiss their current presentation automatically after a successful purchase or restore, while still invoking the optional callbacks first.
- Introductory-offer copy is less repetitive by leaving renewal policy to the shared legal disclosure below the purchase button.
- Added `MacAppFullSizeWindow`, a reusable scene wrapper for the hidden-titlebar, full-size-content window chrome used by the demo paywall.
- The demo Settings scene now uses a native SwiftUI `Settings` window with a top `TabView`, while reusing MAF's Appearance and Plan views.
- The reusable Plan pane now lets active subscribers reopen available plans, keeps App Store subscription management available when relevant, and exposes Restore Purchases without changing the existing plan-card design.
- The compact title-bar ProPlanButton now supports a configurable height while preserving its existing 24pt default.
- Analytics automatic uploads now run off the tracking critical path, serialize network uploads, and merge completion into the latest local state so a slow or unavailable server cannot overwrite events recorded while a request is in flight.
