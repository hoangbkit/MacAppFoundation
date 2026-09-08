# Theme usage examples

## All built-ins

```swift
let store = MacAppThemeStore(
    configuration: .allBuiltIn(defaultThemeID: .system)
)

RootView()
    .macAppTheme(store)
```

## Selected built-ins

```swift
let store = MacAppThemeStore(
    configuration: .builtIns(
        [.system, .midnight, .ocean, .porcelain],
        defaultThemeID: .system
    )
)
```

## Built-ins plus a custom theme

Create a `MacAppTheme` with an app-owned ID and palette, then pass it in the `themes` array of `MacAppThemeConfiguration` together with any built-ins the app wants to expose.
