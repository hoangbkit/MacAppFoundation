import Foundation
import Testing
@testable import MacAppFoundation

private actor ReliabilityMemoryAnalyticsStateStore: AppAnalyticsStateStoring {
    private var data: Data?

    func load() async throws -> Data? { data }
    func save(_ data: Data) async throws { self.data = data }
    func remove() async throws { data = nil }
}

private final class AnalyticsReliabilityClock: @unchecked Sendable {
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

    func advance(by seconds: TimeInterval) {
        lock.lock()
        value = value.addingTimeInterval(seconds)
        lock.unlock()
    }
}

private actor ScriptedAnalyticsTransport: AppAnalyticsTransport {
    enum Outcome: Sendable {
        case success
        case server(status: Int, code: String, message: String, retryAfter: String?)
        case transportFailure
        case cancelled
    }

    private var outcomes: [Outcome]
    private var requests: [URLRequest] = []

    init(_ outcomes: [Outcome] = []) {
        self.outcomes = outcomes
    }

    func enqueue(_ newOutcomes: Outcome...) {
        outcomes.append(contentsOf: newOutcomes)
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let outcome = outcomes.isEmpty ? Outcome.success : outcomes.removeFirst()

        switch outcome {
        case .success:
            let body = try analyticsReliabilityRequestBody(request)
            let requestID = try #require(body["requestId"] as? String)
            let days = try #require(body["days"] as? [[String: Any]])
            let acceptedDays = days.compactMap { $0["day"] as? String }
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

        case .server(let status, let code, let message, let retryAfter):
            var detail: [String: Any] = [
                "code": code,
                "message": message,
            ]
            if let retryAfter {
                detail["retryAfter"] = retryAfter
            }
            let payload: [String: Any] = ["error": detail]
            let headers = retryAfter.map { ["Retry-After": $0] }
            return (
                try JSONSerialization.data(withJSONObject: payload),
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: status,
                    httpVersion: nil,
                    headerFields: headers
                )!
            )

        case .transportFailure:
            throw URLError(.networkConnectionLost)

        case .cancelled:
            throw CancellationError()
        }
    }

    func capturedRequests() -> [URLRequest] { requests }
    func requestCount() -> Int { requests.count }
}

private func analyticsReliabilityConfiguration(
    uploadInterval: TimeInterval = 21_600,
    transportRetryCount: Int = 0
) -> AppAnalyticsConfiguration {
    AppAnalyticsConfiguration(
        appID: "analytics-test",
        appKey: "test-key-123456789",
        baseURL: URL(string: "https://example.com")!,
        keychainService: "com.hoangbkit.MacAppFoundationReliabilityTests.\(UUID().uuidString)",
        stateStorageKey: "analytics-reliability-state-\(UUID().uuidString)",
        appVersion: "1.2.3",
        uploadInterval: uploadInterval,
        transportRetryCount: transportRetryCount
    )
}

private func analyticsReliabilityDate(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
}

private func analyticsReliabilityRequestBody(_ request: URLRequest) throws -> [String: Any] {
    guard let body = request.httpBody,
          let object = try JSONSerialization.jsonObject(with: body) as? [String: Any] else {
        throw AppAnalyticsError.invalidResponse
    }
    return object
}

private func analyticsReliabilityDays(_ request: URLRequest) throws -> [[String: Any]] {
    let body = try analyticsReliabilityRequestBody(request)
    return try #require(body["days"] as? [[String: Any]])
}

@Test func automaticAnalyticsUploadRespectsNormalInterval() async throws {
    let clock = AnalyticsReliabilityClock(analyticsReliabilityDate("2026-09-05T10:00:00Z"))
    let transport = ScriptedAnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: analyticsReliabilityConfiguration(uploadInterval: 3_600),
        transport: transport,
        stateStore: ReliabilityMemoryAnalyticsStateStore(),
        now: { clock.now() }
    )

    try await client.track("first_event")
    #expect(await transport.requestCount() == 1)

    clock.advance(by: 60)
    try await client.track("second_event")
    #expect(await transport.requestCount() == 1)

    clock.advance(by: 3_541)
    try await client.track("third_event")
    #expect(await transport.requestCount() == 2)
}

@Test func rateLimitBackoffSuppressesAutomaticRequestsUntilExpiry() async throws {
    let clock = AnalyticsReliabilityClock(analyticsReliabilityDate("2026-09-05T10:00:00Z"))
    let transport = ScriptedAnalyticsTransport([
        .server(status: 429, code: "rate_limited", message: "Slow down.", retryAfter: "60"),
    ])
    let client = AppAnalyticsClient(
        configuration: analyticsReliabilityConfiguration(uploadInterval: 0),
        transport: transport,
        stateStore: ReliabilityMemoryAnalyticsStateStore(),
        now: { clock.now() }
    )

    try await client.track("first_event")
    #expect(await transport.requestCount() == 1)

    try await client.track("second_event")
    clock.advance(by: 59)
    try await client.track("third_event")
    #expect(await transport.requestCount() == 1)

    clock.advance(by: 2)
    try await client.track("fourth_event")
    #expect(await transport.requestCount() == 2)
}

@Test func explicitFlushBypassesBackoffAndSurfacesRateLimit() async throws {
    let clock = AnalyticsReliabilityClock(analyticsReliabilityDate("2026-09-05T10:00:00Z"))
    let transport = ScriptedAnalyticsTransport([
        .server(status: 429, code: "rate_limited", message: "Slow down.", retryAfter: "60"),
        .server(status: 429, code: "rate_limited", message: "Slow down.", retryAfter: "60"),
    ])
    let client = AppAnalyticsClient(
        configuration: analyticsReliabilityConfiguration(uploadInterval: 0),
        transport: transport,
        stateStore: ReliabilityMemoryAnalyticsStateStore(),
        now: { clock.now() }
    )

    try await client.track("first_event")
    #expect(await transport.requestCount() == 1)

    do {
        try await client.flush()
        Issue.record("Expected explicit flush to surface the rate-limit error.")
    } catch let error as AppAnalyticsError {
        #expect(error == .server(code: "rate_limited", message: "Slow down.", retryAfter: "60"))
    }

    #expect(await transport.requestCount() == 2)
    #expect(try await client.pendingDayCount() == 1)
}

@Test func transientTransportFailureRetriesSameCumulativeRequest() async throws {
    let transport = ScriptedAnalyticsTransport([
        .transportFailure,
        .success,
    ])
    let client = AppAnalyticsClient(
        configuration: analyticsReliabilityConfiguration(transportRetryCount: 1),
        transport: transport,
        stateStore: ReliabilityMemoryAnalyticsStateStore(),
        now: { analyticsReliabilityDate("2026-09-05T10:00:00Z") }
    )

    try await client.track("generation_completed", dimension: "nano", count: 2)

    let requests = await transport.capturedRequests()
    #expect(requests.count == 2)
    #expect(requests[0].httpBody == requests[1].httpBody)
    #expect(requests[0].value(forHTTPHeaderField: "X-Request-ID")
            == requests[1].value(forHTTPHeaderField: "X-Request-ID"))
}

@Test func exhaustedTransportRetriesPreservePendingAnalytics() async throws {
    let transport = ScriptedAnalyticsTransport([
        .transportFailure,
        .transportFailure,
    ])
    let client = AppAnalyticsClient(
        configuration: analyticsReliabilityConfiguration(transportRetryCount: 1),
        transport: transport,
        stateStore: ReliabilityMemoryAnalyticsStateStore(),
        now: { analyticsReliabilityDate("2026-09-05T10:00:00Z") }
    )

    try await client.track("generation_completed")
    #expect(await transport.requestCount() == 2)
    #expect(try await client.pendingDayCount() == 1)

    await transport.enqueue(.success)
    try await client.flush()
    #expect(await transport.requestCount() == 3)

    let request = try #require(await transport.capturedRequests().last)
    let events = try #require(analyticsReliabilityDays(request)[0]["events"] as? [[String: Any]])
    #expect(events.contains { $0["name"] as? String == "generation_completed" && $0["count"] as? Int == 1 })
}

@Test func serverFailurePreservesPendingAnalyticsForLaterRetry() async throws {
    let transport = ScriptedAnalyticsTransport([
        .server(status: 503, code: "service_disabled", message: "Unavailable.", retryAfter: nil),
    ])
    let client = AppAnalyticsClient(
        configuration: analyticsReliabilityConfiguration(),
        transport: transport,
        stateStore: ReliabilityMemoryAnalyticsStateStore(),
        now: { analyticsReliabilityDate("2026-09-05T10:00:00Z") }
    )

    try await client.track("export_completed", count: 3)
    #expect(try await client.pendingDayCount() == 1)

    await transport.enqueue(.success)
    try await client.flush()

    let request = try #require(await transport.capturedRequests().last)
    let events = try #require(analyticsReliabilityDays(request)[0]["events"] as? [[String: Any]])
    #expect(events.contains { $0["name"] as? String == "export_completed" && $0["count"] as? Int == 3 })
}

@Test func partialMultiBatchFailureKeepsUnacceptedBatchRetryable() async throws {
    let clock = AnalyticsReliabilityClock(analyticsReliabilityDate("2026-09-03T10:00:00Z"))
    let transport = ScriptedAnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: analyticsReliabilityConfiguration(uploadInterval: 10 * 24 * 60 * 60),
        transport: transport,
        stateStore: ReliabilityMemoryAnalyticsStateStore(),
        now: { clock.now() }
    )

    for index in 0..<40 {
        try await client.track("day_one_\(index)")
    }
    clock.set(analyticsReliabilityDate("2026-09-04T10:00:00Z"))
    for index in 0..<40 {
        try await client.track("day_two_\(index)")
    }
    clock.set(analyticsReliabilityDate("2026-09-05T10:00:00Z"))
    for index in 0..<40 {
        try await client.track("day_three_\(index)")
    }

    #expect(await transport.requestCount() == 1)
    await transport.enqueue(
        .success,
        .server(status: 503, code: "service_disabled", message: "Unavailable.", retryAfter: nil)
    )

    await #expect(throws: AppAnalyticsError.self) {
        try await client.flush()
    }

    let failedRequests = await transport.capturedRequests()
    #expect(failedRequests.count == 3)
    #expect(try analyticsReliabilityDays(failedRequests[1]).count == 2)
    #expect(try analyticsReliabilityDays(failedRequests[2]).count == 1)
    #expect(try await client.pendingDayCount() == 1)

    await transport.enqueue(.success)
    try await client.flush()

    let retriedRequests = await transport.capturedRequests()
    #expect(retriedRequests.count == 4)
    let retriedDays = try analyticsReliabilityDays(retriedRequests[3])
    #expect(retriedDays.count == 1)
    #expect(retriedDays[0]["day"] as? String == "2026-09-05")
}

@Test func cancelledFlushDoesNotDiscardPendingAnalytics() async throws {
    let clock = AnalyticsReliabilityClock(analyticsReliabilityDate("2026-09-05T10:00:00Z"))
    let transport = ScriptedAnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: analyticsReliabilityConfiguration(uploadInterval: 3_600),
        transport: transport,
        stateStore: ReliabilityMemoryAnalyticsStateStore(),
        now: { clock.now() }
    )

    try await client.track("first_event")
    try await client.track("second_event")
    #expect(await transport.requestCount() == 1)

    await transport.enqueue(.cancelled)
    await #expect(throws: CancellationError.self) {
        try await client.flush()
    }

    #expect(try await client.pendingDayCount() == 1)

    await transport.enqueue(.success)
    try await client.flush()
    let request = try #require(await transport.capturedRequests().last)
    let events = try #require(analyticsReliabilityDays(request)[0]["events"] as? [[String: Any]])
    #expect(events.count == 2)
}
