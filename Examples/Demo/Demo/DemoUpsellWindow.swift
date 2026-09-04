import MacAppFoundation
import SwiftUI

@MainActor
struct DemoUpsellWindow: View {
    let purchaseManager: PurchaseManager

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Environment(DemoState.self) private var demoState

    var body: some View {
        ProUpsellView(
            title: "Free limit reached",
            message: "Upgrade to continue this premium workflow with no limits.",
            features: purchaseManager.features,
            primaryActionTitle: "Unlock Demo Pro",
            secondaryActionTitle: "Continue Free",
            onPrimaryAction: {
                demoState.record("Upsell opened paywall")
                dismiss()
                openWindow(id: DemoWindowID.paywall)
            },
            onSecondaryAction: {
                demoState.record("Upsell dismissed")
                dismiss()
            }
        )
    }
}
