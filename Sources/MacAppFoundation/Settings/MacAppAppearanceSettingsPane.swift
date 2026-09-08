import SwiftUI

/// Built-in Appearance pane backed directly by the app's shared ``MacAppThemeStore``.
///
/// The pane shows exactly the themes supplied by ``MacAppThemeConfiguration`` in
/// app-defined order, including custom themes. Selecting a row delegates to the
/// store, so persistence and fallback behavior remain centralized in the theme
/// system rather than being duplicated by Settings.
@MainActor
public struct MacAppAppearanceSettingsPane: View {
    @Bindable private var themeStore: MacAppThemeStore

    @Environment(\.macAppTheme) private var theme

    public init(themeStore: MacAppThemeStore) {
        self.themeStore = themeStore
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(themeStore.configuration.themes) { candidate in
                    themeRow(candidate)
                }
            }
            .padding(22)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .background(theme.canvas)
    }

    private func themeRow(_ candidate: MacAppTheme) -> some View {
        let isSelected = themeStore.selectedThemeID == candidate.id

        return Button {
            themeStore.select(candidate.id)
        } label: {
            HStack(spacing: 14) {
                HStack(spacing: 5) {
                    themeSwatch(candidate.canvas, border: candidate.separator)
                    themeSwatch(candidate.surface, border: candidate.separator)
                    themeSwatch(candidate.accent, border: candidate.accent)
                }
                .frame(width: 58, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)

                    Text(candidate.caption)
                        .font(.system(size: 11.5))
                        .foregroundStyle(theme.textMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.accent)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(
                isSelected ? theme.selection : theme.surface,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isSelected ? theme.accent.opacity(0.55) : theme.separator.opacity(0.82),
                        lineWidth: 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(candidate.name)
        .accessibilityValue(isSelected ? "Selected" : candidate.caption)
    }

    private func themeSwatch(_ color: Color, border: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay {
                Circle().stroke(border.opacity(0.9), lineWidth: 1)
            }
    }
}
