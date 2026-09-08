# Theme migration notes

The MacAppFoundation theme catalog is intended to become the shared source for macOS theme presets currently duplicated in apps such as BYOKchat and Onlink.

Migration principles:

- preserve the recognizable built-in theme families while expressing them through one richer semantic palette
- keep app-specific theme availability in the host app through `MacAppThemeConfiguration`
- keep custom theme IDs open-ended so an app can add brand-specific themes without changing MacAppFoundation
- inject one `MacAppThemeStore` at each scene root; framework views and app-owned child views may read the same `macAppTheme` environment value
- use the System preset as a runtime semantic macOS palette rather than freezing system colors into fixed RGB values

The catalog should be treated as shared UI infrastructure. App-specific access rules (for example, whether a theme requires Pro) belong above the theme model and can be applied by Settings/Appearance presentation in a later phase.
