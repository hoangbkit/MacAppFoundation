import Testing
@testable import MacAppFoundation

@Suite("MacAppThemeCatalog")
struct MacAppThemeCatalogTests {
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
