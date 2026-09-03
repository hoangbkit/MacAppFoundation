import Foundation

/// Selects the purchase backend used by ``PurchaseServiceFactory``.
public enum PurchaseServiceMode: String, Sendable, Equatable {
    case live
    case simulated

    /// Reads `MACAPPFOUNDATION_PURCHASE_MODE` from the launched app's environment.
    /// Unknown or missing values use `fallback`.
    public static func fromEnvironment(
        fallback: PurchaseServiceMode = .live,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> PurchaseServiceMode {
        guard let value = environment[PurchaseServiceFactory.environmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        else {
            return fallback
        }

        switch value {
        case "simulated", "simulation", "simulated-store", "fake", "mock":
            return .simulated
        case "live", "apple", "storekit", "real":
            return .live
        default:
            return fallback
        }
    }
}

/// Creates a live StoreKit service or, in Debug builds, an in-process simulator.
public enum PurchaseServiceFactory {
    public static let environmentKey = "MACAPPFOUNDATION_PURCHASE_MODE"

    /// Returns the mode that can actually run in the current build.
    /// Release builds always resolve to ``PurchaseServiceMode/live``.
    public static func effectiveMode(for requestedMode: PurchaseServiceMode) -> PurchaseServiceMode {
        #if DEBUG
        requestedMode
        #else
        .live
        #endif
    }

    @MainActor
    public static func make(
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
