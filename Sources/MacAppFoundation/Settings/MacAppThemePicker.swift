import SwiftUI

/// Reusable theme picker used by MacAppFoundation's Theme settings pane.
///
/// The picker renders the themes supplied by the host app in their configured
/// order and reports permanent selection, temporary preview, and locked actions.
@MainActor
public struct MacAppThemePicker: View {
    private let themes: [MacAppTheme]
    private let selectedThemeID: MacAppThemeID
    private let previewingThemeID: MacAppThemeID?
    private let previewProgress: Double
    private let previewableThemeIDs: Set<MacAppThemeID>
    private let lockedThemeIDs: Set<MacAppThemeID>
    private let compact: Bool
    private let onSelect: (MacAppThemeID) -> Void
    private let onPreviewSelect: (MacAppThemeID) -> Void
    private let onLockedSelect: (MacAppThemeID) -> Void

    @Environment(\.macAppTheme) private var activeTheme

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(
                    minimum: compact ? 138 : 170,
                    maximum: compact ? 168 : 210
                ),
                spacing: compact ? 8 : 12
            )
        ]
    }

    public init(
        themes: [MacAppTheme],
        selectedThemeID: MacAppThemeID,
        previewingThemeID: MacAppThemeID? = nil,
        previewProgress: Double = 0,
        previewableThemeIDs: Set<MacAppThemeID> = [],
        lockedThemeIDs: Set<MacAppThemeID> = [],
        compact: Bool = false,
        onSelect: @escaping (MacAppThemeID) -> Void,
        onPreviewSelect: @escaping (MacAppThemeID) -> Void = { _ in },
        onLockedSelect: @escaping (MacAppThemeID) -> Void = { _ in }
    ) {
        self.themes = themes
        self.selectedThemeID = selectedThemeID
        self.previewingThemeID = previewingThemeID
        self.previewProgress = min(1, max(0, previewProgress))
        self.previewableThemeIDs = previewableThemeIDs
        self.lockedThemeIDs = lockedThemeIDs
        self.compact = compact
        self.onSelect = onSelect
        self.onPreviewSelect = onPreviewSelect
        self.onLockedSelect = onLockedSelect
    }

    public var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: compact ? 8 : 12) {
            ForEach(themes) { theme in
                let isPreviewing = previewingThemeID == theme.id
                let isPreviewAvailable = previewableThemeIDs.contains(theme.id)
                let isLocked = lockedThemeIDs.contains(theme.id)

                MacAppThemePreviewCard(
                    theme: theme,
                    compact: compact,
                    isSelected: selectedThemeID == theme.id,
                    isPreviewing: isPreviewing,
                    previewProgress: isPreviewing ? previewProgress : 0,
                    isPreviewAvailable: isPreviewAvailable,
                    isLocked: isLocked
                ) {
                    if isPreviewAvailable {
                        onPreviewSelect(theme.id)
                    } else if isLocked {
                        onLockedSelect(theme.id)
                    } else {
                        onSelect(theme.id)
                    }
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
    public let compact: Bool
    public let isSelected: Bool
    public let isPreviewing: Bool
    public let previewProgress: Double
    public let isPreviewAvailable: Bool
    public let isLocked: Bool
    private let action: () -> Void

    @Environment(\.macAppTheme) private var activeTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    public init(
        theme: MacAppTheme,
        compact: Bool = false,
        isSelected: Bool,
        isPreviewing: Bool = false,
        previewProgress: Double = 0,
        isPreviewAvailable: Bool = false,
        isLocked: Bool = false,
        action: @escaping () -> Void
    ) {
        self.theme = theme
        self.compact = compact
        self.isSelected = isSelected
        self.isPreviewing = isPreviewing
        self.previewProgress = min(1, max(0, previewProgress))
        self.isPreviewAvailable = isPreviewAvailable
        self.isLocked = isLocked
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: compact ? 7 : 10) {
                preview

                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(theme.name)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(activeTheme.textPrimary)
                            .lineLimit(1)

                        Text(schemeLabel)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(activeTheme.textMuted)
                    }

                    Spacer(minLength: 4)

                    stateMark
                }
                .frame(minHeight: 30)
            }
            .padding(compact ? 8 : 10)
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
        .accessibilityHint(accessibilityHint)
        .accessibilityValue(accessibilityValue)
    }

    @ViewBuilder
    private var stateMark: some View {
        if isPreviewing || isPreviewAvailable || isLocked {
            proStateMark
        } else if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(activeTheme.accent)
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
        }
    }

    private var proStateMark: some View {
        ZStack {
            if isPreviewing {
                Circle()
                    .stroke(theme.accent.opacity(0.18), lineWidth: 2)

                Circle()
                    .trim(from: 0, to: CGFloat(previewProgress))
                    .stroke(
                        theme.accent,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(
                        reduceMotion ? nil : .linear(duration: 0.9),
                        value: previewProgress
                    )
            }

            Image(systemName: isPreviewing ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(theme.accent)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: 22, height: 22)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.18),
            value: isPreviewing
        )
        .accessibilityHidden(true)
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
            .padding(compact ? 7 : 10)
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
            .padding(compact ? 7 : 10)
            .background(theme.surface)
        }
        .frame(height: compact ? 82 : 104)
        .background(theme.canvas)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.separator, lineWidth: 1)
        }
        .allowsHitTesting(false)
    }

    private var schemeLabel: String {
        switch theme.preferredColorScheme {
        case .dark: "Dark"
        case .light: "Light"
        case nil: "System"
        @unknown default: "System"
        }
    }

    private var accessibilityHint: String {
        if isPreviewing { return "Continues previewing this Pro theme" }
        if isPreviewAvailable { return "Temporarily previews this Pro theme" }
        if isLocked { return "Requires Pro" }
        return "Selects this app theme"
    }

    private var accessibilityValue: String {
        var values = [schemeLabel]
        if isPreviewing {
            values.insert("Previewing", at: 0)
            values.append("Pro")
        } else if isPreviewAvailable {
            values.append("Pro, Preview available")
        } else if isLocked {
            values.append("Pro, Locked")
        } else if isSelected {
            values.insert("Selected", at: 0)
        }
        return values.joined(separator: ", ")
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
