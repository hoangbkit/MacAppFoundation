# Phase 1 — Theme foundation

Phase 1 establishes the reusable theme contract before existing framework views migrate onto it.

Completed surface:

- semantic palette and open theme IDs
- 13 built-in themes
- app-selected subsets and custom themes
- persisted observable selection store
- root SwiftUI environment injection
- System fallback for previews and unconfigured hierarchies
- tests for the public selection/catalog behavior

Existing MAF visual components migrate to `EnvironmentValues.macAppTheme` in Phase 2.
