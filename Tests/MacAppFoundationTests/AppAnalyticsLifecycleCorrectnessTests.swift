import Foundation
import Testing
@testable import MacAppFoundation

private actor Phase2MemoryAnalyticsStateStore: AppAnalyticsStateStoring {
    private var data: Data?

    func load() async throws -> Data? { data }
    func save(_ data: Data) async throws { self.data = data }
    func remove() async throws { data = nil }
}

private final class Phase2AnalyticsClock: @unchecked Sendable {
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

private actor Phase2AnalyticsTransport: AppAnalyticsTransport {
    private var requests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let body = try phase2RequestBody(request)
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
    }

    func capturedRequests() -> [URLRequest] { requests }
}

private func phase2Configuration(
    uploadInterval: TimeInterval = 86_400
) -> AppAnalyticsConfiguration {
    AppAnalyticsConfiguration(
        appID: "analytics-test",
        appKey: "test-key-123456789",
        baseURL: URL(string: "https://example.com")!,
        keychainService: "com.hoangbkit.MacAppFoundationPhase2Tests.\(UUID().uuidString)",
        stateStorageKey: "analytics-phase2-state-\(UUID().uuidString)",
        appVersion: "1.2.3",
        uploadInterval: uploadInterval,
        transportRetryCount: 0
    )
}

private func phase2Date(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
}

private func phase2RequestBody(_ request: URLRequest) throws -> [String: Any] {
    guard let body = request.httpBody,
          let object = try JSONSerialization.jsonObject(with: body) as? [String: Any] else {
        throw AppAnalyticsError.invalidResponse
    }
    return object
}

private func phase2Days(_ request: URLRequest) throws -> [[String: Any]] {
    let body = try phase2RequestBody(request)
    return try #require(body["days"] as? [[String: Any]])
}

private func phase2Day(_ request: URLRequest, day: String) throws -> [String: Any] {
    let days = try phase2Days(request)
    return try #require(days.first { $0["day"] as? String == day })
}

private func phase2Events(_ day: [String: Any]) throws -> [[String: Any]] {
    try #require(day["events"] as? [[String: Any]])
}

private func phase2Event(
    _ day: [String: Any],
    name: String,
    dimension: String? = nil
) throws -> [String: Any] {
    let events = try phase2Events(day)
    return try #require(events.first {
        guard $0["name"] as? String == name else { return false }
        return ($0["dimension"] as? String) == dimension
    })
}

@Test func sameDayAnalyticsEventsRemainCumulativeAcrossUploads() async throws {
    let timestamp = phase2Date("2026-09-05T10:00:00Z")
    let transport = Phase2AnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: phase2Configuration(uploadInterval: 0),
        transport: transport,
        stateStore: Phase2MemoryAnalyticsStateStore(),
        now: { timestamp }
    )

    try await client.track("generation_completed", count: 2)
    try await client.track("generation_completed", count: 3)

    let requests = await transport.capturedRequests()
    #expect(requests.count == 2)

    let firstDay = try phase2Day(requests[0], day: "2026-09-05")
    let secondDay = try phase2Day(requests[1], day: "2026-09-05")
    #expect(try phase2Event(firstDay, name: "generation_completed")["count"] as? Int == 2)
    #expect(try phase2Event(secondDay, name: "generation_completed")["count"] as? Int == 5)
}

@Test func analyticsDimensionsAccumulateAsIndependentCounters() async throws {
    let timestamp = phase2Date("2026-09-05T10:00:00Z")
    let transport = Phase2AnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: phase2Configuration(uploadInterval: 0),
        transport: transport,
        stateStore: Phase2MemoryAnalyticsStateStore(),
        now: { timestamp }
    )

    try await client.track("generation_completed", dimension: "nano", count: 2)
    try await client.track("generation_completed", dimension: "turbo", count: 3)
    try await client.track("generation_completed", dimension: "nano", count: 4)

    let request = try #require(await transport.capturedRequests().last)
    let day = try phase2Day(request, day: "2026-09-05")
    let events = try phase2Events(day)
    #expect(events.count == 2)
    #expect(try phase2Event(day, name: "generation_completed", dimension: "nano")["count"] as? Int == 6)
    #expect(try phase2Event(day, name: "generation_completed", dimension: "turbo")["count"] as? Int == 3)
}

@Test func repeatedFlushResendsEquivalentCumulativeSnapshot() async throws {
    let timestamp = phase2Date("2026-09-05T10:00:00Z")
    let transport = Phase2AnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: phase2Configuration(),
        transport: transport,
        stateStore: Phase2MemoryAnalyticsStateStore(),
        now: { timestamp }
    )

    try await client.track("generation_completed", dimension: "nano", count: 7)
    try await client.flush()
    try await client.flush()

    let requests = await transport.capturedRequests()
    #expect(requests.count == 3)

    for request in requests {
        let day = try phase2Day(request, day: "2026-09-05")
        #expect(day["sessions"] as? Int == 0)
        #expect(day["sessionSeconds"] as? Int == 0)
        #expect(try phase2Event(day, name: "generation_completed", dimension: "nano")["count"] as? Int == 7)
    }
}

@Test func sessionSnapshotsRemainCumulativeAcrossUploads() async throws {
    let clock = Phase2AnalyticsClock(phase2Date("2026-09-05T10:00:00Z"))
    let transport = Phase2AnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: phase2Configuration(),
        transport: transport,
        stateStore: Phase2MemoryAnalyticsStateStore(),
        now: { clock.now() }
    )

    try await client.applicationDidBecomeActive(at: phase2Date("2026-09-05T10:00:00Z"))
    try await client.applicationWillResignActive(at: phase2Date("2026-09-05T10:10:00Z"))
    clock.set(phase2Date("2026-09-05T10:10:00Z"))
    try await client.flush()

    try await client.applicationDidBecomeActive(at: phase2Date("2026-09-05T10:20:00Z"))
    try await client.applicationWillResignActive(at: phase2Date("2026-09-05T10:25:00Z"))
    clock.set(phase2Date("2026-09-05T10:25:00Z"))
    try await client.flush()

    let requests = await transport.capturedRequests()
    #expect(requests.count == 3)
    let firstCheckpoint = try phase2Day(requests[1], day: "2026-09-05")
    let secondCheckpoint = try phase2Day(requests[2], day: "2026-09-05")

    #expect(firstCheckpoint["sessions"] as? Int == 1)
    #expect(firstCheckpoint["sessionSeconds"] as? Int == 600)
    #expect(secondCheckpoint["sessions"] as? Int == 1)
    #expect(secondCheckpoint["sessionSeconds"] as? Int == 900)
}

@Test func activeSessionDurationSplitsAcrossUTCMidnight() async throws {
    let clock = Phase2AnalyticsClock(phase2Date("2026-09-05T23:55:00Z"))
    let transport = Phase2AnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: phase2Configuration(),
        transport: transport,
        stateStore: Phase2MemoryAnalyticsStateStore(),
        now: { clock.now() }
    )

    try await client.applicationDidBecomeActive(at: phase2Date("2026-09-05T23:55:00Z"))
    try await client.applicationWillResignActive(at: phase2Date("2026-09-06T00:05:00Z"))
    clock.set(phase2Date("2026-09-06T00:05:00Z"))
    try await client.flush()

    let request = try #require(await transport.capturedRequests().last)
    let dayOne = try phase2Day(request, day: "2026-09-05")
    let dayTwo = try phase2Day(request, day: "2026-09-06")

    #expect(dayOne["sessions"] as? Int == 1)
    #expect(dayOne["sessionSeconds"] as? Int == 300)
    #expect(dayTwo["sessions"] as? Int == 0)
    #expect(dayTwo["sessionSeconds"] as? Int == 300)
}

@Test func thirtyMinuteBoundaryResumesButOneSecondBeyondStartsNewSession() async throws {
    let exactClock = Phase2AnalyticsClock(phase2Date("2026-09-05T10:00:00Z"))
    let exactTransport = Phase2AnalyticsTransport()
    let exactClient = AppAnalyticsClient(
        configuration: phase2Configuration(),
        transport: exactTransport,
        stateStore: Phase2MemoryAnalyticsStateStore(),
        now: { exactClock.now() }
    )

    try await exactClient.applicationDidBecomeActive(at: phase2Date("2026-09-05T10:00:00Z"))
    try await exactClient.applicationWillResignActive(at: phase2Date("2026-09-05T10:10:00Z"))
    try await exactClient.applicationDidBecomeActive(at: phase2Date("2026-09-05T10:40:00Z"))
    try await exactClient.applicationWillResignActive(at: phase2Date("2026-09-05T10:45:00Z"))
    exactClock.set(phase2Date("2026-09-05T10:45:00Z"))
    try await exactClient.flush()

    let exactRequest = try #require(await exactTransport.capturedRequests().last)
    let exactDay = try phase2Day(exactRequest, day: "2026-09-05")
    #expect(exactDay["sessions"] as? Int == 1)
    #expect(exactDay["sessionSeconds"] as? Int == 900)

    let beyondClock = Phase2AnalyticsClock(phase2Date("2026-09-05T10:00:00Z"))
    let beyondTransport = Phase2AnalyticsTransport()
    let beyondClient = AppAnalyticsClient(
        configuration: phase2Configuration(),
        transport: beyondTransport,
        stateStore: Phase2MemoryAnalyticsStateStore(),
        now: { beyondClock.now() }
    )

    try await beyondClient.applicationDidBecomeActive(at: phase2Date("2026-09-05T10:00:00Z"))
    try await beyondClient.applicationWillResignActive(at: phase2Date("2026-09-05T10:10:00Z"))
    try await beyondClient.applicationDidBecomeActive(at: phase2Date("2026-09-05T10:40:01Z"))
    try await beyondClient.applicationWillResignActive(at: phase2Date("2026-09-05T10:45:01Z"))
    beyondClock.set(phase2Date("2026-09-05T10:45:01Z"))
    try await beyondClient.flush()

    let beyondRequest = try #require(await beyondTransport.capturedRequests().last)
    let beyondDay = try phase2Day(beyondRequest, day: "2026-09-05")
    #expect(beyondDay["sessions"] as? Int == 2)
    #expect(beyondDay["sessionSeconds"] as? Int == 900)
}

@Test func duplicateLifecycleNotificationsDoNotMoveInactiveSessionBoundary() async throws {
    let clock = Phase2AnalyticsClock(phase2Date("2026-09-05T10:00:00Z"))
    let transport = Phase2AnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: phase2Configuration(),
        transport: transport,
        stateStore: Phase2MemoryAnalyticsStateStore(),
        now: { clock.now() }
    )

    try await client.applicationDidBecomeActive(at: phase2Date("2026-09-05T10:00:00Z"))
    try await client.applicationDidBecomeActive(at: phase2Date("2026-09-05T10:05:00Z"))
    try await client.applicationWillResignActive(at: phase2Date("2026-09-05T10:10:00Z"))
    try await client.applicationWillResignActive(at: phase2Date("2026-09-05T10:20:00Z"))
    try await client.applicationDidBecomeActive(at: phase2Date("2026-09-05T10:45:00Z"))
    try await client.applicationWillResignActive(at: phase2Date("2026-09-05T10:50:00Z"))
    clock.set(phase2Date("2026-09-05T10:50:00Z"))
    try await client.flush()

    let request = try #require(await transport.capturedRequests().last)
    let day = try phase2Day(request, day: "2026-09-05")
    #expect(day["sessions"] as? Int == 2)
    #expect(day["sessionSeconds"] as? Int == 900)
}

@Test func longActiveSessionIsNotExpiredByInactiveTimeout() async throws {
    let clock = Phase2AnalyticsClock(phase2Date("2026-09-05T10:00:00Z"))
    let transport = Phase2AnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: phase2Configuration(),
        transport: transport,
        stateStore: Phase2MemoryAnalyticsStateStore(),
        now: { clock.now() }
    )

    try await client.applicationDidBecomeActive(at: phase2Date("2026-09-05T10:00:00Z"))

    clock.set(phase2Date("2026-09-05T10:40:00Z"))
    try await client.track("long_active_checkpoint")
    try await client.applicationDidBecomeActive(at: phase2Date("2026-09-05T10:45:00Z"))
    try await client.applicationWillResignActive(at: phase2Date("2026-09-05T10:50:00Z"))

    clock.set(phase2Date("2026-09-05T10:50:00Z"))
    try await client.flush()

    let request = try #require(await transport.capturedRequests().last)
    let day = try phase2Day(request, day: "2026-09-05")
    #expect(day["sessions"] as? Int == 1)
    #expect(day["sessionSeconds"] as? Int == 3_000)
    #expect(try phase2Event(day, name: "long_active_checkpoint")["count"] as? Int == 1)
}

@Test func recreatedClientContinuesPersistedCumulativeState() async throws {
    let clock = Phase2AnalyticsClock(phase2Date("2026-09-05T10:00:00Z"))
    let transport = Phase2AnalyticsTransport()
    let store = Phase2MemoryAnalyticsStateStore()
    let configuration = phase2Configuration()

    let firstClient = AppAnalyticsClient(
        configuration: configuration,
        transport: transport,
        stateStore: store,
        now: { clock.now() }
    )

    try await firstClient.track("generation_completed", dimension: "nano", count: 2)
    try await firstClient.applicationDidBecomeActive(at: phase2Date("2026-09-05T10:00:00Z"))
    try await firstClient.applicationWillResignActive(at: phase2Date("2026-09-05T10:10:00Z"))

    clock.set(phase2Date("2026-09-05T10:20:00Z"))
    let secondClient = AppAnalyticsClient(
        configuration: configuration,
        transport: transport,
        stateStore: store,
        now: { clock.now() }
    )

    try await secondClient.track("generation_completed", dimension: "nano", count: 3)
    try await secondClient.applicationDidBecomeActive(at: phase2Date("2026-09-05T10:20:00Z"))
    try await secondClient.applicationWillResignActive(at: phase2Date("2026-09-05T10:25:00Z"))
    clock.set(phase2Date("2026-09-05T10:25:00Z"))
    try await secondClient.flush()

    let request = try #require(await transport.capturedRequests().last)
    let day = try phase2Day(request, day: "2026-09-05")
    #expect(day["sessions"] as? Int == 1)
    #expect(day["sessionSeconds"] as? Int == 900)
    #expect(try phase2Event(day, name: "generation_completed", dimension: "nano")["count"] as? Int == 5)
}
