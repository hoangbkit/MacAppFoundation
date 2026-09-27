import SwiftUI

/// Built-in Settings destinations provided by MacAppFoundation.
///
/// This enum describes only framework-owned panes. App-defined destinations keep
/// using open MacAppSettingsPaneID values and can be mixed freely with these.
public enum MacAppSettingsBuiltInPane: Hashable, Sendable {
    case theme
    case plan

    public static let defaults: Set<Self> = [.theme, .plan]
}

public extension MacAppSettingsPane {
    /// Creates MAF's built-in Theme pane for Free-only theme configurations.
    @MainActor
    static func theme(
        themeStore: MacAppThemeStore,
        title: String = "Theme",
        subtitle: String = "Choose the color theme used throughout the app.",
        systemImage: String = "paintpalette",
        variant: MacAppThemeSettingsPane.Variant = .standard
    ) -> MacAppSettingsPane {
        MacAppSettingsPane(
            id: .theme,
            title: title,
            subtitle: subtitle,
            systemImage: systemImage
        ) {
            MacAppThemeSettingsPane(
                themeStore: themeStore,
                variant: variant
            )
        }
    }

    /// Creates MAF's entitlement-aware Theme pane.
    ///
    /// Supplying PurchaseManager requires an explicit upgrade/paywall action.
    @MainActor
    static func theme(
        themeStore: MacAppThemeStore,
        purchaseManager: PurchaseManager,
        title: String = "Theme",
        subtitle: String = "Choose the color theme used throughout the app.",
        systemImage: String = "paintpalette",
        variant: MacAppThemeSettingsPane.Variant = .standard,
        onUpgrade: @escaping () -> Void
    ) -> MacAppSettingsPane {
        MacAppSettingsPane(
            id: .theme,
            title: title,
            subtitle: subtitle,
            systemImage: systemImage
        ) {
            MacAppThemeSettingsPane(
                themeStore: themeStore,
                purchaseManager: purchaseManager,
                variant: variant,
                onUpgrade: onUpgrade
            )
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
        themeVariant: MacAppThemeSettingsPane.Variant = .standard,
        enabledPanes: Set<MacAppSettingsBuiltInPane> = MacAppSettingsBuiltInPane.defaults,
        onUpgrade: @escaping () -> Void
    ) -> [MacAppSettingsPane] {
        var panes: [MacAppSettingsPane] = []

        if enabledPanes.contains(.theme) {
            panes.append(
                .theme(
                    themeStore: themeStore,
                    purchaseManager: purchaseManager,
                    variant: themeVariant,
                    onUpgrade: onUpgrade
                )
            )
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

    /// Advanced grouped helper for Free-only Theme configurations.
    public static func themeSection(
        themeStore: MacAppThemeStore,
        variant: MacAppThemeSettingsPane.Variant = .standard
    ) -> MacAppSettingsSection {
        MacAppSettingsSection(
            id: .application,
            title: "Application",
            panes: [
                .theme(
                    themeStore: themeStore,
                    variant: variant
                )
            ]
        )
    }

    /// Advanced grouped helper for entitlement-aware Theme configurations.
    public static func themeSection(
        themeStore: MacAppThemeStore,
        purchaseManager: PurchaseManager,
        variant: MacAppThemeSettingsPane.Variant = .standard,
        onUpgrade: @escaping () -> Void
    ) -> MacAppSettingsSection {
        MacAppSettingsSection(
            id: .application,
            title: "Application",
            panes: [
                .theme(
                    themeStore: themeStore,
                    purchaseManager: purchaseManager,
                    variant: variant,
                    onUpgrade: onUpgrade
                )
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
        themeVariant: MacAppThemeSettingsPane.Variant = .standard,
        enabledPanes: Set<MacAppSettingsBuiltInPane> = MacAppSettingsBuiltInPane.defaults,
        onUpgrade: @escaping () -> Void
    ) -> [MacAppSettingsSection] {
        var sections: [MacAppSettingsSection] = []

        if enabledPanes.contains(.theme) {
            sections.append(
                themeSection(
                    themeStore: themeStore,
                    purchaseManager: purchaseManager,
                    variant: themeVariant,
                    onUpgrade: onUpgrade
                )
            )
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
    /// Convenience initializer for apps that only need MAF's Theme pane.
    @MainActor
    init(
        title: String = "Settings",
        systemImage: String = "gearshape.fill",
        themeStore: MacAppThemeStore,
        themeVariant: MacAppThemeSettingsPane.Variant = .standard,
        additionalPanes: [MacAppSettingsPane] = [],
        initialSelection: MacAppSettingsPaneID? = nil,
        router: MacAppSettingsRouter? = nil
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            panes: [
                .theme(themeStore: themeStore, variant: themeVariant)
            ] + additionalPanes,
            initialSelection: initialSelection,
            router: router
        )
    }

    /// Convenience initializer for the standard MAF Settings experience.
    ///
    /// Theme and Plan are included as a flat pane list by default. Apps can
    /// disable either pane with builtInPanes, append app-owned panes, or use the
    /// lower-level sections initializer when labeled grouping is actually useful.
    @MainActor
    init(
        title: String = "Settings",
        systemImage: String = "gearshape.fill",
        themeStore: MacAppThemeStore,
        purchaseManager: PurchaseManager,
        planConfiguration: ProPlanPaneConfiguration,
        themeVariant: MacAppThemeSettingsPane.Variant = .standard,
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
            themeVariant: themeVariant,
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
