#if DEBUG
import AppKit
import SwiftUI

/// Debug-only developer controls shared by MacAppFoundation apps.
///
/// Commerce controls are always present. Apps can register their real paywall,
/// upsell, and other presentations through ``FoundationDeveloperConfiguration``
/// and can append structured app-specific sections without putting developer
/// controls in Settings.
@MainActor
public struct FoundationDeveloperView: View {
    private let purchaseManager: PurchaseManager
    private let configuration: FoundationDeveloperConfiguration

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
        self.purchaseManager = purchaseManager
        self.configuration = configuration
    }

    public var body: some View {
        NavigationStack {
            Form {
                appSection
                purchasesSection
                failureSimulationSection
                replaySection
                diagnosticsSection
                additionalSections
            }
            .formStyle(.grouped)
            .navigationTitle(MacAppFoundationDeveloperTools.windowTitle)
        }
        .frame(
            minWidth: 620,
            idealWidth: MacAppFoundationDeveloperTools.defaultWidth,
            minHeight: 540,
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

    private var purchasesSection: some View {
        Section("Purchases") {
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

            LabeledContent("Entitlement", value: entitlementTitle)
            LabeledContent("Product state", value: productLoadingTitle)

            NavigationLink {
                FoundationDeveloperProductCatalogView(products: purchaseManager.products)
            } label: {
                LabeledContent("Loaded products", value: "\(purchaseManager.products.count)")
            }

            NavigationLink {
                FoundationDeveloperEntitlementView(purchaseManager: purchaseManager)
            } label: {
                LabeledContent("Simulated entitlement", value: simulatedEntitlementTitle)
            }
            .disabled(!purchaseManager.isUsingSimulatedPurchases)

            NavigationLink {
                FoundationDeveloperPlansView(purchaseManager: purchaseManager)
            } label: {
                LabeledContent(
                    "Simulated plans & prices",
                    value: "\(purchaseManager.simulatedConfigurationSnapshot.productIDs.count)"
                )
            }

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

    private var failureSimulationSection: some View {
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

            Button("Reset failure simulation", systemImage: "arrow.counterclockwise") {
                Task { @MainActor in
                    await purchaseManager.resetSimulatedFailures()
                    resetFailureControls()
                }
            }
        }
        .disabled(!purchaseManager.isUsingSimulatedPurchases)
    }

    @ViewBuilder
    private var replaySection: some View {
        if !configuration.replays.isEmpty {
            Section("Replay") {
                ForEach(configuration.replays) { replay in
                    Button {
                        self.replay = replay
                    } label: {
                        Label(replay.title, systemImage: replay.systemImage)
                    }
                }
            }
        }
    }

    private var diagnosticsSection: some View {
        Section("Diagnostics") {
            LabeledContent("Purchase mode", value: purchaseModeTitle)
            LabeledContent("Purchase activity", value: purchaseActivityTitle)
            LabeledContent("Preferred product", value: purchaseManager.preferredProduct?.id ?? "None")
            LabeledContent(
                "Configured products",
                value: "\(purchaseManager.simulatedConfigurationSnapshot.productIDs.count) simulated"
            )

            Button("Copy diagnostics", systemImage: "doc.on.doc") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(diagnosticText, forType: .string)
                diagnosticsStatus = "Copied"
            }

            if let diagnosticsStatus {
                Text(diagnosticsStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var additionalSections: some View {
        ForEach(configuration.additionalSections) { section in
            Section(section.title) {
                ForEach(section.items) { item in
                    developerItem(item)
                }
            }
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
        Entitlement: \(entitlementTitle)
        Product state: \(productLoadingTitle)
        Purchase activity: \(purchaseActivityTitle)
        Preferred product: \(purchaseManager.preferredProduct?.id ?? "None")
        Products:\n\(products.isEmpty ? "None" : products)
        """
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
