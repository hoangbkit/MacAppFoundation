import Foundation

/// Where an `AppAnalyticsClient` keeps its installation identity and daily counters.
public enum AppAnalyticsStorageMode: String, CaseIterable, Equatable, Hashable, Sendable {
    /// Persists the installation ID in the Keychain and daily counters in `UserDefaults`.
    /// This is the default.
    case persisted
    /// Keeps the installation ID and daily counters in memory for the lifetime of the
    /// client instance only. Neither the Keychain nor `UserDefaults` is read or written,
    /// and every new client starts with a fresh installation ID and empty counters.
    case inMemory
}

public struct AppAnalyticsConfiguration: Sendable {
    /// Default automatic upload interval, in seconds.
    public static let defaultUploadInterval: TimeInterval = 20

    public var appID: String
    public var appKey: String?
    public var baseURL: URL
    public var enabled: Bool
    public var keychainService: String
    public var stateStorageKey: String
    public var appVersion: String?
    public var uploadInterval: TimeInterval
    public var transportRetryCount: Int
    /// Storage used by the convenience initializer. A state store injected through
    /// `AppAnalyticsClient.init(configuration:transport:stateStore:)` always wins for
    /// daily counters; the storage mode still controls the installation identity.
    public var storageMode: AppAnalyticsStorageMode

    public init(
        appID: String,
        appKey: String? = nil,
        baseURL: URL,
        enabled: Bool = true,
        keychainService: String = "com.hoangbkit.MacAppFoundation.AppAnalytics",
        stateStorageKey: String? = nil,
        appVersion: String? = nil,
        uploadInterval: TimeInterval = AppAnalyticsConfiguration.defaultUploadInterval,
        transportRetryCount: Int = 1,
        storageMode: AppAnalyticsStorageMode = .persisted
    ) {
        self.appID = appID
        self.appKey = appKey
        self.enabled = enabled
        self.baseURL = ProcessInfo.processInfo.environment["CI"] == nil
            ? baseURL
            : URL(string: "http://localhost:1")!
        self.keychainService = keychainService
        self.stateStorageKey = stateStorageKey
            ?? "com.hoangbkit.MacAppFoundation.analytics.\(appID)"
        self.appVersion = appVersion
        self.uploadInterval = max(0, uploadInterval)
        self.transportRetryCount = max(0, transportRetryCount)
        self.storageMode = storageMode
    }
}

public enum AppAnalyticsErrorSeverity: String, Codable, Sendable {
    case error
    case fatal
}

public enum AppAnalyticsError: Error, LocalizedError, Sendable, Equatable {
    case invalidConfiguration(String)
    case invalidEvent(String)
    case invalidError(String)
    case invalidResponse
    case transport(String)
    case server(code: String, message: String, retryAfter: String?)
    case storage(String)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message), .invalidEvent(let message),
             .invalidError(let message), .transport(let message), .storage(let message):
            message
        case .invalidResponse:
            "The analytics service returned an invalid response."
        case .server(_, let message, _):
            message
        }
    }
}

public protocol AppAnalyticsTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionAppAnalyticsTransport: AppAnalyticsTransport, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw AppAnalyticsError.invalidResponse
        }
        return (data, response)
    }
}

public protocol AppAnalyticsStateStoring: Sendable {
    func load() async throws -> Data?
    func save(_ data: Data) async throws
    func remove() async throws
}

public actor UserDefaultsAppAnalyticsStateStore: AppAnalyticsStateStoring {
    private let storageKey: String

    public init(storageKey: String) {
        self.storageKey = storageKey
    }

    public func load() async throws -> Data? {
        UserDefaults.standard.data(forKey: storageKey)
    }

    public func save(_ data: Data) async throws {
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    public func remove() async throws {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

/// A process-local state store used by `AppAnalyticsStorageMode.inMemory`.
///
/// Nothing it holds survives the lifetime of the store instance, and it never touches
/// `UserDefaults` or any other persistent storage.
public actor InMemoryAppAnalyticsStateStore: AppAnalyticsStateStoring {
    private var data: Data?

    public init() {}

    public func load() async throws -> Data? {
        data
    }

    public func save(_ data: Data) async throws {
        self.data = data
    }

    public func remove() async throws {
        data = nil
    }
}
