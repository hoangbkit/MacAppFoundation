import SwiftUI

public struct ProUpsellBenefit: Identifiable, Hashable, Sendable {
    public let id: String
    public let systemImage: String
    public let title: String
    public let message: String

    public init(
        id: String,
        systemImage: String,
        title: String,
        message: String
    ) {
        self.id = id
        self.systemImage = systemImage
        self.title = title
        self.message = message
    }

    public init(_ feature: PurchaseFeature) {
        self.init(
            id: feature.id,
            systemImage: feature.systemImage,
            title: feature.title,
            message: feature.message
        )
    }
}

/// Reusable macOS upsell surface for limits and locked premium workflows.
///
/// The consuming app owns both actions so this view never assumes whether the
/// paywall is a window, sheet, popover, or another navigation destination.
public struct ProUpsellView: View {
    private let title: String
    private let message: String
    private let benefits: [ProUpsellBenefit]
    private let primaryActionTitle: String
    private let secondaryActionTitle: String
    private let onPrimaryAction: () -> Void
    private let onSecondaryAction: () -> Void

    public init(
        title: String,
        message: String,
        benefits: [ProUpsellBenefit],
        primaryActionTitle: String = "Unlock Pro",
        secondaryActionTitle: String = "Continue Free",
        onPrimaryAction: @escaping () -> Void,
        onSecondaryAction: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.benefits = benefits
        self.primaryActionTitle = primaryActionTitle
        self.secondaryActionTitle = secondaryActionTitle
        self.onPrimaryAction = onPrimaryAction
        self.onSecondaryAction = onSecondaryAction
    }

    public init(
        title: String,
        message: String,
        features: [PurchaseFeature],
        primaryActionTitle: String = "Unlock Pro",
        secondaryActionTitle: String = "Continue Free",
        onPrimaryAction: @escaping () -> Void,
        onSecondaryAction: @escaping () -> Void
    ) {
        self.init(
            title: title,
            message: message,
            benefits: features.map(ProUpsellBenefit.init),
            primaryActionTitle: primaryActionTitle,
            secondaryActionTitle: secondaryActionTitle,
            onPrimaryAction: onPrimaryAction,
            onSecondaryAction: onSecondaryAction
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                Text(message)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(benefits) { benefit in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: benefit.systemImage)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.accentColor)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(benefit.title)
                                .font(.headline)
                            Text(benefit.message)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                Button(secondaryActionTitle, action: onSecondaryAction)
                    .buttonStyle(.bordered)

                Button(primaryActionTitle, action: onPrimaryAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 460, idealWidth: 540, maxWidth: 620)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }
}
