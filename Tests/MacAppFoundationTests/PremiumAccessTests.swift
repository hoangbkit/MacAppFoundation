import XCTest
@testable import MacAppFoundation

final class PremiumAccessTests: XCTestCase {
    private let feature = PremiumFeature(id: "export", title: "Unlimited Export")

    func testFreeRequirementIsAlwaysAllowed() {
        let decision = PremiumAccessPolicy().decision(
            for: feature,
            requirement: .free,
            hasPro: false
        )

        XCTAssertEqual(decision, .allowed)
    }

    func testProRequirementAllowsActiveProUser() {
        let decision = PremiumAccessPolicy().decision(
            for: feature,
            requirement: .pro,
            hasPro: true
        )

        XCTAssertEqual(decision, .allowed)
    }

    func testProRequirementLocksFreeUser() {
        let decision = PremiumAccessPolicy().decision(
            for: feature,
            requirement: .pro,
            hasPro: false
        )

        XCTAssertEqual(decision, .requiresPro(feature: feature))
    }

    func testExistingContentRemainsAccessibleByDefault() {
        let decision = PremiumAccessPolicy().decision(
            for: feature,
            requirement: .pro,
            hasPro: false,
            isExistingContent: true
        )

        XCTAssertEqual(decision, .allowed)
    }

    func testExistingContentCanBeLockedWithStrictPolicy() {
        let policy = PremiumAccessPolicy(existingContentRemainsAccessible: false)
        let decision = policy.decision(
            for: feature,
            requirement: .pro,
            hasPro: false,
            isExistingContent: true
        )

        XCTAssertEqual(decision, .requiresPro(feature: feature))
    }

    @MainActor
    func testProPlanButtonAcceptsCustomHeight() {
        let purchases = PurchaseManager(
            configuration: PurchaseConfiguration(productIDs: ["pro"]),
            simulated: true
        )

        _ = ProPlanButton(
            purchaseManager: purchases,
            height: 28,
            onUpgrade: {},
            onManagePlan: {}
        )
    }

    func testUnresolvedPremiumPresentationNeverLooksFreeOrLocked() {
        let checkingPlan = ProPlanButtonPresentation(
            isResolved: false,
            hasPro: false,
            activeProduct: nil
        )
        XCTAssertEqual(checkingPlan.title, "Checking…")
        XCTAssertEqual(checkingPlan.iconName, "hourglass")
        XCTAssertEqual(checkingPlan.accessibilityValue, "Checking")
        XCTAssertFalse(checkingPlan.isEnabled)
        XCTAssertFalse(checkingPlan.isPro)

        let staleProWhileUnresolved = ProPlanButtonPresentation(
            isResolved: false,
            hasPro: true,
            activeProduct: nil
        )
        XCTAssertEqual(staleProWhileUnresolved, checkingPlan)

        let checkingGate = PremiumGatePresentationState(
            feature: feature,
            requirement: .pro,
            isResolved: false,
            hasPro: false
        )
        XCTAssertEqual(checkingGate, .checking)

        let staleProGate = PremiumGatePresentationState(
            feature: feature,
            requirement: .pro,
            isResolved: false,
            hasPro: true
        )
        XCTAssertEqual(staleProGate, .checking)

        let freeGate = PremiumGatePresentationState(
            feature: feature,
            requirement: .pro,
            isResolved: true,
            hasPro: false
        )
        XCTAssertEqual(freeGate, .requiresPro(feature: feature))

        let proGate = PremiumGatePresentationState(
            feature: feature,
            requirement: .pro,
            isResolved: true,
            hasPro: true
        )
        XCTAssertEqual(proGate, .allowed)

        let freeRequirementWhileUnresolved = PremiumGatePresentationState(
            feature: feature,
            requirement: .free,
            isResolved: false,
            hasPro: false
        )
        XCTAssertEqual(freeRequirementWhileUnresolved, .allowed)
    }

    func testLockInfoPreservesAppOwnedCopy() {
        let info = ProLockInfo(
            title: "Pro Feature",
            reason: "Batch export requires Pro.",
            freeTierDescription: "One export at a time",
            proTierDescription: "Unlimited batch export",
            upgradeButtonTitle: "See Pro Plans"
        )

        XCTAssertEqual(info.title, "Pro Feature")
        XCTAssertEqual(info.upgradeButtonTitle, "See Pro Plans")
        XCTAssertEqual(info.proTierDescription, "Unlimited batch export")
    }
}
