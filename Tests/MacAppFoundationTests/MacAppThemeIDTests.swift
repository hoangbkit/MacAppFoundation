import Testing
@testable import MacAppFoundation

@Suite("MacAppThemeID")
struct MacAppThemeIDTests {
    @Test("String literal IDs remain extensible")
    func stringLiteralIDs() {
        let custom: MacAppThemeID = "custom-theme"
        #expect(custom.rawValue == "custom-theme")
    }

    @Test("Built-in IDs are stable")
    func builtInIDs() {
        #expect(MacAppThemeID.system.rawValue == "system")
        #expect(MacAppThemeID.githubDarkDimmed.rawValue == "github-dark-dimmed")
        #expect(MacAppThemeID.morningMist.rawValue == "morning-mist")
        #expect(MacAppThemeID.githubLight.rawValue == "github-light")
    }
}
