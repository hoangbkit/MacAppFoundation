import Testing
@testable import MacAppFoundation

@Suite("MacAppTheme environment")
struct MacAppThemeEnvironmentTests {
    @Test("System theme is the documented safe fallback")
    func systemFallbackIsStable() {
        #expect(MacAppTheme.system.id == .system)
        #expect(MacAppTheme.system.preferredColorScheme == nil)
    }
}
