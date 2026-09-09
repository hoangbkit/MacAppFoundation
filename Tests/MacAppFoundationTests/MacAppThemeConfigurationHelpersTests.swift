import Testing
@testable import MacAppFoundation

@Suite("MacAppThemeConfiguration helpers")
struct MacAppThemeConfigurationHelpersTests {
    @Test("allBuiltIn exposes the complete catalog")
    func allBuiltInHelper() {
        let configuration = MacAppThemeConfiguration.allBuiltIn(defaultThemeID: .midnight)
        #expect(configuration.themes.count == MacAppThemeCatalog.allBuiltIn.count)
        #expect(configuration.defaultThemeID == .midnight)
    }

    @Test("builtIns preserves requested order and filters unknown IDs")
    func builtInsHelper() {
        let configuration = MacAppThemeConfiguration.builtIns(
            [.porcelain, "unknown", .midnight],
            defaultThemeID: .midnight
        )

        #expect(configuration.themes.map(\.id) == [.porcelain, .midnight])
        #expect(configuration.defaultThemeID == .midnight)
    }
}
