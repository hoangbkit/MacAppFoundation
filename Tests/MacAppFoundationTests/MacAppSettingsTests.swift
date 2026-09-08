import Testing
@testable import MacAppFoundation

@Suite("MacAppSettings")
struct MacAppSettingsTests {
    @Test("Pane and section IDs remain extensible")
    func extensibleIDs() {
        let pane: MacAppSettingsPaneID = "providers"
        let section: MacAppSettingsSectionID = "integrations"

        #expect(pane.rawValue == "providers")
        #expect(section.rawValue == "integrations")
        #expect(MacAppSettingsPaneID.appearance.rawValue == "appearance")
        #expect(MacAppSettingsPaneID.plan.rawValue == "plan")
    }

    @MainActor
    @Test("Sections preserve app-defined pane ordering")
    func sectionOrdering() {
        let general = MacAppSettingsPane(
            id: "general",
            title: "General",
            subtitle: "General preferences",
            systemImage: "gearshape"
        ) {
            EmptyView()
        }
        let appearance = MacAppSettingsPane(
            id: .appearance,
            title: "Appearance",
            subtitle: "Theme preferences",
            systemImage: "paintpalette"
        ) {
            EmptyView()
        }

        let section = MacAppSettingsSection(
            id: .application,
            title: "Application",
            panes: [general, appearance]
        )

        #expect(section.panes.map(\.id) == ["general", .appearance])
        #expect(section.panes.map(\.title) == ["General", "Appearance"])
    }

    @MainActor
    @Test("Router keeps the latest pane request and increments request identity")
    func routerRequests() {
        let router = MacAppSettingsRouter()
        #expect(router.requestedPaneID == nil)
        #expect(router.requestID == 0)

        router.request(.plan)
        let firstRequestID = router.requestID
        #expect(router.requestedPaneID == .plan)
        #expect(firstRequestID == 1)

        router.request("providers")
        #expect(router.requestedPaneID == MacAppSettingsPaneID("providers"))
        #expect(router.requestID == firstRequestID + 1)

        router.clear()
        #expect(router.requestedPaneID == nil)
        #expect(router.requestID == firstRequestID + 1)
    }
}
