#if DEBUG
import XCTest
@testable import MacAppFoundation

@MainActor
final class MacAppFoundationLogStoreTests: XCTestCase {
    func testStoreKeepsOnlyNewestEntriesWithinLimit() {
        let store = MacAppFoundationLogStore(maximumEntries: 2)

        store.append(entry("first"))
        store.append(entry("second"))
        store.append(entry("third"))

        XCTAssertEqual(store.entries.map(\.message), ["second", "third"])
    }

    func testClearRemovesCapturedEntries() {
        let store = MacAppFoundationLogStore(maximumEntries: 2)
        store.append(entry("entry"))

        store.clear()

        XCTAssertTrue(store.entries.isEmpty)
    }

    private func entry(_ message: String) -> MacAppFoundationLogEntry {
        MacAppFoundationLogEntry(
            timestamp: .now,
            level: .debug,
            label: "test",
            message: message,
            metadata: nil
        )
    }
}
#endif
