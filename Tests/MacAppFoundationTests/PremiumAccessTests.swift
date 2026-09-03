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
