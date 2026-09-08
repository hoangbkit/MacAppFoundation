import SwiftUI

/// Convenience access to the current semantic theme in reusable view code.
///
/// `EnvironmentValues.macAppTheme` defaults to `.system`, so framework previews
/// and isolated views render safely even before a host app injects a store.
public extension View {
    func macAppThemePreview(_ theme: MacAppTheme) -> some View {
        macAppTheme(theme)
    }
}
