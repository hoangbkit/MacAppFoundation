# Theming

MacAppFoundation provides a shared semantic macOS theme system. Host apps create a `MacAppThemeStore` once and inject it at the app or scene root. Built-in MAF views read the active theme from `EnvironmentValues.macAppTheme`.

```swift
@State private var themeStore = MacAppThemeStore(
    configuration: MacAppThemeConfiguration(
        themes: [
            .system,
            MacAppThemeCatalog.midnight,
            MacAppThemeCatalog.ocean,
            MacAppThemeCatalog.porcelain,
        ],
        defaultThemeID: .system
    )
)

RootView()
    .macAppTheme(themeStore)
```

The root modifier injects the active theme, applies its accent tint, and applies its preferred light/dark color scheme. The environment has a `.system` fallback so previews and isolated views still render without app setup.

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

Apps may expose all of them with `MacAppThemeCatalog.allBuiltIn` or choose any subset.

## Custom themes

Theme IDs are extensible values rather than a framework-owned enum, so apps can add their own themes alongside built-ins.

```swift
let brandTheme = MacAppTheme(
    id: "brand",
    name: "Brand",
    caption: "Our custom appearance",
    preferredColorScheme: .dark,
    palette: MacAppThemePalette(...)
)

let configuration = MacAppThemeConfiguration(
    themes: [MacAppThemeCatalog.system, brandTheme],
    defaultThemeID: "brand"
)
```

`MacAppThemePalette` exposes semantic roles for canvases, surfaces, borders, selection, primary/secondary/muted text, accent colors, status colors, and shadow. Host-app views may read the same environment when they want to visually integrate with MAF components.
