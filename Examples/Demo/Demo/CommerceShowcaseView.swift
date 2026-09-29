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
                VStack(alignment: .leading, spacing: 6) {
                    Text("Commerce")
                        .font(.system(size: 30, weight: .bold))
                    Text("Production-facing product presentation, purchase, and restore using the shared PurchaseManager.")
                        .foregroundStyle(.secondary)
                }

                GroupBox("Products") {
                    VStack(spacing: 0) {
                        if purchaseManager.products.isEmpty {
                            ContentUnavailableView(
                                "No Products",
                                systemImage: "cart",
                                description: Text("The product catalog has not loaded yet.")
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

                HStack {
                    Button("Restore Purchases") {
                        Task {
                            let outcome = await purchaseManager.restorePurchases(timeout: .seconds(5))
                            message = restoreMessage(outcome)
                            demoState.record(message)
                        }
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
            .frame(maxWidth: 840, alignment: .leading)
        }
        .navigationTitle("Commerce")
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
                        : purchaseActivityTitle
                    demoState.record(message)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(purchaseManager.isBusy)
        }
        .padding(.vertical, 10)
    }

    private var purchaseActivityTitle: String {
        switch purchaseManager.activity {
        case .idle: "Ready"
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
