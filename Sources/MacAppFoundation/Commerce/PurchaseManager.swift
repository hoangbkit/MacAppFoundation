import Foundation
import Observation
import OSLog
import StoreKit

@MainActor
@Observable
public final class PurchaseManager {
    public private(set) var products: [StoreProduct] = []
    public private(set) var productLoadingState: ProductLoadingState = .idle
    public private(set) var entitlementState: EntitlementState = .checking
    public private(set) var activity: PurchaseActivity = .idle

    public let configuration: PurchaseConfiguration

    @ObservationIgnored private var service: any PurchaseServing
    @ObservationIgnored private var updateTask: Task<Void, Never>?
    @ObservationIgnored private var restoreTask: Task<RestoreOutcome, Never>?
    @ObservationIgnored private var restoreGeneration = 0
    @ObservationIgnored private var hasPrepared = false

    @ObservationIgnored private static let logger = Logger(
        subsystem: "com.macappfoundation.purchases",
        category: "restore"
    )

    /// Creates a purchase manager backed by live StoreKit.
    public init(configuration: PurchaseConfiguration) {
        self.configuration = configuration
        self.service = LiveStoreKitService()
    }

    /// Creates a purchase manager with an injected service, primarily for deterministic testing.
    public init(
        configuration: PurchaseConfiguration,
        service: any PurchaseServing
    ) {
        self.configuration = configuration
        self.service = service
    }

    deinit {
        updateTask?.cancel()
    }

    /// The simple entitlement property apps should use for normal feature gating.
    public var hasPro: Bool {
        entitlementState.isActive
    }

    public var isEntitled: Bool {
        entitlementState.isActive
    }

    public var isBusy: Bool {
        activity.isBusy
    }

    public var isPurchasing: Bool {
        if case .purchasing = activity {
            return true
        }
        return false
    }

    public var isRestoring: Bool {
        if case .restoring = activity {
            return true
        }
        return false
    }

    public var preferredProduct: StoreProduct? {
        if let preferredProductID = configuration.preferredProductID,
           let preferredProduct = products.first(where: { $0.id == preferredProductID }) {
            return preferredProduct
        }
        return products.first
    }

    public func product(withID productID: String) -> StoreProduct? {
        products.first(where: { $0.id == productID })
    }

    /// Starts transaction observation, verifies entitlements, and loads the product catalog.
    /// Calling this method repeatedly is safe.
    public func prepare() async {
        if !hasPrepared {
            hasPrepared = true
            startObservingTransactions()
        }

        await refreshEntitlements()
        await loadProducts()
    }

    public func loadProducts(force: Bool = false) async {
        if !force, productLoadingState == .loaded || productLoadingState == .loading {
            return
        }

        guard !configuration.productIDs.isEmpty else {
            products = []
            productLoadingState = .failed(.noProductsAvailable)
            return
        }

        productLoadingState = .loading
        var lastFailure = PurchaseFailure.noProductsAvailable

        for attempt in 1...configuration.productLoadAttempts {
            do {
                let loadedProducts = try await service.products(for: configuration.productIDs)
                let orderedProducts = ProductCatalog.ordered(
                    loadedProducts,
                    using: configuration.productIDs
                )

                guard !orderedProducts.isEmpty else {
                    throw PurchaseFailure.noProductsAvailable
                }

                products = orderedProducts
                productLoadingState = .loaded
                return
            } catch {
                lastFailure = Self.mapFailure(error)
                guard attempt < configuration.productLoadAttempts else {
                    break
                }

                let delay = UInt64(attempt) * 350_000_000
                try? await Task.sleep(nanoseconds: delay)
            }
        }

        productLoadingState = .failed(lastFailure)
    }

    public func refreshEntitlements() async {
        _ = await refreshEntitlementsWithRecords()
    }

    @discardableResult
    private func refreshEntitlementsWithRecords() async -> [EntitlementRecord] {
        let records = await service.currentEntitlements()
        entitlementState = EntitlementEvaluator.evaluate(
            records,
            entitledProductIDs: configuration.entitledProductIDs
        )
        return records
    }

    public func purchase(_ product: StoreProduct) async {
        guard !isBusy else {
            return
        }

        guard configuration.productIDs.contains(product.id) else {
            activity = .failed(.productUnavailable)
            return
        }

        activity = .purchasing(productID: product.id)

        do {
            let outcome = try await service.purchase(productID: product.id)
            switch outcome {
            case .success:
                await refreshEntitlements()
                activity = .idle
            case .pending:
                activity = .pending(productID: product.id)
            case .userCancelled:
                activity = .idle
            }
        } catch {
            activity = .failed(Self.mapFailure(error))
        }
    }

    /// Restores purchases by syncing with the App Store and re-evaluating entitlements.
    /// Concurrent calls coalesce into the in-flight attempt.
    @discardableResult
    public func restorePurchases(timeout: Duration? = nil) async -> RestoreOutcome {
        if let restoreTask {
            return await restoreTask.value
        }

        restoreGeneration += 1
        let generation = restoreGeneration
        activity = .restoring

        let task = Task { [weak self] () -> RestoreOutcome in
            guard let self else { return .nothingToRestore }
            return await self.performRestore(timeout: timeout, generation: generation)
        }
        restoreTask = task

        defer {
            if restoreGeneration == generation {
                restoreTask = nil
            }
        }
        return await task.value
    }

    /// Stops waiting on the in-flight restore and resets purchase activity.
    public func cancelRestore() {
        guard restoreTask != nil || isBusy else { return }

        restoreGeneration += 1
        restoreTask?.cancel()
        restoreTask = nil
        activity = .idle
    }

    private func performRestore(timeout: Duration?, generation: Int) async -> RestoreOutcome {
        do {
            try await runSyncOperation(timeout: timeout)
            guard restoreGeneration == generation else {
                return .failed(.userCancelled)
            }

            let records = await refreshEntitlementsWithRecords()
            Self.logRestoreDiagnostics(
                records,
                entitledProductIDs: configuration.entitledProductIDs
            )
            guard restoreGeneration == generation else {
                return .failed(.userCancelled)
            }

            activity = .idle
            return isEntitled ? .restored : .nothingToRestore
        } catch {
            guard restoreGeneration == generation else {
                return .failed(.userCancelled)
            }

            let failure = Self.mapFailure(error)
            activity = failure.code == .userCancelled ? .idle : .failed(failure)
            return .failed(failure)
        }
    }

    private func runSyncOperation(timeout: Duration?) async throws {
        guard let timeout else {
            try await service.sync()
            return
        }

        let gate = RestoreGate()
        return try await withCheckedThrowingContinuation { continuation in
            gate.activate(continuation)

            Task { [service, gate] in
                do {
                    try await service.sync()
                    gate.resumeReturning()
                } catch {
                    gate.resumeThrowing(error)
                }
            }

            let timeoutTask = Task { [gate] in
                try? await Task.sleep(for: timeout)
                gate.resumeThrowing(PurchaseFailure.timeout)
            }
            gate.attachTimeoutTask(timeoutTask)
        }
    }

    @MainActor
    private final class RestoreGate {
        private var continuation: CheckedContinuation<Void, Error>?
        private var timeoutTask: Task<Void, Never>?
        private var didFinish = false

        func activate(_ continuation: CheckedContinuation<Void, Error>) {
            self.continuation = continuation
        }

        func attachTimeoutTask(_ task: Task<Void, Never>) {
            guard !didFinish else {
                task.cancel()
                return
            }
            timeoutTask = task
        }

        func resumeReturning() {
            finish { $0.resume(returning: ()) }
        }

        func resumeThrowing(_ error: Error) {
            finish { $0.resume(throwing: error) }
        }

        private func finish(_ resume: (CheckedContinuation<Void, Error>) -> Void) {
            guard !didFinish, let continuation else { return }
            didFinish = true
            self.continuation = nil
            timeoutTask?.cancel()
            timeoutTask = nil
            resume(continuation)
        }
    }

    private static func logRestoreDiagnostics(
        _ records: [EntitlementRecord],
        entitledProductIDs: Set<String>
    ) {
        #if DEBUG
        let returnedProductIDs = Set(records.map(\.productID))
        let matchedIDs = returnedProductIDs.intersection(entitledProductIDs)

        if matchedIDs.isEmpty, !returnedProductIDs.isEmpty {
            let returnedList = returnedProductIDs.sorted().joined(separator: ", ")
            let configuredList = entitledProductIDs.sorted().joined(separator: ", ")
            logger.fault("""
            Restore found transactions for [\(returnedList, privacy: .public)] but none match \
            the configured entitlement products [\(configuredList, privacy: .public)].
            """)
        } else if matchedIDs.count < returnedProductIDs.count {
            let unmatchedList = returnedProductIDs
                .subtracting(entitledProductIDs)
                .sorted()
                .joined(separator: ", ")
            logger.notice("""
            Restore matched \(matchedIDs.count) of \(returnedProductIDs.count) transaction(s), \
            ignoring [\(unmatchedList, privacy: .public)].
            """)
        }
        #endif
    }

    public func clearActivity() {
        activity = .idle
    }

    private func startObservingTransactions() {
        updateTask?.cancel()
        updateTask = Task { [weak self, service] in
            for await _ in service.entitlementUpdates() {
                guard !Task.isCancelled else {
                    return
                }
                guard let self else {
                    return
                }
                await self.refreshEntitlements()
                if case .pending = self.activity {
                    self.activity = .idle
                }
            }
        }
    }

    private static func mapFailure(_ error: Error) -> PurchaseFailure {
        if let failure = error as? PurchaseFailure {
            return failure
        }

        if error is CancellationError {
            return .userCancelled
        }

        if let storeKitError = error as? StoreKitError {
            switch storeKitError {
            case .networkError:
                return PurchaseFailure(
                    code: .networkUnavailable,
                    message: "Check your internet connection and try again."
                )
            case .notAvailableInStorefront:
                return PurchaseFailure(
                    code: .storefrontUnavailable,
                    message: "This purchase is not available in your App Store region."
                )
            case .notEntitled:
                return PurchaseFailure(
                    code: .notEntitled,
                    message: "This Apple ID is not entitled to the purchase."
                )
            case .unsupported:
                return PurchaseFailure(
                    code: .system,
                    message: "This purchase is not supported on this Mac."
                )
            case .systemError:
                return PurchaseFailure(
                    code: .system,
                    message: "The App Store could not complete the request. Please try again."
                )
            case .userCancelled:
                return .userCancelled
            case .unknown:
                return .unknown
            @unknown default:
                return .unknown
            }
        }

        if let purchaseError = error as? Product.PurchaseError {
            switch purchaseError {
            case .productUnavailable:
                return .productUnavailable
            case .purchaseNotAllowed:
                return PurchaseFailure(
                    code: .purchaseNotAllowed,
                    message: "Purchases are restricted on this Mac."
                )
            case .ineligibleForOffer:
                return PurchaseFailure(
                    code: .productUnavailable,
                    message: "This offer is not available for this Apple ID."
                )
            case .invalidOfferIdentifier,
                 .invalidOfferPrice,
                 .invalidOfferSignature,
                 .invalidQuantity,
                 .missingOfferParameters:
                return PurchaseFailure(
                    code: .productUnavailable,
                    message: "The selected offer could not be applied."
                )
            @unknown default:
                return .unknown
            }
        }

        return .unknown
    }
}
