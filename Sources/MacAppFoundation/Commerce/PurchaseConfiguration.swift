import Foundation

/// Configuration shared by the StoreKit engine and reusable purchase UI.
public struct PurchaseConfiguration: Sendable, Equatable {
    /// Product identifiers in the order they should be presented for sale.
    public let productIDs: [String]

    /// Product identifiers that grant the app entitlement.
    ///
    /// This set may include historical products that are no longer merchandised
    /// through `productIDs`.
    public let entitledProductIDs: Set<String>

    /// Product selected by default when the catalog is loaded.
    public let preferredProductID: String?

    /// App capabilities shown by paywalls and Pro surfaces.
    public let features: [PurchaseFeature]

    /// Number of catalog loading attempts before surfacing an error.
    public let productLoadAttempts: Int

    /// Optional offline entitlement continuity policy.
    ///
    /// Disabled by default so existing consumers retain their current live-only
    /// StoreKit authorization semantics until they explicitly opt in.
    public let offlineEntitlements: OfflineEntitlementPolicy

    public init(
        productIDs: [String],
        entitledProductIDs: Set<String>? = nil,
        preferredProductID: String? = nil,
        features: [PurchaseFeature] = [],
        productLoadAttempts: Int = 3,
        offlineEntitlements: OfflineEntitlementPolicy = .disabled
    ) {
        let normalizedProductIDs = Self.uniqueNonEmptyValues(productIDs)
        let managedProductIDs = Set(normalizedProductIDs)
        let normalizedEntitledIDs = Set(
            (entitledProductIDs ?? managedProductIDs)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )

        self.productIDs = normalizedProductIDs
        self.entitledProductIDs = normalizedEntitledIDs
        self.preferredProductID = preferredProductID.flatMap { candidate in
            let normalized = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalizedProductIDs.contains(normalized) ? normalized : nil
        }
        self.features = Self.uniqueFeatures(features)
        self.productLoadAttempts = max(1, productLoadAttempts)
        self.offlineEntitlements = offlineEntitlements
    }

    private static func uniqueNonEmptyValues(_ values: [String]) -> [String] {
        var seen = Set<String>()

        return values.compactMap { value in
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else {
                return nil
            }
            return normalized
        }
    }

    private static func uniqueFeatures(_ features: [PurchaseFeature]) -> [PurchaseFeature] {
        var seen = Set<String>()

        return features.filter { feature in
            !feature.id.isEmpty && seen.insert(feature.id).inserted
        }
    }
}
