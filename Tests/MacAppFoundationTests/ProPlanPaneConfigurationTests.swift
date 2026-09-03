import XCTest
@testable import MacAppFoundation

final class ProPlanPaneConfigurationTests: XCTestCase {
    func testDefaultCopyUsesAppName() {
        let configuration = ProPlanPaneConfiguration(appName: "Demo")

        XCTAssertEqual(configuration.freeTitle, "Free")
        XCTAssertEqual(configuration.proTitle, "Pro")
        XCTAssertEqual(
            configuration.freeDescription,
            "Upgrade to unlock the full Demo experience."
        )
        XCTAssertEqual(
            configuration.proDescription,
            "You have access to Demo Pro features."
        )
        XCTAssertEqual(configuration.upgradeButtonTitle, "Upgrade to Pro")
        XCTAssertEqual(configuration.manageSubscriptionTitle, "Manage Subscription")
        XCTAssertEqual(
            configuration.manageSubscriptionURL.absoluteString,
            "https://apps.apple.com/account/subscriptions"
        )
        XCTAssertNil(configuration.features)
    }

    func testAppCanOverrideCopyAndFeatureList() {
        let feature = PurchaseFeature(
            id: "export",
            systemImage: "square.and.arrow.up",
            title: "Batch Export",
            message: "Export whole folders at once.",
            freeValue: "Single file",
            proValue: "Whole folders"
        )
        let manageURL = URL(string: "https://example.com/manage")!
        let configuration = ProPlanPaneConfiguration(
            appName: "Demo",
            freeTitle: "Starter",
            proTitle: "Studio",
            freeDescription: "Starter access",
            proDescription: "Everything unlocked",
            upgradeButtonTitle: "See Plans",
            manageSubscriptionTitle: "Manage Plan",
            manageSubscriptionURL: manageURL,
            features: [feature]
        )

        XCTAssertEqual(configuration.freeTitle, "Starter")
        XCTAssertEqual(configuration.proTitle, "Studio")
        XCTAssertEqual(configuration.freeDescription, "Starter access")
        XCTAssertEqual(configuration.proDescription, "Everything unlocked")
        XCTAssertEqual(configuration.upgradeButtonTitle, "See Plans")
        XCTAssertEqual(configuration.manageSubscriptionTitle, "Manage Plan")
        XCTAssertEqual(configuration.manageSubscriptionURL, manageURL)
        XCTAssertEqual(configuration.features, [feature])
    }
}
