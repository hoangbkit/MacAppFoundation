import Testing
@testable import MacAppFoundation

@Suite("MacAppThemeConfiguration fallback")
struct MacAppThemeConfigurationFallbackTests {
    @Test("Unknown-only built-in subset falls back to System")
    func unknownSubsetFallsBackToSystem() {
        let configuration = MacAppThemeConfiguration.builtIns(["does-not-exist"])
        #expect(configuration.themes.map(\.id) == [.system])
        #expect(configuration.defaultThemeID == .system)
    }
}
