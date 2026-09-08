import XCTest

final class MacAppFoundationDemoLaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCleanLaunchShowsOnboarding() {
        let app = DemoAppLauncher.launch()
        defer { app.terminate() }

        let continueButton = app.buttons[DemoUITestAccessibilityID.onboardingContinue]
        XCTAssertTrue(
            continueButton.waitForExistence(timeout: 10),
            "A reset Demo launch should present an accessible onboarding primary action."
        )
    }
}
