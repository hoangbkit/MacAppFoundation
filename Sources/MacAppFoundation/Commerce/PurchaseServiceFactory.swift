import Foundation

/// Selects the internal purchase backend used by ``PurchaseServiceFactory``.
enum PurchaseServiceMode: Sendable, Equatable {
    case live
    case simulated
}

/// Creates the package's live StoreKit service or, in Debug builds, its in-process simulator.
enum PurchaseServiceFactory {
    /// Returns the mode that can actually run in the current build.
    /// Release builds always resolve to live StoreKit.
    static func effectiveMode(for requestedMode: PurchaseServiceMode) -> PurchaseServiceMode {
        #if DEBUG
        requestedMode
        #else
        .live
        #endif
    }

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
