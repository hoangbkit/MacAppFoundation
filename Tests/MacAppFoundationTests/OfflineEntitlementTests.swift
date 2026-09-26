import XCTest
@testable import MacAppFoundation

@MainActor
final class OfflineEntitlementTests: XCTestCase {
    func testVerifiedLifetimeSurvivesOfflineRelaunch() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = InMemoryEntitlementStore()
        let context = Self.context(account: "account-a")
        let record = Self.lifetimeRecord(context: context)

        let onlineService = OfflineTestPurchaseService(
            context: context,
            entitlements: [record],
            products: [Self.lifetime]
        )
        let onlineManager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.lifetime.id]),
            service: onlineService,
            entitlementStore: store,
            now: { now }
        )

        await onlineManager.prepare()

        XCTAssertTrue(onlineManager.hasPro)
        XCTAssertEqual(onlineManager.accessState.source, .storeKit)

        let offlineService = OfflineTestPurchaseService(
            context: context,
            entitlements: [],
            products: [Self.lifetime],
            defaultLatestLookup: .unavailable
        )
        let offlineManager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.lifetime.id]),
            service: offlineService,
            entitlementStore: store,
            now: { now.addingTimeInterval(60) }
        )

        XCTAssertFalse(offlineManager.hasPro)
        XCTAssertEqual(offlineManager.accessState, .inactive)

        await offlineManager.prepare()

        XCTAssertEqual(offlineManager.entitlementState, .inactive)
        XCTAssertTrue(offlineManager.hasPro)
        XCTAssertEqual(offlineManager.accessState.source, .verifiedCache)
    }

    func testVerifiedSubscriptionSurvivesOfflineWithinKnownPeriod() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let expiration = now.addingTimeInterval(3_600)
        let store = InMemoryEntitlementStore()
        let context = Self.context(account: "account-a")
        let record = Self.subscriptionRecord(
            context: context,
            expirationDate: expiration,
            state: .subscribed
        )

        let onlineManager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.monthly.id]),
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [record],
                products: [Self.monthly]
            ),
            entitlementStore: store,
            now: { now }
        )
        await onlineManager.prepare()

        let offlineManager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.monthly.id]),
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [],
                products: [Self.monthly],
                defaultLatestLookup: .unavailable
            ),
            entitlementStore: store,
            now: { now.addingTimeInterval(1_800) }
        )

        XCTAssertFalse(offlineManager.hasPro)
        XCTAssertEqual(offlineManager.accessState, .inactive)

        await offlineManager.prepare()

        XCTAssertTrue(offlineManager.hasPro)
        XCTAssertEqual(offlineManager.accessState.source, .verifiedCache)
        XCTAssertEqual(offlineManager.entitlementState, .inactive)
    }

    func testExpiredCachedSubscriptionFallsBackToFreeOffline() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = InMemoryEntitlementStore()
        let context = Self.context(account: "account-a")
        let record = Self.subscriptionRecord(
            context: context,
            expirationDate: now.addingTimeInterval(600),
            state: .subscribed
        )

        let onlineManager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.monthly.id]),
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [record],
                products: [Self.monthly]
            ),
            entitlementStore: store,
            now: { now }
        )
        await onlineManager.prepare()

        let offlineManager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.monthly.id]),
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [],
                products: [Self.monthly],
                defaultLatestLookup: .unavailable
            ),
            entitlementStore: store,
            now: { now.addingTimeInterval(1_200) }
        )

        XCTAssertFalse(offlineManager.hasPro)
        XCTAssertEqual(offlineManager.accessState, .inactive)

        await offlineManager.prepare()

        XCTAssertFalse(offlineManager.hasPro)
        XCTAssertEqual(offlineManager.accessState, .inactive)
    }

    func testClockRollbackBlocksRecurringCacheButNotLifetime() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let rolledBack = now.addingTimeInterval(-3_600)
        let context = Self.context(account: "account-a")

        let subscriptionStore = InMemoryEntitlementStore()
        let subscriptionManager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.monthly.id]),
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [
                    Self.subscriptionRecord(
                        context: context,
                        expirationDate: now.addingTimeInterval(86_400),
                        state: .subscribed
                    )
                ],
                products: [Self.monthly]
            ),
            entitlementStore: subscriptionStore,
            now: { now }
        )
        await subscriptionManager.prepare()

        let rolledBackSubscription = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.monthly.id]),
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [],
                products: [Self.monthly],
                defaultLatestLookup: .unavailable
            ),
            entitlementStore: subscriptionStore,
            now: { rolledBack }
        )

        XCTAssertFalse(rolledBackSubscription.hasPro)
        XCTAssertEqual(rolledBackSubscription.accessState, .inactive)
        await rolledBackSubscription.prepare()
        XCTAssertEqual(rolledBackSubscription.accessState, .inactive)

        let lifetimeStore = InMemoryEntitlementStore()
        let lifetimeManager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.lifetime.id]),
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [Self.lifetimeRecord(context: context)],
                products: [Self.lifetime]
            ),
            entitlementStore: lifetimeStore,
            now: { now }
        )
        await lifetimeManager.prepare()

        let rolledBackLifetime = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.lifetime.id]),
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [],
                products: [Self.lifetime],
                defaultLatestLookup: .unavailable
            ),
            entitlementStore: lifetimeStore,
            now: { rolledBack }
        )

        XCTAssertFalse(rolledBackLifetime.hasPro)
        XCTAssertEqual(rolledBackLifetime.accessState, .inactive)
        await rolledBackLifetime.prepare()
        XCTAssertTrue(rolledBackLifetime.hasPro)
        XCTAssertEqual(rolledBackLifetime.accessState.source, .verifiedCache)
    }

    func testForwardThenBackwardClockCannotReviveExpiredSubscriptionCache() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let expiration = now.addingTimeInterval(86_400)
        let store = InMemoryEntitlementStore()
        let context = Self.context(account: "account-a")
        let configuration = Self.configuration(productIDs: [Self.monthly.id])

        let onlineManager = PurchaseManager(
            configuration: configuration,
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [
                    Self.subscriptionRecord(
                        context: context,
                        expirationDate: expiration,
                        state: .subscribed
                    )
                ],
                products: [Self.monthly]
            ),
            entitlementStore: store,
            now: { now }
        )
        await onlineManager.prepare()

        let afterExpiry = PurchaseManager(
            configuration: configuration,
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [],
                products: [Self.monthly],
                defaultLatestLookup: .unavailable
            ),
            entitlementStore: store,
            now: { now.addingTimeInterval(2 * 86_400) }
        )
        await afterExpiry.prepare()
        XCTAssertEqual(afterExpiry.accessState, .inactive)

        let rolledBackBeforeExpiry = PurchaseManager(
            configuration: configuration,
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [],
                products: [Self.monthly],
                defaultLatestLookup: .unavailable
            ),
            entitlementStore: store,
            now: { now.addingTimeInterval(12 * 60 * 60) }
        )
        await rolledBackBeforeExpiry.prepare()

        XCTAssertFalse(rolledBackBeforeExpiry.hasPro)
        XCTAssertEqual(rolledBackBeforeExpiry.accessState, .inactive)
    }

    func testMissingLatestTransactionDoesNotDestroyVerifiedLifetimeCache() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = InMemoryEntitlementStore()
        let context = Self.context(account: "account-a")
        let configuration = Self.configuration(productIDs: [Self.lifetime.id])

        let onlineManager = PurchaseManager(
            configuration: configuration,
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [Self.lifetimeRecord(context: context)],
                products: [Self.lifetime]
            ),
            entitlementStore: store,
            now: { now }
        )
        await onlineManager.prepare()

        XCTAssertNotNil(try store.data(for: context.storageAccount))

        let contradictoryManager = PurchaseManager(
            configuration: configuration,
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [],
                products: [Self.lifetime],
                defaultLatestLookup: .notPurchased
            ),
            entitlementStore: store,
            now: { now.addingTimeInterval(60) }
        )
        await contradictoryManager.prepare()

        XCTAssertEqual(contradictoryManager.entitlementState, .inactive)
        XCTAssertTrue(contradictoryManager.hasPro)
        XCTAssertEqual(
            contradictoryManager.accessState.source,
            .verifiedCache
        )
        XCTAssertNotNil(try store.data(for: context.storageAccount))

        let offlineRelaunch = PurchaseManager(
            configuration: configuration,
            service: OfflineTestPurchaseService(
                context: nil,
                entitlements: [],
                products: [Self.lifetime],
                defaultLatestLookup: .unavailable
            ),
            entitlementStore: store,
            now: { now.addingTimeInterval(120) }
        )
        await offlineRelaunch.prepare()

        XCTAssertTrue(offlineRelaunch.hasPro)
        XCTAssertEqual(offlineRelaunch.accessState.source, .verifiedCache)
    }

    func testExplicitLifetimeRevocationInvalidatesCache() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = InMemoryEntitlementStore()
        let context = Self.context(account: "account-a")

        let onlineManager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.lifetime.id]),
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [Self.lifetimeRecord(context: context)],
                products: [Self.lifetime]
            ),
            entitlementStore: store,
            now: { now }
        )
        await onlineManager.prepare()

        let revoked = EntitlementRecord(
            productID: Self.lifetime.id,
            purchaseDate: now.addingTimeInterval(-86_400),
            revocationDate: now.addingTimeInterval(30),
            productKind: .nonConsumable,
            ownership: .purchased,
            transactionID: "lifetime-transaction",
            originalTransactionID: "lifetime-original",
            appTransactionID: context.appTransactionID,
            environment: context.environment
        )
        let revokedService = OfflineTestPurchaseService(
            context: context,
            entitlements: [],
            products: [Self.lifetime],
            latestLookups: [Self.lifetime.id: .verified(revoked)]
        )
        let manager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.lifetime.id]),
            service: revokedService,
            entitlementStore: store,
            now: { now.addingTimeInterval(60) }
        )

        XCTAssertFalse(manager.hasPro)
        XCTAssertEqual(manager.accessState, .inactive)

        await manager.prepare()

        XCTAssertFalse(manager.hasPro)
        XCTAssertEqual(manager.accessState, .inactive)

        let nextLaunch = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.lifetime.id]),
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [],
                products: [Self.lifetime],
                defaultLatestLookup: .unavailable
            ),
            entitlementStore: store,
            now: { now.addingTimeInterval(120) }
        )

        XCTAssertFalse(nextLaunch.hasPro)
        XCTAssertEqual(nextLaunch.accessState, .inactive)
    }

    func testFreeAccountIdentityPreventsPaidAccountCacheReuseOffline() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = InMemoryEntitlementStore()
        let accountA = Self.context(account: "account-a")
        let accountB = Self.context(account: "account-b")
        let configuration = Self.configuration(productIDs: [Self.lifetime.id])

        let managerA = PurchaseManager(
            configuration: configuration,
            service: OfflineTestPurchaseService(
                context: accountA,
                entitlements: [Self.lifetimeRecord(context: accountA)],
                products: [Self.lifetime]
            ),
            entitlementStore: store,
            now: { now }
        )
        await managerA.prepare()

        XCTAssertNotNil(try store.data(for: accountA.storageAccount))

        let managerB = PurchaseManager(
            configuration: configuration,
            service: OfflineTestPurchaseService(
                context: accountB,
                entitlements: [],
                products: [Self.lifetime],
                defaultLatestLookup: .notPurchased
            ),
            entitlementStore: store,
            now: { now.addingTimeInterval(60) }
        )

        await managerB.prepare()

        XCTAssertFalse(managerB.hasPro)
        XCTAssertEqual(managerB.accessState, .inactive)
        XCTAssertEqual(
            try store.persistedIdentity(for: accountB)?.appTransactionID,
            accountB.appTransactionID
        )
        XCTAssertNotNil(try store.data(for: accountA.storageAccount))

        let offlineRelaunch = PurchaseManager(
            configuration: configuration,
            service: OfflineTestPurchaseService(
                context: nil,
                entitlements: [],
                products: [Self.lifetime],
                defaultLatestLookup: .unavailable
            ),
            entitlementStore: store,
            now: { now.addingTimeInterval(120) }
        )

        await offlineRelaunch.prepare()

        XCTAssertFalse(offlineRelaunch.hasPro)
        XCTAssertEqual(offlineRelaunch.accessState, .inactive)
    }

    func testOfflineRelaunchUsesLastVerifiedIdentityWhenAccountContextIsUnavailable() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = InMemoryEntitlementStore()
        let context = Self.context(account: "account-a")

        let onlineManager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.lifetime.id]),
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [Self.lifetimeRecord(context: context)],
                products: [Self.lifetime]
            ),
            entitlementStore: store,
            now: { now }
        )
        await onlineManager.prepare()

        let offlineManager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.lifetime.id]),
            service: OfflineTestPurchaseService(
                context: nil,
                entitlements: [],
                products: [Self.lifetime],
                defaultLatestLookup: .unavailable
            ),
            entitlementStore: store,
            now: { now.addingTimeInterval(60) }
        )

        XCTAssertEqual(offlineManager.accessState, .inactive)

        await offlineManager.prepare()

        XCTAssertTrue(offlineManager.hasPro)
        XCTAssertEqual(offlineManager.accessState.source, .verifiedCache)
    }

    func testMultipleCachedAccountsUseLastVerifiedIdentityOffline() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = InMemoryEntitlementStore()
        let accountA = Self.context(account: "account-a")
        let accountB = Self.context(account: "account-b")
        let configuration = Self.configuration(productIDs: [Self.lifetime.id])

        let managerA = PurchaseManager(
            configuration: configuration,
            service: OfflineTestPurchaseService(
                context: accountA,
                entitlements: [Self.lifetimeRecord(context: accountA)],
                products: [Self.lifetime]
            ),
            entitlementStore: store,
            now: { now }
        )
        await managerA.prepare()

        let managerB = PurchaseManager(
            configuration: configuration,
            service: OfflineTestPurchaseService(
                context: accountB,
                entitlements: [Self.lifetimeRecord(context: accountB)],
                products: [Self.lifetime]
            ),
            entitlementStore: store,
            now: { now.addingTimeInterval(60) }
        )
        await managerB.prepare()

        XCTAssertNotNil(try store.data(for: accountA.storageAccount))
        XCTAssertNotNil(try store.data(for: accountB.storageAccount))
        XCTAssertEqual(
            try store.persistedIdentity(for: accountB)?.appTransactionID,
            accountB.appTransactionID
        )

        let offlineManager = PurchaseManager(
            configuration: configuration,
            service: OfflineTestPurchaseService(
                context: nil,
                entitlements: [],
                products: [Self.lifetime],
                defaultLatestLookup: .unavailable
            ),
            entitlementStore: store,
            now: { now.addingTimeInterval(120) }
        )

        await offlineManager.prepare()

        XCTAssertTrue(offlineManager.hasPro)
        XCTAssertEqual(offlineManager.accessState.source, .verifiedCache)
    }

    func testVerifiedEntitlementSkipsSeparateAccountContextLookup() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let context = Self.context(account: "account-a")
        let service = OfflineTestPurchaseService(
            context: context,
            entitlements: [Self.lifetimeRecord(context: context)],
            products: [Self.lifetime]
        )
        let manager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.lifetime.id]),
            service: service,
            entitlementStore: InMemoryEntitlementStore(),
            now: { now }
        )

        await manager.prepare()

        XCTAssertEqual(service.entitlementContextCallCount, 0)
        XCTAssertTrue(manager.hasPro)
        XCTAssertEqual(manager.accessState.source, .storeKit)
    }

    func testEmptyCurrentEntitlementsUseAccountContextLookup() async {
        let context = Self.context(account: "account-a")
        let service = OfflineTestPurchaseService(
            context: context,
            entitlements: [],
            products: [Self.lifetime],
            defaultLatestLookup: .notPurchased
        )
        let manager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.lifetime.id]),
            service: service,
            entitlementStore: InMemoryEntitlementStore()
        )

        await manager.prepare()

        XCTAssertEqual(service.entitlementContextCallCount, 1)
        XCTAssertEqual(manager.accessState, .inactive)
    }

    func testDisabledOfflinePolicyDoesNotRequestAccountContext() async {
        let service = OfflineTestPurchaseService(
            context: Self.context(account: "account-a"),
            entitlements: [],
            products: [Self.monthly]
        )
        let manager = PurchaseManager(
            configuration: PurchaseConfiguration(
                productIDs: [Self.monthly.id],
                productLoadAttempts: 1
            ),
            service: service
        )

        await manager.prepare()

        XCTAssertEqual(service.entitlementContextCallCount, 0)
        XCTAssertEqual(manager.entitlementState, .inactive)
        XCTAssertEqual(manager.accessState, .inactive)
    }

    func testMissingAccountContextStaysFreeWhileRetryCanRecoverPro() async {
        let context = Self.context(account: "account-a")
        let service = OfflineTestPurchaseService(
            context: nil,
            entitlements: [],
            products: [Self.lifetime],
            defaultLatestLookup: .unavailable
        )
        let manager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.lifetime.id]),
            service: service,
            entitlementStore: InMemoryEntitlementStore(),
            entitlementRetryDelays: [.milliseconds(10)],
            entitlementRetryInterval: .milliseconds(20)
        )

        await manager.prepare()

        XCTAssertEqual(manager.accessState, .inactive)
        XCTAssertFalse(manager.hasPro)
        let initialCallCount = service.currentEntitlementsCallCount

        service.context = context
        service.entitlements = [Self.lifetimeRecord(context: context)]

        let recovered = await Self.waitUntil {
            manager.accessState.source == .storeKit
        }

        XCTAssertTrue(recovered)
        XCTAssertTrue(manager.hasPro)
        XCTAssertGreaterThan(service.currentEntitlementsCallCount, initialCallCount)
    }

    func testFreshOfflineInstallCanStayFreeWhileRetryingUnavailableVerification() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let context = Self.context(account: "account-a")
        let service = OfflineTestPurchaseService(
            context: context,
            entitlements: [],
            products: [Self.lifetime],
            defaultLatestLookup: .unavailable
        )
        let manager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.lifetime.id]),
            service: service,
            entitlementStore: InMemoryEntitlementStore(),
            entitlementRetryDelays: [.milliseconds(10)],
            entitlementRetryInterval: .milliseconds(20),
            now: { now }
        )

        await manager.prepare()

        XCTAssertEqual(manager.entitlementState, .inactive)
        XCTAssertEqual(manager.accessState, .inactive)
        XCTAssertFalse(manager.hasPro)

        let entitlementCallCount = service.currentEntitlementsCallCount
        service.entitlements = [Self.lifetimeRecord(context: context)]

        let recovered = await Self.waitUntil {
            manager.accessState.source == .storeKit
        }

        XCTAssertTrue(recovered)
        XCTAssertTrue(manager.hasPro)
        XCTAssertGreaterThan(
            service.currentEntitlementsCallCount,
            entitlementCallCount
        )

        let resolvedCallCount = service.currentEntitlementsCallCount
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(service.currentEntitlementsCallCount, resolvedCallCount)
    }

    func testConfirmedFreeDoesNotStartEntitlementRetry() async {
        let context = Self.context(account: "account-a")
        let service = OfflineTestPurchaseService(
            context: context,
            entitlements: [],
            products: [Self.lifetime],
            defaultLatestLookup: .notPurchased
        )
        let manager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.lifetime.id]),
            service: service,
            entitlementStore: InMemoryEntitlementStore(),
            entitlementRetryDelays: [.milliseconds(10)],
            entitlementRetryInterval: .milliseconds(20)
        )

        await manager.prepare()

        XCTAssertEqual(manager.accessState, .inactive)
        XCTAssertFalse(manager.hasPro)

        let resolvedCallCount = service.currentEntitlementsCallCount
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(service.currentEntitlementsCallCount, resolvedCallCount)
    }

    func testInactiveRetryStopsWhenStoreKitConfirmsFree() async {
        let context = Self.context(account: "account-a")
        let service = OfflineTestPurchaseService(
            context: context,
            entitlements: [],
            products: [Self.lifetime],
            defaultLatestLookup: .unavailable
        )
        let manager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.lifetime.id]),
            service: service,
            entitlementStore: InMemoryEntitlementStore(),
            entitlementRetryDelays: [.milliseconds(10)],
            entitlementRetryInterval: .milliseconds(20)
        )

        await manager.prepare()

        XCTAssertEqual(manager.accessState, .inactive)
        let initialCallCount = service.currentEntitlementsCallCount

        service.defaultLatestLookup = .notPurchased

        let retried = await Self.waitUntil {
            service.currentEntitlementsCallCount > initialCallCount
        }
        XCTAssertTrue(retried)
        XCTAssertEqual(manager.accessState, .inactive)

        let resolvedCallCount = service.currentEntitlementsCallCount
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(service.currentEntitlementsCallCount, resolvedCallCount)
    }

    func testValidCachedLifetimeDoesNotStartEntitlementRetry() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let context = Self.context(account: "account-a")
        let store = InMemoryEntitlementStore()

        let onlineManager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.lifetime.id]),
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [Self.lifetimeRecord(context: context)],
                products: [Self.lifetime]
            ),
            entitlementStore: store,
            now: { now }
        )
        await onlineManager.prepare()

        let service = OfflineTestPurchaseService(
            context: context,
            entitlements: [],
            products: [Self.lifetime],
            defaultLatestLookup: .unavailable
        )
        let offlineManager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.lifetime.id]),
            service: service,
            entitlementStore: store,
            entitlementRetryDelays: [.milliseconds(10)],
            entitlementRetryInterval: .milliseconds(20),
            now: { now.addingTimeInterval(60) }
        )

        await offlineManager.prepare()

        XCTAssertTrue(offlineManager.hasPro)
        XCTAssertEqual(offlineManager.accessState.source, .verifiedCache)

        let resolvedCallCount = service.currentEntitlementsCallCount
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(service.currentEntitlementsCallCount, resolvedCallCount)
    }

    func testFreeAccessRetriesUntilStoreKitResolves() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let retryNow = now.addingTimeInterval(1_200)
        let context = Self.context(account: "account-a")
        let store = await Self.expiredSubscriptionStore(
            context: context,
            now: now
        )
        let service = OfflineTestPurchaseService(
            context: context,
            entitlements: [],
            products: [Self.monthly],
            defaultLatestLookup: .unavailable
        )
        let manager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.monthly.id]),
            service: service,
            entitlementStore: store,
            entitlementRetryDelays: [.milliseconds(10)],
            entitlementRetryInterval: .milliseconds(20),
            now: { retryNow }
        )

        await manager.prepare()

        XCTAssertEqual(manager.accessState, .inactive)
        let productCallCount = service.productCallCount
        let entitlementCallCount = service.currentEntitlementsCallCount

        service.entitlements = [
            Self.subscriptionRecord(
                context: context,
                expirationDate: retryNow.addingTimeInterval(3_600),
                state: .subscribed
            )
        ]

        let resolved = await Self.waitUntil {
            manager.accessState.source == .storeKit
        }

        XCTAssertTrue(resolved)
        XCTAssertTrue(manager.hasPro)
        XCTAssertGreaterThan(
            service.currentEntitlementsCallCount,
            entitlementCallCount
        )
        XCTAssertEqual(service.productCallCount, productCallCount)

        let resolvedEntitlementCallCount = service.currentEntitlementsCallCount
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(
            service.currentEntitlementsCallCount,
            resolvedEntitlementCallCount
        )
    }

    func testEntitlementRetryCanResolveToFreeAndThenStops() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let context = Self.context(account: "account-a")
        let store = await Self.expiredSubscriptionStore(
            context: context,
            now: now
        )
        let service = OfflineTestPurchaseService(
            context: context,
            entitlements: [],
            products: [Self.monthly],
            defaultLatestLookup: .unavailable
        )
        let manager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.monthly.id]),
            service: service,
            entitlementStore: store,
            entitlementRetryDelays: [.milliseconds(10)],
            entitlementRetryInterval: .milliseconds(20),
            now: { now.addingTimeInterval(1_200) }
        )

        await manager.prepare()

        XCTAssertEqual(manager.accessState, .inactive)
        let preResolutionCallCount = service.currentEntitlementsCallCount
        service.defaultLatestLookup = .notPurchased

        let retried = await Self.waitUntil {
            service.currentEntitlementsCallCount > preResolutionCallCount
        }

        XCTAssertTrue(retried)
        XCTAssertEqual(manager.accessState, .inactive)
        XCTAssertFalse(manager.hasPro)

        let resolvedEntitlementCallCount = service.currentEntitlementsCallCount
        try? await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(
            service.currentEntitlementsCallCount,
            resolvedEntitlementCallCount
        )
    }

    #if DEBUG
    func testEntitlementRetryIsCancelledWhenPurchaseServiceChanges() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let context = Self.context(account: "account-a")
        let store = await Self.expiredSubscriptionStore(
            context: context,
            now: now
        )
        let service = OfflineTestPurchaseService(
            context: context,
            entitlements: [],
            products: [Self.monthly],
            defaultLatestLookup: .unavailable
        )
        let manager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.monthly.id]),
            service: service,
            entitlementStore: store,
            entitlementRetryDelays: [.milliseconds(100)],
            entitlementRetryInterval: .milliseconds(100),
            now: { now.addingTimeInterval(1_200) }
        )

        await manager.prepare()
        XCTAssertEqual(manager.accessState, .inactive)

        let oldServiceCallCount = service.currentEntitlementsCallCount

        await manager.setSimulatedPurchasesEnabled(true)
        XCTAssertEqual(manager.accessState, .inactive)

        try? await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(
            service.currentEntitlementsCallCount,
            oldServiceCallCount
        )
    }
    #endif

    func testEntitlementRetryContinuesAtPeriodicIntervalUntilStoreKitResolves() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let context = Self.context(account: "account-a")
        let store = await Self.expiredSubscriptionStore(
            context: context,
            now: now
        )
        let service = OfflineTestPurchaseService(
            context: context,
            entitlements: [],
            products: [Self.monthly],
            defaultLatestLookup: .unavailable
        )
        let manager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.monthly.id]),
            service: service,
            entitlementStore: store,
            entitlementRetryDelays: [],
            entitlementRetryInterval: .milliseconds(10),
            now: { now.addingTimeInterval(1_200) }
        )

        await manager.prepare()
        XCTAssertEqual(manager.accessState, .inactive)

        let retriedRepeatedly = await Self.waitUntil {
            service.currentEntitlementsCallCount >= 3
        }
        XCTAssertTrue(retriedRepeatedly)

        let preResolutionCallCount = service.currentEntitlementsCallCount
        service.defaultLatestLookup = .notPurchased

        let resolved = await Self.waitUntil {
            service.currentEntitlementsCallCount > preResolutionCallCount
        }
        XCTAssertTrue(resolved)
        XCTAssertEqual(manager.accessState, .inactive)

        let resolvedCallCount = service.currentEntitlementsCallCount
        try? await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(service.currentEntitlementsCallCount, resolvedCallCount)
    }

    func testCorruptVerifiedCacheNeverGrantsPro() async throws {
        let context = Self.context(account: "account-a")
        let store = InMemoryEntitlementStore()
        try store.set(Data([0xFF, 0x00, 0x01]), for: context.storageAccount)

        let manager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.lifetime.id]),
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [],
                products: [Self.lifetime],
                defaultLatestLookup: .unavailable
            ),
            entitlementStore: store,
            entitlementRetryDelays: [.seconds(60)]
        )

        await manager.prepare()

        XCTAssertFalse(manager.hasPro)
        XCTAssertNil(manager.accessState.source)
        XCTAssertNil(try store.data(for: context.storageAccount))
    }

    func testFreshOfflineInstallCanRecoverVerifiedLifetimeFromLatestTransaction() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let context = Self.context(account: "account-a")
        let lifetime = Self.lifetimeRecord(context: context)

        let manager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.lifetime.id]),
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [],
                products: [Self.lifetime],
                latestLookups: [Self.lifetime.id: .verified(lifetime)]
            ),
            entitlementStore: InMemoryEntitlementStore(),
            now: { now }
        )

        await manager.prepare()

        XCTAssertEqual(manager.entitlementState, .inactive)
        XCTAssertTrue(manager.hasPro)
        XCTAssertEqual(manager.accessState.source, .verifiedCache)
    }

    func testGracePeriodIsPersistedAsOfflineSubscriptionValidity() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = InMemoryEntitlementStore()
        let context = Self.context(account: "account-a")
        let graceEnd = now.addingTimeInterval(3_600)
        let record = EntitlementRecord(
            productID: Self.monthly.id,
            purchaseDate: now.addingTimeInterval(-86_400),
            expirationDate: now.addingTimeInterval(-60),
            gracePeriodExpirationDate: graceEnd,
            productKind: .autoRenewable,
            ownership: .purchased,
            transactionID: "monthly-transaction",
            originalTransactionID: "monthly-original",
            appTransactionID: context.appTransactionID,
            environment: context.environment,
            subscriptionState: .inGracePeriod
        )

        let onlineManager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.monthly.id]),
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [record],
                products: [Self.monthly]
            ),
            entitlementStore: store,
            now: { now }
        )
        await onlineManager.prepare()

        let offlineManager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.monthly.id]),
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [],
                products: [Self.monthly],
                defaultLatestLookup: .unavailable
            ),
            entitlementStore: store,
            now: { now.addingTimeInterval(1_800) }
        )

        XCTAssertFalse(offlineManager.hasPro)
        XCTAssertEqual(offlineManager.accessState, .inactive)
        await offlineManager.prepare()
        XCTAssertTrue(offlineManager.hasPro)
        XCTAssertEqual(offlineManager.accessState.source, .verifiedCache)
    }

    func testFamilySharedLifetimeUsesBoundedOfflineWindow() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = InMemoryEntitlementStore()
        let context = Self.context(account: "account-a")
        let policy = VerifiedEntitlementCachePolicy(
            sharedLifetimeMaxOfflineInterval: 100,
            clockRollbackTolerance: 300
        )
        let configuration = PurchaseConfiguration(
            productIDs: [Self.lifetime.id],
            offlineEntitlements: .verifiedCache(policy)
        )
        let familyShared = EntitlementRecord(
            productID: Self.lifetime.id,
            purchaseDate: now.addingTimeInterval(-86_400),
            productKind: .nonConsumable,
            ownership: .familyShared,
            transactionID: "shared-transaction",
            originalTransactionID: "shared-original",
            appTransactionID: context.appTransactionID,
            environment: context.environment
        )

        let onlineManager = PurchaseManager(
            configuration: configuration,
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [familyShared],
                products: [Self.lifetime]
            ),
            entitlementStore: store,
            now: { now }
        )
        await onlineManager.prepare()

        let rolledBack = PurchaseManager(
            configuration: configuration,
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [],
                products: [Self.lifetime],
                defaultLatestLookup: .unavailable
            ),
            entitlementStore: store,
            now: { now.addingTimeInterval(-3_600) }
        )
        await rolledBack.prepare()
        XCTAssertFalse(rolledBack.hasPro)
        XCTAssertEqual(rolledBack.accessState, .inactive)

        let withinWindow = PurchaseManager(
            configuration: configuration,
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [],
                products: [Self.lifetime],
                defaultLatestLookup: .unavailable
            ),
            entitlementStore: store,
            now: { now.addingTimeInterval(50) }
        )
        XCTAssertFalse(withinWindow.hasPro)
        XCTAssertEqual(withinWindow.accessState, .inactive)
        await withinWindow.prepare()
        XCTAssertTrue(withinWindow.hasPro)

        let afterWindow = PurchaseManager(
            configuration: configuration,
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [],
                products: [Self.lifetime],
                defaultLatestLookup: .unavailable
            ),
            entitlementStore: store,
            now: { now.addingTimeInterval(200) }
        )
        XCTAssertFalse(afterWindow.hasPro)
        XCTAssertEqual(afterWindow.accessState, .inactive)
        await afterWindow.prepare()
        XCTAssertFalse(afterWindow.hasPro)
        XCTAssertEqual(afterWindow.accessState, .inactive)
    }

    func testProductCatalogFailureDoesNotRevokeCachedLifetime() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = InMemoryEntitlementStore()
        let context = Self.context(account: "account-a")
        let configuration = Self.configuration(productIDs: [Self.lifetime.id])

        let onlineManager = PurchaseManager(
            configuration: configuration,
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [Self.lifetimeRecord(context: context)],
                products: [Self.lifetime]
            ),
            entitlementStore: store,
            now: { now }
        )
        await onlineManager.prepare()

        let offlineService = OfflineTestPurchaseService(
            context: context,
            entitlements: [],
            products: [],
            defaultLatestLookup: .unavailable,
            productFailure: .noProductsAvailable
        )
        let offlineManager = PurchaseManager(
            configuration: configuration,
            service: offlineService,
            entitlementStore: store,
            now: { now.addingTimeInterval(60) }
        )

        await offlineManager.prepare()

        XCTAssertTrue(offlineManager.hasPro)
        XCTAssertEqual(
            offlineManager.productLoadingState,
            .failed(.noProductsAvailable)
        )
    }

    func testHistoricalEntitlementCanGrantProWithoutBeingSold() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let context = Self.context(account: "account-a")
        let legacyID = "pro.lifetime.v1"
        let legacyRecord = EntitlementRecord(
            productID: legacyID,
            purchaseDate: now.addingTimeInterval(-86_400),
            productKind: .nonConsumable,
            ownership: .purchased,
            appTransactionID: context.appTransactionID,
            environment: context.environment
        )
        let service = OfflineTestPurchaseService(
            context: context,
            entitlements: [legacyRecord],
            products: [Self.monthly]
        )
        let manager = PurchaseManager(
            configuration: PurchaseConfiguration(
                productIDs: [Self.monthly.id],
                entitledProductIDs: [Self.monthly.id, legacyID]
            ),
            service: service,
            now: { now }
        )

        await manager.prepare()

        XCTAssertTrue(manager.hasPro)
        XCTAssertEqual(manager.products, [Self.monthly])
        XCTAssertNil(manager.activeProduct)
    }

    private static func waitUntil(
        timeout: Duration = .seconds(1),
        condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while clock.now < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(5))
        }

        return condition()
    }

    private static func expiredSubscriptionStore(
        context: PurchaseEntitlementContext,
        now: Date
    ) async -> InMemoryEntitlementStore {
        let store = InMemoryEntitlementStore()
        let manager = PurchaseManager(
            configuration: Self.configuration(productIDs: [Self.monthly.id]),
            service: OfflineTestPurchaseService(
                context: context,
                entitlements: [
                    Self.subscriptionRecord(
                        context: context,
                        expirationDate: now.addingTimeInterval(600),
                        state: .subscribed
                    )
                ],
                products: [Self.monthly]
            ),
            entitlementStore: store,
            now: { now }
        )

        await manager.prepare()
        return store
    }

    private static func configuration(
        productIDs: [String]
    ) -> PurchaseConfiguration {
        PurchaseConfiguration(
            productIDs: productIDs,
            productLoadAttempts: 1,
            offlineEntitlements: .verifiedCache(.init())
        )
    }

    private static func context(account: String) -> PurchaseEntitlementContext {
        PurchaseEntitlementContext(
            bundleID: Bundle.main.bundleIdentifier ?? "com.example.test",
            environment: .production,
            appTransactionID: account
        )
    }

    private static func lifetimeRecord(
        context: PurchaseEntitlementContext
    ) -> EntitlementRecord {
        EntitlementRecord(
            productID: Self.lifetime.id,
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            productKind: .nonConsumable,
            ownership: .purchased,
            transactionID: "lifetime-transaction",
            originalTransactionID: "lifetime-original",
            appTransactionID: context.appTransactionID,
            environment: context.environment
        )
    }

    private static func subscriptionRecord(
        context: PurchaseEntitlementContext,
        expirationDate: Date,
        state: EntitlementSubscriptionState
    ) -> EntitlementRecord {
        EntitlementRecord(
            productID: Self.monthly.id,
            purchaseDate: expirationDate.addingTimeInterval(-30 * 24 * 60 * 60),
            expirationDate: expirationDate,
            productKind: .autoRenewable,
            ownership: .purchased,
            transactionID: "monthly-transaction",
            originalTransactionID: "monthly-original",
            appTransactionID: context.appTransactionID,
            environment: context.environment,
            subscriptionState: state
        )
    }

    private static let monthly = StoreProduct(
        id: "pro.monthly",
        displayName: "Monthly",
        description: "Monthly access",
        displayPrice: "$4.99",
        price: 4.99,
        subscriptionPeriod: .init(value: 1, unit: .month)
    )

    private static let lifetime = StoreProduct(
        id: "pro.lifetime",
        displayName: "Lifetime",
        description: "Lifetime access",
        displayPrice: "$79.99",
        price: 79.99
    )
}

@MainActor
private final class InMemoryEntitlementStore: VerifiedEntitlementStoring {
    private var values: [String: Data] = [:]

    func data(for account: String) throws -> Data? {
        values[account]
    }

    func set(_ data: Data, for account: String) throws {
        values[account] = data
    }

    func removeData(for account: String) throws {
        values.removeValue(forKey: account)
    }

    func persistedIdentity(
        for context: PurchaseEntitlementContext
    ) throws -> PersistedPurchaseIdentity? {
        guard let data = try data(for: context.identityStorageAccount) else {
            return nil
        }
        return try JSONDecoder().decode(
            PersistedPurchaseIdentity.self,
            from: data
        )
    }
}

@MainActor
private final class OfflineTestPurchaseService: PurchaseServing {
    var context: PurchaseEntitlementContext?
    var entitlements: [EntitlementRecord]
    var productsResult: [StoreProduct]
    var latestLookups: [String: LatestEntitlementLookup]
    var defaultLatestLookup: LatestEntitlementLookup
    var productFailure: PurchaseFailure?
    private(set) var entitlementContextCallCount = 0
    private(set) var currentEntitlementsCallCount = 0
    private(set) var productCallCount = 0

    init(
        context: PurchaseEntitlementContext?,
        entitlements: [EntitlementRecord],
        products: [StoreProduct],
        latestLookups: [String: LatestEntitlementLookup] = [:],
        defaultLatestLookup: LatestEntitlementLookup = .notPurchased,
        productFailure: PurchaseFailure? = nil
    ) {
        self.context = context
        self.entitlements = entitlements
        self.productsResult = products
        self.latestLookups = latestLookups
        self.defaultLatestLookup = defaultLatestLookup
        self.productFailure = productFailure
    }

    func products(for identifiers: [String]) async throws -> [StoreProduct] {
        productCallCount += 1
        if let productFailure {
            throw productFailure
        }
        return productsResult.filter { identifiers.contains($0.id) }
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        .userCancelled
    }

    func currentEntitlements() async -> [EntitlementRecord] {
        currentEntitlementsCallCount += 1
        return entitlements
    }

    func entitlementContext() async -> PurchaseEntitlementContext? {
        entitlementContextCallCount += 1
        return context
    }

    func latestEntitlement(for productID: String) async -> LatestEntitlementLookup {
        latestLookups[productID] ?? defaultLatestLookup
    }

    func entitlementUpdates(for productIDs: Set<String>) -> AsyncStream<String> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func subscriptionStatusUpdates(for productIDs: Set<String>) -> AsyncStream<String> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func sync() async throws {}
}
