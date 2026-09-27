import Foundation
import Observation
import SwiftUI

/// Observable theme selection state shared by a host app.
///
/// Apps normally create one store and inject it once at the root with
/// .macAppTheme(store) so every MacAppFoundation view reads the same active
/// theme through the SwiftUI environment.
@MainActor
@Observable
public final class MacAppThemeStore {
    public let configuration: MacAppThemeConfiguration

    public var selectedThemeID: MacAppThemeID {
        didSet {
            guard selectedThemeID != oldValue else { return }
            normalizeSelectionAndPersist()
        }
    }

    private let defaults: UserDefaults
    private var isNormalizingSelection = false

    public init(
        configuration: MacAppThemeConfiguration = .init(),
        defaults: UserDefaults = .standard
    ) {
        self.configuration = configuration
        self.defaults = defaults

        if let storedID = defaults.string(forKey: configuration.storageKey),
           configuration.theme(for: MacAppThemeID(storedID)) != nil {
            selectedThemeID = MacAppThemeID(storedID)
        } else {
            selectedThemeID = configuration.defaultThemeID
        }
    }

    public var currentTheme: MacAppTheme {
        configuration.theme(for: selectedThemeID) ?? configuration.defaultTheme
    }

    public func effectiveThemeID(hasPro: Bool) -> MacAppThemeID {
        canSelect(selectedThemeID, hasPro: hasPro)
            ? selectedThemeID
            : configuration.defaultThemeID
    }

    public func currentTheme(hasPro: Bool) -> MacAppTheme {
        configuration.theme(for: effectiveThemeID(hasPro: hasPro))
            ?? configuration.defaultTheme
    }

    public func canSelect(_ id: MacAppThemeID, hasPro: Bool) -> Bool {
        guard configuration.theme(for: id) != nil else { return false }

        switch configuration.accessRequirement(for: id) {
        case .free:
            return true
        case .pro:
            return hasPro
        }
    }

    /// Selects a theme assuming Free access. Existing callers remain source-compatible;
    /// configured Pro themes require the entitlement-aware overload.
    @discardableResult
    public func select(_ id: MacAppThemeID) -> Bool {
        select(id, hasPro: false)
    }

    /// Selects a theme only when the current entitlement satisfies its requirement.
    @discardableResult
    public func select(_ id: MacAppThemeID, hasPro: Bool) -> Bool {
        guard canSelect(id, hasPro: hasPro) else { return false }
        selectedThemeID = id
        return true
    }

    public func reset() {
        selectedThemeID = configuration.defaultThemeID
    }

    private func normalizeSelectionAndPersist() {
        guard !isNormalizingSelection else { return }

        guard configuration.theme(for: selectedThemeID) != nil else {
            isNormalizingSelection = true
            selectedThemeID = configuration.defaultThemeID
            isNormalizingSelection = false
            defaults.set(configuration.defaultThemeID.rawValue, forKey: configuration.storageKey)
            return
        }

        defaults.set(selectedThemeID.rawValue, forKey: configuration.storageKey)
    }
}

private struct MacAppThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: MacAppTheme = .system
}

public extension EnvironmentValues {
    /// The active MacAppFoundation theme inherited by framework and host-app views.
    var macAppTheme: MacAppTheme {
        get { self[MacAppThemeEnvironmentKey.self] }
        set { self[MacAppThemeEnvironmentKey.self] = newValue }
    }
}

private struct MacAppThemeModifier: ViewModifier {
    @Bindable var store: MacAppThemeStore

    func body(content: Content) -> some View {
        let theme = store.currentTheme

        content
            .environment(\.macAppTheme, theme)
            .tint(theme.accent)
            .preferredColorScheme(theme.preferredColorScheme)
    }
}

private struct MacAppEntitledThemeModifier: ViewModifier {
    @Bindable var store: MacAppThemeStore
    let purchaseManager: PurchaseManager

    func body(content: Content) -> some View {
        let theme = store.currentTheme(hasPro: purchaseManager.hasPro)

        content
            .environment(\.macAppTheme, theme)
            .tint(theme.accent)
            .preferredColorScheme(theme.preferredColorScheme)
    }
}

public extension View {
    /// Injects a shared theme store for this view hierarchy.
    ///
    /// The modifier applies the active accent tint and preferred light/dark color scheme.
    /// Use the purchase-manager overload when the configuration contains Pro themes.
    func macAppTheme(_ store: MacAppThemeStore) -> some View {
        modifier(MacAppThemeModifier(store: store))
    }

    /// Injects a shared theme store with Free/Pro theme enforcement.
    ///
    /// When a saved selection requires Pro and access is inactive, the configured
    /// Free default theme is applied without destroying the saved preference.
    func macAppTheme(
        _ store: MacAppThemeStore,
        purchaseManager: PurchaseManager
    ) -> some View {
        modifier(
            MacAppEntitledThemeModifier(
                store: store,
                purchaseManager: purchaseManager
            )
        )
    }

    /// Injects a fixed theme without persistence or selection state.
    /// Useful for previews and isolated themed surfaces.
    func macAppTheme(_ theme: MacAppTheme) -> some View {
        environment(\.macAppTheme, theme)
            .tint(theme.accent)
            .preferredColorScheme(theme.preferredColorScheme)
    }
}
