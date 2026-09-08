import Testing
@testable import MacAppFoundation

@Suite("MacAppTheme custom ordering")
struct MacAppThemeCustomOrderingTests {
    @Test("Configuration preserves app-defined theme order")
    func preservesOrder() {
        let custom = MacAppTheme(
            id: "custom",
            name: "Custom",
            caption: "Custom",
            preferredColorScheme: .dark,
            palette: MacAppTheme.midnight.palette
        )
        let configuration = MacAppThemeConfiguration(
            themes: [.porcelain, custom, .midnight],
            defaultThemeID: "custom"
        )

        #expect(configuration.themes.map(\.id) == [.porcelain, "custom", .midnight])
    }
}
