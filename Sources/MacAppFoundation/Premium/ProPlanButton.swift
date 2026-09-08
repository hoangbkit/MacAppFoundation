import SwiftUI

/// A compact Free/Pro plan action suitable for app headers and title-bar-adjacent UI.
///
/// `ProPlanButton` owns entitlement-aware presentation while the host app owns
/// navigation. Free users see an "Unlock Pro" action; Pro users see their active
/// plan when it can be resolved from ``PurchaseManager.activeProduct``.
public struct ProPlanButton: View {
    private let purchaseManager: PurchaseManager
    private let onUpgrade: () -> Void
    private let onManagePlan: () -> Void

    public init(
        purchaseManager: PurchaseManager,
        onUpgrade: @escaping () -> Void,
        onManagePlan: @escaping () -> Void
    ) {
        self.purchaseManager = purchaseManager
        self.onUpgrade = onUpgrade
        self.onManagePlan = onManagePlan
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: purchaseManager.hasPro ? "checkmark.seal.fill" : "crown.fill")
                    .font(.system(size: 11, weight: .semibold))

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .lineLimit(1)
        }
        .buttonStyle(ProPlanButtonStyle(isPro: purchaseManager.hasPro))
        .help(purchaseManager.hasPro ? "Manage your plan" : "Unlock Pro")
        .accessibilityLabel(purchaseManager.hasPro ? "Manage plan" : "Unlock Pro")
        .accessibilityValue(purchaseManager.hasPro ? planLabel : "Free plan")
    }

    private var title: String {
        purchaseManager.hasPro ? planLabel : "Unlock Pro"
    }

    private var planLabel: String {
        guard let product = purchaseManager.activeProduct else {
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

    private func action() {
        if purchaseManager.hasPro {
            onManagePlan()
        } else {
            onUpgrade()
        }
    }
}

private struct ProPlanButtonStyle: ButtonStyle {
    let isPro: Bool

    func makeBody(configuration: Configuration) -> some View {
        ProPlanButtonStyleBody(
            label: configuration.label,
            isPro: isPro,
            isPressed: configuration.isPressed
        )
    }
}

private struct ProPlanButtonStyleBody<Label: View>: View {
    let label: Label
    let isPro: Bool
    let isPressed: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.macAppTheme) private var theme
    @State private var isHovered = false

    var body: some View {
        label
            .padding(.horizontal, 10)
            .frame(height: 24)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(borderColor, lineWidth: 0.75)
            }
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.5)
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .animation(.easeOut(duration: 0.12), value: isPressed)
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
