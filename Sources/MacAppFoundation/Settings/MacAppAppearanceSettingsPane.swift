import SwiftUI

/// Built-in Appearance pane backed directly by the app's shared ``MacAppThemeStore``.
///
/// The pane shows exactly the themes supplied by ``MacAppThemeConfiguration`` in
/// app-defined order, including custom themes. Selecting a theme delegates to the
/// store, so persistence and fallback behavior remain centralized in the theme
/// system rather than being duplicated by Settings.
@MainActor
public struct MacAppAppearanceSettingsPane: View {
    @Bindable private var themeStore: MacAppThemeStore

    @Environment(\.macAppTheme) private var theme

    public init(themeStore: MacAppThemeStore) {
        self.themeStore = themeStore
    }

    public var body: some View {
        ScrollView {
            MacAppThemePicker(
                themes: themeStore.configuration.themes,
                selectedThemeID: themeStore.selectedThemeID
            ) { themeID in
                themeStore.select(themeID)
            }
            .padding(22)
            .frame(maxWidth: 780, alignment: .leading)
        }
        .background(theme.canvas)
    }
}
