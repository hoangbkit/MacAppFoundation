import Foundation

public extension PurchaseManager {
    /// Registered capabilities used by premium purchase surfaces.
    var features: [PurchaseFeature] {
        configuration.features
    }

    /// The loaded product currently responsible for the active entitlement, when available.
    var activeProduct: StoreProduct? {
        guard case .active(let snapshot) = entitlementState else {
            return nil
        }

        return products.first { snapshot.activeProductIDs.contains($0.id) }
    }
}
