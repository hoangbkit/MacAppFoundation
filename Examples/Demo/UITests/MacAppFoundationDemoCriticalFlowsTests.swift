import XCTest

final class MacAppFoundationDemoCriticalFlowsTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingCompletesIntoMainWindow() {
        let app = DemoAppLauncher.launch()
        defer { app.terminate() }

        let continueButton = app.buttons[DemoUITestAccessibilityID.onboardingContinue]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))

        continueButton.tap()
        XCTAssertTrue(
            app.buttons[DemoUITestAccessibilityID.onboardingBack].waitForExistence(timeout: 5),
            "Second onboarding step should expose Back."
        )

        app.buttons[DemoUITestAccessibilityID.onboardingContinue].tap()
        app.buttons[DemoUITestAccessibilityID.onboardingContinue].tap()

        XCTAssertTrue(
            app.staticTexts["MacAppFoundation"].waitForExistence(timeout: 10),
            "Completing onboarding should open the Demo main window."
        )
    }

    @MainActor
    func testSettingsPaneNavigation() {
        let app = DemoAppLauncher.launch(onboardingCompleted: true)
        defer { app.terminate() }

        openSettings(in: app)

        assertPane("General", isSelected: true, in: app)

        app.buttons["Appearance"].tap()
        assertPane("Appearance", isSelected: true, in: app)
        XCTAssertTrue(app.buttons["System"].waitForExistence(timeout: 5))

        app.buttons["Plan"].tap()
        assertPane("Plan", isSelected: true, in: app)

        app.buttons["About"].tap()
        assertPane("About", isSelected: true, in: app)
        XCTAssertTrue(app.staticTexts["Architecture"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testProPlanButtonRoutesDirectlyToPlanSettings() {
        let app = DemoAppLauncher.launch(
            onboardingCompleted: true,
            purchasedProductIDs: [DemoAppLauncher.yearlyProductID]
        )
        defer { app.terminate() }

        let managePlan = app.buttons[DemoUITestAccessibilityID.proPlanButton]
        XCTAssertTrue(
            managePlan.waitForExistence(timeout: 10),
            "A persisted simulated Pro entitlement should expose Manage plan."
        )
        XCTAssertEqual(managePlan.label, "Manage plan")
        XCTAssertEqual(managePlan.value as? String, "Pro Yearly")

        managePlan.tap()

        let plan = app.buttons["Plan"]
        XCTAssertTrue(plan.waitForExistence(timeout: 10))
        XCTAssertEqual(plan.value as? String, "Selected")
    }

    @MainActor
    func testThemeSelectionPersistsAcrossRelaunch() {
        var app = DemoAppLauncher.launch(onboardingCompleted: true)
        openSettings(in: app)

        app.buttons["Appearance"].tap()
        let midnight = app.buttons["Midnight"]
        XCTAssertTrue(midnight.waitForExistence(timeout: 10))
        midnight.tap()
        XCTAssertTrue((midnight.value as? String)?.contains("Selected") == true)

        app.terminate()

        app = DemoAppLauncher.launch(resetState: false)
        defer { app.terminate() }

        openSettings(in: app)
        app.buttons["Appearance"].tap()

        let persistedMidnight = app.buttons["Midnight"]
        XCTAssertTrue(persistedMidnight.waitForExistence(timeout: 10))
        XCTAssertTrue(
            (persistedMidnight.value as? String)?.contains("Selected") == true,
            "The selected theme should survive app relaunch."
        )
    }

    @MainActor
    func testPaywallFooterActionsStayVisibleAndHittableAtCompactHeight() {
        let app = DemoAppLauncher.launch(
            onboardingCompleted: true,
            launchArguments: [DemoAppLauncher.compactPaywallArgument]
        )
        defer { app.terminate() }

        app.typeKey("p", modifierFlags: [.command, .option])

        let paywallWindow = app.windows["Demo Pro"]
        XCTAssertTrue(
            paywallWindow.waitForExistence(timeout: 10),
            "The Demo Pro paywall window should open."
        )
        XCTAssertLessThanOrEqual(
            paywallWindow.frame.height,
            450,
            "The compact launch mode must exercise the paywall at roughly its 420pt minimum height."
        )

        let restore = app.buttons["Restore Purchases"]
        let close = app.buttons["Close"]

        XCTAssertTrue(restore.waitForExistence(timeout: 10))
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        XCTAssertTrue(restore.isHittable)
        XCTAssertTrue(close.isHittable)
        XCTAssertGreaterThanOrEqual(
            close.frame.minY,
            paywallWindow.frame.minY - 1,
            "The footer action must not be clipped above the visible paywall window."
        )
        XCTAssertLessThanOrEqual(
            close.frame.maxY,
            paywallWindow.frame.maxY + 1,
            "The footer action must remain inside the visible paywall window."
        )

        close.tap()
        XCTAssertFalse(close.waitForExistence(timeout: 3))
    }

    @MainActor
    private func openSettings(in app: XCUIApplication) {
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(
            app.buttons["General"].waitForExistence(timeout: 10),
            "Command-comma should open the Demo Settings window."
        )
    }

    @MainActor
    private func assertPane(
        _ title: String,
        isSelected: Bool,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let button = app.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(
            button.value as? String,
            isSelected ? "Selected" : "",
            file: file,
            line: line
        )
    }
}
