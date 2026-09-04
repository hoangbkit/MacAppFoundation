import Foundation
import MacAppFoundation

@MainActor
enum DemoCommerce {
    static let monthlyID = "com.hoangbkit.macappfoundation.demo.pro.monthly"
    static let yearlyID = "com.hoangbkit.macappfoundation.demo.pro.yearly"
    static let lifetimeID = "com.hoangbkit.macappfoundation.demo.pro.lifetime"

    static let features: [PurchaseFeature] = [
        PurchaseFeature(
            id: "batch",
            systemImage: "square.stack.3d.up",
            title: "Batch workflows",
            message: "Process many items in one operation.",
            freeValue: "One item",
            proValue: "Unlimited batch"
        ),
        PurchaseFeature(
            id: "automation",
            systemImage: "bolt.fill",
            title: "Automation",
            message: "Run premium automated workflows without manual steps.",
            freeValue: "Manual",
            proValue: "Automatic"
        ),
        PurchaseFeature(
            id: "export",
            systemImage: "square.and.arrow.up",
            title: "Advanced export",
            message: "Unlock every export format and preset.",
            freeValue: "Basic export",
            proValue: "All formats"
        ),
        PurchaseFeature(
            id: "history",
            systemImage: "clock.arrow.circlepath",
            title: "Unlimited history",
            message: "Keep and revisit every generated result.",
            freeValue: "Recent only",
            proValue: "Unlimited"
        )
    ]

    static let simulatedProducts: [StoreProduct] = [
        StoreProduct(
            id: monthlyID,
            displayName: "Monthly",
            description: "MacAppFoundation Demo Pro, billed monthly.",
            displayPrice: "$4.99",
            price: 4.99,
            subscriptionPeriod: .init(value: 1, unit: .month),
            introductoryOffer: .init(
                paymentMode: .payAsYouGo,
                period: .init(value: 1, unit: .month),
                periodCount: 3,
                displayPrice: "$0.99",
                price: 0.99,
                isEligible: true
            )
        ),
        StoreProduct(
            id: yearlyID,
            displayName: "Yearly",
            description: "MacAppFoundation Demo Pro, billed yearly.",
            displayPrice: "$39.99",
            price: 39.99,
            subscriptionPeriod: .init(value: 1, unit: .year),
            introductoryOffer: .init(
                paymentMode: .freeTrial,
                period: .init(value: 7, unit: .day),
                displayPrice: "Free",
                price: 0,
                isEligible: true
            )
        ),
        StoreProduct(
            id: lifetimeID,
            displayName: "Lifetime",
            description: "Permanent access to every Demo Pro feature.",
            displayPrice: "$79.99",
            price: 79.99,
            subscriptionPeriod: nil
        )
    ]

    static let configuration = PurchaseConfiguration(
        productIDs: [monthlyID, yearlyID, lifetimeID],
        preferredProductID: yearlyID,
        features: features,
        productLoadAttempts: 2
    )

    static let manager = PurchaseManager(
        configuration: configuration,
        simulated: true,
        simulatedProducts: simulatedProducts,
        simulatedPersistenceKey: "MacAppFoundationDemo.simulatedPurchases",
        simulatedOperationDelay: .milliseconds(250)
    )

    static let paywallConfiguration = ProPaywallConfiguration(
        title: "Demo Pro",
        subtitle: "One paywall showing subscriptions, a free trial, paid intro pricing, and lifetime access.",
        highlightedProductID: yearlyID,
        highlightedProductBadge: "BEST VALUE",
        termsURL: URL(string: "https://example.com/terms")!,
        privacyURL: URL(string: "https://example.com/privacy")!,
        showsRedeemCode: true
    )

    static let planConfiguration = ProPlanPaneConfiguration(
        appName: "MacAppFoundation Demo"
    )

    static let batchFeature = PremiumFeature(
        id: "batch",
        title: "Batch workflows"
    )

    static let automationFeature = PremiumFeature(
        id: "automation",
        title: "Automation"
    )
}
