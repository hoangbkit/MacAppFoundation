import Observation

@MainActor
@Observable
final class DemoState {
    var useMockData = false
    var showTips = true
    var compactCards = false
    var actionCount = 0
    var lastAction = "Ready"

    func record(_ message: String) {
        actionCount += 1
        lastAction = message
    }

    func reset() {
        useMockData = false
        showTips = true
        compactCards = false
        actionCount = 0
        lastAction = "Ready"
    }
}
