import SwiftUI

/// A neutral onboarding shell whose entire main content area belongs to the app.
///
/// MacAppFoundation owns only the footer layout: leading actions, a centered
/// message, and trailing actions. The app supplies every view in the content area.
public struct OnboardingView<Content: View, LeadingActions: View, Message: View, TrailingActions: View>: View {
    private let content: Content
    private let leadingActions: LeadingActions
    private let message: Message
    private let trailingActions: TrailingActions

    public init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder leadingActions: () -> LeadingActions,
        @ViewBuilder message: () -> Message,
        @ViewBuilder trailingActions: () -> TrailingActions
    ) {
        self.content = content()
        self.leadingActions = leadingActions()
        self.message = message()
        self.trailingActions = trailingActions()
    }

    public var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            OnboardingFooter(
                leadingActions: { leadingActions },
                message: { message },
                trailingActions: { trailingActions }
            )
        }
    }
}

/// The framework-owned footer used by ``OnboardingView``.
///
/// The center message stays visually centered in the window independently of
/// the width of the actions on either side.
public struct OnboardingFooter<LeadingActions: View, Message: View, TrailingActions: View>: View {
    private let leadingActions: LeadingActions
    private let message: Message
    private let trailingActions: TrailingActions

    public init(
        @ViewBuilder leadingActions: () -> LeadingActions,
        @ViewBuilder message: () -> Message,
        @ViewBuilder trailingActions: () -> TrailingActions
    ) {
        self.leadingActions = leadingActions()
        self.message = message()
        self.trailingActions = trailingActions()
    }

    public var body: some View {
        ZStack {
            message
                .lineLimit(1)

            HStack(spacing: 8) {
                leadingActions
                Spacer(minLength: 16)
                trailingActions
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .padding(.horizontal, 16)
        .background(.bar)
    }
}

/// Convenience center message for step-based onboarding flows.
///
/// The title is intentionally optional so apps can display either a compact
/// "Step 2 of 4" message or combine the step with app-owned context such as
/// "Step 2 of 4 · Permissions".
public struct OnboardingStepMessage: View {
    public let title: String?
    public let currentStep: Int
    public let stepCount: Int

    public init(
        title: String? = nil,
        currentStep: Int,
        stepCount: Int
    ) {
        self.title = title
        self.currentStep = currentStep
        self.stepCount = stepCount
    }

    public var body: some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    private var message: String {
        let safeCount = max(stepCount, 1)
        let displayedStep = min(max(currentStep + 1, 1), safeCount)
        let progress = "Step \(displayedStep) of \(safeCount)"

        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty
        else {
            return progress
        }

        return "\(progress) · \(title)"
    }
}
