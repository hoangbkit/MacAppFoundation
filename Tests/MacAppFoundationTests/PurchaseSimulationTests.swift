#if DEBUG
import XCTest
@testable import MacAppFoundation

@MainActor
final class PurchaseSimulationTests: XCTestCase {
    func testSimulatedCatalogCanChangeWithoutMutatingLiveConfiguration() async {
        let manager = makeManager()
        await manager.prepare()

        let yearly = StoreProduct(
            id: "pro.yearly",
            displayName: "Yearly",
            description: "Yearly Pro",
            displayPrice: "$39.99",
            price: 39.99,
            subscriptionPeriod: .init(value: 1, unit: .year),
            introductoryOffer: .init(
                paymentMode: .freeTrial,
                period: .init(value: 1, unit: .week),
                displayPrice: "Free",
                price: 0,
                isEligible: true
            )
        )
        let simulatedConfiguration = PurchaseConfiguration(
            productIDs: [yearly.id],
            preferredProductID: yearly.id,
            productLoadAttempts: 1
        )

        await manager.configureSimulatedCatalog(
            configuration: simulatedConfiguration,
            products: [yearly]
        )

        XCTAssertEqual(manager.configuration.productIDs, [Self.monthly.id])
        XCTAssertEqual(manager.simulatedConfigurationSnapshot, simulatedConfiguration)
        XCTAssertEqual(manager.simulatedCatalogProducts, [yearly])
        XCTAssertEqual(manager.products, [yearly])
        XCTAssertEqual(manager.preferredProduct, yearly)
        XCTAssertEqual(manager.products.first?.introductoryOffer, yearly.introductoryOffer)
    }

    func testCatalogEditPreservesPurchaseFailureSimulation() async {
        let manager = makeManager()
        await manager.prepare()
        let failure = PurchaseFailure(
            code: .networkUnavailable,
            message: "Simulated network failure."
        )
        manager.setSimulatedPurchaseResult(.failure(failure), for: Self.monthly.id)

        let editedMonthly = StoreProduct(
            id: Self.monthly.id,
            displayName: "Monthly Edited",
            description: "Edited monthly plan",
            displayPrice: "$3.99",
            price: 3.99,
            subscriptionPeriod: .init(value: 1, unit: .month)
        )
        await manager.configureSimulatedCatalog(
            configuration: manager.simulatedConfigurationSnapshot,
            products: [editedMonthly]
        )
        await manager.purchase(editedMonthly)

        XCTAssertEqual(manager.activity, .failed(failure))
        XCTAssertFalse(manager.hasPro)
    }

    func testCatalogEditPreservesCatalogAndRestoreFailureSimulation() async {
        let manager = makeManager()
        await manager.prepare()
        let restoreFailure = PurchaseFailure(
            code: .networkUnavailable,
            message: "Simulated restore failure."
        )
        await manager.setSimulatedProductLoadingFailure(.noProductsAvailable)
        manager.setSimulatedRestoreFailure(restoreFailure)

        await manager.configureSimulatedCatalog(
            configuration: manager.simulatedConfigurationSnapshot,
            products: [Self.monthly]
        )

        XCTAssertEqual(manager.productLoadingState, .failed(.noProductsAvailable))
        let outcome = await manager.restorePurchases()
        XCTAssertEqual(outcome, .failed(restoreFailure))
    }

    func testCanForceSimulatedEntitlement() async {
        let manager = makeManager()
        await manager.prepare()

        await manager.setSimulatedPurchasedProductIDs([Self.monthly.id])
        XCTAssertTrue(manager.hasPro)
        XCTAssertEqual(manager.simulatedPurchasedProductIDs, Set([Self.monthly.id]))

        await manager.setSimulatedPurchasedProductIDs([])
        XCTAssertFalse(manager.hasPro)
        XCTAssertTrue(manager.simulatedPurchasedProductIDs.isEmpty)
    }

    func testSuccessfulPurchasePreservesExistingSimulatedPurchases() async {
        let lifetime = StoreProduct(
            id: "pro.lifetime",
            displayName: "Lifetime",
            description: "Lifetime Pro",
            displayPrice: "$79.99",
            price: 79.99
        )
        let configuration = PurchaseConfiguration(
            productIDs: [Self.monthly.id, lifetime.id],
            preferredProductID: Self.monthly.id,
            productLoadAttempts: 1
        )
        let manager = PurchaseManager(
            configuration: configuration,
            simulated: true,
            simulatedProducts: [Self.monthly, lifetime],
            simulatedOperationDelay: .milliseconds(0)
        )
        await manager.prepare()
        await manager.setSimulatedPurchasedProductIDs([lifetime.id])

        let outcome = await manager.purchase(Self.monthly)

        guard let outcome else {
            return XCTFail("Expected successful simulated purchase")
        }
        guard case .success = outcome else {
            return XCTFail("Expected successful simulated purchase")
        }
        XCTAssertEqual(
            manager.simulatedPurchasedProductIDs,
            Set([Self.monthly.id, lifetime.id])
        )
        XCTAssertTrue(manager.hasPro)
        XCTAssertEqual(manager.activeProduct?.id, lifetime.id)
    }

    func testCanInjectPurchaseOutcomes() async {
        let manager = makeManager()
        await manager.prepare()

        manager.setSimulatedPurchaseResult(.pending, for: Self.monthly.id)
        let pendingOutcome = await manager.purchase(Self.monthly)
        XCTAssertEqual(pendingOutcome, .pending)
        XCTAssertEqual(manager.activity, .pending(productID: Self.monthly.id))
        XCTAssertFalse(manager.hasPro)

        manager.clearActivity()
        manager.setSimulatedPurchaseResult(.userCancelled, for: Self.monthly.id)
        let cancelledOutcome = await manager.purchase(Self.monthly)
        XCTAssertEqual(cancelledOutcome, .userCancelled)
        XCTAssertEqual(manager.activity, .idle)
        XCTAssertFalse(manager.hasPro)

        let failure = PurchaseFailure(
            code: .networkUnavailable,
            message: "Simulated network failure."
        )
        manager.setSimulatedPurchaseResult(.failure(failure), for: Self.monthly.id)
        let failedOutcome = await manager.purchase(Self.monthly)
        XCTAssertNil(failedOutcome)
        XCTAssertEqual(manager.activity, .failed(failure))
        XCTAssertFalse(manager.hasPro)
    }

    func testCanInjectAndResetCatalogFailure() async {
        let manager = makeManager()
        await manager.prepare()

        await manager.setSimulatedProductLoadingFailure(.noProductsAvailable)
        XCTAssertEqual(manager.productLoadingState, .failed(.noProductsAvailable))

        await manager.resetSimulatedFailures()
        XCTAssertEqual(manager.productLoadingState, .loaded)
        XCTAssertEqual(manager.products, [Self.monthly])
    }

    func testCanInjectRestoreFailure() async {
        let manager = makeManager()
        await manager.prepare()
        let failure = PurchaseFailure(
            code: .networkUnavailable,
            message: "Simulated restore failure."
        )

        manager.setSimulatedRestoreFailure(failure)
        let outcome = await manager.restorePurchases()

        XCTAssertEqual(outcome, .failed(failure))
        XCTAssertEqual(manager.activity, .failed(failure))
    }

    func testResetSimulatedPurchasesAlsoClearsFailureInjection() async {
        let manager = makeManager()
        await manager.prepare()
        manager.setSimulatedPurchaseResult(.pending, for: Self.monthly.id)
        await manager.setSimulatedProductLoadingFailure(.noProductsAvailable)
        manager.setSimulatedRestoreFailure(.unknown)

        await manager.resetSimulatedPurchases()
        await manager.purchase(Self.monthly)

        XCTAssertTrue(manager.hasPro)
        XCTAssertEqual(manager.activity, .idle)
        XCTAssertEqual(manager.productLoadingState, .loaded)
    }

    func testRestoreSimulatedCatalogDefaultsUsesOriginalAppCatalog() async {
        let manager = makeManager()
        await manager.prepare()
        let yearly = StoreProduct(
            id: "pro.yearly",
            displayName: "Yearly",
            description: "Yearly Pro",
            displayPrice: "$39.99",
            price: 39.99,
            subscriptionPeriod: .init(value: 1, unit: .year)
        )
        await manager.configureSimulatedCatalog(
            configuration: PurchaseConfiguration(productIDs: [yearly.id]),
            products: [yearly]
        )

        XCTAssertEqual(manager.simulatedDefaultConfigurationSnapshot.productIDs, [Self.monthly.id])
        XCTAssertEqual(manager.simulatedDefaultCatalogProducts, [Self.monthly])

        await manager.restoreSimulatedCatalogDefaults()

        XCTAssertEqual(manager.simulatedConfigurationSnapshot.productIDs, [Self.monthly.id])
        XCTAssertEqual(manager.simulatedCatalogProducts, [Self.monthly])
        XCTAssertEqual(manager.products, [Self.monthly])
    }

    func testCatalogChangeDiscardsStaleProductLoadResult() async {
        let manager = PurchaseManager(
            configuration: PurchaseConfiguration(
                productIDs: [Self.monthly.id],
                productLoadAttempts: 1
            ),
            simulated: true,
            simulatedProducts: [Self.monthly],
            simulatedOperationDelay: .milliseconds(150)
        )
        let staleLoad = Task { await manager.loadProducts(force: true) }
        try? await Task.sleep(for: .milliseconds(20))

        let yearly = StoreProduct(
            id: "pro.yearly",
            displayName: "Yearly",
            description: "Yearly Pro",
            displayPrice: "$39.99",
            price: 39.99,
            subscriptionPeriod: .init(value: 1, unit: .year)
        )
        await manager.configureSimulatedCatalog(
            configuration: PurchaseConfiguration(
                productIDs: [yearly.id],
                productLoadAttempts: 1
            ),
            products: [yearly]
        )
        _ = await staleLoad.value

        XCTAssertEqual(manager.productLoadingState, .loaded)
        XCTAssertEqual(manager.products, [yearly])
    }

    private func makeManager() -> PurchaseManager {
        PurchaseManager(
            configuration: PurchaseConfiguration(
                productIDs: [Self.monthly.id],
                preferredProductID: Self.monthly.id,
                productLoadAttempts: 1
            ),
            simulated: true,
            simulatedProducts: [Self.monthly],
            simulatedOperationDelay: .milliseconds(0)
        )
    }

    private static let monthly = StoreProduct(
        id: "pro.monthly",
        displayName: "Monthly",
        description: "Monthly Pro",
        displayPrice: "$4.99",
        price: 4.99,
        subscriptionPeriod: .init(value: 1, unit: .month)
    )
}
#endif
