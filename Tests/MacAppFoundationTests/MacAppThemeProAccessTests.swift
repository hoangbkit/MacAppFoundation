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
        #expect(configuration.previewBehavior.defaultDuration == 5 * 60)
    }

    @Test("Free users cannot permanently select Pro themes")
    func freePermanentSelectionIsBlocked() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = MacAppThemeStore(configuration: configuration, defaults: defaults)

        #expect(!store.select(.midnight, hasPro: false))
        #expect(store.selectedThemeID == .system)
        #expect(defaults.string(forKey: "theme") == nil)
    }

    @Test("Free users can temporarily preview Pro themes")
    func freeUserStartsPreview() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let start = Date(timeIntervalSince1970: 1_000)
        let store = MacAppThemeStore(
            configuration: configuration,
            defaults: defaults,
            now: { start }
        )

        let result = store.choose(.midnight, hasPro: false)

        #expect(result == .previewStarted(.midnight, expiresAt: start.addingTimeInterval(300)))
        #expect(store.selectedThemeID == .system)
        #expect(store.previewThemeID == .midnight)
        #expect(store.effectiveThemeID(hasPro: false) == .midnight)
        #expect(store.themeAfterPreview(hasPro: false).id == .system)
        #expect(defaults.string(forKey: "theme.previewThemeID") == MacAppThemeID.midnight.rawValue)
        #expect(defaults.object(forKey: "theme.previewExpiresAt") as? Date == start.addingTimeInterval(300))
    }

    @Test("Switching Pro previews preserves the original deadline")
    func switchingPreviewPreservesDeadline() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var now = Date(timeIntervalSince1970: 2_000)
        let previewConfiguration = MacAppThemeConfiguration(
            themes: [.system, .midnight, .ocean],
            defaultThemeID: .system,
            storageKey: "theme",
            proThemeIDs: [.midnight, .ocean],
            previewBehavior: .init(schedulesAutomaticExpiration: false)
        )
        let store = MacAppThemeStore(
            configuration: previewConfiguration,
            defaults: defaults,
            now: { now }
        )

        _ = store.choose(.midnight, hasPro: false)
        let firstExpiry = store.previewExpiresAt

        now = now.addingTimeInterval(30)
        _ = store.choose(.ocean, hasPro: false)

        #expect(store.previewThemeID == .ocean)
        #expect(store.previewExpiresAt == firstExpiry)
    }

    @Test("Preview survives relaunch until its absolute expiry")
    func previewPersistsAcrossRelaunch() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let start = Date(timeIntervalSince1970: 3_000)
        let previewConfiguration = MacAppThemeConfiguration(
            themes: [.system, .midnight],
            defaultThemeID: .system,
            storageKey: "theme",
            proThemeIDs: [.midnight],
            previewBehavior: .init(schedulesAutomaticExpiration: false)
        )

        let firstStore = MacAppThemeStore(
            configuration: previewConfiguration,
            defaults: defaults,
            now: { start }
        )
        _ = firstStore.choose(.midnight, hasPro: false)

        let relaunchedStore = MacAppThemeStore(
            configuration: previewConfiguration,
            defaults: defaults,
            now: { start.addingTimeInterval(120) }
        )

        #expect(relaunchedStore.isPreviewActive)
        #expect(relaunchedStore.previewThemeID == .midnight)
        #expect(relaunchedStore.previewRemainingSeconds == 180)
        #expect(relaunchedStore.effectiveThemeID(hasPro: false) == .midnight)
    }

    @Test("Expired persisted preview is cleared and falls back")
    func expiredPreviewIsCleared() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let start = Date(timeIntervalSince1970: 4_000)
        defaults.set(MacAppThemeID.midnight.rawValue, forKey: "theme.previewThemeID")
        defaults.set(start.addingTimeInterval(300), forKey: "theme.previewExpiresAt")

        let store = MacAppThemeStore(
            configuration: configuration,
            defaults: defaults,
            now: { start.addingTimeInterval(301) }
        )

        #expect(!store.isPreviewActive)
        #expect(store.previewThemeID == nil)
        #expect(store.effectiveThemeID(hasPro: false) == .system)
        #expect(defaults.string(forKey: "theme.previewThemeID") == nil)
        #expect(defaults.object(forKey: "theme.previewExpiresAt") == nil)
    }

    @Test("Pro unlock clears stale expired preview metadata")
    func proUnlockClearsExpiredPreviewState() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var now = Date(timeIntervalSince1970: 4_500)
        let previewConfiguration = MacAppThemeConfiguration(
            themes: [.system, .midnight],
            defaultThemeID: .system,
            storageKey: "theme",
            proThemeIDs: [.midnight],
            previewBehavior: .init(schedulesAutomaticExpiration: false)
        )
        let store = MacAppThemeStore(
            configuration: previewConfiguration,
            defaults: defaults,
            now: { now }
        )
        _ = store.choose(.midnight, hasPro: false)

        now = now.addingTimeInterval(301)
        store.synchronizeProAccess(true)

        #expect(store.previewThemeID == nil)
        #expect(store.previewExpiresAt == nil)
        #expect(store.selectedThemeID == .system)
        #expect(store.effectiveThemeID(hasPro: true) == .system)
    }

    @Test("Ending preview immediately restores the entitled theme")
    func endPreviewRestoresTheme() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = MacAppThemeStore(configuration: configuration, defaults: defaults)
        _ = store.choose(.midnight, hasPro: false)

        store.endPreview()

        #expect(!store.isPreviewActive)
        #expect(store.previewThemeID == nil)
        #expect(store.effectiveThemeID(hasPro: false) == .system)
    }

    @Test("Unlocking Pro promotes the active preview")
    func unlockPromotesPreview() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = MacAppThemeStore(configuration: configuration, defaults: defaults)
        _ = store.choose(.midnight, hasPro: false)

        store.synchronizeProAccess(true)

        #expect(!store.isPreviewActive)
        #expect(store.previewThemeID == nil)
        #expect(store.selectedThemeID == .midnight)
        #expect(store.effectiveThemeID(hasPro: true) == .midnight)
        #expect(defaults.string(forKey: "theme") == MacAppThemeID.midnight.rawValue)
    }

    @Test("Disabled preview keeps Pro themes locked")
    func disabledPreviewRequiresPro() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let disabledConfiguration = MacAppThemeConfiguration(
            themes: [.system, .midnight],
            defaultThemeID: .system,
            storageKey: "theme",
            proThemeIDs: [.midnight],
            previewBehavior: .disabled
        )
        let store = MacAppThemeStore(
            configuration: disabledConfiguration,
            defaults: defaults
        )

        #expect(store.choose(.midnight, hasPro: false) == .requiresPro(.midnight))
        #expect(!store.isPreviewActive)
        #expect(store.effectiveThemeID(hasPro: false) == .system)
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

    @Test("Checking entitlement preserves a persisted Pro theme")
    func checkingEntitlementPreservesPersistedProTheme() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(MacAppThemeID.midnight.rawValue, forKey: "theme")

        let store = MacAppThemeStore(configuration: configuration, defaults: defaults)

        #expect(
            store.currentTheme(
                entitlementState: .checking,
                hasPro: false
            ).id == .midnight
        )
    }

    @Test("Checking entitlement preserves a persisted Free theme")
    func checkingEntitlementPreservesPersistedFreeTheme() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(MacAppThemeID.system.rawValue, forKey: "theme")

        let store = MacAppThemeStore(configuration: configuration, defaults: defaults)

        #expect(
            store.currentTheme(
                entitlementState: .checking,
                hasPro: false
            ).id == .system
        )
    }

    @Test("Checking entitlement preserves an active Pro theme preview")
    func checkingEntitlementPreservesActivePreview() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = MacAppThemeStore(configuration: configuration, defaults: defaults)
        _ = store.choose(.midnight, hasPro: false)

        #expect(
            store.currentTheme(
                entitlementState: .checking,
                hasPro: false
            ).id == .midnight
        )
    }

    @Test("Resolved Free entitlement falls back from a persisted Pro theme")
    func resolvedFreeEntitlementFallsBackFromPersistedProTheme() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(MacAppThemeID.midnight.rawValue, forKey: "theme")

        let store = MacAppThemeStore(configuration: configuration, defaults: defaults)

        #expect(
            store.currentTheme(
                entitlementState: .inactive,
                hasPro: false
            ).id == .system
        )
    }

    @Test("Resolved Pro entitlement keeps a persisted Pro theme")
    func resolvedProEntitlementKeepsPersistedProTheme() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(MacAppThemeID.midnight.rawValue, forKey: "theme")

        let store = MacAppThemeStore(configuration: configuration, defaults: defaults)
        let snapshot = EntitlementSnapshot(
            activeProductIDs: ["pro"],
            latestExpirationDate: nil
        )

        #expect(
            store.currentTheme(
                entitlementState: .active(snapshot),
                hasPro: true
            ).id == .midnight
        )
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
