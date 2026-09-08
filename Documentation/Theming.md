# Theming

MacAppFoundation provides a shared macOS theme system designed for apps that want consistent framework-owned UI while still controlling which themes are available.

Apps create one `MacAppThemeStore` and inject it at each SwiftUI scene root:

```swift
@State private var themeStore = MacAppThemeStore(
    configuration: .builtIns([
        .system,
        .midnight,
        .ocean,
        .porcelain
    ])
)

RootView()
    .macAppTheme(themeStore)
```

MAF visual components read `@Environment(\.macAppTheme)` and do not require ad-hoc theme parameters. The modifier also applies the active accent tint and preferred light/dark color scheme.

## Built-in themes

The shared catalog contains 13 presets:

- System
- GitHub Dark Dimmed
- Midnight
- Ocean
- Aurora
- Ember
- Graphite
- Porcelain
- Blossom
- Morning Mist
- Soft Sage
- Sunrise
- GitHub Light

`System` follows semantic AppKit colors at runtime. The named presets use the shared richer semantic palette used by MAF surfaces.

## App-selected subsets and custom themes

Apps can expose every built-in, a subset, or arbitrary custom themes. `MacAppThemeID` is an open value type rather than a closed enum, so custom themes remain first-class.

```swift
let custom = MacAppTheme(
    id: "my-custom-theme",
    name: "My Theme",
    caption: "Custom app palette",
    preferredColorScheme: .dark,
    palette: ...
)

let configuration = MacAppThemeConfiguration(
    themes: [
        .system,
        .midnight,
        custom
    ],
    defaultThemeID: .system
)
```

Theme ordering is preserved exactly as supplied by the host app.

## Semantic palette

The palette includes canvas, raised surfaces, borders, separators, selection, code surfaces, primary/secondary/muted text, accent roles, status colors, and shadow. MAF components consume these semantic roles rather than raw system colors.

## Preferred appearance

Every `MacAppTheme` may declare `preferredColorScheme` as `.dark`, `.light`, or `nil`. A `nil` preference follows the system appearance. The shared `.macAppTheme(themeStore)` modifier applies that preference automatically.

## Reusable theme picker

`MacAppThemePicker` renders any ordered theme list, including custom themes, and reports selection without owning persistence:

```swift
MacAppThemePicker(
    themes: themeStore.configuration.themes,
    selectedThemeID: themeStore.selectedThemeID
) { id in
    themeStore.select(id)
}
```

`MacAppThemePreviewCard` previews candidate canvas, surface, separator, text, selection, and accent roles. It also shows whether the theme follows `System`, `Light`, or `Dark` appearance.

The picker/cards support pointer hover, pressed feedback, keyboard focus, accessibility labels and values, and Reduce Motion. MAF's shared, onboarding, paywall, and compact Pro button treatments also suppress motion-based scale/animation when Reduce Motion is enabled.

## Multi-scene apps

SwiftUI scene environments do not automatically propagate between separate `WindowGroup`, `Window`, `Settings`, or custom scene roots. Create one shared `MacAppThemeStore`, then apply `.macAppTheme(themeStore)` to each scene root that should stay synchronized.

```swift
WindowGroup {
    RootView()
        .macAppTheme(themeStore)
}

Settings {
    MacAppSettingsView(...)
        .macAppTheme(themeStore)
}

Window("Pro", id: "pro") {
    ProPaywallView(...)
        .macAppTheme(themeStore)
}
```

Because every root observes the same store, selecting a theme from Appearance updates all open themed scenes immediately.

## Migrating BYOKchat or Onlink theme code

The MAF catalog intentionally follows the shared theme family already used by BYOKchat and Onlink. Migration should remove app-local global theme registries from reusable MAF surfaces rather than wrapping them.

For BYOKchat-style code:

1. Replace app-global `MacDesignTokens.Colors.*` usage inside reusable surfaces with `@Environment(\.macAppTheme)` semantic roles.
2. Replace the app-local theme enum/model with `MacAppThemeConfiguration` + `MacAppThemeStore` where the app does not need extra domain behavior.
3. Keep the app's chosen subset/order by supplying only those presets to the configuration.
4. Convert genuinely app-specific palettes into custom `MacAppTheme` values instead of adding cases to a framework enum.
5. Replace the local Appearance grid with `MacAppThemePicker` or the built-in `.appearance(themeStore:)` settings pane.

For Onlink-style code, map existing semantic palette roles directly to `MacAppThemePalette`; the richer MAF palette was designed to cover the same canvas/surface/border/text/accent/status responsibilities. Onlink's `githubDark`, `mist`, and `sage` naming correspond to MAF's `githubDarkDimmed`, `morningMist`, and `softSage` built-ins.

Apps remain free to keep additional theme metadata or entitlement rules outside MAF. The important boundary is that MAF-owned visual components receive their active theme exclusively through the SwiftUI environment.

## Fallback behavior

The SwiftUI environment defaults to `.system`, so previews and isolated MAF components remain usable even without an injected store. Production apps should still inject their shared store at each app/scene root so all MAF and app-owned surfaces remain synchronized.
