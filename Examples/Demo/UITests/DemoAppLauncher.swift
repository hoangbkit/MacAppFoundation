import Foundation
import XCTest

@MainActor
enum DemoAppLauncher {
    static let appBundleIdentifier = "com.hoangbkit.maf"

    static func launch(
        resetState: Bool = true,
        onboardingCompleted: Bool = false
    ) -> XCUIApplication {
        if resetState {
            resetPersistentState(onboardingCompleted: onboardingCompleted)
        }

        let app = XCUIApplication()
        app.launch()
        return app
    }

    private static func resetPersistentState(onboardingCompleted: Bool) {
        UserDefaults.standard.removePersistentDomain(forName: appBundleIdentifier)

        guard onboardingCompleted else { return }

        UserDefaults.standard.setPersistentDomain(
            [
                "MacAppFoundation.Onboarding.demo.completed": true,
                "MacAppFoundation.Onboarding.demo.currentStep": 0,
            ],
            forName: appBundleIdentifier
        )
    }
}

enum DemoUITestAccessibilityID {
    static let onboarding = "maf.demo.onboarding"
    static let onboardingBack = "maf.demo.onboarding.back"
    static let onboardingContinue = "maf.demo.onboarding.continue"
    static let settings = "maf.demo.settings"
}
