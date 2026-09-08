import Testing
@testable import MacAppFoundation

@Suite("MacAppThemeCatalog")
struct MacAppThemeCatalogTests {
    @Test("Catalog contains System plus all 12 named BYOKchat themes")
    func completeBuiltInCatalog() {
        let expectedIDs: [MacAppThemeID] = [
            .system,
            .githubDarkDimmed,
            .midnight,
            .ocean,
            .aurora,
            .ember,
            .graphite,
            .porcelain,
            .blossom,
            .morningMist,
            .softSage,
            .sunrise,
            .githubLight,
        ]

        #expect(MacAppThemeCatalog.allBuiltIn.map(\.id) == expectedIDs)
        #expect(MacAppThemeCatalog.allBuiltIn.filter { $0.id != .system }.count == 12)
    }

    @Test("Every built-in ID resolves through the catalog")
    func everyBuiltInResolves() {
        for theme in MacAppThemeCatalog.allBuiltIn {
            #expect(MacAppThemeCatalog.theme(for: theme.id)?.id == theme.id)
        }
    }

    @Test("Convenience accessors expose catalog presets")
    func convenienceAccessorsMatchCatalog() {
        #expect(MacAppTheme.midnight.id == MacAppThemeCatalog.midnight.id)
        #expect(MacAppTheme.githubLight.id == MacAppThemeCatalog.githubLight.id)
    }
}
