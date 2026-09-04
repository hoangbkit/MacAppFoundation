import Foundation
import SwiftUI
import XCTest
@testable import MacAppFoundation

@MainActor
final class V1IntegrationSurfaceTests: XCTestCase {
    func testCanonicalV1ViewsComposeFromSinglePurchaseManager() {
        let yearly = StoreProduct(
            id: "pro.yearly",
            displayName: "Yearly",
            description: "Yearly Pro",
            displayPrice: "$39.99",
            price: 39.99,
            subscriptionPeriod: .init(value: 1, unit: .year),
            introductoryOffer: .init(
                paymentMode: .freeTrial,
                period: .init(value: 7, unit: .day),
                displayPrice: "$0.00",
                price: 0,
                isEligible: true
            )
        )
        let purchaseFeature = PurchaseFeature(
            id: "batch",
            systemImage: "square.stack.3d.up",
            title: "Batch workflows",
            message: "Process multiple items at once.",
            freeValue: "Single item",
            proValue: "Batch"
        )
        let configuration = PurchaseConfiguration(
            productIDs: [yearly.id],
            preferredProductID: yearly.id,
            features: [purchaseFeature]
        )
        let manager = PurchaseManager(
            configuration: configuration,
            simulated: true,
            simulatedProducts: [yearly],
            simulatedOperationDelay: .milliseconds(0)
        )
        let premiumFeature = PremiumFeature(
            id: purchaseFeature.id,
            title: purchaseFeature.title
        )

        _ = ProPaywallView(
            purchaseManager: manager,
            configuration: ProPaywallConfiguration(
                title: "Example Pro",
                subtitle: "Unlock everything.",
                termsURL: URL(string: "https://example.com/terms")!,
                privacyURL: URL(string: "https://example.com/privacy")!
            )
        )

        _ = ProGate(
            purchaseManager: manager,
            feature: premiumFeature
        ) {
            Text("Pro content")
        } lockedContent: { feature in
            ProLockedOverlay(feature: feature, onUpgrade: {})
        }

        _ = ProGateButton(
            purchaseManager: manager,
            feature: premiumFeature,
            lockInfo: ProLockInfo(
                title: "Pro Feature",
                reason: "This workflow requires Pro.",
                freeTierDescription: "Single item",
                proTierDescription: "Batch"
            ),
            onAction: {},
            onUpgrade: {}
        ) {
            Text("Run")
        }

        _ = ProUpsellView(
            title: "Unlock batch workflows",
            message: "Upgrade to Pro to continue.",
            features: [purchaseFeature],
            onPrimaryAction: {},
            onSecondaryAction: {}
        )

        _ = ProPlanPane(
            purchaseManager: manager,
            configuration: ProPlanPaneConfiguration(appName: "Example"),
            onUpgrade: {}
        )

        #if DEBUG
        _ = FoundationDeveloperView(
            purchaseManager: manager,
            configuration: FoundationDeveloperConfiguration()
        )
        #endif

        XCTAssertEqual(manager.configuration, configuration)
        XCTAssertEqual(manager.features, [purchaseFeature])
        XCTAssertFalse(manager.hasPro)
    }
}
