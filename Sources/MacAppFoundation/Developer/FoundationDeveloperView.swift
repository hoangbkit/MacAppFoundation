#if DEBUG
import AppKit
import SwiftUI

/// Debug-only developer controls shared by MacAppFoundation apps.
///
/// The window uses a native macOS navigation split view: stable destinations live
/// in the sidebar, the selected destination owns the detail content, and deeper
/// app-defined destinations push through the detail navigation stack. Editing
/// flows are presented modally so navigation state stays independent from drafts.
@MainActor
public struct FoundationDeveloperView: View {
    @Environment(\.macAppTheme) private var theme
    @Environment(\.appAnalytics) private var analytics

    private let purchaseManager: PurchaseManager
    private let configuration: FoundationDeveloperConfiguration

    @State private var selection: DeveloperDestination? = .overview
    @State private var purchaseOutcome: DeveloperPurchaseOutcome = .success
    @State private var catalogFailureEnabled = false
    @State private var restoreFailureEnabled = false
    @State private var latency: DeveloperPurchaseLatency = .normal
    @State private var replay: FoundationDeveloperReplay?
    @State private var actionError: String?
    @State private var diagnosticsStatus: String?

    public init(
        purchaseManager: PurchaseManager,
        configuration: FoundationDeveloperConfiguration = .init()
    ) {
        precondition(
            MacAppFoundation.isSetup,
            "Call MacAppFoundation.setup() at the beginning of App.init() before using Developer Tools."
        )
        self.purchaseManager = purchaseManager
        self.configuration = configuration
    }

    public var body: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle(MacAppFoundationDeveloperTools.windowTitle)
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
        } detail: {
            NavigationStack {
                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle(navigationTitle)
                    .toolbar {
                        if showsCommerceRefresh {
                            ToolbarItem(placement: .primaryAction) {
                                Button {
                                    refreshCommerce()
                                } label: {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                }
                                .help("Refresh entitlement and products")
                            }
                        }
                    }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .foregroundStyle(theme.textPrimary)
        .tint(theme.accent)
        .background(theme.canvas)
        .frame(
            minWidth: 760,
            idealWidth: MacAppFoundationDeveloperTools.defaultWidth,
            minHeight: 560,
            idealHeight: MacAppFoundationDeveloperTools.defaultHeight
        )
        .sheet(item: $replay) { replay in
            replay.content { self.replay = nil }
        }
        .alert("Developer Action Failed", isPresented: Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "Unknown error")
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section("General") {
                sidebarRow(.overview, title: "Overview", systemImage: "square.grid.2x2")
                sidebarRow(.diagnostics, title: "Diagnostics", systemImage: "stethoscope")
                sidebarRow(.analytics, title: "Analytics", systemImage: "chart.bar.xaxis")
                sidebarRow(.logs, title: "Logs", systemImage: "text.alignleft")
                sidebarRow(.userDefaults, title: "User Defaults", systemImage: "slider.horizontal.3")
            }

            Section("Commerce") {
                sidebarRow(.purchases, title: "Purchases", systemImage: "creditcard")
                sidebarRow(.products, title: "Products", systemImage: "cart")
                sidebarRow(.entitlement, title: "Entitlement", systemImage: "checkmark.seal")
                sidebarRow(.plans, title: "Simulated Plans", systemImage: "list.bullet.rectangle")
                sidebarRow(.failures, title: "Failure Simulation", systemImage: "exclamationmark.triangle")
            }

            if !configuration.replays.isEmpty {
                Section("Flows") {
                    sidebarRow(.replays, title: "Replay", systemImage: "play.rectangle")
                }
            }

            if !configuration.additionalSections.isEmpty {
                Section("App") {
                    ForEach(configuration.additionalSections) { section in
                        sidebarRow(
                            .customSection(section.id),
                            title: section.title,
                            systemImage: "slider.horizontal.3"
                        )
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(theme.canvas)
    }

    private func sidebarRow(
        _ destination: DeveloperDestination,
        title: String,
        systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
            .tag(destination)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .overview {
        case .overview:
            overviewView
        case .purchases:
            purchasesView
        case .products:
            FoundationDeveloperProductCatalogView(products: purchaseManager.products)
        case .entitlement:
            FoundationDeveloperEntitlementView(purchaseManager: purchaseManager)
        case .plans:
            FoundationDeveloperPlansView(purchaseManager: purchaseManager)
        case .failures:
            failureSimulationView
        case .replays:
            replayView
        case .diagnostics:
            diagnosticsView
        case .analytics:
            FoundationDeveloperAnalyticsView(analytics: analytics)
        case .logs:
            MacAppFoundationLogInspectorView(store: MacAppFoundationLogStore.shared)
        case .userDefaults:
            FoundationDeveloperUserDefaultsView()
        case .customSection(let sectionID):
            customSectionView(sectionID: sectionID)
        }
    }

    private var overviewView: some View {
        Form {
            appSection

            Section("Commerce") {
                LabeledContent("Purchase mode", value: purchaseModeTitle)
                LabeledContent("Live entitlement", value: entitlementTitle)
                LabeledContent("Effective access", value: accessTitle)
                LabeledContent("Product state", value: productLoadingTitle)
                LabeledContent("Loaded products", value: "\(purchaseManager.products.count)")
            }
        }
        .developerFormStyle(theme: theme)
    }

    private var purchasesView: some View {
        Form {
            Section("Purchase Mode") {
                Toggle(
                    "Simulated purchases",
                    isOn: Binding(
                        get: { purchaseManager.isUsingSimulatedPurchases },
                        set: { enabled in
                            Task { @MainActor in
                                await purchaseManager.setSimulatedPurchasesEnabled(enabled)
                                resetFailureControls()
                            }
                        }
                    )
                )

                LabeledContent("Live entitlement", value: entitlementTitle)
                LabeledContent("Effective access", value: accessTitle)
                LabeledContent("Product state", value: productLoadingTitle)
                LabeledContent("Loaded products", value: "\(purchaseManager.products.count)")
                LabeledContent("Simulated entitlement", value: simulatedEntitlementTitle)
            }

            Section("Actions") {
                Button("Refresh entitlement", systemImage: "arrow.clockwise") {
                    Task { @MainActor in
                        await purchaseManager.refreshEntitlements()
                    }
                }

                Button("Reload products", systemImage: "arrow.triangle.2.circlepath") {
                    Task { @MainActor in
                        await purchaseManager.loadProducts(force: true)
                    }
                }

                Button("Reset simulated purchases", systemImage: "trash", role: .destructive) {
                    Task { @MainActor in
                        await purchaseManager.resetSimulatedPurchases()
                        resetFailureControls()
                    }
                }
                .disabled(!purchaseManager.isUsingSimulatedPurchases)
            }
        }
        .developerFormStyle(theme: theme)
    }

    private var failureSimulationView: some View {
        Form {
            Section("Purchase Failure Simulation") {
                Picker("Purchase outcome", selection: $purchaseOutcome) {
                    ForEach(DeveloperPurchaseOutcome.allCases) { outcome in
                        Text(outcome.title).tag(outcome)
                    }
                }
                .onChange(of: purchaseOutcome) { _, newValue in
                    applyPurchaseOutcome(newValue)
                }

                Toggle("Product loading failure", isOn: Binding(
                    get: { catalogFailureEnabled },
                    set: { enabled in
                        catalogFailureEnabled = enabled
                        Task { @MainActor in
                            await purchaseManager.setSimulatedProductLoadingFailure(
                                enabled ? .noProductsAvailable : nil
                            )
                        }
                    }
                ))

                Toggle("Restore failure", isOn: Binding(
                    get: { restoreFailureEnabled },
                    set: { enabled in
                        restoreFailureEnabled = enabled
                        purchaseManager.setSimulatedRestoreFailure(
                            enabled ? DeveloperPurchaseOutcome.networkFailure.failure : nil
                        )
                    }
                ))

                Picker("Operation latency", selection: $latency) {
                    ForEach(DeveloperPurchaseLatency.allCases) { latency in
                        Text(latency.title).tag(latency)
                    }
                }
                .onChange(of: latency) { _, newValue in
                    purchaseManager.setSimulatedOperationDelay(newValue.duration)
                }
            }

            Section {
                Button("Reset failure simulation", systemImage: "arrow.counterclockwise") {
                    Task { @MainActor in
                        await purchaseManager.resetSimulatedFailures()
                        resetFailureControls()
                    }
                }
            }
        }
        .developerFormStyle(theme: theme)
        .disabled(!purchaseManager.isUsingSimulatedPurchases)
        .overlay {
            if !purchaseManager.isUsingSimulatedPurchases {
                ContentUnavailableView(
                    "Simulation Disabled",
                    systemImage: "testtube.2",
                    description: Text("Enable simulated purchases from the Purchases destination.")
                )
                .background(theme.canvas.opacity(0.96))
            }
        }
    }

    private var replayView: some View {
        List {
            if configuration.replays.isEmpty {
                ContentUnavailableView(
                    "No Replay Flows",
                    systemImage: "play.rectangle",
                    description: Text("Register app-owned flows in FoundationDeveloperConfiguration.")
                )
            } else {
                ForEach(configuration.replays) { replay in
                    Button {
                        self.replay = replay
                    } label: {
                        Label(replay.title, systemImage: replay.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.canvas)
    }

    private var diagnosticsView: some View {
        Form {
            Section("Commerce") {
                LabeledContent("Purchase mode", value: purchaseModeTitle)
                LabeledContent("Purchase activity", value: purchaseActivityTitle)
                LabeledContent("Preferred product", value: purchaseManager.preferredProduct?.id ?? "None")
                LabeledContent(
                    "Configured products",
                    value: "\(purchaseManager.simulatedConfigurationSnapshot.productIDs.count) simulated"
                )
            }

            Section {
                Button("Copy diagnostics", systemImage: "doc.on.doc") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(diagnosticText, forType: .string)
                    diagnosticsStatus = "Copied"
                }

                if let diagnosticsStatus {
                    Text(diagnosticsStatus)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .developerFormStyle(theme: theme)
    }

    @ViewBuilder
    private func customSectionView(sectionID: String) -> some View {
        if let section = configuration.additionalSections.first(where: { $0.id == sectionID }) {
            Form {
                Section(section.title) {
                    ForEach(section.items) { item in
                        developerItem(item)
                    }
                }
            }
            .developerFormStyle(theme: theme)
        } else {
            ContentUnavailableView(
                "Section Unavailable",
                systemImage: "questionmark.folder",
                description: Text("The selected developer section is no longer registered.")
            )
            .background(theme.canvas)
        }
    }

    private var appSection: some View {
        let info = DeveloperAppInfo.current
        return Section("App") {
            LabeledContent("App", value: info.displayName)
            LabeledContent("Version", value: info.versionAndBuild)
            LabeledContent("Bundle ID", value: info.bundleIdentifier)
            LabeledContent("Build", value: "Debug")
            LabeledContent("System", value: ProcessInfo.processInfo.operatingSystemVersionString)
        }
    }

    @ViewBuilder
    private func developerItem(_ item: FoundationDeveloperItem) -> some View {
        switch item {
        case .action(let action):
            developerActionButton(action)

        case .toggle(let toggle):
            Toggle(toggle.title, isOn: Binding(
                get: { toggle.value },
                set: { toggle.set($0) }
            ))

        case .value(let value):
            LabeledContent(value.title, value: value.value)

        case .destination(let destination):
            NavigationLink {
                destination.content()
                    .navigationTitle(destination.title)
            } label: {
                Label(destination.title, systemImage: destination.systemImage)
            }
        }
    }

    private func developerActionButton(_ action: FoundationDeveloperAction) -> some View {
        Button(
            action.title,
            systemImage: action.systemImage,
            role: action.role == .destructive ? .destructive : nil
        ) {
            Task { @MainActor in
                do {
                    try await action.perform()
                } catch {
                    actionError = error.localizedDescription
                }
            }
        }
    }

    private var navigationTitle: String {
        switch selection ?? .overview {
        case .overview:
            "Overview"
        case .purchases:
            "Purchases"
        case .products:
            "Products"
        case .entitlement:
            "Entitlement"
        case .plans:
            "Simulated Plans"
        case .failures:
            "Failure Simulation"
        case .replays:
            "Replay"
        case .diagnostics:
            "Diagnostics"
        case .analytics:
            "Analytics"
        case .logs:
            "Logs"
        case .userDefaults:
            "User Defaults"
        case .customSection(let sectionID):
            configuration.additionalSections
                .first(where: { $0.id == sectionID })?
                .title ?? MacAppFoundationDeveloperTools.windowTitle
        }
    }

    private var showsCommerceRefresh: Bool {
        switch selection ?? .overview {
        case .overview, .purchases, .products, .entitlement, .plans, .failures:
            true
        case .replays, .diagnostics, .analytics, .logs, .userDefaults, .customSection(_:):
            false
        }
    }

    private func refreshCommerce() {
        Task { @MainActor in
            await purchaseManager.refreshEntitlements()
            await purchaseManager.loadProducts(force: true)
        }
    }

    private func applyPurchaseOutcome(_ outcome: DeveloperPurchaseOutcome) {
        for productID in purchaseManager.simulatedConfigurationSnapshot.productIDs {
            purchaseManager.setSimulatedPurchaseResult(outcome.result, for: productID)
        }
    }

    private func resetFailureControls() {
        purchaseOutcome = .success
        catalogFailureEnabled = false
        restoreFailureEnabled = false
        latency = .normal
        purchaseManager.setSimulatedOperationDelay(latency.duration)
    }

    private var purchaseModeTitle: String {
        purchaseManager.isUsingSimulatedPurchases ? "Simulated" : "Live StoreKit"
    }

    private var entitlementTitle: String {
        switch purchaseManager.entitlementState {
        case .checking: "Checking"
        case .inactive: "Free"
        case .active: "Pro"
        }
    }

    private var accessTitle: String {
        switch purchaseManager.accessState {
        case .inactive:
            return "Free"
        case .active(let source, let snapshot):
            let productIDs = snapshot.activeProductIDs.sorted().joined(separator: ", ")
            let sourceLabel = source == .storeKit ? "StoreKit" : "Verified cache"
            return "\(productIDs) · \(sourceLabel)"
        }
    }

    private var simulatedEntitlementTitle: String {
        let ids = purchaseManager.simulatedPurchasedProductIDs
        guard !ids.isEmpty else { return "Free" }
        return ids.sorted().joined(separator: ", ")
    }

    private var productLoadingTitle: String {
        switch purchaseManager.productLoadingState {
        case .idle: "Idle"
        case .loading: "Loading"
        case .loaded: "Loaded"
        case .failed(let failure): "Failed: \(failure.code.rawValue)"
        }
    }

    private var purchaseActivityTitle: String {
        switch purchaseManager.activity {
        case .idle: "Idle"
        case .purchasing(let productID): "Purchasing \(productID)"
        case .restoring: "Restoring"
        case .pending(let productID): "Pending \(productID)"
        case .failed(let failure): "Failed: \(failure.code.rawValue)"
        }
    }

    private var diagnosticText: String {
        let info = DeveloperAppInfo.current
        let products = purchaseManager.products
            .map { product in
                var value = "\(product.id) = \(product.displayPrice)"
                if let offer = product.introductoryOffer {
                    let eligibility = offer.isEligible ? "eligible" : "ineligible"
                    value += " · \(offer.headline) · \(eligibility)"
                }
                return value
            }
            .joined(separator: "\n")

        return """
        App: \(info.displayName) \(info.versionAndBuild)
        Bundle: \(info.bundleIdentifier)
        System: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Purchase mode: \(purchaseModeTitle)
        Live entitlement: \(entitlementTitle)
        Effective access: \(accessTitle)
        Product state: \(productLoadingTitle)
        Purchase activity: \(purchaseActivityTitle)
        Preferred product: \(purchaseManager.preferredProduct?.id ?? "None")
        Products:\n\(products.isEmpty ? "None" : products)
        """
    }
}

private enum DeveloperDestination: Hashable {
    case overview
    case purchases
    case products
    case entitlement
    case plans
    case failures
    case replays
    case diagnostics
    case analytics
    case logs
    case userDefaults
    case customSection(String)
}

private extension View {
    func developerFormStyle(theme: MacAppTheme) -> some View {
        formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(theme.canvas)
    }
}

private struct DeveloperAppInfo {
    let displayName: String
    let version: String
    let build: String
    let bundleIdentifier: String

    var versionAndBuild: String {
        guard build != "—" else { return version }
        return "\(version) (\(build))"
    }

    static var current: DeveloperAppInfo {
        let bundle = Bundle.main
        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? ProcessInfo.processInfo.processName
        let version = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "—"
        let build = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
            ?? "—"
        return DeveloperAppInfo(
            displayName: displayName,
            version: version,
            build: build,
            bundleIdentifier: bundle.bundleIdentifier ?? "—"
        )
    }
}
#endif
