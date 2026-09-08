# macOS Settings

MacAppFoundation provides a reusable BYOKchat-inspired Settings shell while the host app still owns the macOS `Settings` scene itself.

`MacAppSettingsView` owns the visual structure:

- 218pt custom sidebar
- grouped section labels
- 32pt hoverable/selectable rows
- 72pt detail header
- themed sidebar, separators, surfaces, and detail canvas
- inherited `MacAppSettingsGroupBoxStyle` for pane content

Apps own which sections and panes exist, their ordering, and the content of app-specific panes.

## App-defined panes

Pane and section identifiers are extensible value types rather than framework enums.

```swift
extension MacAppSettingsPaneID {
    static let general: Self = "general"
    static let providers: Self = "providers"
}

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
            MacAppSettingsPane(
                id: .appearance,
                title: "Appearance",
                subtitle: "Choose how the app looks.",
                systemImage: "paintpalette"
            ) {
                AppearanceSettingsView()
            }
        ]
    ),
    MacAppSettingsSection(
        id: .account,
        title: "Account",
        panes: [
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
```

Then host the shell from the app-owned Settings scene:

```swift
@State private var settingsRouter = MacAppSettingsRouter()

var body: some Scene {
    Settings {
        MacAppSettingsView(
            sections: sections,
            initialSelection: .general,
            router: settingsRouter
        )
    }
    .windowStyle(.hiddenTitleBar)
}
```

The shell inherits `macAppTheme` from the app root/scene, and every app-injected pane receives the same SwiftUI environment automatically.

## Routing to a pane

`MacAppSettingsRouter` controls selection only. The host app remains responsible for opening the Settings scene.

```swift
@Environment(\.openSettings) private var openSettings

Button("Manage Providers") {
    settingsRouter.request(.providers)
    openSettings()
}
```

The same pattern works for MAF built-ins such as `.plan` and `.appearance` and for any app-defined pane ID.

If the Settings window is already open, requesting another pane updates the active selection. If a request is made before the Settings scene appears, the shell consumes the pending request when it appears.

## Group boxes

`MacAppSettingsView` applies `MacAppSettingsGroupBoxStyle` to its content hierarchy. App panes may therefore use ordinary SwiftUI `GroupBox` controls and inherit the same MAF theme-aware chrome automatically.

```swift
GroupBox("Chat") {
    LabeledContent("Keyboard") {
        Text("Return sends · Shift-Return inserts a line")
    }
}
```

Apps may also use `MacAppSettingsGroupBoxStyle` explicitly outside the Settings shell when they want the same visual treatment.

## Built-in panes

The shell deliberately does not hard-code pane content. The next implementation phase adds MAF-provided Appearance and Plan panes as the default built-ins while preserving the same injection model, so apps can add, reorder, or omit panes without replacing the shell.

`ProPlanPane` remains independently reusable and theme-aware.
