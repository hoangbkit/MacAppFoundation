import Foundation
import XCTest
@testable import MacAppFoundation

final class ProPaywallConfigurationTests: XCTestCase {
    func testKeepsAppOwnedCopyAndLegalDestinations() throws {
        let termsURL = try XCTUnwrap(URL(string: "https://example.com/terms"))
        let privacyURL = try XCTUnwrap(URL(string: "https://example.com/privacy"))
        let feature = ProPaywallFeature(
            id: "export",
            systemImage: "square.and.arrow.up",
            title: "Export",
            message: "Export without limits."
        )

        let configuration = ProPaywallConfiguration(
            title: "Example Pro",
            subtitle: "Unlock everything.",
            features: [feature],
            highlightedProductID: "pro.yearly",
            termsURL: termsURL,
            privacyURL: privacyURL
        )

        XCTAssertEqual(configuration.title, "Example Pro")
        XCTAssertEqual(configuration.subtitle, "Unlock everything.")
        XCTAssertEqual(configuration.features, [feature])
        XCTAssertEqual(configuration.highlightedProductID, "pro.yearly")
        XCTAssertEqual(configuration.highlightedProductBadge, "BEST VALUE")
        XCTAssertEqual(configuration.purchaseButtonTitle, "Continue")
        XCTAssertEqual(configuration.termsURL, termsURL)
        XCTAssertEqual(configuration.privacyURL, privacyURL)
        XCTAssertTrue(configuration.showsRedeemCode)
    }

    func testPurchaseFeatureCanFeedPaywallFeature() {
        let purchaseFeature = PurchaseFeature(
            id: "voices",
            systemImage: "waveform",
            title: "Voices",
            message: "Unlock every voice.",
            freeValue: "Limited",
            proValue: "Unlimited"
        )

        let paywallFeature = ProPaywallFeature(purchaseFeature)

        XCTAssertEqual(paywallFeature.id, purchaseFeature.id)
        XCTAssertEqual(paywallFeature.systemImage, purchaseFeature.systemImage)
        XCTAssertEqual(paywallFeature.title, purchaseFeature.title)
        XCTAssertEqual(paywallFeature.message, purchaseFeature.message)
    }
}
