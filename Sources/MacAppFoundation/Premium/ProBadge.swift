import SwiftUI

/// A compact badge signalling a Pro-only feature.
public struct ProBadge: View {
    public enum Style: Sendable {
        case filled
        case outline
        case icon
    }

    public var style: Style
    public var color: Color

    public init(style: Style = .filled, color: Color = .accentColor) {
        self.style = style
        self.color = color
    }

    public var body: some View {
        switch style {
        case .filled:
            Text("PRO")
                .font(.system(size: 9, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(color, in: Capsule())
                .accessibilityLabel("Requires Pro")

        case .outline:
            Text("PRO")
                .font(.system(size: 9, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().strokeBorder(color, lineWidth: 1))
                .accessibilityLabel("Requires Pro")

        case .icon:
            Image(systemName: "star.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
                .accessibilityLabel("Requires Pro")
        }
    }
}

public struct ProBadgeModifier: ViewModifier {
    public var style: ProBadge.Style
    public var color: Color
    public var visible: Bool

    public init(
        style: ProBadge.Style = .filled,
        color: Color = .accentColor,
        visible: Bool = true
    ) {
        self.style = style
        self.color = color
        self.visible = visible
    }

    public func body(content: Content) -> some View {
        HStack(spacing: 6) {
            content
            if visible {
                ProBadge(style: style, color: color)
            }
        }
    }
}

public extension View {
    func proBadge(
        style: ProBadge.Style = .filled,
        color: Color = .accentColor,
        visible: Bool = true
    ) -> some View {
        modifier(ProBadgeModifier(style: style, color: color, visible: visible))
    }
}
