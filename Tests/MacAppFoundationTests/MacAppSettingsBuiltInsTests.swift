import Foundation
import Testing
@testable import MacAppFoundation

@Suite("MacAppSettings built-ins")
struct MacAppSettingsBuiltInsTests {
    @MainActor
    @Test("Theme pane uses stable built-in metadata")
    func themeMetadata() {
        let defaults = UserDefaults(suiteName: "MacAppSettingsBuiltInsTests.theme")!
        defaults.removePersistentDomain(forName: "MacAppSettingsBuiltInsTests.theme")
        let store = MacAppThemeStore(
            configuration: .builtIns([.system, .midnight]),
            defaults: defaults
        )

        let pane = MacAppSettingsPane.theme(themeStore: store, variant: .compact)

        #expect(pane.id == .theme)
        #expect(pane.title == "Theme")
        #expect(pane.systemImage == "paintpalette")
    }

    @MainActor
    @Test("Default built-ins are a flat Theme then Plan pane list")
    func defaultPanes() {
        let defaults = UserDefaults(suiteName: "MacAppSettingsBuiltInsTests.defaults")!
        defaults.removePersistentDomain(forName: "MacAppSettingsBuiltInsTests.defaults")
        let store = MacAppThemeStore(defaults: defaults)
        let purchases = PurchaseManager(
            configuration: PurchaseConfiguration(productIDs: ["pro"]),
            simulated: true
        )

        let panes = MacAppSettingsBuiltIns.panes(
            themeStore: store,
            purchaseManager: purchases,
            planConfiguration: ProPlanPaneConfiguration(appName: "Demo"),
            onUpgrade: {}
        )

        #expect(panes.map { $0.id } == [.theme, .plan])
    }

    @MainActor
    @Test("Apps can disable either built-in pane")
    func subsetBuiltIns() {
        let defaults = UserDefaults(suiteName: "MacAppSettingsBuiltInsTests.subset")!
        defaults.removePersistentDomain(forName: "MacAppSettingsBuiltInsTests.subset")
        let store = MacAppThemeStore(defaults: defaults)
        let purchases = PurchaseManager(
            configuration: PurchaseConfiguration(productIDs: ["pro"]),
            simulated: true
        )

        let themeOnly = MacAppSettingsBuiltIns.panes(
            themeStore: store,
            purchaseManager: purchases,
            planConfiguration: ProPlanPaneConfiguration(appName: "Demo"),
            enabledPanes: [.theme],
            onUpgrade: {}
        )
        let planOnly = MacAppSettingsBuiltIns.panes(
            themeStore: store,
            purchaseManager: purchases,
            planConfiguration: ProPlanPaneConfiguration(appName: "Demo"),
            enabledPanes: [.plan],
            onUpgrade: {}
        )

        #expect(themeOnly.map { $0.id } == [.theme])
        #expect(planOnly.map { $0.id } == [.plan])
    }

    @MainActor
    @Test("Grouped section helpers remain available for larger settings surfaces")
    func groupedSectionsRemainAvailable() {
        let defaults = UserDefaults(suiteName: "MacAppSettingsBuiltInsTests.grouped")!
        defaults.removePersistentDomain(forName: "MacAppSettingsBuiltInsTests.grouped")
        let store = MacAppThemeStore(defaults: defaults)
        let purchases = PurchaseManager(
            configuration: PurchaseConfiguration(productIDs: ["pro"]),
            simulated: true
        )

        let sections = MacAppSettingsBuiltIns.sections(
            themeStore: store,
            purchaseManager: purchases,
            planConfiguration: ProPlanPaneConfiguration(appName: "Demo"),
            onUpgrade: {}
        )

        #expect(sections.map { $0.id } == [.application, .account])
        #expect(sections.flatMap { $0.panes }.map { $0.id } == [.theme, .plan])
    }

    @MainActor
    @Test("Plan pane presentation distinguishes Free and Pro")
    func planPanePresentationState() {
        #expect(ProPlanPanePresentationState(hasPro: false) == .free)
        #expect(ProPlanPanePresentationState(hasPro: true) == .pro)
    }

    @MainActor
    @Test("Plan pane actions match free, subscription, lifetime, and mixed entitlements")
    func planPaneActions() {
        let monthly = StoreProduct(
            id: "pro.monthly",
            displayName: "Monthly",
            description: "",
            displayPrice: "$4.99",
            price: 4.99,
            subscriptionPeriod: .init(value: 1, unit: .month)
        )
        let lifetime = StoreProduct(
            id: "pro.lifetime",
            displayName: "Lifetime",
            description: "",
            displayPrice: "$79.99",
            price: 79.99
        )

        let free = ProPlanPaneActionState(
            hasPro: false,
            activeProduct: nil,
            activeSubscriptionProduct: nil
        )
        #expect(free.showsUpgrade)
        #expect(!free.showsViewPlans)
        #expect(!free.showsManageSubscription)

        let subscription = ProPlanPaneActionState(
            hasPro: true,
            activeProduct: monthly,
            activeSubscriptionProduct: monthly
        )
        #expect(!subscription.showsUpgrade)
        #expect(subscription.showsViewPlans)
        #expect(subscription.showsManageSubscription)

        let lifetimeOnly = ProPlanPaneActionState(
            hasPro: true,
            activeProduct: lifetime,
            activeSubscriptionProduct: nil
        )
        #expect(!lifetimeOnly.showsUpgrade)
        #expect(!lifetimeOnly.showsViewPlans)
        #expect(!lifetimeOnly.showsManageSubscription)

        let lifetimeAndSubscription = ProPlanPaneActionState(
            hasPro: true,
            activeProduct: lifetime,
            activeSubscriptionProduct: monthly
        )
        #expect(!lifetimeAndSubscription.showsUpgrade)
        #expect(!lifetimeAndSubscription.showsViewPlans)
        #expect(lifetimeAndSubscription.showsManageSubscription)
    }
}
