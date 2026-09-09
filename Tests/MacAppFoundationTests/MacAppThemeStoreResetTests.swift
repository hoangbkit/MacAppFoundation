import Foundation
import Testing
@testable import MacAppFoundation

@Suite("MacAppThemeStore reset")
@MainActor
struct MacAppThemeStoreResetTests {
    @Test("reset selects and persists the configured default")
    func resetSelectsDefault() {
        let suiteName = "MacAppThemeStoreResetTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = MacAppThemeConfiguration(
            themes: [.system, .midnight],
            defaultThemeID: .system,
            storageKey: "theme"
        )
        let store = MacAppThemeStore(configuration: configuration, defaults: defaults)

        store.select(.midnight)
        store.reset()

        #expect(store.selectedThemeID == .system)
        #expect(defaults.string(forKey: "theme") == MacAppThemeID.system.rawValue)
    }
}
