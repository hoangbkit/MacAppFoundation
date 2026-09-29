#if DEBUG
import Foundation
import XCTest
@testable import MacAppFoundation

final class AppAnalyticsDeveloperToolsTests: XCTestCase {
    func testDeveloperSnapshotExposesConfigurationAndPersistedCounters() async throws {
        let store = DeveloperAnalyticsMemoryStore()
        let appKey = "com.example.analytics"
        let client = AppAnalyticsClient(
            configuration: AppAnalyticsConfiguration(
                appID: "developer-test",
                appKey: appKey,
                baseURL: URL(string: "https://analytics.example.com")!,
                appVersion: "1.2.3",
                uploadInterval: 300
            ),
            transport: DeveloperAnalyticsTransport(),
            stateStore: store
        )

        try await client.track(
            "export_completed",
            dimension: "mp3",
            count: 2
        )
        await client.waitForAutomaticUpload()

        let snapshot = try await client.developerSnapshot()

        XCTAssertEqual(snapshot.configuration.appID, "developer-test")
        XCTAssertEqual(snapshot.configuration.appKey, appKey)
        XCTAssertEqual(
            snapshot.configuration.endpointURL.absoluteString,
            "https://analytics.example.com/v1/analytics/batch"
        )
        XCTAssertEqual(snapshot.configuration.resolvedAppVersion, "1.2.3")
        XCTAssertEqual(snapshot.runtime.pendingDayCount, 1)

        let day = try XCTUnwrap(snapshot.days.first)
        let event = try XCTUnwrap(
            day.events.first {
                $0.name == "export_completed" && $0.dimension == "mp3"
            }
        )
        XCTAssertEqual(event.count, 2)
    }

    func testDeveloperOverrideCanEnableConfiguredDisabledAnalytics() async throws {
        let transport = DeveloperAnalyticsTransport()
        let store = DeveloperAnalyticsMemoryStore()
        let client = AppAnalyticsClient(
            configuration: AppAnalyticsConfiguration(
                appID: "developer-disabled-test",
                appKey: "com.example.disabledoverride",
                baseURL: URL(string: "https://analytics.example.com")!,
                enabled: false,
                uploadInterval: 300
            ),
            transport: transport,
            stateStore: store
        )

        try await client.track("Not Valid")
        var snapshot = try await client.developerSnapshot()
        XCTAssertFalse(snapshot.configuration.configuredEnabled)
        XCTAssertFalse(snapshot.configuration.effectiveEnabled)
        XCTAssertNil(snapshot.configuration.developerEnabledOverride)
        XCTAssertTrue(snapshot.days.isEmpty)

        await client.developerSetEnabledOverride(true)
        try await client.track("generation_completed", dimension: "local")
        await client.waitForAutomaticUpload()

        snapshot = try await client.developerSnapshot()
        XCTAssertFalse(snapshot.configuration.configuredEnabled)
        XCTAssertTrue(snapshot.configuration.effectiveEnabled)
        XCTAssertEqual(snapshot.configuration.developerEnabledOverride, true)
        XCTAssertTrue(
            snapshot.days.flatMap(\.events).contains {
                $0.name == "generation_completed" && $0.dimension == "local"
            }
        )
    }

    func testDeveloperOverrideCanDisableConfiguredEnabledAnalytics() async throws {
        let client = AppAnalyticsClient(
            configuration: AppAnalyticsConfiguration(
                appID: "developer-enabled-test",
                appKey: "com.example.enabledoverride",
                baseURL: URL(string: "https://analytics.example.com")!,
                enabled: true,
                uploadInterval: 300
            ),
            transport: DeveloperAnalyticsTransport(),
            stateStore: DeveloperAnalyticsMemoryStore()
        )

        await client.developerSetEnabledOverride(false)
        try await client.track("Not Valid")

        var snapshot = try await client.developerSnapshot()
        XCTAssertTrue(snapshot.configuration.configuredEnabled)
        XCTAssertFalse(snapshot.configuration.effectiveEnabled)
        XCTAssertEqual(snapshot.configuration.developerEnabledOverride, false)
        XCTAssertTrue(snapshot.days.isEmpty)

        await client.developerSetEnabledOverride(nil)
        snapshot = try await client.developerSnapshot()
        XCTAssertTrue(snapshot.configuration.configuredEnabled)
        XCTAssertTrue(snapshot.configuration.effectiveEnabled)
        XCTAssertNil(snapshot.configuration.developerEnabledOverride)
    }

    @MainActor
    func testTrackedEventAppearsInLiveDeveloperActivity() async throws {
        AppAnalyticsDeveloperActivityStore.shared.clear()

        let client = AppAnalyticsClient(
            configuration: AppAnalyticsConfiguration(
                appID: "developer-live-test",
                appKey: "com.example.liveanalytics",
                baseURL: URL(string: "https://analytics.example.com")!,
                uploadInterval: 300
            ),
            transport: DeveloperAnalyticsTransport(),
            stateStore: DeveloperAnalyticsMemoryStore()
        )

        try await client.track("generation_completed", dimension: "local")
        await Task.yield()

        XCTAssertTrue(
            AppAnalyticsDeveloperActivityStore.shared.entries.contains {
                $0.kind == .event
                    && $0.title == "generation_completed"
                    && $0.detail?.contains("dimension=local") == true
            }
        )

        AppAnalyticsDeveloperActivityStore.shared.clear()
    }
}

private actor DeveloperAnalyticsMemoryStore: AppAnalyticsStateStoring {
    private var data: Data?

    func load() async throws -> Data? {
        data
    }

    func save(_ data: Data) async throws {
        self.data = data
    }

    func remove() async throws {
        data = nil
    }
}

private struct DeveloperAnalyticsTransport: AppAnalyticsTransport {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        let requestID = try XCTUnwrap(object["requestId"] as? String)
        let days = try XCTUnwrap(object["days"] as? [[String: Any]])
        let acceptedDays = try days.map { day in
            try XCTUnwrap(day["day"] as? String)
        }

        let responseBody = try JSONSerialization.data(
            withJSONObject: [
                "ok": true,
                "requestId": requestID,
                "acceptedDays": acceptedDays,
            ]
        )
        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )
        )
        return (responseBody, response)
    }
}
#endif
