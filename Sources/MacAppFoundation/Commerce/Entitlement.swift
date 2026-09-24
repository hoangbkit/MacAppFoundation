import Foundation

public struct EntitlementRecord: Sendable, Equatable {
    public let productID: String
    public let purchaseDate: Date
    public let expirationDate: Date?
    public let revocationDate: Date?
    public let isUpgraded: Bool

    public init(
        productID: String,
        purchaseDate: Date = .now,
        expirationDate: Date? = nil,
        revocationDate: Date? = nil,
        isUpgraded: Bool = false
    ) {
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.revocationDate = revocationDate
        self.isUpgraded = isUpgraded
    }

    public func isActive(at date: Date = .now) -> Bool {
        guard revocationDate == nil, !isUpgraded else {
            return false
        }

        guard let expirationDate else {
            return true
        }

        return expirationDate > date
    }
}

public struct EntitlementSnapshot: Sendable, Equatable {
    public let activeProductIDs: Set<String>

    /// Latest known expiry for an entirely time-limited entitlement set.
    /// `nil` also means at least one active entitlement is permanent.
    public let latestExpirationDate: Date?

    public init(activeProductIDs: Set<String>, latestExpirationDate: Date?) {
        self.activeProductIDs = activeProductIDs
        self.latestExpirationDate = latestExpirationDate
    }
}

public enum EntitlementState: Sendable, Equatable {
    case checking
    case inactive
    case active(EntitlementSnapshot)

    public var isActive: Bool {
        if case .active = self {
            return true
        }
        return false
    }
}

public enum EntitlementEvaluator {
    public static func evaluate(
        _ records: [EntitlementRecord],
        entitledProductIDs: Set<String>,
        at date: Date = .now
    ) -> EntitlementState {
        let activeRecords = records.filter { record in
            entitledProductIDs.contains(record.productID) && record.isActive(at: date)
        }
        return state(from: activeRecords)
    }

    /// Evaluates records that the purchase service already considers current entitlements.
    ///
    /// Live StoreKit uses `Transaction.currentEntitlements`, which is authoritative about
    /// whether the customer is currently entitled. In particular, MacAppFoundation must not
    /// reject a StoreKit current entitlement only because the transaction's billing-period
    /// expiration date has passed; that can revoke access during Billing Grace Period.
    static func evaluateCurrentEntitlements(
        _ records: [EntitlementRecord],
        entitledProductIDs: Set<String>
    ) -> EntitlementState {
        let activeRecords = records.filter { record in
            entitledProductIDs.contains(record.productID)
        }
        return state(from: activeRecords)
    }

    private static func state(from activeRecords: [EntitlementRecord]) -> EntitlementState {
        guard !activeRecords.isEmpty else {
            return .inactive
        }

        let hasPermanentEntitlement = activeRecords.contains { $0.expirationDate == nil }
        let snapshot = EntitlementSnapshot(
            activeProductIDs: Set(activeRecords.map(\.productID)),
            latestExpirationDate: hasPermanentEntitlement
                ? nil
                : activeRecords.compactMap(\.expirationDate).max()
        )
        return .active(snapshot)
    }
}
