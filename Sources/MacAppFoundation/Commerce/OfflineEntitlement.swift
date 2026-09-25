import Foundation
import Security

/// Controls whether PurchaseManager may preserve previously verified entitlements
/// for offline use between launches.
public enum OfflineEntitlementPolicy: Sendable, Equatable {
    case disabled
    case verifiedCache(VerifiedEntitlementCachePolicy)

    var verifiedCachePolicy: VerifiedEntitlementCachePolicy? {
        guard case .verifiedCache(let policy) = self else { return nil }
        return policy
    }
}

/// Policy for the opt-in verified entitlement cache.
public struct VerifiedEntitlementCachePolicy: Sendable, Equatable {
    /// Keychain service used for persisted entitlement snapshots.
    public let keychainService: String

    /// Maximum offline lifetime for a non-consumable entitlement that is not
    /// directly purchased by the current account, such as Family Sharing.
    public let sharedLifetimeMaxOfflineInterval: TimeInterval

    /// Allowed backwards wall-clock movement before recurring cached access is
    /// considered unsafe and requires StoreKit confirmation.
    public let clockRollbackTolerance: TimeInterval

    public init(
        keychainService: String = "com.macappfoundation.purchases.verified-entitlements",
        sharedLifetimeMaxOfflineInterval: TimeInterval = 7 * 24 * 60 * 60,
        clockRollbackTolerance: TimeInterval = 5 * 60
    ) {
        self.keychainService = keychainService
        self.sharedLifetimeMaxOfflineInterval = max(0, sharedLifetimeMaxOfflineInterval)
        self.clockRollbackTolerance = max(0, clockRollbackTolerance)
    }
}

public enum PurchaseAccessSource: String, Sendable, Equatable {
    case storeKit
    case verifiedCache
}

/// Effective authorization state after combining live StoreKit state with an
/// optional previously verified offline cache.
public enum PurchaseAccessState: Sendable, Equatable {
    case checking
    case unresolved
    case inactive
    case active(source: PurchaseAccessSource, snapshot: EntitlementSnapshot)

    public var isActive: Bool {
        if case .active = self { return true }
        return false
    }

    public var snapshot: EntitlementSnapshot? {
        guard case .active(_, let snapshot) = self else { return nil }
        return snapshot
    }

    public var source: PurchaseAccessSource? {
        guard case .active(let source, _) = self else { return nil }
        return source
    }
}

public enum EntitlementProductKind: String, Codable, Sendable, Equatable {
    case autoRenewable
    case nonConsumable
    case unsupported
    case unknown
}

public enum EntitlementOwnership: String, Codable, Sendable, Equatable {
    case purchased
    case familyShared
    case other
    case unknown
}

public enum EntitlementSubscriptionState: String, Codable, Sendable, Equatable {
    case subscribed
    case inGracePeriod
    case inBillingRetryPeriod
    case expired
    case revoked
    case unknown

    var isEntitled: Bool {
        self == .subscribed || self == .inGracePeriod
    }

    var isExplicitlyInactive: Bool {
        self == .inBillingRetryPeriod || self == .expired || self == .revoked
    }
}

public enum PurchaseStoreEnvironment: String, Codable, Sendable, Equatable {
    case production
    case sandbox
    case xcode
    case unknown
}

struct PurchaseEntitlementContext: Sendable, Equatable {
    let bundleID: String
    let environment: PurchaseStoreEnvironment
    let appTransactionID: String

    var storageAccount: String {
        "\(bundleID)|\(environment.rawValue)|\(appTransactionID)"
    }
}

enum LatestEntitlementLookup: Sendable, Equatable {
    case verified(EntitlementRecord)
    case notPurchased
    case unavailable
}

struct PersistedEntitlementRecord: Codable, Sendable, Equatable {
    let productID: String
    let productKind: EntitlementProductKind
    let ownership: EntitlementOwnership
    let transactionID: String?
    let originalTransactionID: String?
    let expirationDate: Date?
    let gracePeriodExpirationDate: Date?
    let revocationDate: Date?
    let isUpgraded: Bool
    let subscriptionState: EntitlementSubscriptionState?
    let verifiedAt: Date

    init(_ record: EntitlementRecord, verifiedAt: Date) {
        productID = record.productID
        productKind = record.productKind
        ownership = record.ownership
        transactionID = record.transactionID
        originalTransactionID = record.originalTransactionID
        expirationDate = record.expirationDate
        gracePeriodExpirationDate = record.gracePeriodExpirationDate
        revocationDate = record.revocationDate
        isUpgraded = record.isUpgraded
        subscriptionState = record.subscriptionState
        self.verifiedAt = verifiedAt
    }
}

struct VerifiedEntitlementCache: Codable, Sendable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let bundleID: String
    let environment: PurchaseStoreEnvironment
    let appTransactionID: String
    let verifiedAt: Date
    let lastObservedAt: Date
    let entitlements: [PersistedEntitlementRecord]

    init(
        context: PurchaseEntitlementContext,
        verifiedAt: Date,
        lastObservedAt: Date? = nil,
        records: [EntitlementRecord],
        entitledProductIDs: Set<String>
    ) {
        schemaVersion = Self.currentSchemaVersion
        bundleID = context.bundleID
        environment = context.environment
        appTransactionID = context.appTransactionID
        self.verifiedAt = verifiedAt
        self.lastObservedAt = lastObservedAt ?? verifiedAt
        entitlements = records
            .filter {
                entitledProductIDs.contains($0.productID)
                    && $0.revocationDate == nil
                    && !$0.isUpgraded
                    && ($0.productKind == .autoRenewable || $0.productKind == .nonConsumable)
            }
            .map { PersistedEntitlementRecord($0, verifiedAt: verifiedAt) }
    }

    init(
        context: PurchaseEntitlementContext,
        verifiedAt: Date,
        entitlements: [PersistedEntitlementRecord]
    ) {
        schemaVersion = Self.currentSchemaVersion
        bundleID = context.bundleID
        environment = context.environment
        appTransactionID = context.appTransactionID
        self.verifiedAt = verifiedAt
        lastObservedAt = verifiedAt
        self.entitlements = entitlements
    }

    func matches(_ context: PurchaseEntitlementContext) -> Bool {
        schemaVersion == Self.currentSchemaVersion
            && bundleID == context.bundleID
            && environment == context.environment
            && appTransactionID == context.appTransactionID
    }

    func replacingEntitlements(
        _ entitlements: [PersistedEntitlementRecord],
        verifiedAt date: Date,
        observedAt: Date
    ) -> VerifiedEntitlementCache {
        VerifiedEntitlementCache(
            schemaVersion: schemaVersion,
            bundleID: bundleID,
            environment: environment,
            appTransactionID: appTransactionID,
            verifiedAt: max(verifiedAt, date),
            lastObservedAt: max(lastObservedAt, observedAt),
            entitlements: entitlements
        )
    }

    func touched(at date: Date) -> VerifiedEntitlementCache {
        VerifiedEntitlementCache(
            schemaVersion: schemaVersion,
            bundleID: bundleID,
            environment: environment,
            appTransactionID: appTransactionID,
            verifiedAt: verifiedAt,
            lastObservedAt: max(lastObservedAt, date),
            entitlements: entitlements
        )
    }

    private init(
        schemaVersion: Int,
        bundleID: String,
        environment: PurchaseStoreEnvironment,
        appTransactionID: String,
        verifiedAt: Date,
        lastObservedAt: Date,
        entitlements: [PersistedEntitlementRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.bundleID = bundleID
        self.environment = environment
        self.appTransactionID = appTransactionID
        self.verifiedAt = verifiedAt
        self.lastObservedAt = lastObservedAt
        self.entitlements = entitlements
    }
}

enum OfflineEntitlementResolver {
    static func accessState(
        cache: VerifiedEntitlementCache,
        context: PurchaseEntitlementContext,
        policy: VerifiedEntitlementCachePolicy,
        now: Date
    ) -> PurchaseAccessState {
        guard cache.matches(context) else {
            return .unresolved
        }

        let clockRolledBack =
            now.addingTimeInterval(policy.clockRollbackTolerance) < cache.lastObservedAt

        let usable = cache.entitlements.filter {
            isUsableOffline(
                $0,
                cache: cache,
                policy: policy,
                now: now,
                clockRolledBack: clockRolledBack
            )
        }

        guard !usable.isEmpty else {
            return .unresolved
        }

        let hasPermanentEntitlement = usable.contains {
            $0.productKind == .nonConsumable && $0.ownership == .purchased
        }
        let latestExpirationDate: Date?
        if hasPermanentEntitlement {
            latestExpirationDate = nil
        } else {
            latestExpirationDate = usable.compactMap {
                offlineExpiration(
                    $0,
                    cache: cache,
                    policy: policy
                )
            }.max()
        }

        return .active(
            source: .verifiedCache,
            snapshot: EntitlementSnapshot(
                activeProductIDs: Set(usable.map(\.productID)),
                latestExpirationDate: latestExpirationDate
            )
        )
    }

    static func cachedRecordIsStillUsable(
        _ record: PersistedEntitlementRecord,
        cache: VerifiedEntitlementCache,
        policy: VerifiedEntitlementCachePolicy,
        now: Date
    ) -> Bool {
        let clockRolledBack =
            now.addingTimeInterval(policy.clockRollbackTolerance) < cache.lastObservedAt
        return isUsableOffline(
            record,
            cache: cache,
            policy: policy,
            now: now,
            clockRolledBack: clockRolledBack
        )
    }

    private static func isUsableOffline(
        _ record: PersistedEntitlementRecord,
        cache: VerifiedEntitlementCache,
        policy: VerifiedEntitlementCachePolicy,
        now: Date,
        clockRolledBack: Bool
    ) -> Bool {
        guard record.revocationDate == nil, !record.isUpgraded else {
            return false
        }

        switch record.productKind {
        case .nonConsumable:
            if record.ownership == .purchased {
                return true
            }
            guard let expiration = offlineExpiration(
                record,
                cache: cache,
                policy: policy
            ) else {
                return false
            }
            return now <= expiration

        case .autoRenewable:
            guard !clockRolledBack else {
                return false
            }
            if record.subscriptionState?.isExplicitlyInactive == true {
                return false
            }
            guard let expiration = offlineExpiration(
                record,
                cache: cache,
                policy: policy
            ) else {
                return false
            }
            return now <= expiration

        case .unsupported, .unknown:
            return false
        }
    }

    private static func offlineExpiration(
        _ record: PersistedEntitlementRecord,
        cache: VerifiedEntitlementCache,
        policy: VerifiedEntitlementCachePolicy
    ) -> Date? {
        switch record.productKind {
        case .nonConsumable:
            guard record.ownership != .purchased else { return nil }
            return record.verifiedAt.addingTimeInterval(
                policy.sharedLifetimeMaxOfflineInterval
            )
        case .autoRenewable:
            return record.gracePeriodExpirationDate ?? record.expirationDate
        case .unsupported, .unknown:
            return nil
        }
    }
}

@MainActor
protocol VerifiedEntitlementStoring: AnyObject {
    func data(for account: String) throws -> Data?
    func set(_ data: Data, for account: String) throws
    func removeData(for account: String) throws
}

enum VerifiedEntitlementStoreError: Error {
    case unavailable
}

@MainActor
final class KeychainVerifiedEntitlementStore: VerifiedEntitlementStoring {
    private let service: String

    init(service: String) {
        self.service = service
    }

    func data(for account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw VerifiedEntitlementStoreError.unavailable
        }
        return data
    }

    func set(_ data: Data, for account: String) throws {
        let lookup: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(
            lookup as CFDictionary,
            attributes as CFDictionary
        )

        if updateStatus == errSecItemNotFound {
            var insert = lookup
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw VerifiedEntitlementStoreError.unavailable
            }
        } else if updateStatus != errSecSuccess {
            throw VerifiedEntitlementStoreError.unavailable
        }
    }

    func removeData(for account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw VerifiedEntitlementStoreError.unavailable
        }
    }
}
