import AppKit
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
