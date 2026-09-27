public extension MacAppThemeConfiguration {
    /// Convenience configuration exposing every built-in theme.
    static func allBuiltIn(
        defaultThemeID: MacAppThemeID = .system,
        storageKey: String = "MacAppFoundation.theme",
        proThemeIDs: Set<MacAppThemeID> = []
    ) -> MacAppThemeConfiguration {
        MacAppThemeConfiguration(
            themes: MacAppThemeCatalog.allBuiltIn,
            defaultThemeID: defaultThemeID,
            storageKey: storageKey,
            proThemeIDs: proThemeIDs
        )
    }

    /// Convenience configuration exposing only the requested built-in IDs.
    static func builtIns(
        _ ids: [MacAppThemeID],
        defaultThemeID: MacAppThemeID? = nil,
        storageKey: String = "MacAppFoundation.theme",
        proThemeIDs: Set<MacAppThemeID> = []
    ) -> MacAppThemeConfiguration {
        let themes = ids.compactMap(MacAppThemeCatalog.theme(for:))
        let availableThemes = themes.isEmpty ? [.system] : themes
        let availableIDs = Set(availableThemes.map(\.id))
        let fallback = defaultThemeID ?? availableThemes.first?.id ?? .system

        return MacAppThemeConfiguration(
            themes: availableThemes,
            defaultThemeID: fallback,
            storageKey: storageKey,
            proThemeIDs: proThemeIDs.intersection(availableIDs)
        )
    }
}
