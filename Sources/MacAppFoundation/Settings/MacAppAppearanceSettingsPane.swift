import SwiftUI

/// Built-in Appearance pane backed directly by the app's shared MacAppThemeStore.
///
/// Apps may optionally supply a PurchaseManager and upgrade callback. Themes marked
/// as Pro in the configuration remain visible to Free users but cannot be selected.
@MainActor
public struct MacAppAppearanceSettingsPane: View {
    @Bindable private var themeStore: MacAppThemeStore
    private let purchaseManager: PurchaseManager?
    private let onUpgrade: () -> Void

    @Environment(\.macAppTheme) private var theme

    public init(
        themeStore: MacAppThemeStore,
        purchaseManager: PurchaseManager? = nil,
        onUpgrade: @escaping () -> Void = {}
    ) {
        self.themeStore = themeStore
        self.purchaseManager = purchaseManager
        self.onUpgrade = onUpgrade
    }

    public var body: some View {
        let hasPro = purchaseManager?.hasPro ?? false
        let lockedThemeIDs = hasPro
            ? Set<MacAppThemeID>()
            : themeStore.configuration.proThemeIDs

        ScrollView {
            MacAppThemePicker(
                themes: themeStore.configuration.themes,
                selectedThemeID: themeStore.effectiveThemeID(hasPro: hasPro),
                lockedThemeIDs: lockedThemeIDs,
                onSelect: { themeID in
                    themeStore.select(themeID, hasPro: hasPro)
                },
                onLockedSelect: { _ in
                    onUpgrade()
                }
            )
            .padding(22)
            .frame(maxWidth: 780, alignment: .leading)
        }
        .background(theme.canvas)
    }
}
