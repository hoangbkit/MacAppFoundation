#if DEBUG
import Foundation

/// The result the simulator returns for a product's next and subsequent purchases.
public enum SimulatedPurchaseResult: Sendable, Equatable {
    case success
    case pending
    case userCancelled
    case failure(PurchaseFailure)
}

/// A lightweight in-process purchase backend for interactive Debug builds.
///
/// This service never contacts App Store Connect and never creates StoreKit transactions.
/// It is excluded from Release builds.
@MainActor
final class SimulatedPurchaseService: PurchaseServing {
    private(set) var purchasedProductIDs: Set<String>

    private var products: [StoreProduct]
    private var productsByID: [String: StoreProduct]
    private let persistenceKey: String?
    private let userDefaults: UserDefaults
    private var operationDelay: Duration

    private var purchaseResults: [String: SimulatedPurchaseResult]
    private var productLoadingFailure: PurchaseFailure?
    private var syncFailure: PurchaseFailure?
    private var purchaseDates: [String: Date] = [:]
    private var updateContinuations: [UUID: AsyncStream<Void>.Continuation] = [:]

    init(
        products: [StoreProduct],
        initiallyPurchasedProductIDs: Set<String> = [],
        purchaseResults: [String: SimulatedPurchaseResult] = [:],
        persistenceKey: String? = nil,
        userDefaults: UserDefaults = .standard,
        operationDelay: Duration = .milliseconds(250)
    ) {
        self.products = products
        self.productsByID = Self.indexProducts(products)
        self.purchaseResults = purchaseResults
        self.persistenceKey = persistenceKey
        self.userDefaults = userDefaults
        self.operationDelay = operationDelay

        let persistedProductIDs = persistenceKey.flatMap { key -> Set<String>? in
            guard userDefaults.object(forKey: key) != nil else {
                return nil
            }
            return Set(userDefaults.stringArray(forKey: key) ?? [])
        }
        let startingProductIDs = persistedProductIDs ?? initiallyPurchasedProductIDs
        self.purchasedProductIDs = startingProductIDs.intersection(Set(products.map(\.id)))
    }

    func products(for identifiers: [String]) async throws -> [StoreProduct] {
        await waitForSimulationDelay()
        if let productLoadingFailure {
            throw productLoadingFailure
        }

        let requestedIDs = Set(identifiers)
        return products.filter { requestedIDs.contains($0.id) }
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        await waitForSimulationDelay()
        guard let product = productsByID[productID] else {
            throw PurchaseFailure.productUnavailable
        }

        switch purchaseResults[productID] ?? .success {
        case .success:
            purchasedProductIDs.insert(productID)
            let purchaseDate = Date.now
            purchaseDates[productID] = purchaseDate
            persistPurchasedProductIDs()
            publishEntitlementUpdate()
            return .success(
                EntitlementRecord(
                    productID: product.id,
                    purchaseDate: purchaseDate
                )
            )
        case .pending:
            return .pending
        case .userCancelled:
            return .userCancelled
        case .failure(let failure):
            throw failure
        }
    }

    func currentEntitlements() async -> [EntitlementRecord] {
        await waitForSimulationDelay()
        return purchasedProductIDs.sorted().map { productID in
            EntitlementRecord(
                productID: productID,
                purchaseDate: purchaseDates[productID] ?? .now
            )
        }
    }

    func entitlementUpdates(for productIDs: Set<String>) -> AsyncStream<Void> {
        let identifier = UUID()
        return AsyncStream { continuation in
            updateContinuations[identifier] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.updateContinuations[identifier] = nil
                }
            }
        }
    }

    func sync() async throws {
        await waitForSimulationDelay()
        if let syncFailure {
            throw syncFailure
        }
    }

    /// Replaces the simulated product catalog while retaining current failure injection,
    /// latency, and any entitlement that still exists in the new catalog.
    func replaceProducts(_ products: [StoreProduct]) {
        self.products = products
        self.productsByID = Self.indexProducts(products)

        let validProductIDs = Set(products.map(\.id))
        purchasedProductIDs.formIntersection(validProductIDs)
        purchaseDates = purchaseDates.filter { validProductIDs.contains($0.key) }
        purchaseResults = purchaseResults.filter { validProductIDs.contains($0.key) }
        persistPurchasedProductIDs()
    }

    /// Changes the behavior for future purchases of a product.
    func setPurchaseResult(
        _ result: SimulatedPurchaseResult,
        for productID: String
    ) {
        purchaseResults[productID] = result
    }

    /// Simulates a catalog-loading failure. Pass `nil` to resume loading products.
    func setProductLoadingFailure(_ failure: PurchaseFailure?) {
        productLoadingFailure = failure
    }

    /// Simulates a restore failure. Pass `nil` to resume successful restores.
    func setSyncFailure(_ failure: PurchaseFailure?) {
        syncFailure = failure
    }

    /// Replaces the active simulated entitlements with known catalog products.
    func setPurchasedProductIDs(_ productIDs: Set<String>) {
        purchasedProductIDs = productIDs.intersection(Set(productsByID.keys))
        let now = Date.now
        purchaseDates = Dictionary(
            uniqueKeysWithValues: purchasedProductIDs.map { ($0, now) }
        )
        persistPurchasedProductIDs()
        publishEntitlementUpdate()
    }

    /// Updates artificial latency for subsequent simulated StoreKit operations.
    func setOperationDelay(_ delay: Duration) {
        operationDelay = delay
    }

    /// Clears injected failures while preserving the simulated entitlement.
    func resetFailures() {
        purchaseResults = [:]
        productLoadingFailure = nil
        syncFailure = nil
    }

    /// Clears all simulated transactions and entitlements.
    func reset() {
        purchasedProductIDs = []
        purchaseDates = [:]
        resetFailures()
        if let persistenceKey {
            userDefaults.removeObject(forKey: persistenceKey)
        }
        publishEntitlementUpdate()
    }

    private func waitForSimulationDelay() async {
        try? await Task.sleep(for: operationDelay)
    }

    private func persistPurchasedProductIDs() {
        guard let persistenceKey else {
            return
        }
        userDefaults.set(purchasedProductIDs.sorted(), forKey: persistenceKey)
    }

    private func publishEntitlementUpdate() {
        for continuation in updateContinuations.values {
            continuation.yield()
        }
    }

    private static func indexProducts(_ products: [StoreProduct]) -> [String: StoreProduct] {
        Dictionary(
            products.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }
}
#endif
