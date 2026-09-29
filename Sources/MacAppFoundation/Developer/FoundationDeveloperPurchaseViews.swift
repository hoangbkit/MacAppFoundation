#if DEBUG
import SwiftUI

@MainActor
struct FoundationDeveloperProductCatalogView: View {
    @Environment(\.macAppTheme) private var theme

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
                            .foregroundStyle(theme.textSecondary)
                        Text(product.planLabel)
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                        if let offer = product.introductoryOffer {
                            Text("\(offer.headline) · \(offer.isEligible ? "Eligible" : "Ineligible")")
                                .font(.caption)
                                .foregroundStyle(offer.isEligible ? theme.success : theme.textSecondary)
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.canvas)
        .foregroundStyle(theme.textPrimary)
        .tint(theme.accent)
    }
}

@MainActor
struct FoundationDeveloperEntitlementView: View {
    @Environment(\.macAppTheme) private var theme

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
        .scrollContentBackground(.hidden)
        .background(theme.canvas)
        .foregroundStyle(theme.textPrimary)
        .tint(theme.accent)
    }

    private func entitlementRow(title: String, productID: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            if isSelected(productID) {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.accent)
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
    @Environment(\.macAppTheme) private var theme

    let purchaseManager: PurchaseManager

    @State private var plans: [DeveloperPlanDraft]
    @State private var preferredProductID: String
    @State private var editor: DeveloperPlanEditorContext?
    @State private var pendingDelete: DeveloperPlanDeleteContext?
    @State private var validationMessage: String?
    @State private var applyStatus: String?

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
        List {
            Section {
                if plans.isEmpty {
                    ContentUnavailableView(
                        "No Simulated Plans",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Add a plan to configure the in-process purchase simulator.")
                    )
                } else {
                    ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                        planRow(plan, index: index)
                    }
                }
            } header: {
                Text("Plans")
            } footer: {
                Text("Select a plan to edit it in a sheet. Changes stay staged until Apply.")
                    .foregroundStyle(theme.textSecondary)
            }

            Section("Default Selection") {
                LabeledContent("Preferred plan", value: preferredPlanTitle)
            }

            Section("Simulator") {
                Button("Restore app defaults", systemImage: "arrow.counterclockwise", role: .destructive) {
                    restoreAppDefaults()
                }

                if let applyStatus {
                    Text(applyStatus)
                        .font(.caption)
                        .foregroundStyle(theme.success)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.canvas)
        .foregroundStyle(theme.textPrimary)
        .tint(theme.accent)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    beginAddingPlan()
                } label: {
                    Label("Add Plan", systemImage: "plus")
                }

                Button("Apply") {
                    apply()
                }
                .fontWeight(.semibold)
            }
        }
        .sheet(item: $editor) { context in
            FoundationDeveloperPlanEditorSheet(
                plan: context.plan,
                isPreferred: context.isPreferred,
                existingProductIDs: productIDs(excluding: context.index)
            ) { plan, isPreferred in
                saveEditor(context, plan: plan, isPreferred: isPreferred)
            }
        }
        .confirmationDialog(
            "Delete Simulated Plan?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { context in
            Button("Delete \(context.title)", role: .destructive) {
                deletePlan(at: context.index)
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: { _ in
            Text("The plan is removed from this draft. Apply to update the simulator.")
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
            Button {
                beginEditingPlan(at: index)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(plan.displayName.isEmpty ? plan.productID : plan.displayName)

                        if preferredProductID == plan.productID {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(theme.accent)
                                .help("Preferred plan")
                        }
                    }

                    Text("\(plan.displayPrice) · \(plan.period.title)")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)

                    if let offerSummary = plan.introductoryOfferSummary {
                        Text(offerSummary)
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if plan.enabled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.accent)
                    .help("Enabled")
            }

            if plan.unlocksEntitlement {
                Image(systemName: "crown.fill")
                    .foregroundStyle(theme.warning)
                    .help("Unlocks Pro")
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
                pendingDelete = DeveloperPlanDeleteContext(
                    index: index,
                    title: plan.displayName.isEmpty ? plan.productID : plan.displayName
                )
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete plan")
        }
        .padding(.vertical, 3)
    }

    private var enabledPlans: [DeveloperPlanDraft] {
        plans.filter(\.enabled)
    }

    private var preferredPlanTitle: String {
        guard let plan = plans.first(where: { $0.productID == preferredProductID }) else {
            return "None"
        }
        return plan.displayName.isEmpty ? plan.productID : plan.displayName
    }

    private func productIDs(excluding index: Int?) -> Set<String> {
        Set(
            plans.enumerated().compactMap { offset, plan in
                guard offset != index else { return nil }
                return plan.productID.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        )
    }

    private func beginAddingPlan() {
        var index = plans.count + 1
        var draft = DeveloperPlanDraft.new(index: index)
        let existing = productIDs(excluding: nil)

        while existing.contains(draft.productID) {
            index += 1
            draft = .new(index: index)
        }

        editor = DeveloperPlanEditorContext(
            index: nil,
            plan: draft,
            isPreferred: plans.isEmpty
        )
    }

    private func beginEditingPlan(at index: Int) {
        guard plans.indices.contains(index) else { return }
        let plan = plans[index]
        editor = DeveloperPlanEditorContext(
            index: index,
            plan: plan,
            isPreferred: preferredProductID == plan.productID
        )
    }

    private func saveEditor(
        _ context: DeveloperPlanEditorContext,
        plan: DeveloperPlanDraft,
        isPreferred: Bool
    ) {
        if let index = context.index, plans.indices.contains(index) {
            plans[index] = plan
        } else {
            plans.append(plan)
        }

        let enabledIDs = Set(enabledPlans.map(\.productID))
        if isPreferred, plan.enabled {
            preferredProductID = plan.productID
        } else if !enabledIDs.contains(preferredProductID) {
            preferredProductID = enabledPlans.first?.productID ?? ""
        }

        applyStatus = nil
    }

    private func deletePlan(at index: Int) {
        guard plans.indices.contains(index) else { return }
        let removedID = plans[index].productID
        plans.remove(at: index)

        if preferredProductID == removedID || !enabledPlans.contains(where: { $0.productID == preferredProductID }) {
            preferredProductID = enabledPlans.first?.productID ?? ""
        }

        pendingDelete = nil
        applyStatus = nil
    }

    private func movePlanUp(_ index: Int) {
        guard index > 0 else { return }
        plans.swapAt(index, index - 1)
        applyStatus = nil
    }

    private func movePlanDown(_ index: Int) {
        guard index + 1 < plans.count else { return }
        plans.swapAt(index, index + 1)
        applyStatus = nil
    }

    private func restoreAppDefaults() {
        let configuration = purchaseManager.simulatedDefaultConfigurationSnapshot
        let sourceProducts = purchaseManager.simulatedDefaultCatalogProducts
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
        applyStatus = nil
    }

    private func apply() {
        let enabled = enabledPlans
        guard !enabled.isEmpty else {
            validationMessage = "Enable at least one simulated plan."
            return
        }

        let normalizedCatalogIDs = plans.map {
            $0.productID.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard normalizedCatalogIDs.allSatisfy({ !$0.isEmpty }) else {
            validationMessage = "Every simulated plan needs a product identifier."
            return
        }
        guard Set(normalizedCatalogIDs).count == normalizedCatalogIDs.count else {
            validationMessage = "All simulated plans must use unique product identifiers."
            return
        }

        let normalizedIDs = enabled.map {
            $0.productID.trimmingCharacters(in: .whitespacesAndNewlines)
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
            preferredProductID = preferred
            applyStatus = "Applied to simulator"
        }
    }
}

private struct DeveloperPlanEditorContext: Identifiable {
    let id = UUID()
    let index: Int?
    let plan: DeveloperPlanDraft
    let isPreferred: Bool
}

private struct DeveloperPlanDeleteContext: Identifiable {
    let id = UUID()
    let index: Int
    let title: String
}

@MainActor
private struct FoundationDeveloperPlanEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.macAppTheme) private var theme

    @State private var plan: DeveloperPlanDraft
    @State private var isPreferred: Bool

    private let existingProductIDs: Set<String>
    private let onSave: (DeveloperPlanDraft, Bool) -> Void

    init(
        plan: DeveloperPlanDraft,
        isPreferred: Bool,
        existingProductIDs: Set<String>,
        onSave: @escaping (DeveloperPlanDraft, Bool) -> Void
    ) {
        _plan = State(initialValue: plan)
        _isPreferred = State(initialValue: isPreferred)
        self.existingProductIDs = existingProductIDs
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Availability") {
                    Toggle("Enabled", isOn: $plan.enabled)
                        .onChange(of: plan.enabled) { _, enabled in
                            if !enabled {
                                isPreferred = false
                            }
                        }

                    Toggle("Unlocks Pro", isOn: $plan.unlocksEntitlement)
                        .disabled(!plan.enabled)

                    Toggle("Preferred plan", isOn: $isPreferred)
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

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(theme.destructive)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(theme.canvas)
            .foregroundStyle(theme.textPrimary)
            .tint(theme.accent)
            .navigationTitle(plan.displayName.isEmpty ? "Plan" : plan.displayName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(plan, isPreferred)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(validationMessage != nil)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 620)
    }

    private var validationMessage: String? {
        let normalizedID = plan.productID.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedID.isEmpty {
            return "Product identifier is required."
        }
        if existingProductIDs.contains(normalizedID) {
            return "Product identifier must be unique."
        }
        if plan.price < 0 {
            return "Plan price cannot be negative."
        }
        if plan.introductoryOfferPrice < 0 {
            return "Introductory-offer price cannot be negative."
        }
        return nil
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
                .foregroundStyle(theme.textSecondary)
        }
    }
}
#endif
