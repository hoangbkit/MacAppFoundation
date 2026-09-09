import Foundation
import Testing
@testable import MacAppFoundation

private actor ConsolidationAnalyticsStateStore: AppAnalyticsStateStoring {
    private var data: Data?

    func load() async throws -> Data? { data }
    func save(_ data: Data) async throws { self.data = data }
    func remove() async throws { data = nil }
}

private final class ConsolidationAnalyticsClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ value: Date) {
        self.value = value
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ value: Date) {
        lock.lock()
        self.value = value
        lock.unlock()
    }
}

private actor ConsolidationAnalyticsTransport: AppAnalyticsTransport {
    enum ResponseMode: Sendable {
        case success
        case reverseAcceptedDays
    }

    private var mode: ResponseMode = .success
    private var requests: [URLRequest] = []

    func setMode(_ mode: ResponseMode) {
        self.mode = mode
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let body = try consolidationRequestBody(request)
        let requestID = try #require(body["requestId"] as? String)
        let days = try #require(body["days"] as? [[String: Any]])
        let actualDays = days.compactMap { $0["day"] as? String }
        let acceptedDays: [String]
        switch mode {
        case .success:
            acceptedDays = actualDays
        case .reverseAcceptedDays:
            acceptedDays = actualDays.reversed()
        }

        let payload: [String: Any] = [
            "ok": true,
            "requestId": requestID,
            "acceptedDays": acceptedDays,
        ]
        return (
            try JSONSerialization.data(withJSONObject: payload),
            HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
        )
    }

    func capturedRequests() -> [URLRequest] { requests }
}

private func consolidationConfiguration(
    uploadInterval: TimeInterval = 10 * 24 * 60 * 60
) -> AppAnalyticsConfiguration {
    AppAnalyticsConfiguration(
        appID: "analytics-test",
        appKey: "test-key-123456789",
        baseURL: URL(string: "https://example.com")!,
        keychainService: "com.hoangbkit.MacAppFoundationConsolidationTests.\(UUID().uuidString)",
        stateStorageKey: "analytics-consolidation-state-\(UUID().uuidString)",
        appVersion: "1.2.3",
        uploadInterval: uploadInterval,
        transportRetryCount: 0
    )
}

private func consolidationDate(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
}

private func consolidationRequestBody(_ request: URLRequest) throws -> [String: Any] {
    guard let body = request.httpBody,
          let object = try JSONSerialization.jsonObject(with: body) as? [String: Any] else {
        throw AppAnalyticsError.invalidResponse
    }
    return object
}

@Test func analyticsRequiresExactAcceptedDayOrderingBeforeDroppingHistoricalState() async throws {
    let clock = ConsolidationAnalyticsClock(consolidationDate("2026-09-07T12:00:00Z"))
    let transport = ConsolidationAnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: consolidationConfiguration(),
        transport: transport,
        stateStore: ConsolidationAnalyticsStateStore(),
        now: { clock.now() }
    )

    try await client.track("first_event")

    clock.set(consolidationDate("2026-09-08T12:00:00Z"))
    try await client.track("second_event")
    #expect(try await client.pendingDayCount() == 2)

    await transport.setMode(.reverseAcceptedDays)
    await #expect(throws: AppAnalyticsError.self) {
        try await client.flush()
    }

    #expect(try await client.pendingDayCount() == 2)
    let request = try #require(await transport.capturedRequests().last)
    let body = try consolidationRequestBody(request)
    let days = try #require(body["days"] as? [[String: Any]])
    #expect(days.compactMap { $0["day"] as? String } == ["2026-09-07", "2026-09-08"])
}

@Test func analyticsRequestIDHeaderMatchesBodyRequestID() async throws {
    let timestamp = consolidationDate("2026-09-08T12:00:00Z")
    let transport = ConsolidationAnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: consolidationConfiguration(),
        transport: transport,
        stateStore: ConsolidationAnalyticsStateStore(),
        now: { timestamp }
    )

    try await client.track("generation_completed")

    let request = try #require(await transport.capturedRequests().first)
    let body = try consolidationRequestBody(request)
    let bodyRequestID = try #require(body["requestId"] as? String)
    #expect(request.value(forHTTPHeaderField: "X-Request-ID") == bodyRequestID)
}
