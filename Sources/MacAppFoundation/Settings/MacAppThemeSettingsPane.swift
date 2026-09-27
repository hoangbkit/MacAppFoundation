import SwiftUI

/// Built-in Theme pane backed directly by the app's shared MacAppThemeStore.
///
/// Free users may temporarily preview configured Pro themes before upgrading.
/// The preview countdown and expiry are owned by the shared theme store, so every
/// themed scene follows the same effective theme.
@MainActor
public struct MacAppThemeSettingsPane: View {
    public enum Variant: Sendable, Equatable {
        case standard
        case compact
    }

    @Bindable private var themeStore: MacAppThemeStore
    private let purchaseManager: PurchaseManager?
    private let variant: Variant
    private let onUpgrade: (() -> Void)?

    @Environment(\.macAppTheme) private var theme

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
        let hasPro = purchaseManager?.hasPro ?? false
        let proThemeIDs = themeStore.configuration.proThemeIDs
        let previewableThemeIDs = hasPro
            ? Set<MacAppThemeID>()
            : Set(proThemeIDs.filter { themeStore.canPreview($0, hasPro: false) })
        let lockedThemeIDs = hasPro
            ? Set<MacAppThemeID>()
            : proThemeIDs.subtracting(previewableThemeIDs)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MacAppThemePicker(
                    themes: themeStore.configuration.themes,
                    selectedThemeID: themeStore.effectiveThemeID(hasPro: hasPro),
                    previewingThemeID: themeStore.isPreviewActive
                        ? themeStore.previewThemeID
                        : nil,
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

                if themeStore.isPreviewActive {
                    previewStatus(hasPro: hasPro)
                }
            }
            .padding(22)
            .frame(maxWidth: 780, alignment: .leading)
        }
        .background(theme.canvas)
    }

    private func previewStatus(hasPro: Bool) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
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
            .background(theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Previewing \(themeStore.previewTheme?.name ?? "Pro theme"). Returns to \(themeStore.themeAfterPreview(hasPro: hasPro).name) in \(countdown)."
            )
        }
    }

    private var countdown: String {
        let seconds = themeStore.previewRemainingSeconds
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
