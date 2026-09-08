# macOS Settings

MacAppFoundation provides a reusable BYOKchat-inspired Settings shell while the host app still owns the macOS `Settings` scene itself.

`MacAppSettingsView` owns the visual structure:

- 218pt custom sidebar
- grouped section labels
- 32pt hoverable/selectable rows
- 72pt detail header
- themed sidebar, separators, surfaces, and detail canvas
- inherited `MacAppSettingsGroupBoxStyle` for pane content

MAF ships Appearance and Plan as its standard built-in panes. Apps may use both, remove either one, append their own sections, or compose every pane manually for exact ordering.

## Standard Appearance + Plan settings

The convenience initializer includes both built-ins by default:

```swift
@State private var themeStore = MacAppThemeStore(
    configuration: .builtIns([
        .system,
        .midnight,
        .ocean,
        .porcelain
    ])
)
@State private var settingsRouter = MacAppSettingsRouter()

var body: some Scene {
    Settings {
        MacAppSettingsView(
            themeStore: themeStore,
            purchaseManager: purchases,
            planConfiguration: ProPlanPaneConfiguration(appName: "My App"),
            router: settingsRouter,
            onUpgrade: {
                openWindow(id: "pro-paywall")
            }
        )
        .macAppTheme(themeStore)
    }
    .windowStyle(.hiddenTitleBar)
}
```

The default grouping is:

```text
APPLICATION
  Appearance

ACCOUNT
  Plan
```

`MacAppAppearanceSettingsPane` reads `themeStore.configuration.themes`, so it automatically shows the exact built-in subset and custom themes configured by the host app, in host-app order. Selection is persisted by `MacAppThemeStore`.

`MacAppPlanSettingsPane` embeds `ProPlanPane`. MAF owns the pane layout, while the host app owns paywall presentation through `onUpgrade`.

## Theme picker

Appearance uses the reusable `MacAppThemePicker` and `MacAppThemePreviewCard` components. Cards preview each candidate theme using its own canvas, surface, text, selection, separator, and accent roles rather than the currently active theme.

The picker displays the theme's preferred appearance as `System`, `Light`, or `Dark`, supports app-defined custom themes, preserves the host app's configured order, and exposes selection through a callback rather than owning persistence.

```swift
MacAppThemePicker(
    themes: themeStore.configuration.themes,
    selectedThemeID: themeStore.selectedThemeID
) { id in
    themeStore.select(id)
}
```

Theme cards support pointer hover, pressed feedback, keyboard focus, accessibility labels/values, and macOS Reduce Motion. The same Reduce Motion rule is also applied to MAF's shared button style, onboarding/paywall buttons, and compact Pro plan control.

## Apps without commerce

Apps that only need Appearance can use the lighter convenience initializer:

```swift
Settings {
    MacAppSettingsView(
        themeStore: themeStore,
        additionalSections: appSections,
        router: settingsRouter
    )
    .macAppTheme(themeStore)
}
```

## Disabling built-in panes

For apps using the full convenience initializer, select the built-ins explicitly:

```swift
MacAppSettingsView(
    themeStore: themeStore,
    purchaseManager: purchases,
    planConfiguration: planConfiguration,
    builtInPanes: [.appearance],
    onUpgrade: presentPaywall
)
```

Use `[.plan]` for Plan only. Use the lower-level `sections:` initializer when no built-ins are desired.

## Exact ordering and app-defined panes

Pane and section identifiers are extensible value types rather than framework-owned closed enums.

```swift
extension MacAppSettingsPaneID {
    static let general: Self = "general"
    static let providers: Self = "providers"
}
```

Built-in pane factories can be placed anywhere alongside app panes:

```swift
let sections = [
    MacAppSettingsSection(
        id: .application,
        title: "Application",
        panes: [
            MacAppSettingsPane(
                id: .general,
                title: "General",
                subtitle: "Application behavior and defaults.",
                systemImage: "gearshape"
            ) {
                GeneralSettingsView()
            },
            .appearance(themeStore: themeStore)
        ]
    ),
    MacAppSettingsSection(
        id: .account,
        title: "Account",
        panes: [
            .plan(
                purchaseManager: purchases,
                configuration: planConfiguration,
                onUpgrade: presentPaywall
            ),
            MacAppSettingsPane(
                id: .providers,
                title: "Connections",
                subtitle: "Manage provider connections.",
                systemImage: "bolt.horizontal.circle"
            ) {
                ProviderSettingsView()
            }
        ]
    )
]

MacAppSettingsView(
    sections: sections,
    initialSelection: .general,
    router: settingsRouter
)
```

This produces the BYOKchat-style structure without coupling MAF to app-specific panes:

```text
APPLICATION
  General
  Appearance

ACCOUNT
  Plan
  Connections
```

Apps may also use `MacAppSettingsBuiltIns.appearanceSection(...)` and `MacAppSettingsBuiltIns.planSection(...)` when the default MAF section grouping is useful during custom composition.

## Routing to a pane

`MacAppSettingsRouter` controls selection only. The host app remains responsible for opening the Settings scene.

```swift
@Environment(\.openSettings) private var openSettings

Button("Manage Plan") {
    settingsRouter.request(.plan)
    openSettings()
}
```

The same pattern works for `.appearance` and any app-defined pane ID. If Settings is already open, requesting another pane updates the active selection. If a request is made first, the shell consumes the pending request when it appears.

## Theme environment

Every MAF Settings surface reads `@Environment(\.macAppTheme)`. App-injected pane content inherits the same environment automatically.

A SwiftUI `Settings` scene is a separate view root from the main `WindowGroup`, so inject the same shared store into that root as shown above:

```swift
Settings {
    MacAppSettingsView(...)
        .macAppTheme(themeStore)
}
```

Changing the theme in Appearance updates the shared store immediately and therefore updates every scene hierarchy using that store.

## Group boxes

`MacAppSettingsView` applies `MacAppSettingsGroupBoxStyle` to its content hierarchy. App panes may use ordinary SwiftUI `GroupBox` controls and inherit the same MAF theme-aware chrome automatically.

```swift
GroupBox("Chat") {
    LabeledContent("Keyboard") {
        Text("Return sends · Shift-Return inserts a line")
    }
}
```

Apps may also use `MacAppSettingsGroupBoxStyle` explicitly outside the Settings shell when they want the same visual treatment.
