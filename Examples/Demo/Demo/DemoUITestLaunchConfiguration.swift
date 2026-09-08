#if DEBUG
import Foundation

@MainActor
enum DemoUITestLaunchConfiguration {
    static let resetStateArgument = "--maf-ui-test-reset-state"
    static let onboardingCompletedArgument = "--maf-ui-test-onboarding-completed"
    static let purchasedProductArgumentPrefix = "--maf-ui-test-purchased-product-id="

    static func apply() {
        let arguments = ProcessInfo.processInfo.arguments
        let defaults = UserDefaults.standard

        if arguments.contains(resetStateArgument),
           let bundleIdentifier = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleIdentifier)
        }

        if arguments.contains(onboardingCompletedArgument) {
            defaults.set(true, forKey: "MacAppFoundation.Onboarding.demo.completed")
            defaults.set(0, forKey: "MacAppFoundation.Onboarding.demo.currentStep")
        }

        let purchasedProductIDs = arguments.compactMap { argument -> String? in
            guard argument.hasPrefix(purchasedProductArgumentPrefix) else { return nil }
            let productID = String(argument.dropFirst(purchasedProductArgumentPrefix.count))
            return productID.isEmpty ? nil : productID
        }

        if !purchasedProductIDs.isEmpty {
            defaults.set(
                purchasedProductIDs,
                forKey: "MacAppFoundationDemo.simulatedPurchases"
            )
        }
    }
}
#endif
