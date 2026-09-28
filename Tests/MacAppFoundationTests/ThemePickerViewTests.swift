import Foundation
import Testing
@testable import MacAppFoundation

@Suite("ThemePickerView")
@MainActor
struct ThemePickerViewTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "ThemePickerViewTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

    @Test("Picker requires a Free light theme")
    func requiresFreeLightTheme() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = MacAppThemeConfiguration(
            themes: [.system, MacAppThemeCatalog.midnight],
            defaultThemeID: .system,
            storageKey: "theme"
        )
        let store = MacAppThemeStore(configuration: configuration, defaults: defaults)
        let picker = ThemePickerView(themeStore: store)

        #expect(picker.configurationErrorMessage != nil)
        #expect(
            picker.configurationErrorMessage?.contains(
                "at least one Free Light theme and one Free Dark theme"
            ) == true
        )
    }

    @Test("Picker requires a Free dark theme")
    func requiresFreeDarkTheme() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = MacAppThemeConfiguration(
            themes: [.system, MacAppThemeCatalog.porcelain],
            defaultThemeID: .system,
            storageKey: "theme"
        )
        let store = MacAppThemeStore(configuration: configuration, defaults: defaults)
        let picker = ThemePickerView(themeStore: store)

        #expect(picker.configurationErrorMessage != nil)
    }

    @Test("Pro themes cannot satisfy Free appearance requirements")
    func proThemesDoNotSatisfyFreeAppearanceRequirements() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = MacAppThemeConfiguration(
            themes: [
                .system,
                MacAppThemeCatalog.midnight,
                MacAppThemeCatalog.porcelain,
            ],
            defaultThemeID: .system,
            storageKey: "theme",
            proThemeIDs: [.midnight]
        )
        let store = MacAppThemeStore(configuration: configuration, defaults: defaults)
        let picker = ThemePickerView(themeStore: store)

        #expect(picker.configurationErrorMessage != nil)
    }

    @Test("Picker accepts Free light and dark coverage")
    func acceptsFreeLightAndDarkCoverage() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = MacAppThemeConfiguration(
            themes: [
                .system,
                MacAppThemeCatalog.midnight,
                MacAppThemeCatalog.porcelain,
            ],
            defaultThemeID: .system,
            storageKey: "theme"
        )
        let store = MacAppThemeStore(configuration: configuration, defaults: defaults)
        let picker = ThemePickerView(themeStore: store)

        #expect(picker.configurationErrorMessage == nil)
    }
}
