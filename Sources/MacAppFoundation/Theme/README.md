# Theme module

Phase 1 of the MacAppFoundation design-system migration lives here. The public surface is intentionally small:

- `MacAppThemeID`: extensible stable identifier
- `MacAppThemePalette`: semantic colors
- `MacAppTheme`: metadata + palette + preferred color scheme
- `MacAppThemeCatalog`: shared built-ins
- `MacAppThemeConfiguration`: app-selected subset/custom themes/default/storage key
- `MacAppThemeStore`: observable persisted selection
- `EnvironmentValues.macAppTheme` and `.macAppTheme(...)`: root injection

Visual framework components migrate onto this environment in Phase 2.
