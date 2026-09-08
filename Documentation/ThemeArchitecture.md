# Theme architecture

MacAppFoundation separates four responsibilities:

1. `MacAppTheme`: semantic visual values for one appearance.
2. `MacAppThemeCatalog`: reusable built-in presets.
3. `MacAppThemeConfiguration`: the app-selected theme set, default, and storage key.
4. `MacAppThemeStore`: observable selection and persistence injected into SwiftUI once at the root.

Framework-owned visual views consume `EnvironmentValues.macAppTheme`. Host-app views may consume the same value. This avoids passing theme parameters down component trees and keeps app-specific theme catalogs and Settings composition independent from reusable view implementation.
