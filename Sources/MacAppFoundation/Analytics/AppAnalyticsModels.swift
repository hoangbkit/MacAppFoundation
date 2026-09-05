import Foundation

public struct AppAnalyticsConfiguration: Sendable {
    public var appID: String
    public var appKey: String
    public var baseURL: URL
    public var keychainService: String
    public var stateStorageKey: String
    public var appVersion: String?
    public var uploadInterval: TimeInterval
    public var transportRetryCount: Int

    public init(
        appID: String,
        appKey: String,
        baseURL: URL,
        keychainService: String = "com.hoangbkit.MacAppFoundation.AppAnalytics",
        stateStorageKey: String? = nil,
        appVersion: String? = nil,
        uploadInterval: TimeInterval = 6 * 60 * 60,
        transportRetryCount: Int = 1
    ) {
        self.appID = appID
        self.appKey = appKey
        self.baseURL = baseURL
        self.keychainService = keychainService
        self.stateStorageKey = stateStorageKey
            ?? "com.hoangbkit.MacAppFoundation.analytics.\(appID)"
        self.appVersion = appVersion
        self.uploadInterval = max(0, uploadInterval)
        self.transportRetryCount = max(0, transportRetryCount)
    }
}

public enum AppAnalyticsError: Error, LocalizedError, Sendable, Equatable {
    case invalidConfiguration(String)
    case invalidEvent(String)
    case invalidResponse
    case transport(String)
    case server(code: String, message: String, retryAfter: String?)
    case storage(String)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message), .invalidEvent(let message),
             .transport(let message), .storage(let message):
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
