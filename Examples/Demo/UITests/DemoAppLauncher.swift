import XCTest

@MainActor
enum DemoAppLauncher {
    static let yearlyProductID = "com.hoangbkit.macappfoundation.demo.pro.yearly"

    static func launch(
        resetState: Bool = true,
        onboardingCompleted: Bool = false,
        purchasedProductIDs: [String] = [],
        launchArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()

        if resetState {
            app.launchArguments.append("--maf-ui-test-reset-state")
        }

        if onboardingCompleted {
            app.launchArguments.append("--maf-ui-test-onboarding-completed")
        }

        for productID in purchasedProductIDs {
            app.launchArguments.append("--maf-ui-test-purchased-product-id=\(productID)")
        }

        app.launchArguments.append(contentsOf: launchArguments)
        app.launch()
        return app
    }
}

enum DemoUITestAccessibilityID {
    static let onboarding = "maf.demo.onboarding"
    static let onboardingBack = "maf.demo.onboarding.back"
    static let onboardingContinue = "maf.demo.onboarding.continue"
    static let settings = "maf.demo.settings"
}
