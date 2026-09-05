import Foundation
import MacAppFoundation

actor DemoAnalyticsTransport: AppAnalyticsTransport {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let body = request.httpBody,
              let object = try JSONSerialization.jsonObject(with: body) as? [String: Any],
              let requestID = object["requestId"] as? String,
              let days = object["days"] as? [[String: Any]] else {
            throw AppAnalyticsError.invalidResponse
        }
        let payload: [String: Any] = [
            "ok": true,
            "requestId": requestID,
            "acceptedDays": days.compactMap { $0["day"] as? String },
        ]
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (try JSONSerialization.data(withJSONObject: payload), response)
    }
}

enum DemoAnalytics {
    static let client = AppAnalyticsClient(
        configuration: AppAnalyticsConfiguration(
            appID: "macappfoundation-demo",
            appKey: "demo-analytics-key-not-for-production",
            baseURL: URL(string: "https://example.com")!,
            stateStorageKey: "macappfoundation.demo.analytics",
            appVersion: "1.0",
            uploadInterval: 6 * 60 * 60,
            transportRetryCount: 0
        ),
        transport: DemoAnalyticsTransport()
    )
}
