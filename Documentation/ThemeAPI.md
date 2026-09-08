# Theme API quick reference

```swift
MacAppThemeID
MacAppThemePalette
MacAppTheme
MacAppThemeCatalog
MacAppThemeConfiguration
MacAppThemeStore
EnvironmentValues.macAppTheme
View.macAppTheme(_:)
```

Host apps generally configure the available catalog once, create one `MacAppThemeStore`, and inject it at the scene root. Framework visual components consume the semantic environment theme rather than receiving theme parameters.
