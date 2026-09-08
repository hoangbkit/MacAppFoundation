import MacAppFoundation
import SwiftUI

@MainActor
struct DemoSettingsView: View {
    let purchaseManager: PurchaseManager

    @Environment(\.openWindow) private var openWindow
    @Environment(DemoState.self) private var demoState
    @State private var selection: SettingsTab = .plan

    private enum SettingsTab: Hashable {
        case general
        case plan
        case about
    }

    var body: some View {
        @Bindable var demoState = demoState

        TabView(selection: $selection) {
            generalTab(showTips: $demoState.showTips, compactCards: $demoState.compactCards)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsTab.general)

            ProPlanPane(
                purchaseManager: purchaseManager,
                configuration: DemoCommerce.planConfiguration,
                onUpgrade: {
                    openWindow(id: DemoWindowID.paywall)
                }
            )
            .tabItem {
                Label("Plan", systemImage: "creditcard")
            }
            .tag(SettingsTab.plan)

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .padding()
        .frame(width: 500)
    }

    private func generalTab(
        showTips: Binding<Bool>,
        compactCards: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                HStack {
                    Text("Show demo tips")
                    Spacer()
                    Toggle("", isOn: showTips)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .padding(.horizontal, 8)

                Divider()

                HStack {
                    Text("Compact showcase cards")
                    Spacer()
                    Toggle("", isOn: compactCards)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .padding(.horizontal, 8)
            }

            GroupBox {
                HStack {
                    Text("Settings ownership")
                    Spacer()
                    Text("App-owned")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox {
                HStack {
                    Text("Demo")
                    Spacer()
                    Text("MacAppFoundation")
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)

                Divider()

                HStack {
                    Text("Deployment target")
                    Spacer()
                    Text("macOS 15+")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
            }

            GroupBox("Architecture") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("One shared PurchaseManager", systemImage: "checkmark.circle")
                    Label("App-owned Settings scene", systemImage: "checkmark.circle")
                    Label("Separate debug Developer Tools window", systemImage: "checkmark.circle")
                    Label("No app-specific state inside the package", systemImage: "checkmark.circle")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
        }
    }
}
