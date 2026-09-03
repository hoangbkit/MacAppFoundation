#if DEBUG
import SwiftUI

@MainActor
struct FoundationDeveloperProductCatalogView: View {
    let products: [StoreProduct]

    var body: some View {
        List {
            if products.isEmpty {
                ContentUnavailableView(
                    "No Products Loaded",
                    systemImage: "cart",
                    description: Text("Reload products or enable the simulator to inspect pricing.")
                )
            } else {
                ForEach(products) { product in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(product.displayName)
                                .font(.headline)
                            Spacer()
                            Text(product.displayPrice)
                                .font(.headline)
                        }
                        Text(product.id)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        Text(product.subscriptionPeriod?.shortLabel ?? "lifetime")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let offer = product.introductoryOffer {
                            Text("\(offer.headline) · \(offer.isEligible ? "Eligible" : "Ineligible")")
                                .font(.caption)
                                .foregroundStyle(offer.isEligible ? .green : .secondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .navigationTitle("Product Prices")
    }
}

@MainActor
struct FoundationDeveloperEntitlementView: View {
    let purchaseManager: PurchaseManager

    var body: some View {
        List {
            Section("Simulated Entitlement") {
                Button {
                    Task { @MainActor in
                        await purchaseManager.setSimulatedPurchasedProductIDs([])
                    }
                } label: {
                    entitlementRow(title: "Free", productID: nil)
                }

                ForEach(purchaseManager.simulatedConfigurationSnapshot.productIDs, id: \.self) { productID in
                    Button {
                        Task { @MainActor in
                            await purchaseManager.setSimulatedPurchasedProductIDs([productID])
                        }
                    } label: {
                        entitlementRow(
                            title: purchaseManager.simulatedCatalogProducts
                                .first(where: { $0.id == productID })?.displayName ?? productID,
                            productID: productID
                        )
                    }
                }
            }
        }
        .navigationTitle("Entitlement")
    }

    private func entitlementRow(title: String, productID: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            if isSelected(productID) {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
            }
        }
        .contentShape(Rectangle())
    }

    private func isSelected(_ productID: String?) -> Bool {
        let active = purchaseManager.simulatedPurchasedProductIDs
        guard let productID else { return active.isEmpty }
        return active == Set([productID])
    }
}

@MainActor
struct FoundationDeveloperPlansView: View {
    let purchaseManager: PurchaseManager

    @Environment(\.dismiss) private var dismiss
    @State private var plans: [DeveloperPlanDraft]
    @State private var preferredProductID: String
    @State private var validationMessage: String?

    init(purchaseManager: PurchaseManager) {
        self.purchaseManager = purchaseManager
        let configuration = purchaseManager.simulatedConfigurationSnapshot
        let sourceProducts = purchaseManager.simulatedCatalogProducts.isEmpty
            ? purchaseManager.products
            : purchaseManager.simulatedCatalogProducts
        let drafts = sourceProducts.map {
            DeveloperPlanDraft(
                product: $0,
                enabled: configuration.productIDs.contains($0.id),
                unlocksEntitlement: configuration.entitledProductIDs.contains($0.id)
            )
        }
        _plans = State(initialValue: drafts)
        _preferredProductID = State(
            initialValue: configuration.preferredProductID
                ?? drafts.first(where: \.enabled)?.productID
                ?? ""
        )
    }

    var body: some View {
        Form {
            Section {
                ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                    planRow(plan, index: index)
                }

                Button("Add simulated plan", systemImage: "plus") {
                    let index = plans.count + 1
                    plans.append(.new(index: index))
                }
            } header: {
                Text("Plans")
            } footer: {
                Text("Only enabled products appear in simulated paywalls. Pricing and introductory-offer changes never affect App Store Connect.")
            }

            Section("Default Selection") {
                if enabledPlans.isEmpty {
                    Text("Enable at least one plan")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Preferred plan", selection: $preferredProductID) {
                        ForEach(enabledPlans) { plan in
                            Text(plan.displayName.isEmpty ? plan.productID : plan.displayName)
                                .tag(plan.productID)
                        }
                    }
                }
            }

            Section {
                Button("Restore app defaults", role: .destructive) {
                    restoreAppDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Simulated Plans")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    apply()
                }
                .fontWeight(.semibold)
            }
        }
        .alert("Cannot Apply Plans", isPresented: Binding(
            get: { validationMessage != nil },
            set: { if !$0 { validationMessage = nil } }
        )) {
            Button("OK", role: .cancel) { validationMessage = nil }
        } message: {
            Text(validationMessage ?? "")
        }
    }

    private func planRow(_ plan: DeveloperPlanDraft, index: Int) -> some View {
        HStack(spacing: 10) {
            NavigationLink {
                FoundationDeveloperPlanDetailView(plan: $plans[index])
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.displayName.isEmpty ? plan.productID : plan.displayName)
                    Text("\(plan.displayPrice) · \(plan.period.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let offerSummary = plan.introductoryOfferSummary {
                        Text(offerSummary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if plan.enabled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .help("Enabled")
            }

            Button {
                movePlanUp(index)
            } label: {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(.borderless)
            .disabled(index == 0)
            .help("Move up")

            Button {
                movePlanDown(index)
            } label: {
                Image(systemName: "arrow.down")
            }
            .buttonStyle(.borderless)
            .disabled(index == plans.count - 1)
            .help("Move down")

            Button(role: .destructive) {
                plans.remove(at: index)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete plan")
        }
    }

    private var enabledPlans: [DeveloperPlanDraft] {
        plans.filter(\.enabled)
    }

    private func movePlanUp(_ index: Int) {
        guard index > 0 else { return }
        plans.swapAt(index, index - 1)
    }

    private func movePlanDown(_ index: Int) {
        guard index + 1 < plans.count else { return }
        plans.swapAt(index, index + 1)
    }

    private func restoreAppDefaults() {
        let configuration = purchaseManager.configuration
        let sourceProducts = purchaseManager.products.isEmpty
            ? purchaseManager.simulatedCatalogProducts
            : purchaseManager.products
        plans = sourceProducts.map {
            DeveloperPlanDraft(
                product: $0,
                enabled: configuration.productIDs.contains($0.id),
                unlocksEntitlement: configuration.entitledProductIDs.contains($0.id)
            )
        }
        preferredProductID = configuration.preferredProductID
            ?? plans.first(where: \.enabled)?.productID
            ?? ""
    }

    private func apply() {
        let enabled = enabledPlans
        guard !enabled.isEmpty else {
            validationMessage = "Enable at least one simulated plan."
            return
        }

        let normalizedIDs = enabled.map {
            $0.productID.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard normalizedIDs.allSatisfy({ !$0.isEmpty }) else {
            validationMessage = "Every enabled plan needs a product identifier."
            return
        }
        guard Set(normalizedIDs).count == normalizedIDs.count else {
            validationMessage = "Enabled plans must use unique product identifiers."
            return
        }
        guard plans.allSatisfy({ $0.price >= 0 }) else {
            validationMessage = "Plan prices cannot be negative."
            return
        }
        guard plans.allSatisfy({ $0.introductoryOfferPrice >= 0 }) else {
            validationMessage = "Introductory-offer prices cannot be negative."
            return
        }

        let normalizedPreferred = preferredProductID.trimmingCharacters(in: .whitespacesAndNewlines)
        let preferred = normalizedIDs.contains(normalizedPreferred)
            ? normalizedPreferred
            : normalizedIDs[0]
        let entitledIDs = Set(
            enabled
                .filter(\.unlocksEntitlement)
                .map { $0.productID.trimmingCharacters(in: .whitespacesAndNewlines) }
        )
        let existing = purchaseManager.simulatedConfigurationSnapshot
        let configuration = PurchaseConfiguration(
            productIDs: normalizedIDs,
            entitledProductIDs: entitledIDs,
            preferredProductID: preferred,
            features: existing.features,
            productLoadAttempts: existing.productLoadAttempts
        )
        let products = plans.map(\.product)

        Task { @MainActor in
            await purchaseManager.configureSimulatedCatalog(
                configuration: configuration,
                products: products
            )
            dismiss()
        }
    }
}

@MainActor
struct FoundationDeveloperPlanDetailView: View {
    @Binding var plan: DeveloperPlanDraft

    var body: some View {
        Form {
            Section("Availability") {
                Toggle("Enabled", isOn: $plan.enabled)
                Toggle("Unlocks Pro", isOn: $plan.unlocksEntitlement)
                    .disabled(!plan.enabled)
            }

            Section("Product") {
                TextField("Product identifier", text: $plan.productID)
                TextField("Display name", text: $plan.displayName)
                TextField("Description", text: $plan.productDescription, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("Pricing") {
                TextField("Displayed price", text: $plan.displayPrice)
                TextField("Numeric price", value: $plan.price, format: .number)
                Picker("Billing period", selection: $plan.period) {
                    ForEach(DeveloperPlanPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
            }

            if plan.period != .lifetime {
                introductoryOfferSection
            }
        }
        .formStyle(.grouped)
        .navigationTitle(plan.displayName.isEmpty ? "Plan" : plan.displayName)
    }

    private var introductoryOfferSection: some View {
        Section {
            Picker("Offer", selection: $plan.introductoryOfferMode) {
                ForEach(DeveloperIntroductoryOfferMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            if plan.introductoryOfferMode != .none {
                Toggle("Eligible", isOn: $plan.introductoryOfferEligible)

                Stepper(
                    "Period length: \(plan.introductoryOfferPeriodValue)",
                    value: $plan.introductoryOfferPeriodValue,
                    in: 1...365
                )

                Picker("Period unit", selection: $plan.introductoryOfferPeriodUnit) {
                    ForEach(DeveloperIntroductoryOfferPeriodUnit.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }

                Stepper(
                    "Number of periods: \(plan.introductoryOfferPeriodCount)",
                    value: $plan.introductoryOfferPeriodCount,
                    in: 1...52
                )

                if plan.introductoryOfferMode == .freeTrial {
                    LabeledContent("Offer price", value: "Free")
                } else {
                    TextField(
                        "Displayed offer price",
                        text: $plan.introductoryOfferDisplayPrice
                    )
                    TextField(
                        "Numeric offer price",
                        value: $plan.introductoryOfferPrice,
                        format: .number
                    )
                }
            }
        } header: {
            Text("Introductory Offer")
        } footer: {
            Text("Eligibility controls whether trial or introductory-offer copy appears in ProPaywallView. These settings affect the in-process simulator only.")
        }
    }
}
#endif
