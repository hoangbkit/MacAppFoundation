import MacAppFoundation
import SwiftUI

private extension MacAppSettingsPaneID {
    static let demoGeneral: Self = "demo.general"
    static let demoAbout: Self = "demo.about"
}

@MainActor
struct DemoSettingsView: View {
    let purchaseManager: PurchaseManager
    let themeStore: MacAppThemeStore
    let settingsRouter: MacAppSettingsRouter

    @Environment(\.openWindow) private var openWindow
    @Environment(DemoState.self) private var demoState
    @State private var selection: MacAppSettingsPaneID = .demoGeneral

    var body: some View {
        TabView(selection: $selection) {
            DemoGeneralSettingsPane(demoState: demoState)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(MacAppSettingsPaneID.demoGeneral)

            MacAppAppearanceSettingsPane(themeStore: themeStore)
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }
                .tag(MacAppSettingsPaneID.appearance)

            MacAppPlanSettingsPane(
                purchaseManager: purchaseManager,
                configuration: DemoCommerce.planConfiguration,
                onUpgrade: {
                    openWindow(id: DemoWindowID.paywall)
                }
            )
            .tabItem {
                Label("Plan", systemImage: "creditcard")
            }
            .tag(MacAppSettingsPaneID.plan)

            DemoAboutSettingsPane()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(MacAppSettingsPaneID.demoAbout)
        }
        .frame(width: 760, height: 560)
        .accessibilityIdentifier(DemoAccessibilityID.settings)
        .onAppear {
            consumeRouterRequest()
        }
        .onChange(of: settingsRouter.requestID) { _, _ in
            consumeRouterRequest()
        }
    }

    private func consumeRouterRequest() {
        guard let requestedPaneID = settingsRouter.requestedPaneID else {
            return
        }

        switch requestedPaneID {
        case .demoGeneral, .appearance, .plan, .demoAbout:
            selection = requestedPaneID
            settingsRouter.clear()
        default:
            break
        }
    }
}

@MainActor
private struct DemoGeneralSettingsPane: View {
    @Bindable var demoState: DemoState
    @Environment(\.macAppTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Showcase") {
                    VStack(spacing: 0) {
                        settingRow("Show demo tips") {
                            Toggle("", isOn: $demoState.showTips)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }

                        Rectangle()
                            .fill(theme.separator.opacity(0.72))
                            .frame(height: 1)

                        settingRow("Compact showcase cards") {
                            Toggle("", isOn: $demoState.compactCards)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                    }
                }

                GroupBox("Foundation ownership") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("Settings presentation", value: "Native SwiftUI Settings + TabView")
                        LabeledContent("Pane content", value: "Host app + MAF built-ins")
                        LabeledContent("Theme selection", value: "Shared MacAppThemeStore")
                        LabeledContent("Window routing", value: "openSettings()")
                    }
                    .foregroundStyle(theme.textPrimary)
                }
            }
            .padding(22)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .background(theme.canvas)
    }

    private func settingRow<Accessory: View>(
        _ title: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            accessory()
        }
        .padding(.vertical, 8)
    }
}

private struct DemoAboutSettingsPane: View {
    @Environment(\.macAppTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Demo") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("Framework", value: "MacAppFoundation")
                        LabeledContent("Deployment target", value: "macOS 15+")
                        LabeledContent("Theme catalog", value: "Built-ins + Demo Violet")
                    }
                }

                GroupBox("Architecture") {
                    VStack(alignment: .leading, spacing: 9) {
                        architectureRow("One shared PurchaseManager")
                        architectureRow("One shared MacAppThemeStore across scenes")
                        architectureRow("Native Settings scene with a SwiftUI TabView")
                        architectureRow("MAF-owned Appearance and Plan tabs")
                        architectureRow("App-owned General and About tabs")
                        architectureRow("Separate debug Developer Tools window")
                    }
                }
            }
            .padding(22)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .background(theme.canvas)
    }

    private func architectureRow(_ title: String) -> some View {
        Label(title, systemImage: "checkmark.circle.fill")
            .foregroundStyle(theme.textPrimary)
            .tint(theme.success)
    }
}
