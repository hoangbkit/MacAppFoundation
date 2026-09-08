# macOS Settings

MacAppFoundation provides a reusable BYOKchat-inspired Settings shell while the host app still owns the macOS `Settings` scene itself.

`MacAppSettingsView` owns the visual structure:

- 218pt custom sidebar
- 32pt hoverable/selectable rows
- 72pt detail header
- themed sidebar, separators, surfaces, and detail canvas
- inherited `MacAppSettingsGroupBoxStyle` for pane content
- optional labeled sections for larger Settings surfaces

For the common small-app case, MAF recommends a flat sidebar. Section grouping is opt-in rather than the default.

## Flat panes — recommended default

For apps with a small number of destinations, pass panes directly:

```swift
MacAppSettingsView(
    panes: [
        generalPane,
        .appearance(themeStore: themeStore),
        .plan(
            purchaseManager: purchases,
            configuration: planConfiguration,
            onUpgrade: presentPaywall
        ),
        aboutPane
    ],
    initialSelection: .general,
    router: settingsRouter
)
```

This produces:

```text
General
Appearance
Plan
About
```

There are no section labels unless the app explicitly uses `sections:`.

## Standard Appearance + Plan settings

The convenience initializer includes the two MAF built-ins as a flat list by default:

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

The default sidebar is simply:

```text
Appearance
Plan
```

`MacAppAppearanceSettingsPane` reads `themeStore.configuration.themes`, so it automatically shows the exact built-in subset and custom themes configured by the host app, in host-app order. Selection is persisted by `MacAppThemeStore`.

`MacAppPlanSettingsPane` embeds `ProPlanPane`. MAF owns the pane layout, while the host app owns paywall presentation through `onUpgrade`.

## Add app-owned panes

The convenience initializers accept `additionalPanes`:

```swift
MacAppSettingsView(
    themeStore: themeStore,
    purchaseManager: purchases,
    planConfiguration: planConfiguration,
    additionalPanes: [generalPane, aboutPane],
    initialSelection: .general,
    router: settingsRouter,
    onUpgrade: presentPaywall
)
```

For exact ordering, use the lower-level `panes:` initializer and place built-in pane factories anywhere in the array.

Pane identifiers are extensible value types rather than a framework-owned closed enum:

```swift
extension MacAppSettingsPaneID {
    static let general: Self = "general"
    static let providers: Self = "providers"
}
```

## Apps without commerce

Apps that only need Appearance can use the lighter convenience initializer:

```swift
Settings {
    MacAppSettingsView(
        themeStore: themeStore,
        additionalPanes: appPanes,
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

Use `[.plan]` for Plan only. Use the lower-level `panes:` initializer when no built-ins are desired.

## Optional grouped sections

Labeled grouping remains available for larger Settings surfaces where it improves scanning:

```swift
let sections = [
    MacAppSettingsSection(
        id: .application,
        title: "Application",
        panes: [
            generalPane,
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
            providersPane
        ]
    )
]

MacAppSettingsView(
    sections: sections,
    initialSelection: .general,
    router: settingsRouter
)
```

This produces the more structured BYOKchat-style layout:

```text
APPLICATION
  General
  Appearance

ACCOUNT
  Plan
  Connections
```

`MacAppSettingsBuiltIns.appearanceSection(...)`, `planSection(...)`, and `sections(...)` remain available as grouped helpers.

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

Theme cards support pointer hover, pressed feedback, keyboard focus, accessibility labels/values, and macOS Reduce Motion.

## Routing to a pane

`MacAppSettingsRouter` controls selection only. The host app remains responsible for opening the Settings scene.

```swift
@Environment(\.openSettings) private var openSettings

Button("Manage Plan") {
    settingsRouter.request(.plan)
    openSettings()
}
```

The same pattern works for `.appearance` and any app-defined pane ID. If Settings is already open, requesting another pane updates the active selection. If a request is made first, the shell consumes the pending request when it appears. Valid requests are one-shot: after the shell applies the requested pane, it clears that request so a later normal Settings launch does not unexpectedly reopen the old destination. Requests for panes that are not currently present remain pending so they can resolve if the pane list changes.

## Theme environment

Every MAF Settings surface reads `@Environment(\.macAppTheme)`. App-injected pane content inherits the same environment automatically.

A SwiftUI `Settings` scene is a separate view root from the main `WindowGroup`, so inject the same shared store into that root:

```swift
Settings {
    MacAppSettingsView(...)
        .macAppTheme(themeStore)
}
```

Changing the theme in Appearance updates the shared store immediately and therefore updates every scene hierarchy using that store.

## Group boxes

`MacAppSettingsView` applies `MacAppSettingsGroupBoxStyle` to its content hierarchy. App panes may use ordinary SwiftUI `GroupBox` controls and inherit the same MAF theme-aware chrome automatically.
