import AppKit
import Foundation
import SwiftUI
import Testing
@testable import MacAppFoundation

@Suite("MacApp application appearance")
@MainActor
struct MacAppApplicationAppearanceTests {
    @Test("System clears the app-wide appearance override")
    func systemClearsApplicationAppearance() {
        #expect(
            MacAppApplicationAppearance.appearanceName(
                for: .system,
                theme: MacAppThemeCatalog.midnight
            ) == nil
        )
    }

    @Test("Named dark themes request dark Aqua")
    func darkThemeUsesDarkAqua() {
        #expect(
            MacAppApplicationAppearance.appearanceName(
                for: .midnight,
                theme: MacAppThemeCatalog.midnight
            ) == .darkAqua
        )
    }

    @Test("Named light themes request Aqua")
    func lightThemeUsesAqua() {
        #expect(
            MacAppApplicationAppearance.appearanceName(
                for: .porcelain,
                theme: MacAppThemeCatalog.porcelain
            ) == .aqua
        )
    }

    @Test("Named themes with no preferred appearance follow System")
    func nilPreferredAppearanceClearsOverride() {
        let theme = MacAppTheme(
            id: "adaptive",
            name: "Adaptive",
            caption: "Follow macOS",
            preferredColorScheme: nil,
            palette: MacAppThemeCatalog.porcelain.palette
        )

        #expect(
            MacAppApplicationAppearance.appearanceName(
                for: theme.id,
                theme: theme
            ) == nil
        )
    }

    @Test("System clears a previous override before resolving effective appearance")
    func systemClearsOverrideBeforeResolution() throws {
        let light = try #require(NSAppearance(named: .aqua))
        var events: [String] = []

        let scheme = MacAppApplicationAppearance
            .synchronizeAndResolveSystemColorScheme(
                effectiveThemeID: .system,
                theme: MacAppThemeCatalog.midnight,
                currentAppearanceName: .darkAqua,
                applyAppearance: { appearanceName in
                    events.append(appearanceName == nil ? "apply:nil" : "apply:override")
                },
                effectiveAppearance: {
                    events.append("read-effective")
                    return light
                }
            )

        #expect(events == ["apply:nil", "read-effective"])
        #expect(scheme == .light)
    }

    @Test("Ending a dark Pro preview restores System light backing")
    func endingPreviewRestoresSystemBacking() throws {
        let suiteName = "MacAppApplicationAppearanceTests.preview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let configuration = MacAppThemeConfiguration(
            themes: [
                .system,
                MacAppThemeCatalog.githubDarkDimmed,
                MacAppThemeCatalog.porcelain,
                MacAppThemeCatalog.midnight,
            ],
            defaultThemeID: .system,
            storageKey: "theme",
            proThemeIDs: [.midnight],
            systemLightThemeID: .porcelain,
            systemDarkThemeID: .githubDarkDimmed
        )
        let store = MacAppThemeStore(
            configuration: configuration,
            defaults: defaults
        )

        let result = store.choose(.midnight, hasPro: false)
        if case .previewStarted(let id, _) = result {
            #expect(id == .midnight)
        } else {
            Issue.record("Expected Midnight preview to start")
        }
        #expect(store.effectiveThemeID(hasPro: false) == .midnight)

        store.endPreview()
        #expect(store.effectiveThemeID(hasPro: false) == .system)

        let light = try #require(NSAppearance(named: .aqua))
        var events: [String] = []
        let systemScheme = MacAppApplicationAppearance
            .synchronizeAndResolveSystemColorScheme(
                effectiveThemeID: .system,
                theme: try #require(configuration.theme(for: .system)),
                currentAppearanceName: .darkAqua,
                applyAppearance: { appearanceName in
                    events.append(appearanceName == nil ? "apply:nil" : "apply:override")
                },
                effectiveAppearance: {
                    events.append("read-effective")
                    return light
                }
            )

        #expect(events == ["apply:nil", "read-effective"])
        #expect(systemScheme == .light)
        #expect(
            store.currentTheme(
                hasPro: false,
                systemColorScheme: systemScheme
            ).id == .porcelain
        )
    }

    @Test("AppKit appearances resolve to the matching SwiftUI color scheme")
    func appKitAppearanceResolvesColorScheme() throws {
        let light = try #require(NSAppearance(named: .aqua))
        let dark = try #require(NSAppearance(named: .darkAqua))
        let highContrastLight = try #require(
            NSAppearance(named: .accessibilityHighContrastAqua)
        )
        let highContrastDark = try #require(
            NSAppearance(named: .accessibilityHighContrastDarkAqua)
        )

        #expect(MacAppApplicationAppearance.colorScheme(for: light) == .light)
        #expect(MacAppApplicationAppearance.colorScheme(for: dark) == .dark)
        #expect(
            MacAppApplicationAppearance.colorScheme(for: highContrastLight) == .light
        )
        #expect(
            MacAppApplicationAppearance.colorScheme(for: highContrastDark) == .dark
        )
    }
}
