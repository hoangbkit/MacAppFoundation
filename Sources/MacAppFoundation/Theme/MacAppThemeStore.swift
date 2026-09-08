import Foundation
import Observation
import SwiftUI

/// Observable theme selection state shared by a host app.
///
/// Apps normally create one store and inject it once at the root with
/// `.macAppTheme(store)` so every MacAppFoundation view reads the same active
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

    public func select(_ id: MacAppThemeID) {
        guard configuration.theme(for: id) != nil else { return }
        selectedThemeID = id
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

public extension View {
    /// Injects a shared theme store for this view hierarchy.
    ///
    /// The modifier also applies the active accent tint and preferred light/dark
    /// color scheme. MacAppFoundation visual components read `macAppTheme` from
    /// the environment rather than requiring theme parameters.
    func macAppTheme(_ store: MacAppThemeStore) -> some View {
        modifier(MacAppThemeModifier(store: store))
    }

    /// Injects a fixed theme without persistence or selection state.
    /// Useful for previews and isolated themed surfaces.
    func macAppTheme(_ theme: MacAppTheme) -> some View {
        environment(\.macAppTheme, theme)
            .tint(theme.accent)
            .preferredColorScheme(theme.preferredColorScheme)
    }
}
