import MacAppFoundation
import SwiftUI

@MainActor
struct CommerceShowcaseView: View {
    let purchaseManager: PurchaseManager

    @Environment(DemoState.self) private var demoState
    @State private var message = "Ready"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                GroupBox("Current state") {
                    VStack(spacing: 10) {
                        LabeledContent("Entitlement", value: entitlementTitle)
                        LabeledContent("Product loading", value: productLoadingTitle)
                        LabeledContent("Purchase activity", value: activityTitle)
                        LabeledContent("Preferred product", value: purchaseManager.preferredProduct?.displayName ?? "None")
                        #if DEBUG
                        LabeledContent(
                            "Backend",
                            value: purchaseManager.isUsingSimulatedPurchases ? "In-process simulator" : "StoreKit Testing"
                        )
                        #endif
                    }
                    .padding(6)
                }

                GroupBox("Commerce actions") {
                    HStack(spacing: 10) {
                        Button("Load Products") {
                            Task {
                                await purchaseManager.loadProducts(force: true)
                                message = "Product catalog reloaded"
                            }
                        }

                        Button("Refresh Entitlement") {
                            Task {
                                await purchaseManager.refreshEntitlements()
                                message = "Entitlement refreshed"
                            }
                        }

                        Button("Restore Purchases") {
                            Task {
                                let outcome = await purchaseManager.restorePurchases(timeout: .seconds(5))
                                message = restoreMessage(outcome)
                                demoState.record(message)
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .padding(6)
                }

                GroupBox("Loaded products") {
                    VStack(spacing: 0) {
                        if purchaseManager.products.isEmpty {
                            ContentUnavailableView(
                                "No Products",
                                systemImage: "cart",
                                description: Text("Load the catalog or switch to the simulator.")
                            )
                            .frame(minHeight: 160)
                        } else {
                            ForEach(Array(purchaseManager.products.enumerated()), id: \.element.id) { index, product in
                                productRow(product)
                                if index < purchaseManager.products.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding(6)
                }

                #if DEBUG
                GroupBox("Debug simulator API") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(
                            "Use in-process simulator",
                            isOn: Binding(
                                get: { purchaseManager.isUsingSimulatedPurchases },
                                set: { enabled in
                                    Task {
                                        await purchaseManager.setSimulatedPurchasesEnabled(enabled)
                                        message = enabled ? "Simulator enabled" : "StoreKit Testing enabled"
                                    }
                                }
                            )
                        )

                        HStack(spacing: 8) {
                            Button("Free") {
                                forceEntitlement(nil)
                            }
                            ForEach(purchaseManager.products) { product in
                                Button(product.planLabel) {
                                    forceEntitlement(product.id)
                                }
                            }
                        }
                        .disabled(!purchaseManager.isUsingSimulatedPurchases)

                        HStack(spacing: 8) {
                            Button("Reset Simulator", role: .destructive) {
                                Task {
                                    await purchaseManager.resetSimulatedPurchases()
                                    message = "Simulator reset"
                                }
                            }

                            Button("Reset Failures") {
                                Task {
                                    await purchaseManager.resetSimulatedFailures()
                                    message = "Failure simulation reset"
                                }
                            }
                        }
                        .disabled(!purchaseManager.isUsingSimulatedPurchases)

                        Text("The Developer Tools window exposes the complete catalog editor, introductory offers, latency, purchase outcomes, loading failures, and restore failures.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(6)
                }
                #endif

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(maxWidth: 840, alignment: .leading)
        }
        .navigationTitle("Commerce")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Commerce + Simulation")
                .font(.system(size: 30, weight: .bold))
            Text("The same PurchaseManager drives StoreKit, simulated products, entitlements, purchase, and restore.")
                .foregroundStyle(.secondary)
        }
    }

    private func productRow(_ product: StoreProduct) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(product.displayName)
                        .fontWeight(.semibold)
                    if product.id == purchaseManager.preferredProduct?.id {
                        Text("PREFERRED")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(product.id)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                if let offer = product.introductoryOffer {
                    Text("\(offer.headline) · \(offer.isEligible ? "eligible" : "ineligible")")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(product.displayPrice)
                    .fontWeight(.semibold)
                Text(product.planLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Purchase") {
                Task {
                    await purchaseManager.purchase(product)
                    message = purchaseManager.hasPro
                        ? "Entitlement active after \(product.displayName)"
                        : activityTitle
                    demoState.record(message)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(purchaseManager.isBusy)
        }
        .padding(.vertical, 10)
    }

    #if DEBUG
    private func forceEntitlement(_ productID: String?) {
        Task {
            if let productID {
                await purchaseManager.setSimulatedPurchasedProductIDs([productID])
                message = "Forced entitlement: \(productID)"
            } else {
                await purchaseManager.setSimulatedPurchasedProductIDs([])
                message = "Forced Free entitlement"
            }
            demoState.record(message)
        }
    }
    #endif

    private var entitlementTitle: String {
        switch purchaseManager.entitlementState {
        case .checking: "Checking"
        case .inactive: "Free"
        case .active(let snapshot): snapshot.activeProductIDs.sorted().joined(separator: ", ")
        }
    }

    private var productLoadingTitle: String {
        switch purchaseManager.productLoadingState {
        case .idle: "Idle"
        case .loading: "Loading"
        case .loaded: "Loaded"
        case .failed(let failure): "Failed: \(failure.message)"
        }
    }

    private var activityTitle: String {
        switch purchaseManager.activity {
        case .idle: "Idle"
        case .purchasing(let productID): "Purchasing \(productID)"
        case .restoring: "Restoring"
        case .pending(let productID): "Pending \(productID)"
        case .failed(let failure): "Failed: \(failure.message)"
        }
    }

    private func restoreMessage(_ outcome: RestoreOutcome) -> String {
        switch outcome {
        case .restored: "Purchases restored"
        case .nothingToRestore: "Nothing to restore"
        case .failed(let failure): "Restore failed: \(failure.message)"
        }
    }
}
