# Changelog

All notable changes to MacAppFoundation will be documented in this file.

## 1.2.0 - 2026-09-24

### Fixed

- Preserve Pro access during StoreKit Billing Grace Period by treating `Transaction.currentEntitlements` as authoritative instead of independently expiring returned transactions.
- Keep Lifetime as the primary displayed plan when Lifetime and a recurring subscription are both active.
- Keep subscription management available when a recurring subscription remains active alongside Lifetime access.

### Changed

- Added a separate active recurring-subscription lookup so plan display and subscription-management state are represented independently.
- Clarified the `PurchaseServing.currentEntitlements()` contract: returned records are already considered current by the backing store.
