import XCTest

@MainActor
final class MacAppFoundationDemoLaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCleanLaunchShowsOnboarding() {
        let app = DemoAppLauncher.launch()
        defer { app.terminate() }

        let onboarding = app.descendants(matching: .any)[DemoUITestAccessibilityID.onboarding]
        XCTAssertTrue(
            onboarding.waitForExistence(timeout: 10),
            "A reset Demo launch should present onboarding."
        )

        XCTAssertTrue(
            app.buttons[DemoUITestAccessibilityID.onboardingContinue].exists,
            "The onboarding primary action should be accessible to UI tests."
        )
    }
}
