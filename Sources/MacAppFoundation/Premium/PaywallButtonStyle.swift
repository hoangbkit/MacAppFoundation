import SwiftUI

/// A framework-owned button style for paywall actions.
///
/// Explicit sizing, shape, colors, and interaction states keep paywall controls
/// visually stable across supported macOS releases instead of inheriting changes
/// from the system bordered button styles.
public struct PaywallButtonStyle: ButtonStyle {
    public enum Kind: Sendable, Equatable {
        case primary
        case secondary
        case text
    }

    private let kind: Kind

    public init(_ kind: Kind = .secondary) {
        self.kind = kind
    }

    public func makeBody(configuration: Configuration) -> some View {
        PaywallButtonStyleBody(
            label: configuration.label,
            kind: kind,
            isPressed: configuration.isPressed
        )
    }
}

private struct PaywallButtonStyleBody<Label: View>: View {
    let label: Label
    let kind: PaywallButtonStyle.Kind
    let isPressed: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.macAppTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)

        label
            .font(font)
            .lineLimit(1)
            .foregroundStyle(foregroundColor)
            .tint(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: minimumHeight)
            .background {
                shape.fill(backgroundColor)
            }
            .overlay {
                shape.strokeBorder(borderColor, lineWidth: 1)
            }
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.55)
            .scaleEffect(isPressed && !reduceMotion ? 0.98 : 1)
            .onHover { hovering in
                guard isEnabled else {
                    isHovering = false
                    return
                }

                if reduceMotion {
                    isHovering = hovering
                } else {
                    withAnimation(.easeOut(duration: 0.12)) {
                        isHovering = hovering
                    }
                }
            }
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.08),
                value: isPressed
            )
    }

    private var font: Font {
        switch kind {
        case .primary:
            .system(size: 14, weight: .semibold)
        case .secondary, .text:
            .system(size: 13, weight: .medium)
        }
    }

    private var minimumHeight: CGFloat {
        switch kind {
        case .primary:
            40
        case .secondary, .text:
            30
        }
    }

    private var horizontalPadding: CGFloat {
        switch kind {
        case .primary:
            18
        case .secondary:
            14
        case .text:
            8
        }
    }

    private var foregroundColor: Color {
        switch kind {
        case .primary:
            theme.accentForeground
        case .secondary:
            theme.textPrimary
        case .text:
            isHovering ? theme.textPrimary : theme.textSecondary
        }
    }

    private var backgroundColor: Color {
        switch kind {
        case .primary:
            if isPressed { return theme.accent.opacity(0.84) }
            if isHovering { return theme.accent.opacity(0.9) }
            return theme.accent

        case .secondary:
            if isPressed { return theme.selection }
            if isHovering { return theme.selection.opacity(0.72) }
            return theme.surfaceRaised

        case .text:
            if isPressed { return theme.selection }
            if isHovering { return theme.selection.opacity(0.72) }
            return .clear
        }
    }

    private var borderColor: Color {
        switch kind {
        case .primary, .text:
            .clear
        case .secondary:
            isHovering ? theme.accent.opacity(0.65) : theme.border
        }
    }
}
