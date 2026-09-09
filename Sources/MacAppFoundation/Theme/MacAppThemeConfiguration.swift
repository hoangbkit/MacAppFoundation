import Foundation

/// Defines which themes a host app exposes and how selection is persisted.
public struct MacAppThemeConfiguration: @unchecked Sendable {
    public let themes: [MacAppTheme]
    public let defaultThemeID: MacAppThemeID
    public let storageKey: String

    public init(
        themes: [MacAppTheme] = MacAppThemeCatalog.allBuiltIn,
        defaultThemeID: MacAppThemeID = .system,
        storageKey: String = "MacAppFoundation.theme"
    ) {
        precondition(!themes.isEmpty, "MacAppThemeConfiguration requires at least one theme.")
        precondition(Set(themes.map(\.id)).count == themes.count, "Theme IDs must be unique.")

        self.themes = themes
        self.defaultThemeID = themes.contains { $0.id == defaultThemeID }
            ? defaultThemeID
            : themes[0].id
        self.storageKey = storageKey
    }

    public func theme(for id: MacAppThemeID) -> MacAppTheme? {
        themes.first { $0.id == id }
    }

    public var defaultTheme: MacAppTheme {
        theme(for: defaultThemeID) ?? themes[0]
    }
}
