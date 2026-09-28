import SwiftUI

/// Reusable theme picker that can be embedded anywhere in an app.
///
/// `ThemePickerView` owns theme-selection behavior, scrolling, Pro locking, and
/// temporary Pro-theme previews, but deliberately owns no container styling. The
/// host app decides the surrounding background, padding, section/card treatment,
/// and whether the picker fills a whole Settings destination or only part of one.
@MainActor
public struct ThemePickerView: View {
    public enum Variant: Sendable, Equatable {
        case standard
        case compact
    }

    @Bindable private var themeStore: MacAppThemeStore
    private let purchaseManager: PurchaseManager?
    private let variant: Variant
    private let onUpgrade: (() -> Void)?

    @Environment(\.macAppTheme) private var theme

    /// Creates a reusable theme picker.
    ///
    /// Free-only configurations need no commerce dependencies. When Pro themes
    /// are configured, both `purchaseManager` and `onUpgrade` must be supplied
    /// so the picker can distinguish previewable/locked themes and route upgrades.
    public init(
        themeStore: MacAppThemeStore,
        purchaseManager: PurchaseManager? = nil,
        variant: Variant = .standard,
        onUpgrade: (() -> Void)? = nil
    ) {
        self.themeStore = themeStore
        self.purchaseManager = purchaseManager
        self.variant = variant
        self.onUpgrade = onUpgrade
    }

    public var body: some View {
        Group {
            if let configurationErrorMessage {
                configurationErrorView(configurationErrorMessage)
            } else {
                picker
            }
        }
    }

    private var picker: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let hasPro = purchaseManager?.hasPro ?? false
            let selectedThemeID = purchaseManager.map {
                themeStore.effectiveThemeID(
                    entitlementState: $0.entitlementState,
                    hasPro: $0.hasPro
                )
            } ?? themeStore.effectiveThemeID(hasPro: false)
            let proThemeIDs = themeStore.configuration.proThemeIDs
            let previewableThemeIDs = hasPro
                ? Set<MacAppThemeID>()
                : Set(proThemeIDs.filter { themeStore.canPreview($0, hasPro: false) })
            let lockedThemeIDs = hasPro
                ? Set<MacAppThemeID>()
                : proThemeIDs.subtracting(previewableThemeIDs)

            ScrollView {
                MacAppThemePicker(
                    themes: themeStore.configuration.themes,
                    selectedThemeID: selectedThemeID,
                    previewingThemeID: themeStore.isPreviewActive
                        ? themeStore.previewThemeID
                        : nil,
                    previewProgress: previewProgress,
                    previewableThemeIDs: previewableThemeIDs,
                    lockedThemeIDs: lockedThemeIDs,
                    compact: variant == .compact,
                    onSelect: { themeID in
                        themeStore.select(themeID, hasPro: hasPro)
                    },
                    onPreviewSelect: { themeID in
                        let result = themeStore.choose(themeID, hasPro: hasPro)
                        if case .requiresPro = result {
                            onUpgrade?()
                        }
                    },
                    onLockedSelect: { _ in
                        onUpgrade?()
                    }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .safeAreaInset(edge: .bottom, spacing: 12) {
                if themeStore.isPreviewActive {
                    previewStatus(hasPro: hasPro)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    var previewProgress: Double {
        guard themeStore.isPreviewActive else { return 0 }
        let duration = themeStore.configuration.previewBehavior.defaultDuration
        guard duration > 0 else { return 0 }

        return min(
            1,
            max(0, Double(themeStore.previewRemainingSeconds) / duration)
        )
    }

    var configurationErrorMessage: String? {
        let configuration = themeStore.configuration
        guard configuration.hasRequiredFreeAppearanceThemes else {
            return "Theme configuration requires at least one Free Light theme and one Free Dark theme. System uses those themes to follow macOS appearance."
        }

        guard !configuration.proThemeIDs.isEmpty else { return nil }
        guard purchaseManager != nil, onUpgrade != nil else {
            return "This theme picker includes Pro themes but is missing PurchaseManager or onUpgrade. Pass both dependencies to enable Pro theme access and upgrades."
        }
        return nil
    }

    private func previewStatus(hasPro: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.headline)
                .foregroundStyle(theme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Previewing \(themeStore.previewTheme?.name ?? "Pro theme")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)

                Text(
                    "Returns to \(themeStore.themeAfterPreview(hasPro: hasPro).name) in \(countdown)"
                )
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            }

            Spacer(minLength: 8)

            if let onUpgrade {
                Button("Unlock Pro", action: onUpgrade)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }

            Button("End") {
                themeStore.endPreview()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(
            theme.surfaceRaised,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        }
        .shadow(color: theme.shadow, radius: 8, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Previewing \(themeStore.previewTheme?.name ?? "Pro theme"). Returns to \(themeStore.themeAfterPreview(hasPro: hasPro).name) in \(countdown)."
        )
    }

    private var countdown: String {
        let seconds = themeStore.previewRemainingSeconds
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func configurationErrorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.warning)

            VStack(alignment: .leading, spacing: 4) {
                Text("Theme configuration error")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
