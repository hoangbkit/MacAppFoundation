import SwiftUI

/// A compact Free/Pro plan action suitable for app headers and title-bar-adjacent UI.
///
/// `ProPlanButton` owns entitlement-aware presentation while the host app owns
/// navigation. Free users see an "Unlock Pro" action; Pro users see their active
/// plan when it can be resolved from ``PurchaseManager.activeProduct``.
public struct ProPlanButton: View {
    /// Stable accessibility identifier for UI automation and assistive tooling.
    public static let accessibilityIdentifier = "MacAppFoundation.ProPlanButton"

    private let purchaseManager: PurchaseManager
    private let height: CGFloat
    private let onUpgrade: () -> Void
    private let onManagePlan: () -> Void

    public init(
        purchaseManager: PurchaseManager,
        height: CGFloat = 24,
        onUpgrade: @escaping () -> Void,
        onManagePlan: @escaping () -> Void
    ) {
        self.purchaseManager = purchaseManager
        self.height = max(0, height)
        self.onUpgrade = onUpgrade
        self.onManagePlan = onManagePlan
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: presentation.iconName)
                    .font(.system(size: 11, weight: .semibold))

                Text(presentation.title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .lineLimit(1)
        }
        .buttonStyle(
            ProPlanButtonStyle(
                isPro: presentation.isPro,
                height: height
            )
        )
        .help(presentation.helpText)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(Self.accessibilityIdentifier)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(presentation.accessibilityValue)
    }

    private var presentation: ProPlanButtonPresentation {
        ProPlanButtonPresentation(
            hasPro: purchaseManager.hasPro,
            activeProduct: purchaseManager.activeProduct
        )
    }

    private func action() {
        if presentation.isPro {
            onManagePlan()
        } else {
            onUpgrade()
        }
    }
}

struct ProPlanButtonPresentation: Equatable {
    let title: String
    let iconName: String
    let helpText: String
    let accessibilityLabel: String
    let accessibilityValue: String
    let isPro: Bool

    init(
        hasPro: Bool,
        activeProduct: StoreProduct?
    ) {
        isPro = hasPro

        if hasPro {
            let planLabel = Self.planLabel(for: activeProduct)
            title = planLabel
            iconName = "checkmark.seal.fill"
            helpText = "Manage your plan"
            accessibilityLabel = "Manage plan"
            accessibilityValue = planLabel
        } else {
            title = "Unlock Pro"
            iconName = "crown.fill"
            helpText = "Unlock Pro"
            accessibilityLabel = "Unlock Pro"
            accessibilityValue = "Free plan"
        }
    }

    private static func planLabel(for product: StoreProduct?) -> String {
        guard let product else {
            return "Pro"
        }

        if product.isLifetime {
            return "Pro Lifetime"
        }

        switch product.subscriptionPeriod?.unit {
        case .month:
            return "Pro Monthly"
        case .year:
            return "Pro Yearly"
        default:
            return "Pro"
        }
    }
}

private struct ProPlanButtonStyle: ButtonStyle {
    let isPro: Bool
    let height: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        ProPlanButtonStyleBody(
            label: configuration.label,
            isPro: isPro,
            isPressed: configuration.isPressed,
            height: height
        )
    }
}

private struct ProPlanButtonStyleBody<Label: View>: View {
    let label: Label
    let isPro: Bool
    let isPressed: Bool
    let height: CGFloat

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.macAppTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        label
            .padding(.horizontal, 10)
            .frame(height: height)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(borderColor, lineWidth: 0.75)
            }
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.5)
            .onHover { hovering in
                if reduceMotion {
                    isHovered = hovering
                } else {
                    withAnimation(.easeOut(duration: 0.12)) {
                        isHovered = hovering
                    }
                }
            }
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: isPressed
            )
    }

    private var foregroundColor: Color {
        isPro ? theme.textSecondary : theme.accent
    }

    private var backgroundColor: Color {
        if isPro {
            if isPressed {
                return theme.selection
            }
            return isHovered ? theme.surfaceRaised : theme.surface
        }

        return theme.accent.opacity(isPressed ? 0.24 : isHovered ? 0.20 : 0.16)
    }

    private var borderColor: Color {
        if isPro {
            return isHovered || isPressed ? theme.border.opacity(1) : theme.border.opacity(0.72)
        }

        return theme.accent.opacity(isHovered || isPressed ? 0.58 : 0.45)
    }
}
