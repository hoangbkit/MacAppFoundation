import SwiftUI

public extension View {
    /// Prepares StoreKit once and refreshes entitlements whenever the app becomes active.
    func managesPurchases(_ manager: PurchaseManager) -> some View {
        modifier(PurchaseLifecycleModifier(manager: manager))
    }
}

private struct PurchaseLifecycleModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let manager: PurchaseManager

    func body(content: Content) -> some View {
        content
            .task {
                await manager.prepare()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else {
                    return
                }
                Task {
                    await manager.refreshEntitlements()
                }
            }
    }
}
