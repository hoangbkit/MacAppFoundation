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
    }

    func testPurchaseRefreshesEntitlementAfterSuccess() async {
        let service = MockPurchaseService()
        service.productsResult = [Self.monthly]
        service.purchaseOutcome = .success(EntitlementRecord(productID: Self.monthly.id))

        let manager = PurchaseManager(
            configuration: PurchaseConfiguration(productIDs: [Self.monthly.id]),
            service: service
        )

        await manager.loadProducts()
        service.entitlements = [EntitlementRecord(productID: Self.monthly.id)]
        await manager.purchase(Self.monthly)

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

        await manager.purchase(Self.monthly)

        XCTAssertEqual(manager.activity, .pending(productID: Self.monthly.id))
        XCTAssertFalse(manager.hasPro)
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
}

@MainActor
private final class MockPurchaseService: PurchaseServing {
    var productsResult: [StoreProduct] = []
    var purchaseOutcome: PurchaseOutcome = .userCancelled
    var entitlements: [EntitlementRecord] = []
    var productLoadCount = 0
    var syncCount = 0
    var syncFailure: PurchaseFailure?

    private var updateContinuations: [AsyncStream<Void>.Continuation] = []

    func products(for identifiers: [String]) async throws -> [StoreProduct] {
        productLoadCount += 1
        return productsResult.filter { identifiers.contains($0.id) }
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        purchaseOutcome
    }

    func currentEntitlements() async -> [EntitlementRecord] {
        entitlements
    }

    func entitlementUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
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
