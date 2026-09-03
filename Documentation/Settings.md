# macOS Settings Integration

MacAppFoundation keeps the macOS `Settings` scene app-owned. The package provides `ProPlanPane` as the reusable Plan tab; General, About, tab selection, and any other app preferences remain in the consuming app.

A Spokio-style setup looks like this:

```swift
import MacAppFoundation
import SwiftUI

@main
struct DemoApp: App {
    private let purchases = PurchaseManager(
        configuration: PurchaseConfiguration(
            productIDs: [
                "com.example.demo.pro.monthly",
                "com.example.demo.pro.yearly",
                "com.example.demo.pro.lifetime"
            ],
            preferredProductID: "com.example.demo.pro.yearly"
        )
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        Settings {
            DemoSettingsView(purchases: purchases)
        }
    }
}

private enum SettingsTab: Hashable {
    case general
    case plan
    case about
}

private struct DemoSettingsView: View {
    let purchases: PurchaseManager
    @State private var selection: SettingsTab = .general

    var body: some View {
        TabView(selection: $selection) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsTab.general)

            ProPlanPane(
                purchaseManager: purchases,
                configuration: ProPlanPaneConfiguration(appName: "Demo")
            ) {
                // App-owned paywall presentation, for example openWindow(id:).
                presentPaywall()
            }
            .tabItem {
                Label("Plan", systemImage: "creditcard")
            }
            .tag(SettingsTab.plan)

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .padding()
        .frame(width: 500, alignment: .top)
        .fixedSize()
    }

    private func presentPaywall() {
        // Keep navigation/window ownership in the app.
    }
}
```

`ProPlanPane` follows the current Spokio Plan-pane structure:

- Free/Pro status card in a top `GroupBox`
- active plan badge derived from `PurchaseManager.activeProduct`
- upgrade action supplied by the app
- App Store subscription-management link for Pro users
- lower `GroupBox` containing the Pro feature list
- native system colors plus the app accent color rather than a framework theme system

The pane uses `PurchaseManager.features` by default. Pass `features:` in `ProPlanPaneConfiguration` only when the Plan tab should show a different list.

Developer Tools intentionally do not belong in Settings; they are wired as a separate debug-only window and menu command in the next phase.
