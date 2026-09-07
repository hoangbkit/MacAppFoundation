import SwiftUI

/// A framework-owned button style for onboarding actions.
///
/// The style uses explicit sizing, padding, shape, and pressed-state treatment so
/// onboarding controls stay visually consistent across supported macOS releases.
public struct OnboardingButtonStyle: ButtonStyle {
    public enum Prominence: Sendable, Equatable {
        case secondary
        case primary
    }

    @Environment(\.isEnabled) private var isEnabled

    private let prominence: Prominence

    public init(_ prominence: Prominence = .secondary) {
        self.prominence = prominence
    }

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)

        configuration.label
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 14)
            .frame(minHeight: 30)
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

    private var foregroundColor: Color {
        switch prominence {
        case .secondary:
            .primary
        case .primary:
            .white
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch prominence {
        case .secondary:
            Color.primary.opacity(isPressed ? 0.13 : 0.08)
        case .primary:
            Color.accentColor.opacity(isPressed ? 0.84 : 1)
        }
    }

    private var borderColor: Color {
        switch prominence {
        case .secondary:
            Color.primary.opacity(0.14)
        case .primary:
            .clear
        }
    }
}
