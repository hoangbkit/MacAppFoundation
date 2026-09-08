public extension MacAppThemeConfiguration {
    /// Convenience configuration exposing every built-in theme.
    static func allBuiltIn(
        defaultThemeID: MacAppThemeID = .system,
        storageKey: String = "MacAppFoundation.theme"
    ) -> MacAppThemeConfiguration {
        MacAppThemeConfiguration(
            themes: MacAppThemeCatalog.allBuiltIn,
            defaultThemeID: defaultThemeID,
            storageKey: storageKey
        )
    }

    /// Convenience configuration exposing only the requested built-in IDs.
    static func builtIns(
        _ ids: [MacAppThemeID],
        defaultThemeID: MacAppThemeID? = nil,
        storageKey: String = "MacAppFoundation.theme"
    ) -> MacAppThemeConfiguration {
        let themes = ids.compactMap(MacAppThemeCatalog.theme(for:))
        let fallback = defaultThemeID ?? themes.first?.id ?? .system
        return MacAppThemeConfiguration(
            themes: themes.isEmpty ? [.system] : themes,
            defaultThemeID: fallback,
            storageKey: storageKey
        )
    }
}
