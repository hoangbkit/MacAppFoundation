import Foundation
import SwiftUI

/// Defines which themes a host app exposes, which require Pro, how previews behave,
/// and how selection is persisted.
public struct MacAppThemeConfiguration: @unchecked Sendable {
    public let themes: [MacAppTheme]
    public let defaultThemeID: MacAppThemeID
    public let storageKey: String
    public let proThemeIDs: Set<MacAppThemeID>
    public let systemLightThemeID: MacAppThemeID?
    public let systemDarkThemeID: MacAppThemeID?
    public let previewBehavior: MacAppThemePreviewBehavior

    public init(
        themes: [MacAppTheme] = MacAppThemeCatalog.allBuiltIn,
        defaultThemeID: MacAppThemeID = .system,
        storageKey: String = "MacAppFoundation.theme",
        proThemeIDs: Set<MacAppThemeID> = [],
        systemLightThemeID: MacAppThemeID? = nil,
        systemDarkThemeID: MacAppThemeID? = nil,
        previewBehavior: MacAppThemePreviewBehavior = .standard
    ) {
        precondition(!themes.isEmpty, "MacAppThemeConfiguration requires at least one theme.")
        precondition(Set(themes.map(\.id)).count == themes.count, "Theme IDs must be unique.")

        let themeIDs = Set(themes.map(\.id))
        precondition(
            proThemeIDs.isSubset(of: themeIDs),
            "Every Pro theme ID must exist in the configured theme list."
        )

        let resolvedDefaultThemeID = themeIDs.contains(defaultThemeID)
            ? defaultThemeID
            : themes[0].id
        precondition(
            !proThemeIDs.contains(resolvedDefaultThemeID),
            "The default theme must remain available to Free users."
        )

        let freeLightThemes = themes.filter {
            !proThemeIDs.contains($0.id)
                && $0.id != .system
                && $0.preferredColorScheme == .light
        }
        let freeDarkThemes = themes.filter {
            !proThemeIDs.contains($0.id)
                && $0.id != .system
                && $0.preferredColorScheme == .dark
        }

        self.themes = themes
        self.defaultThemeID = resolvedDefaultThemeID
        self.storageKey = storageKey
        self.proThemeIDs = proThemeIDs
        self.systemLightThemeID = Self.resolveSystemThemeID(
            requested: systemLightThemeID,
            candidates: freeLightThemes
        )
        self.systemDarkThemeID = Self.resolveSystemThemeID(
            requested: systemDarkThemeID,
            candidates: freeDarkThemes
        )
        self.previewBehavior = previewBehavior
    }

    public func theme(for id: MacAppThemeID) -> MacAppTheme? {
        themes.first { $0.id == id }
    }

    public func accessRequirement(for id: MacAppThemeID) -> PremiumAccessRequirement {
        proThemeIDs.contains(id) ? .pro : .free
    }

    public func isProTheme(_ id: MacAppThemeID) -> Bool {
        proThemeIDs.contains(id)
    }

    /// Free light themes eligible to back the System selection.
    public var freeLightThemes: [MacAppTheme] {
        themes.filter {
            !proThemeIDs.contains($0.id)
                && $0.id != .system
                && $0.preferredColorScheme == .light
        }
    }

    /// Free dark themes eligible to back the System selection.
    public var freeDarkThemes: [MacAppTheme] {
        themes.filter {
            !proThemeIDs.contains($0.id)
                && $0.id != .system
                && $0.preferredColorScheme == .dark
        }
    }

    /// ThemePickerView requires both sides so System can always follow macOS safely.
    public var hasRequiredFreeAppearanceThemes: Bool {
        !freeLightThemes.isEmpty && !freeDarkThemes.isEmpty
    }

    public var systemLightTheme: MacAppTheme? {
        guard let systemLightThemeID else { return nil }
        return theme(for: systemLightThemeID)
    }

    public var systemDarkTheme: MacAppTheme? {
        guard let systemDarkThemeID else { return nil }
        return theme(for: systemDarkThemeID)
    }

    public var defaultTheme: MacAppTheme {
        theme(for: defaultThemeID) ?? themes[0]
    }

    private static func resolveSystemThemeID(
        requested: MacAppThemeID?,
        candidates: [MacAppTheme]
    ) -> MacAppThemeID? {
        if let requested,
           candidates.contains(where: { $0.id == requested }) {
            return requested
        }
        return candidates.first?.id
    }
}
