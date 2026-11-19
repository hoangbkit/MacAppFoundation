import Foundation
import Testing
@testable import MacAppFoundation

private actor MemoryAnalyticsStateStore: AppAnalyticsStateStoring {
    private var data: Data?

    func load() async throws -> Data? { data }
    func save(_ data: Data) async throws { self.data = data }
    func remove() async throws { data = nil }
    func containsData() -> Bool { data != nil }
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

private func analyticsConfiguration(
    appKey: String? = "test-key-123456789",
    enabled: Bool = true,
    uploadInterval: TimeInterval = 21_600,
    storageMode: AppAnalyticsStorageMode = .persisted
) -> AppAnalyticsConfiguration {
    AppAnalyticsConfiguration(
        appID: "analytics-test",
        appKey: appKey,
        baseURL: URL(string: "https://example.com")!,
        enabled: enabled,
        keychainService: "com.hoangbkit.MacAppFoundationTests.\(UUID().uuidString)",
        stateStorageKey: "analytics-state-\(UUID().uuidString)",
        appVersion: "1.2.3",
        uploadInterval: uploadInterval,
        transportRetryCount: 0,
        storageMode: storageMode
    )
}

private func isoDate(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
}

private func analyticsContext() -> AppAnalyticsClientContext {
    AppAnalyticsClientContext(
        osVersion: "26.0.1",
        appBuild: "143",
        deviceFamily: "mac",
        architecture: "arm64"
    )
}


private func requestBody(_ request: URLRequest) throws -> [String: Any] {
    guard let body = request.httpBody,
          let object = try JSONSerialization.jsonObject(with: body) as? [String: Any] else {
        throw AppAnalyticsError.invalidResponse
    }
    return object
}

@Test func analyticsConfigurationDefaultsToTwentySecondUploadInterval() {
    let configuration = AppAnalyticsConfiguration(
        appID: "analytics-test",
        baseURL: URL(string: "https://example.com")!
    )

    #expect(configuration.enabled)
    #expect(configuration.uploadInterval == 20)
    #expect(configuration.storageMode == .persisted)
}

@Test func disabledAnalyticsIsCompletelyInert() async throws {
    let transport = MockAnalyticsTransport()
    let store = MemoryAnalyticsStateStore()
    let client = AppAnalyticsClient(
        configuration: analyticsConfiguration(enabled: false),
        transport: transport,
        stateStore: store,
        now: { isoDate("2026-09-05T10:00:00Z") },
        clientContext: analyticsContext()
    )

    try await client.track("Not Valid")
    try await client.trackError("NotValid", component: "Not Valid")
    try await client.applicationDidBecomeActive()
    try await client.applicationWillResignActive()
    try await client.flush()
    await client.waitForAutomaticUpload()

    #expect(await transport.capturedRequests().isEmpty)
    #expect(await store.containsData() == false)
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
        now: { timestamp },
        clientContext: analyticsContext()
    )

    try await client.track("generation_completed", dimension: "nano", count: 2)
    await client.waitForAutomaticUpload()

    let requests = await transport.capturedRequests()
    #expect(requests.count == 1)
    let request = try #require(requests.first)
    #expect(request.url?.path == "/v1/analytics/batch")
    #expect(request.value(forHTTPHeaderField: "X-App-ID") == configuration.appID)
    #expect(request.value(forHTTPHeaderField: "X-App-Key") == configuration.appKey)
    #expect(request.value(forHTTPHeaderField: "X-App-Version") == "1.2.3")
    #expect(request.value(forHTTPHeaderField: "X-App-Build") == "143")
    #expect(request.value(forHTTPHeaderField: "X-Installation-ID")?.isEmpty == false)

    let body = try requestBody(request)
    #expect(body["schemaVersion"] as? Int == 1)
    #expect((body["requestId"] as? String)?.hasPrefix("native-") == true)
    let days = try #require(body["days"] as? [[String: Any]])
    #expect(days.count == 1)
    #expect(days[0]["day"] as? String == "2026-09-05")
    #expect(days[0]["platform"] as? String == "macos")
    #expect(days[0]["appVersion"] as? String == "1.2.3")
    #expect(days[0]["appBuild"] as? String == "143")
    #expect(days[0]["osVersion"] as? String == "26.0.1")
    #expect(days[0]["deviceFamily"] as? String == "mac")
    #expect(days[0]["architecture"] as? String == "arm64")
    let errors = try #require(days[0]["errors"] as? [[String: Any]])
    #expect(errors.isEmpty)
    let events = try #require(days[0]["events"] as? [[String: Any]])
    #expect(events.count == 1)
    #expect(events[0]["name"] as? String == "generation_completed")
    #expect(events[0]["dimension"] as? String == "nano")
    #expect(events[0]["count"] as? Int == 2)
}

@Test func analyticsOmitsAppKeyHeaderWhenNotConfigured() async throws {
    let transport = MockAnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: analyticsConfiguration(appKey: nil),
        transport: transport,
        stateStore: MemoryAnalyticsStateStore(),
        now: { isoDate("2026-09-05T10:00:00Z") },
        clientContext: analyticsContext()
    )

    try await client.track("generation_completed")
    await client.waitForAutomaticUpload()

    let request = try #require(await transport.capturedRequests().first)
    #expect(request.value(forHTTPHeaderField: "X-App-Key") == nil)
    #expect(request.value(forHTTPHeaderField: "X-App-ID") == "analytics-test")
    #expect(request.value(forHTTPHeaderField: "X-Installation-ID")?.isEmpty == false)
}

@Test func analyticsTracksBoundedCumulativeErrors() async throws {
    let transport = MockAnalyticsTransport()
    let store = MemoryAnalyticsStateStore()
    let timestamp = isoDate("2026-09-05T10:00:00Z")
    let client = AppAnalyticsClient(
        configuration: analyticsConfiguration(uploadInterval: 86_400),
        transport: transport,
        stateStore: store,
        now: { timestamp },
        clientContext: analyticsContext()
    )

    try await client.trackError(
        "model_load_failed",
        component: "generation",
        count: 2
    )
    try await client.trackError(
        "model_load_failed",
        component: "generation",
        count: 1
    )
    try await client.trackError(
        "unexpected_termination",
        component: "app",
        severity: .fatal
    )
    try await client.flush()

    let request = try #require(await transport.capturedRequests().last)
    let body = try requestBody(request)
    let days = try #require(body["days"] as? [[String: Any]])
    let errors = try #require(days[0]["errors"] as? [[String: Any]])
    #expect(errors.count == 2)

    let modelError = try #require(errors.first { $0["code"] as? String == "model_load_failed" })
    #expect(modelError["component"] as? String == "generation")
    #expect(modelError["severity"] as? String == "error")
    #expect(modelError["count"] as? Int == 3)

    let fatal = try #require(errors.first { $0["code"] as? String == "unexpected_termination" })
    #expect(fatal["component"] as? String == "app")
    #expect(fatal["severity"] as? String == "fatal")
    #expect(fatal["count"] as? Int == 1)
}

@Test func analyticsRejectsInvalidOrExcessErrorSignals() async throws {
    let client = AppAnalyticsClient(
        configuration: analyticsConfiguration(uploadInterval: 86_400),
        transport: MockAnalyticsTransport(),
        stateStore: MemoryAnalyticsStateStore(),
        now: { isoDate("2026-09-05T10:00:00Z") },
        clientContext: analyticsContext()
    )

    await #expect(throws: AppAnalyticsError.self) {
        try await client.trackError("NotValid", component: "generation")
    }
    await #expect(throws: AppAnalyticsError.self) {
        try await client.trackError("model_load_failed", component: "Generation")
    }
    await #expect(throws: AppAnalyticsError.self) {
        try await client.trackError("model_load_failed", component: "generation", count: 101)
    }

    try await client.trackError("model_load_failed", component: "generation", count: 100)
    await #expect(throws: AppAnalyticsError.self) {
        try await client.trackError("database_open_failed", component: "storage")
    }
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

@Test func inMemoryInstallationIDIsStableWithinClient() async throws {
    let transport = MockAnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: analyticsConfiguration(uploadInterval: 0, storageMode: .inMemory),
        transport: transport,
        stateStore: MemoryAnalyticsStateStore(),
        now: { isoDate("2026-09-05T10:00:00Z") }
    )

    try await client.track("generation_completed")
    await client.waitForAutomaticUpload()
    try await client.track("export_completed")
    await client.waitForAutomaticUpload()

    let requests = await transport.capturedRequests()
    #expect(requests.count == 2)
    let firstID = try #require(requests[0].value(forHTTPHeaderField: "X-Installation-ID"))
    let secondID = try #require(requests[1].value(forHTTPHeaderField: "X-Installation-ID"))
    #expect(firstID == secondID)
}

@Test func inMemoryInstallationIDIsUniquePerClientAndDoesNotTouchKeychain() async throws {
    let service = "com.hoangbkit.MacAppFoundationTests.InMemory.\(UUID().uuidString)"
    let secureStore = AppAnalyticsSecureStore(service: service)

    func trackedID() async throws -> String {
        let transport = MockAnalyticsTransport()
        let client = AppAnalyticsClient(
            configuration: AppAnalyticsConfiguration(
                appID: "analytics-test",
                baseURL: URL(string: "https://example.com")!,
                keychainService: service,
                stateStorageKey: "analytics-state-\(UUID().uuidString)",
                uploadInterval: 0,
                storageMode: .inMemory
            ),
            transport: transport,
            stateStore: MemoryAnalyticsStateStore(),
            now: { isoDate("2026-09-05T10:00:00Z") }
        )
        try await client.track("generation_completed")
        await client.waitForAutomaticUpload()
        let request = try #require(await transport.capturedRequests().first)
        return try #require(request.value(forHTTPHeaderField: "X-Installation-ID"))
    }

    let first = try await trackedID()
    let second = try await trackedID()
    #expect(first != second)
    #expect(try await secureStore.string(for: "analytics-test.installation") == nil)
}

@Test func inMemoryInstallationIDIgnoresKeychainIdentity() async throws {
    let service = "com.hoangbkit.MacAppFoundationTests.InMemory.\(UUID().uuidString)"

    func trackedID(for mode: AppAnalyticsStorageMode) async throws -> String {
        let transport = MockAnalyticsTransport()
        let client = AppAnalyticsClient(
            configuration: AppAnalyticsConfiguration(
                appID: "analytics-test",
                baseURL: URL(string: "https://example.com")!,
                keychainService: service,
                stateStorageKey: "analytics-state-\(UUID().uuidString)",
                uploadInterval: 0,
                storageMode: mode
            ),
            transport: transport,
            stateStore: MemoryAnalyticsStateStore(),
            now: { isoDate("2026-09-05T10:00:00Z") }
        )
        try await client.track("generation_completed")
        await client.waitForAutomaticUpload()
        let request = try #require(await transport.capturedRequests().first)
        return try #require(request.value(forHTTPHeaderField: "X-Installation-ID"))
    }

    let keychainID = try await trackedID(for: .persisted)
    let inMemoryID = try await trackedID(for: .inMemory)
    #expect(inMemoryID != keychainID)
}

@Test func inMemoryStorageModeDoesNotWriteUserDefaults() async throws {
    let key = "analytics-in-memory-\(UUID().uuidString)"
    let configuration = AppAnalyticsConfiguration(
        appID: "analytics-test",
        baseURL: URL(string: "https://example.com")!,
        stateStorageKey: key,
        uploadInterval: 86_400,
        storageMode: .inMemory
    )

    let client = AppAnalyticsClient(
        configuration: configuration,
        transport: MockAnalyticsTransport()
    )
    try await client.track("generation_completed", count: 3)
    try await client.flush()

    #expect(UserDefaults.standard.data(forKey: key) == nil)
}

@Test func inMemoryStorageModeCountersArePerClient() async throws {
    let configuration = AppAnalyticsConfiguration(
        appID: "analytics-test",
        baseURL: URL(string: "https://example.com")!,
        uploadInterval: 86_400,
        storageMode: .inMemory
    )

    let first = AppAnalyticsClient(
        configuration: configuration,
        transport: MockAnalyticsTransport()
    )
    try await first.track("generation_completed", count: 3)
    #expect(try await first.pendingDayCount() == 1)

    let second = AppAnalyticsClient(
        configuration: configuration,
        transport: MockAnalyticsTransport()
    )
    #expect(try await second.pendingDayCount() == 0)
}

@Test func explicitlyInjectedStateStoreWinsOverStorageMode() async throws {
    let customStore = MemoryAnalyticsStateStore()
    let configuration = analyticsConfiguration(
        uploadInterval: 86_400,
        storageMode: .inMemory
    )
    let client = AppAnalyticsClient(
        configuration: configuration,
        transport: MockAnalyticsTransport(),
        stateStore: customStore
    )

    try await client.track("generation_completed", count: 2)
    #expect(await customStore.containsData())
    #expect(UserDefaults.standard.data(forKey: configuration.stateStorageKey) == nil)
}

@Test func setEnabledFalseStopsAllAnalyticsWorkAndClearsStateWithoutFinalUpload() async throws {
    let transport = MockAnalyticsTransport()
    let store = MemoryAnalyticsStateStore()
    let client = AppAnalyticsClient(
        configuration: analyticsConfiguration(uploadInterval: 86_400),
        transport: transport,
        stateStore: store,
        now: { isoDate("2026-09-05T10:00:00Z") }
    )

    try await client.track("generation_completed")
    await client.waitForAutomaticUpload()
    #expect(await transport.capturedRequests().count == 1)

    // Record new local activity that has not been uploaded yet (throttled by uploadInterval).
    try await client.track("pending_before_disable")
    #expect(try await client.pendingDayCount() == 1)

    await client.setEnabled(false)
    #expect(await client.isEnabled == false)
    #expect(await store.containsData() == false)
    #expect(try await client.pendingDayCount() == 0)

    try await client.track("export_completed")
    try await client.trackError("model_load_failed", component: "generation")
    try await client.applicationDidBecomeActive(at: isoDate("2026-09-05T10:00:00Z"))
    try await client.applicationWillResignActive(at: isoDate("2026-09-05T10:01:00Z"))
    try await client.flush()
    await client.waitForAutomaticUpload()

    // Only the initial automatic upload ran; disabling performed no final upload and blocked later work.
    #expect(await transport.capturedRequests().count == 1)
    #expect(try await client.pendingDayCount() == 0)
}

@Test func reEnablingAnalyticsStartsFromCleanStateAndPreservesInstallationIdentity() async throws {
    let transport = MockAnalyticsTransport()
    let client = AppAnalyticsClient(
        configuration: analyticsConfiguration(uploadInterval: 86_400, storageMode: .inMemory),
        transport: transport,
        stateStore: MemoryAnalyticsStateStore(),
        now: { isoDate("2026-09-05T10:00:00Z") }
    )

    try await client.track("generation_completed", count: 5)
    await client.waitForAutomaticUpload()
    let firstRequest = try #require(await transport.capturedRequests().first)
    let firstInstallationID = try #require(firstRequest.value(forHTTPHeaderField: "X-Installation-ID"))

    await client.setEnabled(false)
    await client.setEnabled(true)
    #expect(await client.isEnabled)

    try await client.track("generation_completed")
    try await client.flush()

    let requests = await transport.capturedRequests()
    let lastRequest = try #require(requests.last)
    let secondInstallationID = try #require(lastRequest.value(forHTTPHeaderField: "X-Installation-ID"))
    #expect(firstInstallationID == secondInstallationID)

    let body = try requestBody(lastRequest)
    let days = try #require(body["days"] as? [[String: Any]])
    let events = try #require(days[0]["events"] as? [[String: Any]])
    #expect(events.count == 1)
    #expect(events[0]["count"] as? Int == 1)
}

@Test func setEnabledIsIdempotentAndDoesNotClearPreexistingStateWhenAlreadyDisabled() async throws {
    let transport = MockAnalyticsTransport()
    let store = MemoryAnalyticsStateStore()
    let configuration = analyticsConfiguration(uploadInterval: 86_400)

    let firstClient = AppAnalyticsClient(
        configuration: configuration,
        transport: transport,
        stateStore: store,
        now: { isoDate("2026-09-05T10:00:00Z") }
    )
    try await firstClient.track("generation_completed", count: 2)
    await firstClient.waitForAutomaticUpload()
    #expect(await store.containsData())

    // Calling setEnabled(true) when already enabled is a no-op and preserves state.
    await firstClient.setEnabled(true)
    #expect(try await firstClient.pendingDayCount() == 1)

    // A client created with enabled: false leaves existing state intact even if setEnabled(false) is called redundantly.
    var disabledConfig = configuration
    disabledConfig.enabled = false
    let disabledClient = AppAnalyticsClient(
        configuration: disabledConfig,
        transport: transport,
        stateStore: store,
        now: { isoDate("2026-09-05T10:00:00Z") }
    )
    await disabledClient.setEnabled(false)
    #expect(await store.containsData())

    await disabledClient.setEnabled(true)
    #expect(try await disabledClient.pendingDayCount() == 1)
}

@Test func resetLocalStateWorksWhileAnalyticsDisabled() async throws {
    let client = AppAnalyticsClient(
        configuration: analyticsConfiguration(enabled: false),
        transport: MockAnalyticsTransport(),
        stateStore: MemoryAnalyticsStateStore(),
        now: { isoDate("2026-09-05T10:00:00Z") }
    )

    try await client.resetLocalState()
    #expect(try await client.pendingDayCount() == 0)
}
