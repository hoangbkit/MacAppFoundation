import SwiftUI

/// Built-in Settings destinations provided by MacAppFoundation.
///
/// This enum describes only framework-owned panes. App-defined destinations keep
/// using open ``MacAppSettingsPaneID`` values and can be mixed freely with these.
public enum MacAppSettingsBuiltInPane: Hashable, Sendable {
    case appearance
    case plan

    public static let defaults: Set<Self> = [.appearance, .plan]
}

public extension MacAppSettingsPane {
    /// Creates MAF's built-in Appearance pane.
    @MainActor
    static func appearance(
        themeStore: MacAppThemeStore,
        title: String = "Appearance",
        subtitle: String = "Choose the color theme used throughout the app.",
        systemImage: String = "paintpalette"
    ) -> MacAppSettingsPane {
        MacAppSettingsPane(
            id: .appearance,
            title: title,
            subtitle: subtitle,
            systemImage: systemImage
        ) {
            MacAppAppearanceSettingsPane(themeStore: themeStore)
        }
    }

    /// Creates MAF's built-in Plan pane while keeping paywall presentation app-owned.
    @MainActor
    static func plan(
        purchaseManager: PurchaseManager,
        configuration: ProPlanPaneConfiguration,
        title: String = "Plan",
        subtitle: String = "Manage Pro access, purchases, and subscription status.",
        systemImage: String = "creditcard",
        onUpgrade: @escaping () -> Void
    ) -> MacAppSettingsPane {
        MacAppSettingsPane(
            id: .plan,
            title: title,
            subtitle: subtitle,
            systemImage: systemImage
        ) {
            MacAppPlanSettingsPane(
                purchaseManager: purchaseManager,
                configuration: configuration,
                onUpgrade: onUpgrade
            )
        }
    }
}

/// Builders for MAF's built-in Settings destinations.
@MainActor
public enum MacAppSettingsBuiltIns {
    /// Returns the standard flat built-in pane list in display order.
    public static func panes(
        themeStore: MacAppThemeStore,
        purchaseManager: PurchaseManager,
        planConfiguration: ProPlanPaneConfiguration,
        enabledPanes: Set<MacAppSettingsBuiltInPane> = MacAppSettingsBuiltInPane.defaults,
        onUpgrade: @escaping () -> Void
    ) -> [MacAppSettingsPane] {
        var panes: [MacAppSettingsPane] = []

        if enabledPanes.contains(.appearance) {
            panes.append(.appearance(themeStore: themeStore))
        }

        if enabledPanes.contains(.plan) {
            panes.append(
                .plan(
                    purchaseManager: purchaseManager,
                    configuration: planConfiguration,
                    onUpgrade: onUpgrade
                )
            )
        }

        return panes
    }

    /// Advanced grouped helper for apps that benefit from labeled sections.
    public static func appearanceSection(
        themeStore: MacAppThemeStore
    ) -> MacAppSettingsSection {
        MacAppSettingsSection(
            id: .application,
            title: "Application",
            panes: [
                .appearance(themeStore: themeStore)
            ]
        )
    }

    /// Advanced grouped helper for apps that benefit from labeled sections.
    public static func planSection(
        purchaseManager: PurchaseManager,
        planConfiguration: ProPlanPaneConfiguration,
        onUpgrade: @escaping () -> Void
    ) -> MacAppSettingsSection {
        MacAppSettingsSection(
            id: .account,
            title: "Account",
            panes: [
                .plan(
                    purchaseManager: purchaseManager,
                    configuration: planConfiguration,
                    onUpgrade: onUpgrade
                )
            ]
        )
    }

    /// Advanced grouped built-in layout retained for larger Settings surfaces.
    public static func sections(
        themeStore: MacAppThemeStore,
        purchaseManager: PurchaseManager,
        planConfiguration: ProPlanPaneConfiguration,
        enabledPanes: Set<MacAppSettingsBuiltInPane> = MacAppSettingsBuiltInPane.defaults,
        onUpgrade: @escaping () -> Void
    ) -> [MacAppSettingsSection] {
        var sections: [MacAppSettingsSection] = []

        if enabledPanes.contains(.appearance) {
            sections.append(appearanceSection(themeStore: themeStore))
        }

        if enabledPanes.contains(.plan) {
            sections.append(
                planSection(
                    purchaseManager: purchaseManager,
                    planConfiguration: planConfiguration,
                    onUpgrade: onUpgrade
                )
            )
        }

        return sections
    }
}

public extension MacAppSettingsView {
    /// Convenience initializer for apps that only need MAF's Appearance pane.
    @MainActor
    init(
        title: String = "Settings",
        systemImage: String = "gearshape.fill",
        themeStore: MacAppThemeStore,
        additionalPanes: [MacAppSettingsPane] = [],
        initialSelection: MacAppSettingsPaneID? = nil,
        router: MacAppSettingsRouter? = nil
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            panes: [
                .appearance(themeStore: themeStore)
            ] + additionalPanes,
            initialSelection: initialSelection,
            router: router
        )
    }

    /// Convenience initializer for the standard MAF Settings experience.
    ///
    /// Appearance and Plan are included as a flat pane list by default. Apps can
    /// disable either pane with `builtInPanes`, append app-owned panes, or use the
    /// lower-level `sections:` initializer when labeled grouping is actually useful.
    @MainActor
    init(
        title: String = "Settings",
        systemImage: String = "gearshape.fill",
        themeStore: MacAppThemeStore,
        purchaseManager: PurchaseManager,
        planConfiguration: ProPlanPaneConfiguration,
        builtInPanes: Set<MacAppSettingsBuiltInPane> = MacAppSettingsBuiltInPane.defaults,
        additionalPanes: [MacAppSettingsPane] = [],
        initialSelection: MacAppSettingsPaneID? = nil,
        router: MacAppSettingsRouter? = nil,
        onUpgrade: @escaping () -> Void
    ) {
        let panes = MacAppSettingsBuiltIns.panes(
            themeStore: themeStore,
            purchaseManager: purchaseManager,
            planConfiguration: planConfiguration,
            enabledPanes: builtInPanes,
            onUpgrade: onUpgrade
        ) + additionalPanes

        self.init(
            title: title,
            systemImage: systemImage,
            panes: panes,
            initialSelection: initialSelection,
            router: router
        )
    }
}
