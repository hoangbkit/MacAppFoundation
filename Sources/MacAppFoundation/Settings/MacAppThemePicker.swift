import SwiftUI

/// Reusable theme picker used by MacAppFoundation's Appearance settings pane.
///
/// The picker renders the themes supplied by the host app in their configured
/// order and does not own persistence. Selection is reported through `onSelect`.
@MainActor
public struct MacAppThemePicker: View {
    private let themes: [MacAppTheme]
    private let selectedThemeID: MacAppThemeID
    private let onSelect: (MacAppThemeID) -> Void

    @Environment(\.macAppTheme) private var activeTheme

    private let columns = [
        GridItem(.adaptive(minimum: 170, maximum: 210), spacing: 12)
    ]

    public init(
        themes: [MacAppTheme],
        selectedThemeID: MacAppThemeID,
        onSelect: @escaping (MacAppThemeID) -> Void
    ) {
        self.themes = themes
        self.selectedThemeID = selectedThemeID
        self.onSelect = onSelect
    }

    public var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(themes) { theme in
                MacAppThemePreviewCard(
                    theme: theme,
                    isSelected: selectedThemeID == theme.id
                ) {
                    onSelect(theme.id)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Themes")
        .tint(activeTheme.accent)
    }
}

/// Reusable preview card for one MAF or app-defined theme.
@MainActor
public struct MacAppThemePreviewCard: View {
    public let theme: MacAppTheme
    public let isSelected: Bool
    private let action: () -> Void

    @Environment(\.macAppTheme) private var activeTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    public init(
        theme: MacAppTheme,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                preview

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(theme.name)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(activeTheme.textPrimary)
                            .lineLimit(1)

                        Text(appearanceLabel)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(activeTheme.textMuted)
                    }

                    Spacer(minLength: 4)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(activeTheme.accent)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(10)
            .background(cardBackground, in: cardShape)
            .overlay {
                cardShape.stroke(borderColor, lineWidth: isFocused ? 2 : 1)
            }
            .contentShape(cardShape)
            .scaleEffect(isHovering && !reduceMotion ? 1.01 : 1)
        }
        .buttonStyle(MacAppThemeCardButtonStyle())
        .focused($isFocused)
        .onHover { hovering in
            if reduceMotion {
                isHovering = hovering
            } else {
                withAnimation(.easeOut(duration: 0.12)) {
                    isHovering = hovering
                }
            }
        }
        .accessibilityLabel(theme.name)
        .accessibilityHint("Selects this app theme")
        .accessibilityValue(isSelected ? "Selected, \(appearanceLabel)" : appearanceLabel)
    }

    private var preview: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 7, height: 7)
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.textMuted.opacity(0.48))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.textMuted.opacity(0.26))
                    .frame(width: 34, height: 6)
            }
            .padding(10)
            .background(theme.canvasTop)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.textPrimary.opacity(0.82))
                    .frame(width: 78, height: 7)
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.textMuted.opacity(0.48))
                    .frame(width: 112, height: 6)

                HStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.selection)
                        .frame(width: 70, height: 24)
                        .overlay(alignment: .center) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(theme.accent)
                                .frame(width: 34, height: 5)
                        }
                }
            }
            .padding(10)
            .background(theme.surface)
        }
        .frame(height: 104)
        .background(theme.canvas)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.separator, lineWidth: 1)
        }
        .allowsHitTesting(false)
    }

    private var appearanceLabel: String {
        switch theme.preferredColorScheme {
        case .dark: "Dark"
        case .light: "Light"
        case nil: "System"
        @unknown default: "System"
        }
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }

    private var cardBackground: Color {
        if isSelected { return activeTheme.selection }
        if isHovering { return activeTheme.surfaceRaised }
        return activeTheme.surface
    }

    private var borderColor: Color {
        if isFocused { return activeTheme.accent }
        if isSelected { return activeTheme.accent.opacity(0.65) }
        if isHovering { return activeTheme.border }
        return activeTheme.separator.opacity(0.82)
    }
}

private struct MacAppThemeCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.08),
                value: configuration.isPressed
            )
    }
}
