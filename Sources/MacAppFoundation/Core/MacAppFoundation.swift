import Foundation

/// Process-wide bootstrap for MacAppFoundation.
///
/// Call `MacAppFoundation.setup()` once at the very beginning of the app's
/// `App.init()`, before resolving services or creating loggers. The call is
/// intentionally synchronous, cheap, and idempotent so additional framework-wide
/// startup configuration can be added here without changing every adopter again.
///
/// MacAppFoundation owns SwiftLog bootstrap after setup. Apps using this entry
/// point must not also call `LoggingSystem.bootstrap` themselves.
public enum MacAppFoundation {
    private static let setupLock = NSLock()
    nonisolated(unsafe) private static var didSetup = false

    public static func setup() {
        setupLock.lock()
        defer { setupLock.unlock() }

        guard !didSetup else { return }
        MacAppFoundationLogging.bootstrap()
        didSetup = true
    }

    static var isSetup: Bool {
        setupLock.lock()
        defer { setupLock.unlock() }
        return didSetup
    }
}
