import Foundation

/// Defines which themes a host app exposes, which require Pro, and how selection is persisted.
public struct MacAppThemeConfiguration: @unchecked Sendable {
    public let themes: [MacAppTheme]
    public let defaultThemeID: MacAppThemeID
    public let storageKey: String
    public let proThemeIDs: Set<MacAppThemeID>

    public init(
        themes: [MacAppTheme] = MacAppThemeCatalog.allBuiltIn,
        defaultThemeID: MacAppThemeID = .system,
        storageKey: String = "MacAppFoundation.theme",
        proThemeIDs: Set<MacAppThemeID> = []
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

        self.themes = themes
        self.defaultThemeID = resolvedDefaultThemeID
        self.storageKey = storageKey
        self.proThemeIDs = proThemeIDs
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

    public var defaultTheme: MacAppTheme {
        theme(for: defaultThemeID) ?? themes[0]
    }
}
