import Foundation
import Testing
@testable import MacAppFoundation

@Suite("MacAppTheme Pro access")
@MainActor
struct MacAppThemeProAccessTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "MacAppThemeProAccessTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

    private var configuration: MacAppThemeConfiguration {
        MacAppThemeConfiguration(
            themes: [.system, .midnight, .ocean],
            defaultThemeID: .system,
            storageKey: "theme",
            proThemeIDs: [.midnight, .ocean]
        )
    }

    @Test("Theme requirements default to Free unless configured as Pro")
    func accessRequirements() {
        #expect(configuration.accessRequirement(for: .system) == .free)
        #expect(configuration.accessRequirement(for: .midnight) == .pro)
        #expect(configuration.isProTheme(.ocean))
        #expect(!configuration.isProTheme(.system))
    }

    @Test("Free users cannot select Pro themes")
    func freeSelectionIsBlocked() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = MacAppThemeStore(configuration: configuration, defaults: defaults)

        #expect(!store.select(.midnight, hasPro: false))
        #expect(store.selectedThemeID == .system)
        #expect(defaults.string(forKey: "theme") == nil)
    }

    @Test("Pro users can select and persist Pro themes")
    func proSelectionPersists() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = MacAppThemeStore(configuration: configuration, defaults: defaults)

        #expect(store.select(.midnight, hasPro: true))
        #expect(store.selectedThemeID == .midnight)
        #expect(defaults.string(forKey: "theme") == MacAppThemeID.midnight.rawValue)
        #expect(store.effectiveThemeID(hasPro: true) == .midnight)
    }

    @Test("Persisted Pro selection falls back without destroying preference")
    func persistedProSelectionFallsBackForFreeAccess() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(MacAppThemeID.midnight.rawValue, forKey: "theme")

        let store = MacAppThemeStore(configuration: configuration, defaults: defaults)

        #expect(store.selectedThemeID == .midnight)
        #expect(store.effectiveThemeID(hasPro: false) == .system)
        #expect(store.currentTheme(hasPro: false).id == .system)
        #expect(store.effectiveThemeID(hasPro: true) == .midnight)
        #expect(defaults.string(forKey: "theme") == MacAppThemeID.midnight.rawValue)
    }

    @Test("Built-in helper preserves only configured Pro IDs")
    func builtInHelperFiltersProThemeIDs() {
        let configuration = MacAppThemeConfiguration.builtIns(
            [.system, .midnight],
            proThemeIDs: [.midnight, .ocean]
        )

        #expect(configuration.proThemeIDs == [.midnight])
        #expect(configuration.accessRequirement(for: .system) == .free)
        #expect(configuration.accessRequirement(for: .midnight) == .pro)
    }
}
