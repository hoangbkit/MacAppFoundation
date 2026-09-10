import Foundation
import Testing
@testable import MacAppFoundation

private actor Phase3MemoryAnalyticsStateStore: AppAnalyticsStateStoring {
    private var data: Data?
    private var removals = 0

    init(data: Data? = nil) {
        self.data = data
    }

    func load() async throws -> Data? { data }
    func save(_ data: Data) async throws { self.data = data }
    func remove() async throws {
        data = nil
        removals += 1
    }

    func removalCount() -> Int { removals }
    func snapshot() -> Data? { data }
}

private final class Phase3AnalyticsClock: @unchecked Sendable {
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

private actor Phase3AnalyticsTransport: AppAnalyticsTransport {
    enum Outcome: Sendable {
        case success
        case invalidRequestID
        case acceptedDays([String])
        case server(status: Int, code: String, message: String, retryAfter: String?)
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
        let body = try phase3RequestBody(request)
        let requestID = try #require(body["requestId"] as? String)
        let days = try #require(body["days"] as? [[String: Any]])
        let actualDays = days.compactMap { $0["day"] as? String }
        let outcome = outcomes.isEmpty ? Outcome.success : outcomes.removeFirst()

        let payload: [String: Any]
        let status: Int
        let headers: [String: String]?

        switch outcome {
        case .success:
            status = 200
            headers = nil
            payload = [
                "ok": true,
                "requestId": requestID,
                "acceptedDays": actualDays,
            ]
        case .invalidRequestID:
            status = 200
            headers = nil
            payload = [
                "ok": true,
                "requestId": "wrong-request-id",
                "acceptedDays": actualDays,
            ]
        case .acceptedDays(let acceptedDays):
            status = 200
            headers = nil
            payload = [
                "ok": true,
                "requestId": requestID,
                "acceptedDays": acceptedDays,
            ]
        case .server(let responseStatus, let code, let message, let retryAfter):
            status = responseStatus
            headers = retryAfter.map { ["Retry-After": $0] }
            var detail: [String: Any] = [
                "code": code,
                "message": message,
            ]
            if let retryAfter {
                detail["retryAfter"] = retryAfter
            }
            payload = ["error": detail]
        }

        return (
            try JSONSerialization.data(withJSONObject: payload),
            HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: headers
            )!
        )
    }

    func capturedRequests() -> [URLRequest] { requests }
    func requestCount() -> Int { requests.count }
}

private func phase3Configuration(
    keychainService: String? = nil,
    stateStorageKey: String? = nil,
    appVersion: String? = "1.2.3",
    uploadInterval: TimeInterval = 86_400
) -> AppAnalyticsConfiguration {
    AppAnalyticsConfiguration(
        appID: "analytics-test",
        appKey: "test-key-123456789",
        baseURL: URL(string: "https://example.com")!,
        keychainService: keychainService
            ?? "com.hoangbkit.MacAppFoundationPhase3Tests.\(UUID().uuidString)",
        stateStorageKey: stateStorageKey
            ?? "analytics-phase3-state-\(UUID().uuidString)",
        appVersion: appVersion,
        uploadInterval: uploadInterval,
        transportRetryCount: 0
    )
}

private func phase3Date(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
}

private func phase3RequestBody(_ request: URLRequest) throws -> [String: Any] {
    guard let body = request.httpBody,
          let object = try JSONSerialization.jsonObject(with: body) as? [String: Any] else {
        throw AppAnalyticsError.invalidResponse
    }
    return object
}

private func phase3Days(_ request: URLRequest) throws -> [[String: Any]] {
    let body = try phase3RequestBody(request)
    return try #require(body["days"] as? [[String: Any]])
}

private func phase3Events(_ day: [String: Any]) throws -> [[String: Any]] {
    try #require(day["events"] as? [[String: Any]])
}

private func phase3PersistedState(
    days: [String: [String: Any]]
) throws -> Data {
    try JSONSerialization.data(withJSONObject: ["days": days])
}

private func phase3PersistedDay(
    appVersion: String? = "1.2.3",
    sessions: Int = 0,
    sessionSeconds: Int = 0,
    events: [(name: String, dimension: String?, count: Int)] = []
) -> [String: Any] {
    var eventMap: [String: Any] = [:]
    for (index, event) in events.enumerated() {
        var payload: [String: Any] = [
            "name": event.name,
            "count": event.count,
        ]
        if let dimension = event.dimension {
            payload["dimension"] = dimension
        }
        eventMap["event-\(index)"] = payload
    }

    var result: [String: Any] = [
        "sessions": sessions,
        "sessionSeconds": sessionSeconds,
        "events": eventMap,
    ]
    if let appVersion {
        result["appVersion"] = appVersion
    }
    return result
}

private func phase3EventCounters(_ count: Int, prefix: String = "event") -> [(String, String?, Int)] {
    (0..<count).map { index in
        ("\(prefix)_\(String(format: "%03d", index))", nil, 1)
    }
}

@Test func analyticsRetentionKeepsSixDayOldSnapshotAndPrunesSevenDayOldSnapshot() async throws {
    let now = phase3Date("2026-09-08T12:00:00Z")
    let state = try phase3PersistedState(days: [
        "2026-09-01": phase3PersistedDay(events: [("old_event", nil, 1)]),
        "2026-09-02": phase3PersistedDay(events: [("kept_event", nil, 1)]),
    ])
    let transport = Phase3AnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: phase3Configuration(),
        transport: transport,
        stateStore: Phase3MemoryAnalyticsStateStore(data: state),
        now: { now }
    )

    try await client.flush()

    let request = try #require(await transport.capturedRequests().first)
    let days = try phase3Days(request)
    #expect(days.count == 1)
    #expect(days[0]["day"] as? String == "2026-09-02")
}

@Test func analyticsBatchContainsAtMostSevenUTCdays() async throws {
    let dayKeys = [
        "2026-09-02", "2026-09-03", "2026-09-04", "2026-09-05",
        "2026-09-06", "2026-09-07", "2026-09-08",
    ]
    let state = try phase3PersistedState(days: Dictionary(uniqueKeysWithValues: dayKeys.map {
        ($0, phase3PersistedDay(events: [("daily_event", nil, 1)]))
    }))
    let transport = Phase3AnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: phase3Configuration(),
        transport: transport,
        stateStore: Phase3MemoryAnalyticsStateStore(data: state),
        now: { phase3Date("2026-09-08T12:00:00Z") }
    )

    try await client.flush()

    let requests = await transport.capturedRequests()
    #expect(requests.count == 1)
    #expect(try phase3Days(requests[0]).count == 7)
}

@Test func analyticsHundredCounterBatchLimitSplitsLargeSnapshotSet() async throws {
    let state = try phase3PersistedState(days: [
        "2026-09-06": phase3PersistedDay(events: phase3EventCounters(40, prefix: "first")),
        "2026-09-07": phase3PersistedDay(events: phase3EventCounters(40, prefix: "second")),
        "2026-09-08": phase3PersistedDay(events: phase3EventCounters(40, prefix: "third")),
    ])
    let transport = Phase3AnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: phase3Configuration(),
        transport: transport,
        stateStore: Phase3MemoryAnalyticsStateStore(data: state),
        now: { phase3Date("2026-09-08T12:00:00Z") }
    )

    try await client.flush()

    let requests = await transport.capturedRequests()
    #expect(requests.count == 2)
    let firstCounters = try phase3Days(requests[0]).reduce(0) { total, day in
        total + (try phase3Events(day).count)
    }
    let secondCounters = try phase3Days(requests[1]).reduce(0) { total, day in
        total + (try phase3Events(day).count)
    }
    #expect(firstCounters == 80)
    #expect(secondCounters == 40)
    #expect(firstCounters <= 100)
    #expect(secondCounters <= 100)
}

@Test func analyticsAllowsExactlyFiftyCountersButRejectsFiftyFirstUniqueCounter() async throws {
    let timestamp = phase3Date("2026-09-08T12:00:00Z")
    let transport = Phase3AnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: phase3Configuration(uploadInterval: 86_400),
        transport: transport,
        stateStore: Phase3MemoryAnalyticsStateStore(),
        now: { timestamp }
    )

    for index in 0..<50 {
        try await client.track("event_\(String(format: "%02d", index))")
    }

    await #expect(throws: AppAnalyticsError.self) {
        try await client.track("event_50")
    }

    try await client.flush()
    let request = try #require(await transport.capturedRequests().last)
    let day = try #require(phase3Days(request).first)
    #expect(try phase3Events(day).count == 50)
}

@Test func analyticsEventCountSaturatesAtServerMaximum() async throws {
    let timestamp = phase3Date("2026-09-08T12:00:00Z")
    let transport = Phase3AnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: phase3Configuration(),
        transport: transport,
        stateStore: Phase3MemoryAnalyticsStateStore(),
        now: { timestamp }
    )

    try await client.track("generation_completed", count: 99_999)
    try await client.track("generation_completed", count: 10)
    try await client.flush()

    let request = try #require(await transport.capturedRequests().last)
    let day = try #require(phase3Days(request).first)
    let event = try #require(phase3Events(day).first)
    #expect(event["count"] as? Int == 100_000)
}

@Test func analyticsStoredSessionValuesAreBoundedToServerCaps() async throws {
    let state = try phase3PersistedState(days: [
        "2026-09-08": phase3PersistedDay(
            sessions: 1_500,
            sessionSeconds: 100_000,
            events: []
        ),
    ])
    let transport = Phase3AnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: phase3Configuration(),
        transport: transport,
        stateStore: Phase3MemoryAnalyticsStateStore(data: state),
        now: { phase3Date("2026-09-08T12:00:00Z") }
    )

    try await client.flush()

    let request = try #require(await transport.capturedRequests().first)
    let day = try #require(phase3Days(request).first)
    #expect(day["sessions"] as? Int == 1_000)
    #expect(day["sessionSeconds"] as? Int == 86_400)
}

@Test func analyticsTokenBoundariesMatchServerContract() async throws {
    let timestamp = phase3Date("2026-09-08T12:00:00Z")
    let validName = "a" + String(repeating: "b", count: 47)
    let invalidName = "a" + String(repeating: "b", count: 48)
    let validDimension = "A" + String(repeating: "b", count: 63)
    let invalidDimension = "A" + String(repeating: "b", count: 64)
    let transport = Phase3AnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: phase3Configuration(),
        transport: transport,
        stateStore: Phase3MemoryAnalyticsStateStore(),
        now: { timestamp }
    )

    try await client.track(validName, dimension: validDimension)

    await #expect(throws: AppAnalyticsError.self) {
        try await client.track(invalidName)
    }
    await #expect(throws: AppAnalyticsError.self) {
        try await client.track("valid_name", dimension: invalidDimension)
    }
    await #expect(throws: AppAnalyticsError.self) {
        try await client.track("Uppercase")
    }
    await #expect(throws: AppAnalyticsError.self) {
        try await client.track("valid_name", dimension: "-invalid")
    }
}

@Test func analyticsAppVersionBoundaryIsSentWhenValidAndOmittedWhenInvalid() async throws {
    let timestamp = phase3Date("2026-09-08T12:00:00Z")
    let validVersion = "A" + String(repeating: "b", count: 63)
    let validTransport = Phase3AnalyticsTransport()
    let validClient = AppAnalyticsClient(
        configuration: phase3Configuration(appVersion: validVersion),
        transport: validTransport,
        stateStore: Phase3MemoryAnalyticsStateStore(),
        now: { timestamp }
    )

    try await validClient.track("generation_completed")
    let validRequest = try #require(await validTransport.capturedRequests().first)
    let validDay = try #require(phase3Days(validRequest).first)
    #expect(validRequest.value(forHTTPHeaderField: "X-App-Version") == validVersion)
    #expect(validDay["appVersion"] as? String == validVersion)

    let invalidVersion = "A" + String(repeating: "b", count: 64)
    let invalidTransport = Phase3AnalyticsTransport()
    let invalidClient = AppAnalyticsClient(
        configuration: phase3Configuration(appVersion: invalidVersion),
        transport: invalidTransport,
        stateStore: Phase3MemoryAnalyticsStateStore(),
        now: { timestamp }
    )

    try await invalidClient.track("generation_completed")
    let invalidRequest = try #require(await invalidTransport.capturedRequests().first)
    let invalidDay = try #require(phase3Days(invalidRequest).first)
    #expect(invalidRequest.value(forHTTPHeaderField: "X-App-Version") == nil)
    #expect(invalidDay["appVersion"] == nil)
}

@Test func oversizedPersistedAnalyticsBatchIsRejectedBeforeTransport() async throws {
    let oversizedEvents: [(String, String?, Int)] = (0..<40).map { index in
        ("e\(index)_" + String(repeating: "x", count: 1_000), nil, 1)
    }
    let state = try phase3PersistedState(days: [
        "2026-09-08": phase3PersistedDay(events: oversizedEvents),
    ])
    let transport = Phase3AnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: phase3Configuration(),
        transport: transport,
        stateStore: Phase3MemoryAnalyticsStateStore(data: state),
        now: { phase3Date("2026-09-08T12:00:00Z") }
    )

    await #expect(throws: AppAnalyticsError.self) {
        try await client.flush()
    }
    #expect(await transport.requestCount() == 0)
}

@Test func analyticsRejectsMismatchedResponseRequestIDWithoutDroppingState() async throws {
    let state = try phase3PersistedState(days: [
        "2026-09-08": phase3PersistedDay(events: [("generation_completed", nil, 1)]),
    ])
    let store = Phase3MemoryAnalyticsStateStore(data: state)
    let transport = Phase3AnalyticsTransport([.invalidRequestID])
    let client = AppAnalyticsClient(
        configuration: phase3Configuration(),
        transport: transport,
        stateStore: store,
        now: { phase3Date("2026-09-08T12:00:00Z") }
    )

    await #expect(throws: AppAnalyticsError.self) {
        try await client.flush()
    }
    #expect(try await client.pendingDayCount() == 1)
}

@Test func analyticsRejectsMissingOrExtraAcceptedDays() async throws {
    let days = [
        "2026-09-07": phase3PersistedDay(events: [("first_event", nil, 1)]),
        "2026-09-08": phase3PersistedDay(events: [("second_event", nil, 1)]),
    ]
    let now = phase3Date("2026-09-08T12:00:00Z")

    let missingTransport = Phase3AnalyticsTransport([.acceptedDays(["2026-09-07"])])
    let missingClient = AppAnalyticsClient(
        configuration: phase3Configuration(),
        transport: missingTransport,
        stateStore: Phase3MemoryAnalyticsStateStore(data: try phase3PersistedState(days: days)),
        now: { now }
    )
    await #expect(throws: AppAnalyticsError.self) {
        try await missingClient.flush()
    }
    #expect(try await missingClient.pendingDayCount() == 2)

    let extraTransport = Phase3AnalyticsTransport([
        .acceptedDays(["2026-09-07", "2026-09-08", "2026-09-06"]),
    ])
    let extraClient = AppAnalyticsClient(
        configuration: phase3Configuration(),
        transport: extraTransport,
        stateStore: Phase3MemoryAnalyticsStateStore(data: try phase3PersistedState(days: days)),
        now: { now }
    )
    await #expect(throws: AppAnalyticsError.self) {
        try await extraClient.flush()
    }
    #expect(try await extraClient.pendingDayCount() == 2)
}

@Test func analyticsStructuredServerErrorsPreserveCodeMessageAndRetryAfter() async throws {
    let cases: [(Int, String, String, String?)] = [
        (401, "attestation_required", "Attestation required.", nil),
        (403, "installation_suspended", "Installation suspended.", nil),
        (429, "rate_limited", "Slow down.", "60"),
        (503, "app_disabled", "Analytics disabled.", "120"),
    ]

    for (status, code, message, retryAfter) in cases {
        let state = try phase3PersistedState(days: [
            "2026-09-08": phase3PersistedDay(events: [("generation_completed", nil, 1)]),
        ])
        let transport = Phase3AnalyticsTransport([
            .server(status: status, code: code, message: message, retryAfter: retryAfter),
        ])
        let client = AppAnalyticsClient(
            configuration: phase3Configuration(),
            transport: transport,
            stateStore: Phase3MemoryAnalyticsStateStore(data: state),
            now: { phase3Date("2026-09-08T12:00:00Z") }
        )

        do {
            try await client.flush()
            Issue.record("Expected server error \(code).")
        } catch let error as AppAnalyticsError {
            #expect(error == .server(code: code, message: message, retryAfter: retryAfter))
        }
    }
}

@Test func corruptAnalyticsPersistenceRecoversToCleanState() async throws {
    let store = Phase3MemoryAnalyticsStateStore(data: Data("not-valid-json".utf8))
    let transport = Phase3AnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: phase3Configuration(),
        transport: transport,
        stateStore: store,
        now: { phase3Date("2026-09-08T12:00:00Z") }
    )

    try await client.track("generation_completed")

    #expect(await store.removalCount() == 1)
    #expect(try await client.pendingDayCount() == 1)
    #expect(await store.snapshot() != nil)
}

@Test func resetAnalyticsStatePreservesInstallationIdentity() async throws {
    let service = "com.hoangbkit.MacAppFoundationPhase3Reset.\(UUID().uuidString)"
    let transport = Phase3AnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: phase3Configuration(keychainService: service),
        transport: transport,
        stateStore: Phase3MemoryAnalyticsStateStore(),
        now: { phase3Date("2026-09-08T12:00:00Z") }
    )

    try await client.track("generation_completed", count: 3)
    let firstRequest = try #require(await transport.capturedRequests().first)
    let firstID = try #require(firstRequest.value(forHTTPHeaderField: "X-Installation-ID"))

    try await client.resetLocalState()
    try await client.track("generation_completed")

    let secondRequest = try #require(await transport.capturedRequests().last)
    let secondID = try #require(secondRequest.value(forHTTPHeaderField: "X-Installation-ID"))
    let day = try #require(phase3Days(secondRequest).first)
    let event = try #require(phase3Events(day).first)

    #expect(secondID == firstID)
    #expect(event["count"] as? Int == 1)
}

@Test func analyticsInstallationIdentityIsStableAcrossClientInstances() async throws {
    let service = "com.hoangbkit.MacAppFoundationPhase3Stable.\(UUID().uuidString)"
    let configuration = phase3Configuration(keychainService: service)
    let firstTransport = Phase3AnalyticsTransport()
    let secondTransport = Phase3AnalyticsTransport()
    let timestamp = phase3Date("2026-09-08T12:00:00Z")

    let first = AppAnalyticsClient(
        configuration: configuration,
        transport: firstTransport,
        stateStore: Phase3MemoryAnalyticsStateStore(),
        now: { timestamp }
    )
    try await first.track("first_event")

    let second = AppAnalyticsClient(
        configuration: configuration,
        transport: secondTransport,
        stateStore: Phase3MemoryAnalyticsStateStore(),
        now: { timestamp }
    )
    try await second.track("second_event")

    let firstRequest = try #require(await firstTransport.capturedRequests().first)
    let secondRequest = try #require(await secondTransport.capturedRequests().first)
    #expect(firstRequest.value(forHTTPHeaderField: "X-Installation-ID")
            == secondRequest.value(forHTTPHeaderField: "X-Installation-ID"))
}

@Test func concurrentAnalyticsClientsShareFirstInstallationIdentity() async throws {
    let service = "com.hoangbkit.MacAppFoundationPhase3Concurrent.\(UUID().uuidString)"
    let configuration = phase3Configuration(keychainService: service)
    let firstTransport = Phase3AnalyticsTransport()
    let secondTransport = Phase3AnalyticsTransport()
    let timestamp = phase3Date("2026-09-08T12:00:00Z")

    let first = AppAnalyticsClient(
        configuration: configuration,
        transport: firstTransport,
        stateStore: Phase3MemoryAnalyticsStateStore(),
        now: { timestamp }
    )
    let second = AppAnalyticsClient(
        configuration: configuration,
        transport: secondTransport,
        stateStore: Phase3MemoryAnalyticsStateStore(),
        now: { timestamp }
    )

    async let firstTrack: Void = first.track("first_event")
    async let secondTrack: Void = second.track("second_event")
    _ = try await (firstTrack, secondTrack)

    let firstRequest = try #require(await firstTransport.capturedRequests().first)
    let secondRequest = try #require(await secondTransport.capturedRequests().first)
    let firstID = try #require(firstRequest.value(forHTTPHeaderField: "X-Installation-ID"))
    let secondID = try #require(secondRequest.value(forHTTPHeaderField: "X-Installation-ID"))

    #expect(firstID == secondID)
    #expect(firstID.isEmpty == false)
}
