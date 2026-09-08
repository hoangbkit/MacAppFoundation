import SwiftUI

/// A compact badge signalling a Pro-only feature.
public struct ProBadge: View {
    public enum Style: Sendable {
        case filled
        case outline
        case icon
    }

    @Environment(\.macAppTheme) private var theme

    public var style: Style
    private var colorOverride: Color?

    /// The explicit badge color. Reading this value preserves the historical
    /// `.accentColor` default; rendering uses the active MAF theme when no
    /// explicit override was supplied.
    public var color: Color {
        get { colorOverride ?? .accentColor }
        set { colorOverride = newValue }
    }

    public init(style: Style = .filled) {
        self.style = style
        self.colorOverride = nil
    }

    public init(style: Style = .filled, color: Color) {
        self.style = style
        self.colorOverride = color
    }

    public var body: some View {
        let resolvedColor = colorOverride ?? theme.accent

        switch style {
        case .filled:
            Text("PRO")
                .font(.system(size: 9, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(theme.accentForeground)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(resolvedColor, in: Capsule())
                .accessibilityLabel("Requires Pro")

        case .outline:
            Text("PRO")
                .font(.system(size: 9, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(resolvedColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().strokeBorder(resolvedColor, lineWidth: 1))
                .accessibilityLabel("Requires Pro")

        case .icon:
            Image(systemName: "star.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(resolvedColor)
                .accessibilityLabel("Requires Pro")
        }
    }
}

public struct ProBadgeModifier: ViewModifier {
    public var style: ProBadge.Style
    private var colorOverride: Color?
    public var visible: Bool

    public var color: Color {
        get { colorOverride ?? .accentColor }
        set { colorOverride = newValue }
    }

    public init(
        style: ProBadge.Style = .filled,
        visible: Bool = true
    ) {
        self.style = style
        self.colorOverride = nil
        self.visible = visible
    }

    public init(
        style: ProBadge.Style = .filled,
        color: Color,
        visible: Bool = true
    ) {
        self.style = style
        self.colorOverride = color
        self.visible = visible
    }

    public func body(content: Content) -> some View {
        HStack(spacing: 6) {
            content
            if visible {
                if let colorOverride {
                    ProBadge(style: style, color: colorOverride)
                } else {
                    ProBadge(style: style)
                }
            }
        }
    }
}

public extension View {
    func proBadge(
        style: ProBadge.Style = .filled,
        visible: Bool = true
    ) -> some View {
        modifier(ProBadgeModifier(style: style, visible: visible))
    }

    func proBadge(
        style: ProBadge.Style = .filled,
        color: Color,
        visible: Bool = true
    ) -> some View {
        modifier(ProBadgeModifier(style: style, color: color, visible: visible))
    }
}
