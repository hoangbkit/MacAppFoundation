import Foundation
import Testing
@testable import MacAppFoundation

@Suite("MacAppTheme")
@MainActor
struct MacAppThemeTests {
    @Test("Built-in theme IDs are unique")
    func builtInThemeIDsAreUnique() {
        let themes = MacAppThemeCatalog.allBuiltIn
        let ids = themes.map(\.id)

        #expect(themes.count == 13)
        #expect(Set(ids).count == themes.count)
        #expect(ids.first == .system)
    }

    @Test("Configuration supports a subset of built-in themes")
    func configurationSupportsSubset() {
        let configuration = MacAppThemeConfiguration(
            themes: [
                MacAppThemeCatalog.midnight,
                MacAppThemeCatalog.porcelain,
            ],
            defaultThemeID: .porcelain,
            storageKey: "theme-tests.subset"
        )

        #expect(configuration.themes.count == 2)
        #expect(configuration.defaultThemeID == .porcelain)
        #expect(configuration.theme(for: .midnight)?.name == "Midnight")
        #expect(configuration.theme(for: .system) == nil)
    }

    @Test("Configuration falls back when requested default is unavailable")
    func configurationFallsBackToFirstTheme() {
        let configuration = MacAppThemeConfiguration(
            themes: [MacAppThemeCatalog.ocean, MacAppThemeCatalog.sunrise],
            defaultThemeID: .system,
            storageKey: "theme-tests.fallback"
        )

        #expect(configuration.defaultThemeID == .ocean)
    }

    @Test("Configuration accepts app-defined themes")
    func configurationAcceptsCustomTheme() {
        let customID: MacAppThemeID = "demo-custom"
        let customTheme = MacAppTheme(
            id: customID,
            name: "Demo Custom",
            caption: "Host-defined",
            preferredColorScheme: .dark,
            palette: MacAppThemeCatalog.midnight.palette
        )
        let configuration = MacAppThemeConfiguration(
            themes: [.system, customTheme],
            defaultThemeID: customID,
            storageKey: "theme-tests.custom"
        )

        #expect(configuration.theme(for: customID)?.name == "Demo Custom")
        #expect(configuration.defaultThemeID == customID)
    }

    @Test("Store restores and persists a valid selection")
    func storeRestoresAndPersistsSelection() {
        let suiteName = "MacAppThemeTests.persistence.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = MacAppThemeConfiguration(
            themes: [.system, MacAppThemeCatalog.midnight, MacAppThemeCatalog.porcelain],
            defaultThemeID: .system,
            storageKey: "theme"
        )

        let firstStore = MacAppThemeStore(configuration: configuration, defaults: defaults)
        firstStore.select(.midnight)
        #expect(firstStore.selectedThemeID == .midnight)
        #expect(defaults.string(forKey: "theme") == MacAppThemeID.midnight.rawValue)

        let restoredStore = MacAppThemeStore(configuration: configuration, defaults: defaults)
        #expect(restoredStore.selectedThemeID == .midnight)
        #expect(restoredStore.currentTheme.id == .midnight)
    }

    @Test("Store ignores a persisted theme not exposed by the app")
    func storeIgnoresUnavailablePersistedTheme() {
        let suiteName = "MacAppThemeTests.unavailable.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(MacAppThemeID.aurora.rawValue, forKey: "theme")

        let configuration = MacAppThemeConfiguration(
            themes: [MacAppThemeCatalog.ocean, MacAppThemeCatalog.porcelain],
            defaultThemeID: .porcelain,
            storageKey: "theme"
        )
        let store = MacAppThemeStore(configuration: configuration, defaults: defaults)

        #expect(store.selectedThemeID == .porcelain)
        #expect(store.currentTheme.id == .porcelain)
    }

    @Test("Store rejects programmatic selection outside the configured catalog")
    func storeRejectsUnavailableSelection() {
        let suiteName = "MacAppThemeTests.selection.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = MacAppThemeConfiguration(
            themes: [MacAppThemeCatalog.ocean, MacAppThemeCatalog.porcelain],
            defaultThemeID: .ocean,
            storageKey: "theme"
        )
        let store = MacAppThemeStore(configuration: configuration, defaults: defaults)

        store.select(.aurora)

        #expect(store.selectedThemeID == .ocean)
        #expect(store.currentTheme.id == .ocean)
    }
}
