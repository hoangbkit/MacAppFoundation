import Foundation
import Observation

/// Persistent navigation state for a macOS onboarding flow.
///
/// MacAppFoundation owns only the flow state. Apps remain responsible for the
/// content of every onboarding step and decide when the flow is complete.
@MainActor
@Observable
public final class OnboardingState {
    public let id: String
    public let stepCount: Int

    public private(set) var currentStep: Int
    public private(set) var isCompleted: Bool

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let completedKey: String
    @ObservationIgnored private let currentStepKey: String

    public init(
        id: String,
        stepCount: Int,
        defaults: UserDefaults = .standard
    ) {
        let normalizedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        precondition(!normalizedID.isEmpty, "OnboardingState requires a non-empty id.")
        precondition(stepCount > 0, "OnboardingState requires at least one step.")

        self.id = normalizedID
        self.stepCount = stepCount
        self.defaults = defaults

        let keyPrefix = "MacAppFoundation.Onboarding.\(normalizedID)"
        completedKey = "\(keyPrefix).completed"
        currentStepKey = "\(keyPrefix).currentStep"

        isCompleted = defaults.bool(forKey: completedKey)
        currentStep = min(max(defaults.integer(forKey: currentStepKey), 0), stepCount - 1)
    }

    public var canGoBack: Bool {
        currentStep > 0
    }

    public var canGoForward: Bool {
        currentStep < stepCount - 1
    }

    public var isLastStep: Bool {
        currentStep == stepCount - 1
    }

    public func goBack() {
        move(to: currentStep - 1)
    }

    public func goForward() {
        move(to: currentStep + 1)
    }

    public func move(to step: Int) {
        let clampedStep = min(max(step, 0), stepCount - 1)
        guard clampedStep != currentStep else { return }

        currentStep = clampedStep
        defaults.set(clampedStep, forKey: currentStepKey)
    }

    /// Marks onboarding complete without imposing any app-specific dismissal behavior.
    public func complete() {
        guard !isCompleted else { return }
        isCompleted = true
        defaults.set(true, forKey: completedKey)
    }

    /// Starts the flow from its first step while preserving completion state.
    ///
    /// This is the appropriate operation for a Developer Tools "Replay Onboarding"
    /// action because replaying should not make onboarding mandatory on the next launch.
    public func restart() {
        currentStep = 0
        defaults.set(0, forKey: currentStepKey)
    }

    /// Clears completion and returns to the first step.
    ///
    /// Apps can use this when they intentionally want to reproduce a true first launch.
    public func reset() {
        currentStep = 0
        isCompleted = false
        defaults.removeObject(forKey: completedKey)
        defaults.removeObject(forKey: currentStepKey)
    }
}
