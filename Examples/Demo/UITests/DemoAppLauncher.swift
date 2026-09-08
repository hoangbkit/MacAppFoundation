import Foundation
import XCTest

@MainActor
enum DemoAppLauncher {
    static let appBundleIdentifier = "com.hoangbkit.maf"
    static let simulatedPurchasePersistenceKey = "MacAppFoundationDemo.simulatedPurchases"
    static let yearlyProductID = "com.hoangbkit.macappfoundation.demo.pro.yearly"

    static func launch(
        resetState: Bool = true,
        onboardingCompleted: Bool = false,
        purchasedProductIDs: [String] = [],
        launchArguments: [String] = []
    ) -> XCUIApplication {
        if resetState {
            resetPersistentState(
                onboardingCompleted: onboardingCompleted,
                purchasedProductIDs: purchasedProductIDs
            )
        }

        let app = XCUIApplication()
        app.launchArguments.append(contentsOf: launchArguments)
        app.launch()
        return app
    }

    private static func resetPersistentState(
        onboardingCompleted: Bool,
        purchasedProductIDs: [String]
    ) {
        UserDefaults.standard.removePersistentDomain(forName: appBundleIdentifier)

        var domain: [String: Any] = [:]

        if onboardingCompleted {
            domain["MacAppFoundation.Onboarding.demo.completed"] = true
            domain["MacAppFoundation.Onboarding.demo.currentStep"] = 0
        }

        if !purchasedProductIDs.isEmpty {
            domain[simulatedPurchasePersistenceKey] = purchasedProductIDs
        }

        if !domain.isEmpty {
            UserDefaults.standard.setPersistentDomain(
                domain,
                forName: appBundleIdentifier
            )
        }
    }
}

enum DemoUITestAccessibilityID {
    static let onboarding = "maf.demo.onboarding"
    static let onboardingBack = "maf.demo.onboarding.back"
    static let onboardingContinue = "maf.demo.onboarding.continue"
    static let settings = "maf.demo.settings"
}
