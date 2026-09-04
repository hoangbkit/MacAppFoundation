import MacAppFoundation
import SwiftUI

struct DemoOnboardingView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    let onboarding: OnboardingState

    var body: some View {
        OnboardingView {
            content
                .id(onboarding.currentStep)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .padding(40)
        } leadingActions: {
            if onboarding.canGoBack {
                Button("Back") {
                    withAnimation(.snappy(duration: 0.22)) {
                        onboarding.goBack()
                    }
                }
            }
        } message: {
            OnboardingStepMessage(
                title: stepTitle,
                currentStep: onboarding.currentStep,
                stepCount: onboarding.stepCount
            )
        } trailingActions: {
            Button(onboarding.isLastStep ? "Get Started" : "Continue") {
                continueFlow()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(width: 620, height: 500)
    }

    @ViewBuilder
    private var content: some View {
        switch onboarding.currentStep {
        case 0:
            VStack(spacing: 20) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 72))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text("Welcome to MAF")
                        .font(.largeTitle.bold())

                    Text("Reusable macOS foundations without taking over your app's design.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case 1:
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your content stays yours")
                        .font(.largeTitle.bold())
                    Text("This entire area is designed by the app. MacAppFoundation only provides the window, flow state, and footer shell.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    demoRow(
                        icon: "rectangle.on.rectangle",
                        title: "Any SwiftUI layout",
                        detail: "Forms, animations, permissions, previews, or setup controls."
                    )
                    demoRow(
                        icon: "arrow.left.and.right",
                        title: "App-owned actions",
                        detail: "Choose what Back, Skip, Continue, or custom actions mean."
                    )
                    demoRow(
                        icon: "text.aligncenter",
                        title: "Flexible footer message",
                        detail: "Combine step progress with any context the app wants to show."
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        default:
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.green)

                VStack(spacing: 8) {
                    Text("You're ready")
                        .font(.largeTitle.bold())
                    Text("Completing onboarding closes this window and opens the main app. You can replay this flow anytime from Developer Tools.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 470)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var stepTitle: String {
        switch onboarding.currentStep {
        case 0: "Welcome"
        case 1: "App-owned content"
        default: "Ready"
        }
    }

    private func demoRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private func continueFlow() {
        guard onboarding.isLastStep else {
            withAnimation(.snappy(duration: 0.22)) {
                onboarding.goForward()
            }
            return
        }

        onboarding.complete()
        openWindow(id: DemoWindowID.main)
        dismissWindow(id: DemoWindowID.onboarding)
    }
}
