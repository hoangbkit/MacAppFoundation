import SwiftUI

/// Built-in Settings wrapper for ``ProPlanPane``.
///
/// MacAppFoundation owns the themed layout while the host app still decides how
/// the upgrade action presents its paywall or purchase flow.
@MainActor
public struct MacAppPlanSettingsPane: View {
    private let purchaseManager: PurchaseManager
    private let configuration: ProPlanPaneConfiguration
    private let onUpgrade: () -> Void

    @Environment(\.macAppTheme) private var theme

    public init(
        purchaseManager: PurchaseManager,
        configuration: ProPlanPaneConfiguration,
        onUpgrade: @escaping () -> Void
    ) {
        self.purchaseManager = purchaseManager
        self.configuration = configuration
        self.onUpgrade = onUpgrade
    }

    public var body: some View {
        ScrollView {
            ProPlanPane(
                purchaseManager: purchaseManager,
                configuration: configuration,
                onUpgrade: onUpgrade
            )
            .padding(22)
            .frame(maxWidth: 760, alignment: .topLeading)
        }
        .background(theme.canvas)
    }
}
