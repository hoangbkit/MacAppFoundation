import Foundation
import Testing
@testable import MacAppFoundation

@Suite("MacAppSettings built-ins")
struct MacAppSettingsBuiltInsTests {
    @MainActor
    @Test("Appearance pane uses stable built-in metadata")
    func appearanceMetadata() {
        let defaults = UserDefaults(suiteName: "MacAppSettingsBuiltInsTests.appearance")!
        defaults.removePersistentDomain(forName: "MacAppSettingsBuiltInsTests.appearance")
        let store = MacAppThemeStore(
            configuration: .builtIns([.system, .midnight]),
            defaults: defaults
        )

        let pane = MacAppSettingsPane.appearance(themeStore: store)

        #expect(pane.id == .appearance)
        #expect(pane.title == "Appearance")
        #expect(pane.systemImage == "paintpalette")
    }

    @MainActor
    @Test("Default built-ins are a flat Appearance then Plan pane list")
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

        #expect(panes.map { $0.id } == [.appearance, .plan])
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

        let appearanceOnly = MacAppSettingsBuiltIns.panes(
            themeStore: store,
            purchaseManager: purchases,
            planConfiguration: ProPlanPaneConfiguration(appName: "Demo"),
            enabledPanes: [.appearance],
            onUpgrade: {}
        )
        let planOnly = MacAppSettingsBuiltIns.panes(
            themeStore: store,
            purchaseManager: purchases,
            planConfiguration: ProPlanPaneConfiguration(appName: "Demo"),
            enabledPanes: [.plan],
            onUpgrade: {}
        )

        #expect(appearanceOnly.map { $0.id } == [.appearance])
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
        #expect(sections.flatMap { $0.panes }.map { $0.id } == [.appearance, .plan])
    }
}
