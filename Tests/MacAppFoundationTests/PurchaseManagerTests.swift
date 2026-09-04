import XCTest
@testable import MacAppFoundation

@MainActor
final class PurchaseManagerTests: XCTestCase {
    func testPrepareLoadsProductsAndEvaluatesEntitlement() async {
        let service = MockPurchaseService()
        service.productsResult = [Self.monthly]
        service.entitlements = [EntitlementRecord(productID: Self.monthly.id)]

        let manager = PurchaseManager(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        await manager.prepare()

        XCTAssertEqual(manager.products, [Self.monthly])
        XCTAssertEqual(manager.productLoadingState, .loaded)
        XCTAssertTrue(manager.hasPro)
        XCTAssertEqual(service.productLoadCount, 1)
        XCTAssertEqual(service.observedProductIDs, [Self.monthly.id])
    }

    func testPurchaseReturnsOutcomeAndRefreshesEntitlementAfterSuccess() async {
        let service = MockPurchaseService()
        let record = EntitlementRecord(productID: Self.monthly.id)
        service.productsResult = [Self.monthly]
        service.purchaseOutcome = .success(record)

        let manager = PurchaseManager(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        await manager.loadProducts()
        service.entitlements = [record]
        let outcome = await manager.purchase(Self.monthly)

        XCTAssertEqual(outcome, .success(record))
        XCTAssertTrue(manager.hasPro)
        XCTAssertEqual(manager.activity, .idle)
    }

    func testPendingPurchaseDoesNotUnlockEntitlement() async {
        let service = MockPurchaseService()
        service.purchaseOutcome = .pending

        let manager = PurchaseManager(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        let outcome = await manager.purchase(Self.monthly)

        XCTAssertEqual(outcome, .pending)
        XCTAssertEqual(manager.activity, .pending(productID: Self.monthly.id))
        XCTAssertFalse(manager.hasPro)
    }

    func testUnsupportedProductTypeIsRejectedBeforeServicePurchase() async {
        let consumable = StoreProduct(
            id: "credits",
            displayName: "Credits",
            description: "",
            displayPrice: "$0.99",
            price: 0.99,
            type: .consumable
        )
        let service = MockPurchaseService()
        service.productsResult = [consumable]
        let manager = PurchaseManager(
            configuration: PurchaseConfiguration(productIDs: [consumable.id]),
            service: service
        )

        await manager.loadProducts()
        let outcome = await manager.purchase(consumable)

        XCTAssertNil(outcome)
        XCTAssertEqual(manager.activity, .failed(.productUnavailable))
        XCTAssertEqual(service.purchaseCount, 0)
    }

    func testRestoreReportsNothingWhenNoEntitlementExists() async {
        let service = MockPurchaseService()
        let manager = PurchaseManager(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        let outcome = await manager.restorePurchases()

        XCTAssertEqual(outcome, .nothingToRestore)
        XCTAssertEqual(service.syncCount, 1)
        XCTAssertEqual(manager.activity, .idle)
    }

    func testRestoreReturnsFailureWhenSyncThrows() async {
        let service = MockPurchaseService()
        service.syncFailure = .unknown
        let manager = PurchaseManager(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        let outcome = await manager.restorePurchases()

        XCTAssertEqual(outcome, .failed(.unknown))
        XCTAssertEqual(manager.activity, .failed(.unknown))
    }

    func testRestoreDoesNotStartWhilePurchaseIsRunning() async {
        let service = MockPurchaseService()
        service.purchaseDelay = .seconds(1)
        let manager = PurchaseManager(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        let purchaseTask = Task { await manager.purchase(Self.monthly) }
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(manager.isPurchasing)

        let restoreOutcome = await manager.restorePurchases()

        XCTAssertEqual(restoreOutcome, .failed(.operationInProgress))
        XCTAssertEqual(service.syncCount, 0)
        XCTAssertTrue(manager.isPurchasing)

        purchaseTask.cancel()
        _ = await purchaseTask.value
    }

    func testCancelRestoreDoesNotClearPurchaseActivity() async {
        let service = MockPurchaseService()
        service.purchaseDelay = .seconds(1)
        let manager = PurchaseManager(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        let purchaseTask = Task { await manager.purchase(Self.monthly) }
        try? await Task.sleep(for: .milliseconds(50))
        manager.cancelRestore()

        XCTAssertTrue(manager.isPurchasing)
        purchaseTask.cancel()
        _ = await purchaseTask.value
    }

    func testTransactionUpdateStillClearsPendingAskToBuy() async throws {
        let service = MockPurchaseService()
        service.productsResult = [Self.monthly]
        service.purchaseOutcome = .pending
        let manager = PurchaseManager(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        await manager.prepare()
        await manager.purchase(Self.monthly)
        XCTAssertEqual(manager.activity, .pending(productID: Self.monthly.id))

        service.yieldEntitlementUpdate()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(manager.activity, .idle)
    }

    func testPreferredProductUsesConfiguredCatalogOrder() async {
        let service = MockPurchaseService()
        service.productsResult = [Self.yearly, Self.monthly]
        let manager = PurchaseManager(
            configuration: PurchaseConfiguration(
                productIDs: [Self.monthly.id, Self.yearly.id],
                preferredProductID: Self.yearly.id
            ),
            service: service
        )

        await manager.loadProducts()

        XCTAssertEqual(manager.products, [Self.monthly, Self.yearly])
        XCTAssertEqual(manager.preferredProduct?.id, Self.yearly.id)
        XCTAssertEqual(manager.preferredEntitlementProduct?.id, Self.yearly.id)
    }

    func testActiveProductMatchesVerifiedEntitlement() async {
        let service = MockPurchaseService()
        service.productsResult = [Self.monthly, Self.yearly]
        service.entitlements = [EntitlementRecord(productID: Self.yearly.id)]

        let manager = PurchaseManager(
            configuration: PurchaseConfiguration(
                productIDs: [Self.monthly.id, Self.yearly.id]
            ),
            service: service
        )

        await manager.prepare()

        XCTAssertTrue(manager.hasPro)
        XCTAssertEqual(manager.activeProduct?.id, Self.yearly.id)
    }

    func testActiveProductPrefersLifetimeWhenSubscriptionAlsoActive() async {
        let service = MockPurchaseService()
        service.productsResult = [Self.monthly, Self.lifetime]
        service.entitlements = [
            EntitlementRecord(
                productID: Self.monthly.id,
                expirationDate: Date.now.addingTimeInterval(86_400)
            ),
            EntitlementRecord(productID: Self.lifetime.id)
        ]
        let manager = PurchaseManager(
            configuration: PurchaseConfiguration(
                productIDs: [Self.monthly.id, Self.lifetime.id]
            ),
            service: service
        )

        await manager.prepare()

        XCTAssertEqual(manager.activeProduct?.id, Self.lifetime.id)
    }

    func testEntitlementProductsExcludeNonEntitledAndUnsupportedProducts() async {
        let bonus = StoreProduct(
            id: "bonus",
            displayName: "Bonus",
            description: "",
            displayPrice: "$1.99",
            price: 1.99
        )
        let credits = StoreProduct(
            id: "credits",
            displayName: "Credits",
            description: "",
            displayPrice: "$0.99",
            price: 0.99,
            type: .consumable
        )
        let service = MockPurchaseService()
        service.productsResult = [Self.monthly, bonus, credits]
        let manager = PurchaseManager(
            configuration: PurchaseConfiguration(
                productIDs: [Self.monthly.id, bonus.id, credits.id],
                entitledProductIDs: [Self.monthly.id, credits.id]
            ),
            service: service
        )

        await manager.loadProducts()

        XCTAssertEqual(manager.entitlementProducts.map(\.id), [Self.monthly.id])
    }

    func testFeaturesExposeConfiguredCatalog() {
        let features = [
            PurchaseFeature(
                id: "export",
                systemImage: "square.and.arrow.up",
                title: "Export",
                message: "Unlimited exports",
                freeValue: "Limited",
                proValue: "Unlimited"
            )
        ]
        let manager = PurchaseManager(
            configuration: PurchaseConfiguration(
                productIDs: [Self.monthly.id],
                features: features
            ),
            service: MockPurchaseService()
        )

        XCTAssertEqual(manager.features, features)
    }

    private static let monthly = StoreProduct(
        id: "pro.monthly",
        displayName: "Monthly",
        description: "Monthly access",
        displayPrice: "$4.99",
        price: 4.99,
        subscriptionPeriod: .init(value: 1, unit: .month)
    )

    private static let yearly = StoreProduct(
        id: "pro.yearly",
        displayName: "Yearly",
        description: "Yearly access",
        displayPrice: "$39.99",
        price: 39.99,
        subscriptionPeriod: .init(value: 1, unit: .year)
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
private final class MockPurchaseService: PurchaseServing {
    var productsResult: [StoreProduct] = []
    var purchaseOutcome: PurchaseOutcome = .userCancelled
    var purchaseDelay: Duration = .milliseconds(0)
    var entitlements: [EntitlementRecord] = []
    var productLoadCount = 0
    var purchaseCount = 0
    var syncCount = 0
    var syncFailure: PurchaseFailure?
    var observedProductIDs: Set<String> = []

    private var updateContinuations: [AsyncStream<Void>.Continuation] = []

    func products(for identifiers: [String]) async throws -> [StoreProduct] {
        productLoadCount += 1
        return productsResult.filter { identifiers.contains($0.id) }
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        purchaseCount += 1
        try? await Task.sleep(for: purchaseDelay)
        return purchaseOutcome
    }

    func currentEntitlements() async -> [EntitlementRecord] {
        entitlements
    }

    func entitlementUpdates(for productIDs: Set<String>) -> AsyncStream<Void> {
        observedProductIDs = productIDs
        return AsyncStream { continuation in
            updateContinuations.append(continuation)
        }
    }

    func yieldEntitlementUpdate() {
        for continuation in updateContinuations {
            continuation.yield()
        }
    }

    func sync() async throws {
        syncCount += 1
        if let syncFailure {
            throw syncFailure
        }
    }
}
