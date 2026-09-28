import Foundation
import Observation
import SwiftUI

/// Observable theme selection and temporary preview state shared by a host app.
///
/// Apps normally create one store and inject it once at each scene root with
/// `.macAppTheme(store, purchaseManager:)` when Pro themes are configured.
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

    public private(set) var previewThemeID: MacAppThemeID?
    public private(set) var previewExpiresAt: Date?

    private let defaults: UserDefaults
    private let now: @MainActor () -> Date
    private var isNormalizingSelection = false
    @ObservationIgnored private var previewExpiryTask: Task<Void, Never>?

    public convenience init(
        configuration: MacAppThemeConfiguration = .init(),
        defaults: UserDefaults = .standard
    ) {
        self.init(
            configuration: configuration,
            defaults: defaults,
            now: { .now }
        )
    }

    /// Internal clock injection used by deterministic package tests.
    init(
        configuration: MacAppThemeConfiguration,
        defaults: UserDefaults,
        now: @escaping @MainActor () -> Date
    ) {
        self.configuration = configuration
        self.defaults = defaults
        self.now = now

        if let storedID = defaults.string(forKey: configuration.storageKey),
           configuration.theme(for: MacAppThemeID(storedID)) != nil {
            selectedThemeID = MacAppThemeID(storedID)
        } else {
            selectedThemeID = configuration.defaultThemeID
        }

        previewThemeID = nil
        previewExpiresAt = nil
        restorePreviewState()
        schedulePreviewExpirationIfNeeded()
    }

    deinit {
        previewExpiryTask?.cancel()
    }

    /// Raw persisted theme selection, without entitlement or preview resolution.
    public var currentTheme: MacAppTheme {
        configuration.theme(for: selectedThemeID) ?? configuration.defaultTheme
    }

    public var previewTheme: MacAppTheme? {
        guard let id = activePreviewThemeID else { return nil }
        return configuration.theme(for: id)
    }

    public var isPreviewActive: Bool {
        activePreviewThemeID != nil
    }

    public var previewRemainingSeconds: Int {
        guard let previewExpiresAt, isPreviewActive else { return 0 }
        return max(0, Int(ceil(previewExpiresAt.timeIntervalSince(now()))))
    }

    public func effectiveThemeID(hasPro: Bool) -> MacAppThemeID {
        if let previewThemeID = activePreviewThemeID,
           !hasPro || configuration.previewBehavior.promotesPreviewOnProUnlock {
            return previewThemeID
        }
        return themeAfterPreviewID(hasPro: hasPro)
    }

    public func currentTheme(hasPro: Bool) -> MacAppTheme {
        configuration.theme(for: effectiveThemeID(hasPro: hasPro))
            ?? configuration.defaultTheme
    }

    /// Resolves the visual theme while StoreKit entitlement state is still settling.
    ///
    /// During `.checking`, keep the persisted selection (or an active preview) visible
    /// instead of temporarily treating the user as Free. Once entitlement resolution
    /// completes, normal Free/Pro gating applies.
    func currentTheme(
        entitlementState: EntitlementState,
        hasPro: Bool
    ) -> MacAppTheme {
        if case .checking = entitlementState {
            return previewTheme ?? currentTheme
        }
        return currentTheme(hasPro: hasPro)
    }

    /// Theme that becomes effective when a temporary preview ends.
    public func themeAfterPreview(hasPro: Bool) -> MacAppTheme {
        configuration.theme(for: themeAfterPreviewID(hasPro: hasPro))
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

    public func canPreview(_ id: MacAppThemeID, hasPro: Bool) -> Bool {
        guard !hasPro,
              configuration.previewBehavior.isEnabled,
              configuration.previewBehavior.defaultDuration > 0,
              configuration.isProTheme(id),
              configuration.theme(for: id) != nil
        else {
            return false
        }
        return true
    }

    /// Selects a theme assuming Free access. Existing callers remain source-compatible;
    /// configured Pro themes require the entitlement-aware overload.
    @discardableResult
    public func select(_ id: MacAppThemeID) -> Bool {
        select(id, hasPro: false)
    }

    /// Permanently selects a theme only when the entitlement satisfies its requirement.
    @discardableResult
    public func select(_ id: MacAppThemeID, hasPro: Bool) -> Bool {
        guard canSelect(id, hasPro: hasPro) else { return false }
        clearPreviewState()
        selectedThemeID = id
        return true
    }

    /// Chooses a theme using the configured Free/Pro and preview behavior.
    ///
    /// Free themes select permanently. Pro users select Pro themes permanently.
    /// Free users start a temporary preview when previewing is enabled.
    @discardableResult
    public func choose(_ id: MacAppThemeID, hasPro: Bool) -> MacAppThemeSelectionResult {
        guard configuration.theme(for: id) != nil else {
            return .unavailable(id)
        }

        if canSelect(id, hasPro: hasPro) {
            _ = select(id, hasPro: hasPro)
            return .selected(id)
        }

        guard canPreview(id, hasPro: hasPro) else {
            return .requiresPro(id)
        }

        let expiresAt: Date
        if configuration.previewBehavior.preservesExpiryWhenSwitchingThemes,
           isPreviewActive,
           let existingExpiry = previewExpiresAt {
            expiresAt = existingExpiry
        } else {
            expiresAt = now().addingTimeInterval(
                configuration.previewBehavior.defaultDuration
            )
        }

        previewThemeID = id
        previewExpiresAt = expiresAt
        persistPreviewState()
        schedulePreviewExpirationIfNeeded()
        return .previewStarted(id, expiresAt: expiresAt)
    }

    public func endPreview() {
        guard previewThemeID != nil || previewExpiresAt != nil else { return }
        clearPreviewState()
    }

    /// Reconciles an entitlement change with an active preview.
    ///
    /// By default, unlocking Pro while previewing promotes that theme to the
    /// permanent selection, matching AppFoundation's preview behavior.
    public func synchronizeProAccess(_ hasPro: Bool) {
        guard hasPro else { return }

        guard let previewID = activePreviewThemeID else {
            if previewThemeID != nil || previewExpiresAt != nil {
                clearPreviewState()
            }
            return
        }

        if configuration.previewBehavior.promotesPreviewOnProUnlock {
            selectedThemeID = previewID
        }
        clearPreviewState()
    }

    /// Clears an expired preview immediately and refreshes its expiration task.
    public func refreshPreviewState() {
        guard previewThemeID != nil || previewExpiresAt != nil else { return }

        guard isPreviewActive else {
            clearPreviewState()
            return
        }

        schedulePreviewExpirationIfNeeded()
    }

    public func reset() {
        clearPreviewState()
        selectedThemeID = configuration.defaultThemeID
    }

    private var activePreviewThemeID: MacAppThemeID? {
        guard configuration.previewBehavior.isEnabled,
              let previewThemeID,
              let previewExpiresAt,
              previewExpiresAt > now(),
              configuration.isProTheme(previewThemeID),
              configuration.theme(for: previewThemeID) != nil
        else {
            return nil
        }
        return previewThemeID
    }

    private func themeAfterPreviewID(hasPro: Bool) -> MacAppThemeID {
        canSelect(selectedThemeID, hasPro: hasPro)
            ? selectedThemeID
            : configuration.defaultThemeID
    }

    private var previewThemeIDStorageKey: String {
        "\(configuration.storageKey).previewThemeID"
    }

    private var previewExpiresAtStorageKey: String {
        "\(configuration.storageKey).previewExpiresAt"
    }

    private func restorePreviewState() {
        guard configuration.previewBehavior.isEnabled,
              let rawID = defaults.string(forKey: previewThemeIDStorageKey),
              let expiresAt = defaults.object(forKey: previewExpiresAtStorageKey) as? Date
        else {
            clearPersistedPreviewState()
            return
        }

        let id = MacAppThemeID(rawID)
        guard configuration.isProTheme(id),
              configuration.theme(for: id) != nil,
              expiresAt > now()
        else {
            clearPersistedPreviewState()
            return
        }

        previewThemeID = id
        previewExpiresAt = expiresAt
    }

    private func persistPreviewState() {
        guard let previewThemeID, let previewExpiresAt else {
            clearPersistedPreviewState()
            return
        }

        defaults.set(previewThemeID.rawValue, forKey: previewThemeIDStorageKey)
        defaults.set(previewExpiresAt, forKey: previewExpiresAtStorageKey)
    }

    private func clearPreviewState() {
        previewExpiryTask?.cancel()
        previewExpiryTask = nil
        previewThemeID = nil
        previewExpiresAt = nil
        clearPersistedPreviewState()
    }

    private func clearPersistedPreviewState() {
        defaults.removeObject(forKey: previewThemeIDStorageKey)
        defaults.removeObject(forKey: previewExpiresAtStorageKey)
    }

    private func schedulePreviewExpirationIfNeeded() {
        previewExpiryTask?.cancel()
        previewExpiryTask = nil

        guard configuration.previewBehavior.schedulesAutomaticExpiration,
              let previewExpiresAt,
              activePreviewThemeID != nil
        else {
            return
        }

        let delay = max(0, previewExpiresAt.timeIntervalSince(now()))
        previewExpiryTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            self?.refreshPreviewState()
        }
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
        let theme = store.currentTheme(hasPro: false)

        content
            .environment(\.macAppTheme, theme)
            .tint(theme.accent)
            .preferredColorScheme(theme.preferredColorScheme)
            .task {
                store.refreshPreviewState()
            }
    }
}

private struct MacAppEntitledThemeModifier: ViewModifier {
    @Bindable var store: MacAppThemeStore
    let purchaseManager: PurchaseManager

    func body(content: Content) -> some View {
        let hasPro = purchaseManager.hasPro
        let theme = store.currentTheme(
            entitlementState: purchaseManager.entitlementState,
            hasPro: hasPro
        )

        content
            .environment(\.macAppTheme, theme)
            .tint(theme.accent)
            .preferredColorScheme(theme.preferredColorScheme)
            .task {
                store.synchronizeProAccess(hasPro)
                store.refreshPreviewState()
            }
            .onChange(of: purchaseManager.hasPro) { _, newHasPro in
                store.synchronizeProAccess(newHasPro)
            }
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

    /// Injects a shared theme store with Free/Pro gating and timed preview support.
    ///
    /// A Free user may temporarily preview a Pro theme without changing the saved
    /// selection. When preview expires, the app returns to the entitled selection
    /// or the configured Free default.
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
    /// Useful for isolated previews and embedded themed surfaces.
    func macAppTheme(_ theme: MacAppTheme) -> some View {
        environment(\.macAppTheme, theme)
            .tint(theme.accent)
            .preferredColorScheme(theme.preferredColorScheme)
    }
}
