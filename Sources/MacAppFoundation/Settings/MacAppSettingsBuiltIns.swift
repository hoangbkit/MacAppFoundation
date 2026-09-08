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

/// Builders for MAF's conventional default Settings grouping.
@MainActor
public enum MacAppSettingsBuiltIns {
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
        additionalSections: [MacAppSettingsSection] = [],
        initialSelection: MacAppSettingsPaneID? = nil,
        router: MacAppSettingsRouter? = nil
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            sections: [
                MacAppSettingsBuiltIns.appearanceSection(themeStore: themeStore)
            ] + additionalSections,
            initialSelection: initialSelection,
            router: router
        )
    }

    /// Convenience initializer for the standard MAF Settings experience.
    ///
    /// Appearance and Plan are included by default. Apps can disable either pane
    /// with `builtInPanes`, append additional sections, or use the lower-level
    /// `sections:` initializer when exact interleaving/reordering is required.
    @MainActor
    init(
        title: String = "Settings",
        systemImage: String = "gearshape.fill",
        themeStore: MacAppThemeStore,
        purchaseManager: PurchaseManager,
        planConfiguration: ProPlanPaneConfiguration,
        builtInPanes: Set<MacAppSettingsBuiltInPane> = MacAppSettingsBuiltInPane.defaults,
        additionalSections: [MacAppSettingsSection] = [],
        initialSelection: MacAppSettingsPaneID? = nil,
        router: MacAppSettingsRouter? = nil,
        onUpgrade: @escaping () -> Void
    ) {
        let sections = MacAppSettingsBuiltIns.sections(
            themeStore: themeStore,
            purchaseManager: purchaseManager,
            planConfiguration: planConfiguration,
            enabledPanes: builtInPanes,
            onUpgrade: onUpgrade
        ) + additionalSections

        self.init(
            title: title,
            systemImage: systemImage,
            sections: sections,
            initialSelection: initialSelection,
            router: router
        )
    }
}
