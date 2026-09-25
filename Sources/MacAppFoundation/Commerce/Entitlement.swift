import Foundation

public struct EntitlementRecord: Sendable, Equatable {
    public let productID: String
    public let purchaseDate: Date
    public let expirationDate: Date?
    public let gracePeriodExpirationDate: Date?
    public let revocationDate: Date?
    public let isUpgraded: Bool
    public let productKind: EntitlementProductKind
    public let ownership: EntitlementOwnership
    public let transactionID: String?
    public let originalTransactionID: String?
    public let appTransactionID: String?
    public let environment: PurchaseStoreEnvironment
    public let subscriptionState: EntitlementSubscriptionState?

    public init(
        productID: String,
        purchaseDate: Date = .now,
        expirationDate: Date? = nil,
        gracePeriodExpirationDate: Date? = nil,
        revocationDate: Date? = nil,
        isUpgraded: Bool = false,
        productKind: EntitlementProductKind = .unknown,
        ownership: EntitlementOwnership = .unknown,
        transactionID: String? = nil,
        originalTransactionID: String? = nil,
        appTransactionID: String? = nil,
        environment: PurchaseStoreEnvironment = .unknown,
        subscriptionState: EntitlementSubscriptionState? = nil
    ) {
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.gracePeriodExpirationDate = gracePeriodExpirationDate
        self.revocationDate = revocationDate
        self.isUpgraded = isUpgraded
        self.productKind = productKind
        self.ownership = ownership
        self.transactionID = transactionID
        self.originalTransactionID = originalTransactionID
        self.appTransactionID = appTransactionID
        self.environment = environment
        self.subscriptionState = subscriptionState
    }

    public func isActive(at date: Date = .now) -> Bool {
        guard revocationDate == nil, !isUpgraded else {
            return false
        }

        if productKind == .autoRenewable {
            if subscriptionState?.isExplicitlyInactive == true {
                return false
            }
            guard let effectiveExpiration = gracePeriodExpirationDate ?? expirationDate else {
                return false
            }
            return effectiveExpiration > date
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
                && record.revocationDate == nil
                && !record.isUpgraded
                && record.subscriptionState?.isExplicitlyInactive != true
        }
        return state(from: activeRecords)
    }

    static func snapshot(from records: [EntitlementRecord]) -> EntitlementSnapshot? {
        state(from: records).snapshot
    }

    private static func state(from activeRecords: [EntitlementRecord]) -> EntitlementState {
        guard !activeRecords.isEmpty else {
            return .inactive
        }

        let hasPermanentEntitlement = activeRecords.contains {
            $0.productKind == .nonConsumable
                ? $0.ownership == .purchased
                : $0.expirationDate == nil && $0.gracePeriodExpirationDate == nil
        }
        let snapshot = EntitlementSnapshot(
            activeProductIDs: Set(activeRecords.map(\.productID)),
            latestExpirationDate: hasPermanentEntitlement
                ? nil
                : activeRecords.compactMap {
                    $0.gracePeriodExpirationDate ?? $0.expirationDate
                }.max()
        )
        return .active(snapshot)
    }
}

private extension EntitlementState {
    var snapshot: EntitlementSnapshot? {
        guard case .active(let snapshot) = self else { return nil }
        return snapshot
    }
}
