import Foundation
import Testing
@testable import MacAppFoundation

private actor MemoryAnalyticsStateStore: AppAnalyticsStateStoring {
    private var data: Data?

    func load() async throws -> Data? { data }
    func save(_ data: Data) async throws { self.data = data }
    func remove() async throws { data = nil }
}

private actor MockAnalyticsTransport: AppAnalyticsTransport {
    private var requests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard let body = request.httpBody,
              let object = try JSONSerialization.jsonObject(with: body) as? [String: Any],
              let requestID = object["requestId"] as? String,
              let days = object["days"] as? [[String: Any]] else {
            throw AppAnalyticsError.invalidResponse
        }
        let acceptedDays = days.compactMap { $0["day"] as? String }
        let payload: [String: Any] = [
            "ok": true,
            "requestId": requestID,
            "acceptedDays": acceptedDays,
        ]
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (try JSONSerialization.data(withJSONObject: payload), response)
    }

    func capturedRequests() -> [URLRequest] { requests }
}

private func analyticsConfiguration() -> AppAnalyticsConfiguration {
    AppAnalyticsConfiguration(
        appID: "analytics-test",
        appKey: "test-key-123456789",
        baseURL: URL(string: "https://example.com")!,
        keychainService: "com.hoangbkit.MacAppFoundationTests.\(UUID().uuidString)",
        stateStorageKey: "analytics-state-\(UUID().uuidString)",
        appVersion: "1.2.3",
        uploadInterval: 21_600,
        transportRetryCount: 0
    )
}

private func isoDate(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
}

private func requestBody(_ request: URLRequest) throws -> [String: Any] {
    guard let body = request.httpBody,
          let object = try JSONSerialization.jsonObject(with: body) as? [String: Any] else {
        throw AppAnalyticsError.invalidResponse
    }
    return object
}

@Test func analyticsFlushMatchesNativeServerContract() async throws {
    let transport = MockAnalyticsTransport()
    let store = MemoryAnalyticsStateStore()
    let timestamp = isoDate("2026-09-05T10:00:00Z")
    let configuration = analyticsConfiguration()
    let client = AppAnalyticsClient(
        configuration: configuration,
        transport: transport,
        stateStore: store,
        now: { timestamp }
    )

    try await client.track("generation_completed", dimension: "nano", count: 2)
    try await client.flush()

    let requests = await transport.capturedRequests()
    #expect(requests.count == 1)
    let request = try #require(requests.first)
    #expect(request.url?.path == "/v1/analytics/batch")
    #expect(request.value(forHTTPHeaderField: "X-App-ID") == configuration.appID)
    #expect(request.value(forHTTPHeaderField: "X-App-Key") == configuration.appKey)
    #expect(request.value(forHTTPHeaderField: "X-App-Version") == "1.2.3")
    #expect(request.value(forHTTPHeaderField: "X-Installation-ID")?.isEmpty == false)

    let body = try requestBody(request)
    #expect(body["schemaVersion"] as? Int == 1)
    #expect((body["requestId"] as? String)?.hasPrefix("native-") == true)
    let days = try #require(body["days"] as? [[String: Any]])
    #expect(days.count == 1)
    #expect(days[0]["day"] as? String == "2026-09-05")
    #expect(days[0]["platform"] as? String == "macos")
    let events = try #require(days[0]["events"] as? [[String: Any]])
    #expect(events.count == 1)
    #expect(events[0]["name"] as? String == "generation_completed")
    #expect(events[0]["dimension"] as? String == "nano")
    #expect(events[0]["count"] as? Int == 2)
}

@Test func analyticsSessionAccountingExcludesInactiveTimeAndUsesThirtyMinuteTimeout() async throws {
    let transport = MockAnalyticsTransport()
    let store = MemoryAnalyticsStateStore()
    let flushTime = isoDate("2026-09-05T11:05:00Z")
    let client = AppAnalyticsClient(
        configuration: analyticsConfiguration(),
        transport: transport,
        stateStore: store,
        now: { flushTime }
    )

    try await client.applicationDidBecomeActive(at: isoDate("2026-09-05T10:00:00Z"))
    try await client.applicationWillResignActive(at: isoDate("2026-09-05T10:10:00Z"))
    try await client.applicationDidBecomeActive(at: isoDate("2026-09-05T10:20:00Z"))
    try await client.applicationWillResignActive(at: isoDate("2026-09-05T10:25:00Z"))
    try await client.applicationDidBecomeActive(at: isoDate("2026-09-05T11:00:00Z"))
    try await client.applicationWillResignActive(at: flushTime)
    try await client.flush()

    let request = try #require(await transport.capturedRequests().last)
    let body = try requestBody(request)
    let days = try #require(body["days"] as? [[String: Any]])
    #expect(days[0]["sessions"] as? Int == 2)
    #expect(days[0]["sessionSeconds"] as? Int == 1_200)
}

@Test func analyticsRejectsInvalidEventNamesBeforePersistence() async throws {
    let client = AppAnalyticsClient(
        configuration: analyticsConfiguration(),
        transport: MockAnalyticsTransport(),
        stateStore: MemoryAnalyticsStateStore(),
        now: { isoDate("2026-09-05T10:00:00Z") }
    )

    await #expect(throws: AppAnalyticsError.self) {
        try await client.track("Not Valid")
    }
    #expect(try await client.pendingDayCount() == 0)
}
