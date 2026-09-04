#if os(macOS)
import StoreKit
import SwiftUI

/// Native macOS Pro paywall built on ``PurchaseManager``.
///
/// The layout is adapted from PaywallKit's proven desktop paywall while all
/// purchase state, entitlement verification, and simulation remain owned by
/// MacAppFoundation's commerce layer.
public struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss

    private let purchaseManager: PurchaseManager
    private let configuration: ProPaywallConfiguration
    private let onPurchased: ((StoreProduct) -> Void)?
    private let onRestored: (() -> Void)?
    private let onClose: (() -> Void)?

    @State private var selectedProductID: String?
    @State private var alertMessage: String?
    @State private var restoreMessage: String?
    @State private var isOfferCodeRedemptionPresented = false

    public init(
        purchaseManager: PurchaseManager,
        configuration: ProPaywallConfiguration,
        initialSelectedProductID: String? = nil,
        onPurchased: ((StoreProduct) -> Void)? = nil,
        onRestored: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.purchaseManager = purchaseManager
        self.configuration = configuration
        self.onPurchased = onPurchased
        self.onRestored = onRestored
        self.onClose = onClose
        _selectedProductID = State(initialValue: initialSelectedProductID)
    }

    public var body: some View {
        GeometryReader { proxy in
            let outerPadding = max(20, min(proxy.size.width * 0.03, 32))
            let topPadding = max(28, min(proxy.size.height * 0.08, 44))
            let columnSpacing = max(18, min(proxy.size.width * 0.03, 30))

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: columnSpacing) {
                    leadingPane
                    trailingPane
                }
                .padding(.horizontal, outerPadding)
                .padding(.top, topPadding)
                .padding(.bottom, outerPadding)

                Divider()

                bottomBar
                    .padding(.horizontal, max(16, outerPadding - 6))
                    .padding(.vertical, 14)
            }
        }
        .frame(
            minWidth: 760,
            idealWidth: 860,
            maxWidth: 980,
            minHeight: 500,
            idealHeight: 580
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            if purchaseManager.products.isEmpty {
                await purchaseManager.loadProducts(force: true)
            }
            await purchaseManager.refreshEntitlements()
            selectDefaultPlanIfNeeded()
        }
        .onChange(of: purchaseManager.products) { _, _ in
            selectDefaultPlanIfNeeded()
        }
        .offerCodeRedemption(isPresented: $isOfferCodeRedemptionPresented) { result in
            switch result {
            case .success:
                Task {
                    await purchaseManager.refreshEntitlements()
                }
            case .failure(let error):
                presentError(error)
            }
        }
        .alert("Purchase", isPresented: alertBinding) {
            Button("OK", role: .cancel) {
                alertMessage = nil
            }
        } message: {
            Text(alertMessage ?? PurchaseFailure.unknown.message)
        }
    }

    private var leadingPane: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(configuration.title)
                        .font(.system(size: 34, weight: .bold))

                    Text(configuration.subtitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !resolvedFeatures.isEmpty {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(resolvedFeatures) { feature in
                            HStack(alignment: .top, spacing: 14) {
                                featureIcon(feature.systemImage)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(feature.title)
                                        .font(.headline)
                                    Text(feature.message)
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(
            minWidth: 280,
            idealWidth: 420,
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }

    private var trailingPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            productContent

            Spacer(minLength: 10)

            purchaseButton

            if let disclosure = selectedProduct?.introductoryOfferDisclosure {
                Text(disclosure)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }

            legalFooter
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(
            minWidth: 300,
            idealWidth: 340,
            maxWidth: 390,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }

    @ViewBuilder
    private var productContent: some View {
        switch purchaseManager.productLoadingState {
        case .idle, .loading:
            loadingState

        case .failed(let failure):
            VStack(spacing: 12) {
                Label("Unable to load plans", systemImage: "wifi.exclamationmark")
                    .font(.headline)
                Text(failure.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task { await purchaseManager.loadProducts(force: true) }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)

        case .loaded:
            if purchaseManager.products.isEmpty {
                Text(PurchaseFailure.noProductsAvailable.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
            } else {
                VStack(spacing: 12) {
                    ForEach(purchaseManager.products) { product in
                        planCard(product)
                    }
                }
            }
        }
    }

    private func planCard(_ product: StoreProduct) -> some View {
        let isSelected = selectedProductID == product.id

        return Button {
            guard !purchaseManager.isBusy else { return }
            withAnimation(.snappy) {
                selectedProductID = product.id
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                selectionIndicator(isSelected: isSelected)

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.planLabel)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let headline = product.introductoryOfferHeadline {
                        Text(headline)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)

                        if let postOffer = product.postIntroductoryOfferBillingDescription {
                            Text(postOffer)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text(product.isLifetime ? "Pay once" : product.billingDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 7) {
                    if let badge = badge(for: product) {
                        Text(badge)
                            .font(.caption2.bold())
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }

                    Text(product.displayPrice)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            .background(
                isSelected ? Color.accentColor.opacity(0.10) : Color.clear,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.primary.opacity(0.12),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(purchaseManager.isBusy)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var purchaseButton: some View {
        Button {
            guard let product = selectedProduct, !purchaseManager.isBusy else { return }
            let hadProBeforePurchase = purchaseManager.hasPro

            Task {
                await purchaseManager.purchase(product)

                if case .failed(let failure) = purchaseManager.activity {
                    alertMessage = failure.message
                    purchaseManager.clearActivity()
                    return
                }

                if !hadProBeforePurchase, purchaseManager.hasPro {
                    onPurchased?(product)
                }
            }
        } label: {
            HStack(spacing: 8) {
                if purchaseManager.isPurchasing {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(purchaseButtonTitle)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(selectedProduct == nil || purchaseManager.isBusy)
        .opacity(selectedProduct == nil || purchaseManager.isRestoring ? 0.6 : 1)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                restorePurchases()
            } label: {
                HStack(spacing: 6) {
                    if purchaseManager.isRestoring {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(purchaseManager.isRestoring ? "Restoring…" : "Restore Purchases")
                }
            }
            .buttonStyle(.bordered)
            .disabled(purchaseManager.isBusy)

            if configuration.showsRedeemCode {
                Button("Redeem Code") {
                    isOfferCodeRedemptionPresented = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(purchaseManager.isBusy)
            }

            if let restoreMessage {
                Text(restoreMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(restoreMessage)
            }

            Spacer()

            Button {
                close()
            } label: {
                Label("Close", systemImage: "xmark")
            }
            .buttonStyle(.bordered)
            .disabled(purchaseManager.isBusy)
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("Loading available plans…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
    }

    private var legalFooter: some View {
        VStack(spacing: 9) {
            Text(PurchasePlanDisclosure.text(for: purchaseManager.products))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Link("Terms of Use", destination: configuration.termsURL)
                Text("•")
                    .foregroundStyle(.tertiary)
                Link("Privacy Policy", destination: configuration.privacyURL)
            }
            .font(.caption.weight(.semibold))
        }
    }

    private func featureIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor)
            )
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.55),
                    lineWidth: 1.5
                )
            if isSelected {
                Circle()
                    .fill(Color.accentColor)
                    .padding(4)
            }
        }
        .frame(width: 21, height: 21)
        .accessibilityHidden(true)
    }

    private var resolvedFeatures: [ProPaywallFeature] {
        if !configuration.features.isEmpty {
            return configuration.features
        }
        return purchaseManager.configuration.features.map(ProPaywallFeature.init)
    }

    private var selectedProduct: StoreProduct? {
        guard let selectedProductID else { return nil }
        return purchaseManager.product(withID: selectedProductID)
    }

    private var purchaseButtonTitle: String {
        if purchaseManager.isPurchasing {
            return "Purchasing…"
        }
        guard let selectedProduct else {
            return configuration.purchaseButtonTitle
        }
        return selectedProduct.purchaseActionTitle(
            defaultTitle: configuration.purchaseButtonTitle
        )
    }

    private func selectDefaultPlanIfNeeded() {
        if let selectedProductID,
           purchaseManager.product(withID: selectedProductID) != nil {
            return
        }

        if let highlightedProductID = configuration.highlightedProductID,
           purchaseManager.product(withID: highlightedProductID) != nil {
            selectedProductID = highlightedProductID
            return
        }

        selectedProductID = purchaseManager.preferredProduct?.id
            ?? purchaseManager.products.first?.id
    }

    private func restorePurchases() {
        guard !purchaseManager.isBusy else { return }
        restoreMessage = nil

        Task {
            switch await purchaseManager.restorePurchases() {
            case .restored:
                restoreMessage = "Purchases restored."
                onRestored?()
            case .nothingToRestore:
                restoreMessage = "No previous purchases were found."
            case .failed(let failure):
                restoreMessage = failure.message
                purchaseManager.clearActivity()
            }
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func badge(for product: StoreProduct) -> String? {
        let configuredBadge = configuration.highlightedProductID == product.id
            ? configuration.highlightedProductBadge
            : nil

        if let configuredBadge, isSavingsPercentageBadge(configuredBadge) {
            return configuredBadge
        }

        if isYearlyPlan(product),
           let monthlyProduct = purchaseManager.products.first(where: isMonthlyPlan),
           let savingsPercentage = yearlySavingsPercentage(
               monthlyPrice: monthlyProduct.price,
               yearlyPrice: product.price
           ) {
            return "SAVE \(savingsPercentage)%"
        }

        return configuredBadge
    }

    private func isMonthlyPlan(_ product: StoreProduct) -> Bool {
        guard let period = product.subscriptionPeriod else { return false }
        return period.value == 1 && period.unit == .month
    }

    private func isYearlyPlan(_ product: StoreProduct) -> Bool {
        guard let period = product.subscriptionPeriod else { return false }
        return (period.value == 1 && period.unit == .year)
            || (period.value == 12 && period.unit == .month)
    }

    private func yearlySavingsPercentage(
        monthlyPrice: Double,
        yearlyPrice: Double
    ) -> Int? {
        let annualizedMonthlyPrice = monthlyPrice * 12
        guard annualizedMonthlyPrice > 0,
              yearlyPrice >= 0,
              yearlyPrice < annualizedMonthlyPrice
        else { return nil }

        let percentage = ((annualizedMonthlyPrice - yearlyPrice) / annualizedMonthlyPrice) * 100
        let rounded = Int(percentage.rounded())
        return rounded > 0 ? rounded : nil
    }

    private func isSavingsPercentageBadge(_ value: String) -> Bool {
        let uppercased = value.uppercased()
        return uppercased.contains("SAVE") && uppercased.contains("%")
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    alertMessage = nil
                }
            }
        )
    }

    private func presentError(_ error: Error) {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            alertMessage = description
        } else {
            alertMessage = error.localizedDescription
        }
    }
}
#endif