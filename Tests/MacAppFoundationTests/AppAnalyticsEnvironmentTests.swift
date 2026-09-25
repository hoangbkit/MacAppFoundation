import Foundation
import SwiftUI
import XCTest
@testable import MacAppFoundation

final class AppAnalyticsEnvironmentTests: XCTestCase {
    func testAnalyticsEnvironmentDefaultsToNil() {
        let values = EnvironmentValues()
        XCTAssertNil(values.appAnalytics)
    }

    func testAnalyticsEnvironmentCanCarrySharedClient() throws {
        let baseURL = try XCTUnwrap(URL(string: "https://analytics.example.com"))
        let client = AppAnalyticsClient(
            configuration: AppAnalyticsConfiguration(
                appID: "test-app",
                baseURL: baseURL
            )
        )
        var values = EnvironmentValues()

        values.appAnalytics = client

        XCTAssertTrue(values.appAnalytics === client)
    }
}
