import Foundation

public enum ProductLoadingState: Sendable, Equatable {
    case idle
    case loading
    case loaded
    case failed(PurchaseFailure)
}

public enum PurchaseActivity: Sendable, Equatable {
    case idle
    case purchasing(productID: String)
    case restoring
    case pending(productID: String)
    case failed(PurchaseFailure)

    public var isBusy: Bool {
        switch self {
        case .purchasing, .restoring:
            true
        case .idle, .pending, .failed:
            false
        }
    }
}

public enum PurchaseOutcome: Sendable, Equatable {
    case success(EntitlementRecord)
    case pending
    case userCancelled
}

public enum RestoreOutcome: Sendable, Equatable {
    case restored
    case nothingToRestore
    case failed(PurchaseFailure)
}

public struct PurchaseFailure: Error, LocalizedError, Sendable, Equatable, Hashable {
    public enum Code: String, Sendable, Equatable {
        case noProductsAvailable
        case productUnavailable
        case purchaseNotAllowed
        case networkUnavailable
        case verificationFailed
        case storefrontUnavailable
        case notEntitled
        case system
        case timeout
        case userCancelled
        case unknown
    }

    public let code: Code
    public let message: String

    public init(code: Code, message: String) {
        self.code = code
        self.message = message
    }

    public var errorDescription: String? { message }

    public static let noProductsAvailable = PurchaseFailure(
        code: .noProductsAvailable,
        message: "No purchase options are available right now. Please try again shortly."
    )

    public static let productUnavailable = PurchaseFailure(
        code: .productUnavailable,
        message: "This purchase option is currently unavailable."
    )

    public static let verificationFailed = PurchaseFailure(
        code: .verificationFailed,
        message: "The App Store purchase could not be verified."
    )

    public static let unknown = PurchaseFailure(
        code: .unknown,
        message: "Something went wrong. Please try again."
    )

    public static let timeout = PurchaseFailure(
        code: .timeout,
        message: "The App Store isn't responding. Please try again."
    )

    public static let userCancelled = PurchaseFailure(
        code: .userCancelled,
        message: "Canceled."
    )
}
