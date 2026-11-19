import Foundation
import MacAppFoundation
import SwiftUI

enum DemoWindowID {
    static let main = "demo.main"
    static let onboarding = "demo.onboarding"
    static let paywall = "demo.paywall"
    static let upsell = "demo.upsell"
}

@main
@MainActor
struct MacAppFoundationDemoApp: App {
    @Environment(\.openWindow) private var openWindow
    @State private var demoState: DemoState
    @State private var themeStore: MacAppThemeStore
    @State private var settingsRouter: MacAppSettingsRouter
    @State private var onboarding: OnboardingState
    @State private var analytics: AppAnalyticsClient

    private let purchases: PurchaseManager

    init() {
        MacAppFoundationLogging.bootstrap()

        _demoState = State(initialValue: DemoState())
        _themeStore = State(initialValue: MacAppThemeStore(configuration: DemoTheme.configuration))
        _settingsRouter = State(initialValue: MacAppSettingsRouter())
        _onboarding = State(
            initialValue: OnboardingState(
                id: "demo",
                stepCount: 3
            )
        )
        purchases = DemoCommerce.manager
        _analytics = State(
            initialValue: Self.makeAnalyticsClient(
                enabled: true,
                storageMode: .persisted
            )
        )
    }

    private static func makeAnalyticsClient(
        enabled: Bool,
        storageMode: AppAnalyticsStorageMode
    ) -> AppAnalyticsClient {
        AppAnalyticsClient(
            configuration: AppAnalyticsConfiguration(
                appID: "maf",
                appKey: Bundle.main.bundleIdentifier ?? "com.hoangbkit.maf",
                baseURL: URL(string: "https://analytics.133043.xyz")!,
                enabled: enabled,
                storageMode: storageMode
            )
        )
    }

    var body: some Scene {
        Window("MacAppFoundation Demo", id: DemoWindowID.main) {
            ContentView(
                purchaseManager: purchases,
                settingsRouter: settingsRouter
            )
            .environment(demoState)
            .macAppTheme(themeStore, purchaseManager: purchases)
            .managesPurchases(purchases)
            .managesAnalytics(analytics)
        }
        .defaultSize(width: 1080, height: 700)
        .defaultLaunchBehavior(onboarding.mainWindowLaunchBehavior)
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
            }
            #endif
        }

        OnboardingWindow(
            "Welcome to MAF",
            id: DemoWindowID.onboarding,
            state: onboarding,
            defaultWidth: 620,
            defaultHeight: 500
        ) {
            DemoOnboardingView(onboarding: onboarding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .macAppTheme(themeStore, purchaseManager: purchases)
        }

        MacAppFullSizeWindow(
            "Demo Pro",
            id: DemoWindowID.paywall,
            defaultWidth: 860,
            defaultHeight: 600
        ) {
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
            .macAppTheme(themeStore, purchaseManager: purchases)
            .managesAnalytics(analytics)
        }

        Window("Pro Upsell", id: DemoWindowID.upsell) {
            DemoUpsellWindow(purchaseManager: purchases)
                .environment(demoState)
                .macAppTheme(themeStore, purchaseManager: purchases)
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
            .macAppTheme(themeStore, purchaseManager: purchases)
            .managesAnalytics(analytics)
        }
        .defaultSize(
            width: MacAppFoundationDeveloperTools.defaultWidth,
            height: MacAppFoundationDeveloperTools.defaultHeight
        )
        #endif

        Settings {
            DemoSettingsView(
                purchaseManager: purchases,
                themeStore: themeStore,
                settingsRouter: settingsRouter,
                analytics: analytics
            )
            .environment(demoState)
            .macAppTheme(themeStore, purchaseManager: purchases)
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
                                title: "Replay Onboarding",
                                systemImage: "arrow.counterclockwise.circle"
                            ) {
                                replayOnboarding()
                            }
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
                                replaceAnalyticsClient(storageMode: demoState.analyticsStorageMode, force: true)
                            }
                        )
                    ]
                )
            ],
            onAnalyticsStorageModeChange: { storageMode in
                replaceAnalyticsClient(storageMode: storageMode)
            }
        )
    }

    private func replaceAnalyticsClient(
        storageMode: AppAnalyticsStorageMode,
        force: Bool = false
    ) {
        guard force || demoState.analyticsStorageMode != storageMode else { return }
        let previousAnalytics = analytics
        demoState.analyticsStorageMode = storageMode
        analytics = Self.makeAnalyticsClient(
            enabled: demoState.analyticsEnabled,
            storageMode: storageMode
        )
        let modeTitle = storageMode == .inMemory ? "In Memory" : "Persisted"
        demoState.record("Analytics storage mode: \(modeTitle)")
        Task {
            try? await previousAnalytics.applicationWillResignActive()
        }
    }

    private func replayOnboarding() {
        onboarding.restart()
        openWindow(id: DemoWindowID.onboarding)
    }
    #endif
}
