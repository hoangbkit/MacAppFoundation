# Changelog

All notable changes to MacAppFoundation will be documented in this file.

## 1.2.0 - 2026-09-24

### Fixed

- Preserve Pro access during StoreKit Billing Grace Period by treating `Transaction.currentEntitlements` as authoritative instead of independently expiring returned transactions.
- Keep Lifetime as the primary displayed plan when Lifetime and a recurring subscription are both active.
- Keep subscription management available when a recurring subscription remains active alongside Lifetime access.
- Prevent duplicate purchase attempts while a StoreKit purchase is pending approval.
- Keep unrelated transaction updates from clearing the pending state of another product.
- Limit StoreKit transaction observation to products that actually grant Pro, leaving non-Pro catalog transactions for their owning subsystem.

### Changed

- Added a separate active recurring-subscription lookup so plan display and subscription-management state are represented independently.
- Clarified the `PurchaseServing.currentEntitlements()` contract: returned records are already considered current by the backing store.
- Transaction update streams now identify the updated product so pending purchases are resolved only by their matching StoreKit transaction.
