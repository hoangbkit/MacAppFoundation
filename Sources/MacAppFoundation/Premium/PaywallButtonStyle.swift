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

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.macAppTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let kind: Kind

    public init(_ kind: Kind = .secondary) {
        self.kind = kind
    }

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)

        configuration.label
            .font(font)
            .lineLimit(1)
            .foregroundStyle(foregroundColor)
            .tint(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: minimumHeight)
            .background {
                shape.fill(backgroundColor(isPressed: configuration.isPressed))
            }
            .overlay {
                shape.strokeBorder(borderColor, lineWidth: 1)
            }
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.55)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.08),
                value: configuration.isPressed
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
            theme.textSecondary
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch kind {
        case .primary:
            theme.accent.opacity(isPressed ? 0.84 : 1)
        case .secondary:
            isPressed ? theme.selection : theme.surfaceRaised
        case .text:
            isPressed ? theme.selection : .clear
        }
    }

    private var borderColor: Color {
        switch kind {
        case .primary, .text:
            .clear
        case .secondary:
            theme.border
        }
    }
}
