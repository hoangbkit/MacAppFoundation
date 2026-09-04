import SwiftUI

@MainActor
struct DemoDeveloperStateView: View {
    @Environment(DemoState.self) private var demoState

    var body: some View {
        Form {
            Section("App-owned debug state") {
                LabeledContent("Use Mock Data", value: demoState.useMockData ? "On" : "Off")
                LabeledContent("Show Tips", value: demoState.showTips ? "On" : "Off")
                LabeledContent("Compact Cards", value: demoState.compactCards ? "On" : "Off")
                LabeledContent("Action Count", value: "\(demoState.actionCount)")
                LabeledContent("Last Action", value: demoState.lastAction)
            }

            Section {
                Text("This destination is registered by the app through FoundationDeveloperDestination; MacAppFoundation does not need to know the app's state model.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Demo App State")
    }
}
