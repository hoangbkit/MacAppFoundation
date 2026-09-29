#if DEBUG
import Combine
import Foundation

@MainActor
final class AppAnalyticsDeveloperActivityStore: ObservableObject {
    enum Kind: String, Sendable {
        case event = "Event"
        case error = "Error"
        case lifecycle = "Lifecycle"
        case upload = "Upload"
        case reset = "Reset"
        case failure = "Failure"
    }

    struct Entry: Identifiable, Sendable {
        let id = UUID()
        let timestamp: Date
        let kind: Kind
        let title: String
        let detail: String?
    }

    static let shared = AppAnalyticsDeveloperActivityStore()

    @Published private(set) var entries: [Entry] = []

    private let maximumEntries = 500

    func append(
        kind: Kind,
        title: String,
        detail: String? = nil,
        timestamp: Date = .now
    ) {
        entries.append(
            Entry(
                timestamp: timestamp,
                kind: kind,
                title: title,
                detail: detail
            )
        )

        let overflow = entries.count - maximumEntries
        if overflow > 0 {
            entries.removeFirst(overflow)
        }
    }

    func clear() {
        entries.removeAll(keepingCapacity: true)
    }
}
#endif
