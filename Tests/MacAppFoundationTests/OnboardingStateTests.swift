import Foundation
import XCTest
@testable import MacAppFoundation

@MainActor
final class OnboardingStateTests: XCTestCase {
    func testProgressResumesUntilCompletion() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let state = OnboardingState(
            id: "demo",
            stepCount: 3,
            defaults: defaults
        )

        XCTAssertEqual(state.currentStep, 0)
        XCTAssertFalse(state.isCompleted)

        state.goForward()
        XCTAssertEqual(state.currentStep, 1)

        let resumed = OnboardingState(
            id: "demo",
            stepCount: 3,
            defaults: defaults
        )
        XCTAssertEqual(resumed.currentStep, 1)
        XCTAssertFalse(resumed.isCompleted)
    }

    func testCompletionPersists() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let state = OnboardingState(
            id: "demo",
            stepCount: 3,
            defaults: defaults
        )
        state.complete()

        let resumed = OnboardingState(
            id: "demo",
            stepCount: 3,
            defaults: defaults
        )
        XCTAssertTrue(resumed.isCompleted)
    }

    func testReplayRestartsWithoutClearingCompletion() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let state = OnboardingState(
            id: "demo",
            stepCount: 3,
            defaults: defaults
        )
        state.move(to: 2)
        state.complete()
        state.restart()

        XCTAssertEqual(state.currentStep, 0)
        XCTAssertTrue(state.isCompleted)

        let resumed = OnboardingState(
            id: "demo",
            stepCount: 3,
            defaults: defaults
        )
        XCTAssertEqual(resumed.currentStep, 0)
        XCTAssertTrue(resumed.isCompleted)
    }

    func testResetRestoresFirstLaunchState() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let state = OnboardingState(
            id: "demo",
            stepCount: 3,
            defaults: defaults
        )
        state.move(to: 2)
        state.complete()
        state.reset()

        XCTAssertEqual(state.currentStep, 0)
        XCTAssertFalse(state.isCompleted)

        let resumed = OnboardingState(
            id: "demo",
            stepCount: 3,
            defaults: defaults
        )
        XCTAssertEqual(resumed.currentStep, 0)
        XCTAssertFalse(resumed.isCompleted)
    }

    private var defaultsSuiteName: String {
        "MacAppFoundationTests.OnboardingState"
    }

    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: defaultsSuiteName)!
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        return defaults
    }
}
