import Foundation

/// Selects the internal purchase backend used by ``PurchaseServiceFactory``.
enum PurchaseServiceMode: Sendable, Equatable {
    case live
    case simulated
}

/// Creates the package's live StoreKit service or, in Debug builds, its in-process simulator.
enum PurchaseServiceFactory {
    @MainActor
    static func make(
        mode requestedMode: PurchaseServiceMode = .live,
        simulatedProducts: [StoreProduct] = [],
        simulatedPersistenceKey: String? = nil,
        simulatedOperationDelay: Duration = .milliseconds(250)
    ) -> any PurchaseServing {
        #if DEBUG
        if requestedMode == .simulated {
            return SimulatedPurchaseService(
                products: simulatedProducts,
                persistenceKey: simulatedPersistenceKey,
                operationDelay: simulatedOperationDelay
            )
        }
        #endif

        return LiveStoreKitService()
    }
}
