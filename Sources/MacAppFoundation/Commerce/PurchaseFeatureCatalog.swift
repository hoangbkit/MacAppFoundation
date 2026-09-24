import Foundation

public extension PurchaseManager {
    /// Registered capabilities used by premium purchase surfaces.
    var features: [PurchaseFeature] {
        configuration.features
    }

    /// The loaded product currently best representing the active entitlement.
    /// Permanent lifetime access wins over recurring products when both remain active.
    var activeProduct: StoreProduct? {
        guard case .active(let snapshot) = entitlementState else {
            return nil
        }

        let activeProducts = entitlementProducts.filter {
            snapshot.activeProductIDs.contains($0.id)
        }

        if let lifetime = activeProducts.first(where: \.isLifetime) {
            return lifetime
        }

        if let preferredProductID = preferredEntitlementProduct?.id,
           let preferred = activeProducts.first(where: { $0.id == preferredProductID }) {
            return preferred
        }

        return activeProducts.first
    }

    /// The active recurring entitlement, even when lifetime access is the primary active product.
    ///
    /// This is intentionally separate from `activeProduct`: lifetime access wins for plan
    /// display, but an existing subscription may still need to be managed or cancelled.
    var activeSubscriptionProduct: StoreProduct? {
        guard case .active(let snapshot) = entitlementState else {
            return nil
        }

        return entitlementProducts.first {
            snapshot.activeProductIDs.contains($0.id) && $0.isRecurring
        }
    }
}
