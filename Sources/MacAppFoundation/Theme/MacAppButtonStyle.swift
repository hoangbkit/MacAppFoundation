import SwiftUI

/// General-purpose MacAppFoundation button styling backed by the active app theme.
///
/// Feature-specific components may provide their own semantic wrappers, while
/// generic framework-owned surfaces can use this style directly without falling
/// back to OS-version-dependent bordered button appearances.
public struct MacAppButtonStyle: ButtonStyle {
    public enum Kind: Sendable, Equatable {
        case primary
        case secondary
        case quiet
    }

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.macAppTheme) private var theme

    private let kind: Kind

    public init(_ kind: Kind = .secondary) {
        self.kind = kind
    }

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        configuration.label
            .font(.system(size: 13, weight: kind == .primary ? .semibold : .medium))
            .lineLimit(1)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: 32)
            .background {
                shape.fill(backgroundColor(isPressed: configuration.isPressed))
            }
            .overlay {
                shape.strokeBorder(borderColor, lineWidth: 1)
            }
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.55)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }

    private var horizontalPadding: CGFloat {
        kind == .quiet ? 8 : 14
    }

    private var foregroundColor: Color {
        switch kind {
        case .primary:
            theme.accentForeground
        case .secondary:
            theme.textPrimary
        case .quiet:
            theme.textSecondary
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch kind {
        case .primary:
            theme.accent.opacity(isPressed ? 0.84 : 1)
        case .secondary:
            isPressed ? theme.selection : theme.surfaceRaised
        case .quiet:
            isPressed ? theme.selection : .clear
        }
    }

    private var borderColor: Color {
        switch kind {
        case .primary, .quiet:
            .clear
        case .secondary:
            theme.border
        }
    }
}
