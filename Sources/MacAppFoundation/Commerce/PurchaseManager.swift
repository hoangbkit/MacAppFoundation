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
    @ObservationIgnored private var serviceGeneration = 0
    @ObservationIgnored private var simulatedConfiguration: PurchaseConfiguration
    @ObservationIgnored private var simulatedProducts: [StoreProduct]
    @ObservationIgnored private let defaultSimulatedConfiguration: PurchaseConfiguration
    @ObservationIgnored private let defaultSimulatedProducts: [StoreProduct]
    @ObservationIgnored private let simulatedPersistenceKey: String?
    @ObservationIgnored private var simulatedOperationDelay: Duration
    @ObservationIgnored private var updateTask: Task<Void, Never>?
    @ObservationIgnored private var restoreTask: Task<RestoreOutcome, Never>?
    @ObservationIgnored private var restoreGeneration = 0
    @ObservationIgnored private var hasPrepared = false

    @ObservationIgnored private static let logger = Logger(
        subsystem: "com.macappfoundation.purchases",
        category: "restore"
    )

    /// Creates a purchase manager backed by live StoreKit by default.
    ///
    /// Set `simulated` to `true` in a Debug build to use MacAppFoundation's
    /// in-process simulator. Release builds always fall back to live StoreKit.
    public init(
        configuration: PurchaseConfiguration,
        simulated: Bool = false,
        simulatedProducts: [StoreProduct] = [],
        simulatedPersistenceKey: String? = nil,
        simulatedOperationDelay: Duration = .milliseconds(250)
    ) {
        self.configuration = configuration
        self.simulatedConfiguration = configuration
        self.simulatedProducts = simulatedProducts
        self.defaultSimulatedConfiguration = configuration
        self.defaultSimulatedProducts = simulatedProducts
        self.simulatedPersistenceKey = simulatedPersistenceKey
        self.simulatedOperationDelay = simulatedOperationDelay
        self.service = PurchaseServiceFactory.make(
            mode: simulated ? .simulated : .live,
            simulatedProducts: simulatedProducts,
            simulatedPersistenceKey: simulatedPersistenceKey,
            simulatedOperationDelay: simulatedOperationDelay
        )
    }

    /// Internal service injection used by deterministic package tests.
    init(
        configuration: PurchaseConfiguration,
        service: any PurchaseServing
    ) {
        self.configuration = configuration
        self.simulatedConfiguration = configuration
        self.simulatedProducts = []
        self.defaultSimulatedConfiguration = configuration
        self.defaultSimulatedProducts = []
        self.simulatedPersistenceKey = nil
        self.simulatedOperationDelay = .milliseconds(250)
        self.service = service
    }

    deinit {
        updateTask?.cancel()
        restoreTask?.cancel()
    }

    /// The simple entitlement property apps should use for normal feature gating.
    public var hasPro: Bool {
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

    /// Product identifiers that currently grant Pro, including Debug simulator edits.
    public var entitledProductIDs: Set<String> {
        activeConfiguration.entitledProductIDs
    }

    /// Loaded products that both grant Pro and use a supported entitlement product type.
    public var entitlementProducts: [StoreProduct] {
        products.filter {
            entitledProductIDs.contains($0.id) && $0.isSupportedProProduct
        }
    }

    public var preferredProduct: StoreProduct? {
        if let preferredProductID = activeConfiguration.preferredProductID,
           let preferredProduct = products.first(where: { $0.id == preferredProductID }) {
            return preferredProduct
        }
        return products.first
    }

    /// Preferred product restricted to the products that can actually unlock Pro.
    public var preferredEntitlementProduct: StoreProduct? {
        if let preferredProductID = activeConfiguration.preferredProductID,
           let preferredProduct = entitlementProducts.first(where: { $0.id == preferredProductID }) {
            return preferredProduct
        }
        return entitlementProducts.first
    }

    #if DEBUG
    /// Whether this manager is currently backed by the in-process purchase simulator.
    public var isUsingSimulatedPurchases: Bool {
        service is SimulatedPurchaseService
    }

    /// The configuration currently used by the Debug simulator.
    public var simulatedConfigurationSnapshot: PurchaseConfiguration {
        simulatedConfiguration
    }

    /// The app-supplied simulator configuration before Developer Tools edits.
    public var simulatedDefaultConfigurationSnapshot: PurchaseConfiguration {
        defaultSimulatedConfiguration
    }

    /// All products retained for the Debug simulator, including products disabled by its configuration.
    public var simulatedCatalogProducts: [StoreProduct] {
        simulatedProducts
    }

    /// The app-supplied simulator catalog before Developer Tools edits.
    public var simulatedDefaultCatalogProducts: [StoreProduct] {
        defaultSimulatedProducts
    }

    /// The currently active simulated entitlement product identifiers.
    public var simulatedPurchasedProductIDs: Set<String> {
        (service as? SimulatedPurchaseService)?.purchasedProductIDs ?? []
    }

    /// Artificial latency applied to simulated StoreKit operations.
    public var simulatedPurchaseOperationDelay: Duration {
        simulatedOperationDelay
    }
    #endif

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

        let generation = serviceGeneration
        let service = service
        let configuration = activeConfiguration
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
                guard generation == serviceGeneration else { return }

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
                guard generation == serviceGeneration else { return }
                lastFailure = Self.mapFailure(error)
                guard attempt < configuration.productLoadAttempts else {
                    break
                }

                let delay = UInt64(attempt) * 350_000_000
                try? await Task.sleep(nanoseconds: delay)
                guard generation == serviceGeneration else { return }
            }
        }

        guard generation == serviceGeneration else { return }
        productLoadingState = .failed(lastFailure)
    }

    public func refreshEntitlements() async {
        _ = await refreshEntitlementsWithRecords()
    }

    @discardableResult
    private func refreshEntitlementsWithRecords() async -> [EntitlementRecord] {
        let generation = serviceGeneration
        let service = service
        let entitledProductIDs = activeConfiguration.entitledProductIDs
        let records = await service.currentEntitlements()
        guard generation == serviceGeneration else { return [] }

        entitlementState = EntitlementEvaluator.evaluate(
            records,
            entitledProductIDs: entitledProductIDs
        )
        return records
    }

    /// Attempts a purchase and returns the actual StoreKit/simulator outcome.
    /// Failures are exposed through ``activity`` and return `nil`.
    @discardableResult
    public func purchase(_ product: StoreProduct) async -> PurchaseOutcome? {
        guard !isBusy else {
            return nil
        }

        guard activeConfiguration.productIDs.contains(product.id),
              (product(withID: product.id) ?? product).isSupportedProProduct
        else {
            activity = .failed(.productUnavailable)
            return nil
        }

        let generation = serviceGeneration
        let service = service
        activity = .purchasing(productID: product.id)

        do {
            let outcome = try await service.purchase(productID: product.id)
            guard generation == serviceGeneration else { return nil }

            switch outcome {
            case .success:
                await refreshEntitlements()
                guard generation == serviceGeneration else { return nil }
                activity = .idle
            case .pending:
                activity = .pending(productID: product.id)
            case .userCancelled:
                activity = .idle
            }
            return outcome
        } catch {
            guard generation == serviceGeneration else { return nil }
            activity = .failed(Self.mapFailure(error))
            return nil
        }
    }

    /// Restores purchases by syncing with the App Store and re-evaluating entitlements.
    /// Concurrent restore calls coalesce into the in-flight attempt. A restore never starts
    /// while a purchase is already running.
    @discardableResult
    public func restorePurchases(timeout: Duration? = nil) async -> RestoreOutcome {
        if let restoreTask {
            return await restoreTask.value
        }
        guard !isPurchasing else {
            return .failed(.operationInProgress)
        }

        restoreGeneration += 1
        let generation = restoreGeneration
        let capturedServiceGeneration = serviceGeneration
        activity = .restoring

        let task = Task { [weak self] () -> RestoreOutcome in
            guard let self else { return .nothingToRestore }
            return await self.performRestore(
                timeout: timeout,
                generation: generation,
                serviceGeneration: capturedServiceGeneration
            )
        }
        restoreTask = task

        defer {
            if restoreGeneration == generation {
                restoreTask = nil
            }
        }
        return await task.value
    }

    /// Stops waiting on the in-flight restore without disturbing an unrelated purchase.
    public func cancelRestore() {
        guard restoreTask != nil || isRestoring else { return }

        restoreGeneration += 1
        restoreTask?.cancel()
        restoreTask = nil
        if isRestoring {
            activity = .idle
        }
    }

    private func performRestore(
        timeout: Duration?,
        generation: Int,
        serviceGeneration: Int
    ) async -> RestoreOutcome {
        do {
            try await runSyncOperation(timeout: timeout)
            guard restoreGeneration == generation,
                  self.serviceGeneration == serviceGeneration
            else {
                return .failed(.userCancelled)
            }

            let records = await refreshEntitlementsWithRecords()
            guard restoreGeneration == generation,
                  self.serviceGeneration == serviceGeneration
            else {
                return .failed(.userCancelled)
            }

            Self.logRestoreDiagnostics(
                records,
                entitledProductIDs: activeConfiguration.entitledProductIDs
            )

            activity = .idle
            return hasPro ? .restored : .nothingToRestore
        } catch {
            guard restoreGeneration == generation,
                  self.serviceGeneration == serviceGeneration
            else {
                return .failed(.userCancelled)
            }

            let failure = Self.mapFailure(error)
            activity = failure.code == .userCancelled ? .idle : .failed(failure)
            return .failed(failure)
        }
    }

    private func runSyncOperation(timeout: Duration?) async throws {
        let service = service
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

    #if DEBUG
    /// Switches this manager between live StoreKit and the in-process simulator.
    /// Switching is ignored while a purchase or restore is in progress.
    public func setSimulatedPurchasesEnabled(_ enabled: Bool) async {
        guard !isBusy, isUsingSimulatedPurchases != enabled else {
            return
        }

        invalidateServiceOperations()
        service = PurchaseServiceFactory.make(
            mode: enabled ? .simulated : .live,
            simulatedProducts: simulatedProducts,
            simulatedPersistenceKey: simulatedPersistenceKey,
            simulatedOperationDelay: simulatedOperationDelay
        )
        resetObservableStateForServiceChange()
        await prepare()
    }

    /// Replaces the Debug simulator's catalog without changing the live StoreKit configuration.
    ///
    /// Disabled products may remain in the simulator catalog; only `configuration.productIDs`
    /// are loaded by simulated purchase surfaces. Active simulator edits preserve current
    /// entitlement and failure injection for products that still exist.
    public func configureSimulatedCatalog(
        configuration: PurchaseConfiguration,
        products: [StoreProduct]
    ) async {
        guard !isBusy else { return }

        simulatedConfiguration = configuration
        simulatedProducts = products

        guard let simulatedService = service as? SimulatedPurchaseService else {
            return
        }

        invalidateServiceOperations()
        simulatedService.replaceProducts(products)
        resetObservableStateForServiceChange()
        await prepare()
    }

    /// Restores the app-supplied Debug simulator catalog and configuration.
    public func restoreSimulatedCatalogDefaults() async {
        await configureSimulatedCatalog(
            configuration: defaultSimulatedConfiguration,
            products: defaultSimulatedProducts
        )
    }

    /// Sets the simulated outcome for a product's future purchase attempts.
    public func setSimulatedPurchaseResult(
        _ result: SimulatedPurchaseResult,
        for productID: String
    ) {
        (service as? SimulatedPurchaseService)?.setPurchaseResult(result, for: productID)
    }

    /// Sets the simulated entitlement directly and refreshes observable entitlement state.
    public func setSimulatedPurchasedProductIDs(_ productIDs: Set<String>) async {
        guard !isBusy, let simulatedService = service as? SimulatedPurchaseService else {
            return
        }
        simulatedService.setPurchasedProductIDs(productIDs)
        activity = .idle
        await refreshEntitlements()
    }

    /// Injects or clears product-catalog loading failure and immediately reloads the catalog.
    public func setSimulatedProductLoadingFailure(_ failure: PurchaseFailure?) async {
        guard !isBusy, let simulatedService = service as? SimulatedPurchaseService else {
            return
        }
        simulatedService.setProductLoadingFailure(failure)
        await loadProducts(force: true)
    }

    /// Injects or clears restore failure for future simulated restore attempts.
    public func setSimulatedRestoreFailure(_ failure: PurchaseFailure?) {
        guard !isBusy else { return }
        (service as? SimulatedPurchaseService)?.setSyncFailure(failure)
    }

    /// Updates artificial latency for subsequent simulated StoreKit operations.
    public func setSimulatedOperationDelay(_ delay: Duration) {
        guard !isBusy else { return }
        simulatedOperationDelay = delay
        (service as? SimulatedPurchaseService)?.setOperationDelay(delay)
    }

    /// Clears purchase, catalog, and restore failure injection while keeping entitlement state.
    public func resetSimulatedFailures() async {
        guard !isBusy, let simulatedService = service as? SimulatedPurchaseService else {
            return
        }
        simulatedService.resetFailures()
        activity = .idle
        await loadProducts(force: true)
    }

    /// Clears simulator state and refreshes the observable entitlement and product state.
    public func resetSimulatedPurchases() async {
        guard !isBusy, let simulatedService = service as? SimulatedPurchaseService else {
            return
        }

        simulatedService.reset()
        activity = .idle
        await refreshEntitlements()
        await loadProducts(force: true)
    }
    #endif

    private var activeConfiguration: PurchaseConfiguration {
        #if DEBUG
        if service is SimulatedPurchaseService {
            return simulatedConfiguration
        }
        #endif
        return configuration
    }

    private func invalidateServiceOperations() {
        serviceGeneration &+= 1
        updateTask?.cancel()
        updateTask = nil
    }

    private func resetObservableStateForServiceChange() {
        hasPrepared = false
        products = []
        productLoadingState = .idle
        entitlementState = .checking
        activity = .idle
    }

    private func startObservingTransactions() {
        updateTask?.cancel()
        let generation = serviceGeneration
        let service = service
        let managedProductIDs = Set(activeConfiguration.productIDs)

        updateTask = Task { [weak self, service] in
            for await _ in service.entitlementUpdates(for: managedProductIDs) {
                guard !Task.isCancelled else {
                    return
                }
                guard let self, generation == self.serviceGeneration else {
                    return
                }
                await self.refreshEntitlements()
                guard generation == self.serviceGeneration else { return }
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
