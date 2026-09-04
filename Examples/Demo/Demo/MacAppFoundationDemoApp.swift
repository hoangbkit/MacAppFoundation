import MacAppFoundation
import SwiftUI

enum DemoWindowID {
    static let main = "demo.main"
    static let paywall = "demo.paywall"
    static let upsell = "demo.upsell"
}

@main
@MainActor
struct MacAppFoundationDemoApp: App {
    @Environment(\.openWindow) private var openWindow
    @State private var demoState = DemoState()

    private let purchases = DemoCommerce.manager

    var body: some Scene {
        Window("MacAppFoundation Demo", id: DemoWindowID.main) {
            ContentView(purchaseManager: purchases)
                .environment(demoState)
                .managesPurchases(purchases)
        }
        .defaultSize(width: 1080, height: 700)
        .commands {
            CommandMenu("Demo") {
                Button("Show Pro Paywall") {
                    openWindow(id: DemoWindowID.paywall)
                }
                .keyboardShortcut("p", modifiers: [.command, .option])

                Button("Show Upsell") {
                    openWindow(id: DemoWindowID.upsell)
                }
                .keyboardShortcut("u", modifiers: [.command, .option])
            }

            #if DEBUG
            CommandMenu("Developer") {
                Button("Developer Tools…") {
                    openWindow(id: MacAppFoundationDeveloperTools.windowID)
                }
                .keyboardShortcut("d", modifiers: [.command, .option])

                Divider()

                Button("Use Simulated Purchases") {
                    Task {
                        await purchases.setSimulatedPurchasesEnabled(true)
                    }
                }

                Button("Use StoreKit Testing") {
                    Task {
                        await purchases.setSimulatedPurchasesEnabled(false)
                    }
                }

                Button("Reset Simulated Purchases", role: .destructive) {
                    Task {
                        await purchases.setSimulatedPurchasesEnabled(true)
                        await purchases.resetSimulatedPurchases()
                    }
                }
            }
            #endif
        }

        Window("Demo Pro", id: DemoWindowID.paywall) {
            ProPaywallView(
                purchaseManager: purchases,
                configuration: DemoCommerce.paywallConfiguration,
                onPurchased: { product in
                    demoState.record("Purchased \(product.displayName)")
                },
                onRestored: {
                    demoState.record("Restored purchases")
                }
            )
        }
        .defaultSize(width: 860, height: 580)
        .windowResizability(.contentSize)

        Window("Pro Upsell", id: DemoWindowID.upsell) {
            DemoUpsellWindow(purchaseManager: purchases)
                .environment(demoState)
        }
        .defaultSize(width: 560, height: 520)
        .windowResizability(.contentSize)

        #if DEBUG
        Window(
            MacAppFoundationDeveloperTools.windowTitle,
            id: MacAppFoundationDeveloperTools.windowID
        ) {
            FoundationDeveloperView(
                purchaseManager: purchases,
                configuration: developerConfiguration
            )
            .environment(demoState)
        }
        .defaultSize(
            width: MacAppFoundationDeveloperTools.defaultWidth,
            height: MacAppFoundationDeveloperTools.defaultHeight
        )
        #endif

        Settings {
            DemoSettingsView(purchaseManager: purchases)
                .environment(demoState)
        }
    }

    #if DEBUG
    private var developerConfiguration: FoundationDeveloperConfiguration {
        FoundationDeveloperConfiguration(
            replays: [
                FoundationDeveloperReplay(
                    id: "paywall",
                    title: "Pro Paywall",
                    systemImage: "crown.fill"
                ) { dismiss in
                    ProPaywallView(
                        purchaseManager: purchases,
                        configuration: DemoCommerce.paywallConfiguration,
                        onPurchased: { _ in dismiss() },
                        onRestored: dismiss,
                        onClose: dismiss
                    )
                },
                FoundationDeveloperReplay(
                    id: "upsell",
                    title: "Limit Upsell",
                    systemImage: "arrow.up.circle.fill"
                ) { dismiss in
                    ProUpsellView(
                        title: "Free limit reached",
                        message: "This is the app's real reusable upsell surface.",
                        features: purchases.features,
                        onPrimaryAction: dismiss,
                        onSecondaryAction: dismiss
                    )
                }
            ],
            additionalSections: [
                FoundationDeveloperSection(
                    title: "Demo App",
                    items: [
                        .toggle(
                            FoundationDeveloperToggle(
                                title: "Use Mock Data",
                                value: { demoState.useMockData },
                                setValue: { demoState.useMockData = $0 }
                            )
                        ),
                        .value(
                            FoundationDeveloperValue(
                                title: "Demo Actions",
                                value: { "\(demoState.actionCount)" }
                            )
                        ),
                        .action(
                            FoundationDeveloperAction(
                                title: "Record Demo Action",
                                systemImage: "plus.circle"
                            ) {
                                demoState.record("Developer action ran")
                            }
                        ),
                        .destination(
                            FoundationDeveloperDestination(
                                title: "App State",
                                systemImage: "waveform.path.ecg"
                            ) {
                                DemoDeveloperStateView()
                                    .environment(demoState)
                            }
                        ),
                        .action(
                            FoundationDeveloperAction(
                                title: "Reset Demo State",
                                systemImage: "trash",
                                role: .destructive
                            ) {
                                demoState.reset()
                            }
                        )
                    ]
                )
            ]
        )
    }
    #endif
}
