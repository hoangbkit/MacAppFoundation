import XCTest
@testable import MacAppFoundation

final class PurchaseConfigurationTests: XCTestCase {
    func testNormalizesProductIdentifiersAndPreservesOrder() {
        let configuration = PurchaseConfiguration(
            productIDs: [" yearly ", "monthly", "yearly", "", "monthly"]
        )

        XCTAssertEqual(configuration.productIDs, ["yearly", "monthly"])
        XCTAssertEqual(configuration.entitledProductIDs, ["yearly", "monthly"])
    }

    func testEntitlementIdentifiersAreLimitedToManagedCatalog() {
        let configuration = PurchaseConfiguration(
            productIDs: ["monthly", "lifetime"],
            entitledProductIDs: [" monthly ", "legacy", ""]
        )

        XCTAssertEqual(configuration.entitledProductIDs, ["monthly"])
    }

    func testDropsPreferredIdentifierThatIsNotInCatalog() {
        let configuration = PurchaseConfiguration(
            productIDs: ["monthly"],
            preferredProductID: "yearly"
        )

        XCTAssertNil(configuration.preferredProductID)
    }

    func testClampsProductLoadAttemptsToAtLeastOne() {
        let configuration = PurchaseConfiguration(
            productIDs: ["monthly"],
            productLoadAttempts: 0
        )

        XCTAssertEqual(configuration.productLoadAttempts, 1)
    }

    func testNormalizesRegisteredFeaturesByIdentifier() {
        let feature = PurchaseFeature(
            id: " exports ",
            systemImage: "square.and.arrow.up",
            title: "Exports",
            message: "Export without limits.",
            freeValue: "3 / week",
            proValue: "Unlimited"
        )
        let duplicate = PurchaseFeature(
            id: "exports",
            systemImage: "star",
            title: "Duplicate",
            message: "Ignored",
            freeValue: "None",
            proValue: "All"
        )

        let configuration = PurchaseConfiguration(
            productIDs: ["yearly"],
            features: [feature, duplicate]
        )

        XCTAssertEqual(configuration.features.map(\.id), ["exports"])
        XCTAssertEqual(configuration.features.first?.title, "Exports")
    }
}
