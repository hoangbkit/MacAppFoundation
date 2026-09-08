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
    @Test("Default built-ins include Appearance then Plan")
    func defaultSections() {
        let defaults = UserDefaults(suiteName: "MacAppSettingsBuiltInsTests.defaults")!
        defaults.removePersistentDomain(forName: "MacAppSettingsBuiltInsTests.defaults")
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

        #expect(sections.map(\.id) == [.application, .account])
        #expect(sections.flatMap(\.panes).map(\.id) == [.appearance, .plan])
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

        let appearanceOnly = MacAppSettingsBuiltIns.sections(
            themeStore: store,
            purchaseManager: purchases,
            planConfiguration: ProPlanPaneConfiguration(appName: "Demo"),
            enabledPanes: [.appearance],
            onUpgrade: {}
        )
        let planOnly = MacAppSettingsBuiltIns.sections(
            themeStore: store,
            purchaseManager: purchases,
            planConfiguration: ProPlanPaneConfiguration(appName: "Demo"),
            enabledPanes: [.plan],
            onUpgrade: {}
        )

        #expect(appearanceOnly.flatMap(\.panes).map(\.id) == [.appearance])
        #expect(planOnly.flatMap(\.panes).map(\.id) == [.plan])
    }
}
