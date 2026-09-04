import SwiftUI

/// A dedicated transient macOS window for onboarding.
///
/// The scene is presented on launch until ``OnboardingState/isCompleted`` is true,
/// opts out of window restoration, and can still be reopened explicitly with
/// `openWindow(id:)` for replay.
@MainActor
public struct OnboardingWindow<Content: View>: Scene {
    private let title: String
    private let id: String
    private let state: OnboardingState
    private let defaultWidth: CGFloat
    private let defaultHeight: CGFloat
    private let content: Content

    public init(
        _ title: String,
        id: String,
        state: OnboardingState,
        defaultWidth: CGFloat = 620,
        defaultHeight: CGFloat = 500,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.id = id
        self.state = state
        self.defaultWidth = defaultWidth
        self.defaultHeight = defaultHeight
        self.content = content()
    }

    public var body: some Scene {
        Window(title, id: id) {
            content
        }
        .defaultSize(width: defaultWidth, height: defaultHeight)
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(state.isCompleted ? .suppressed : .presented)
    }
}

public extension OnboardingState {
    /// Launch behavior for the app's primary window while onboarding is active.
    ///
    /// Apply this to the main `Window`/`WindowGroup` so first launch shows only
    /// the onboarding window. After completion, the primary window becomes the
    /// normal launch destination.
    var mainWindowLaunchBehavior: SceneLaunchBehavior {
        isCompleted ? .presented : .suppressed
    }
}
