import Foundation
import Logging

#if DEBUG
import Combine
#endif

public enum MacAppFoundationLogging {
    private static let bootstrapLock = NSLock()
    nonisolated(unsafe) private static var didBootstrap = false

    /// Opts the process into MacAppFoundation's SwiftLog backend.
    ///
    /// Call this before creating any Logger instances. SwiftLog permits one
    /// process-wide bootstrap, so apps using another backend must not call this.
    public static func bootstrap() {
        bootstrapLock.lock()
        defer { bootstrapLock.unlock() }

        guard !didBootstrap else { return }

        LoggingSystem.bootstrap { label in
            var console = MacAppFoundationConsoleLogHandler(label: label)

            #if DEBUG
            console.logLevel = .debug
            var inMemory = MacAppFoundationStoreLogHandler(label: label)
            inMemory.logLevel = .debug
            return MultiplexLogHandler([console, inMemory])
            #else
            console.logLevel = .info
            return console
            #endif
        }

        didBootstrap = true
    }

    static var isBootstrapped: Bool {
        bootstrapLock.lock()
        defer { bootstrapLock.unlock() }
        return didBootstrap
    }
}

private struct MacAppFoundationConsoleLogHandler: LogHandler {
    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .info
    let label: String

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(event: LogEvent) {
        let timestamp = Date.now.formatted(.dateTime.hour().minute().second())
        print("[\(timestamp)][\(event.level)][\(label)] \(event.message)")
    }
}

#if DEBUG
struct MacAppFoundationLogEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let level: Logger.Level
    let label: String
    let message: String
    let metadata: String?
}

@MainActor
final class MacAppFoundationLogStore: ObservableObject {
    static let shared = MacAppFoundationLogStore()

    @Published private(set) var entries: [MacAppFoundationLogEntry] = []

    let maximumEntries: Int

    init(maximumEntries: Int = 500) {
        precondition(maximumEntries > 0)
        self.maximumEntries = maximumEntries
    }

    func append(_ entry: MacAppFoundationLogEntry) {
        entries.append(entry)
        let overflow = entries.count - maximumEntries
        if overflow > 0 {
            entries.removeFirst(overflow)
        }
    }

    func clear() {
        entries.removeAll(keepingCapacity: true)
    }
}

private struct MacAppFoundationStoreLogHandler: LogHandler {
    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .debug

    private let label: String

    init(label: String) {
        self.label = label
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(event: LogEvent) {
        var combinedMetadata = metadata
        if let eventMetadata = event.metadata {
            combinedMetadata.merge(eventMetadata) { _, eventValue in eventValue }
        }

        let formattedMetadata = combinedMetadata.isEmpty
            ? nil
            : combinedMetadata
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")

        let entry = MacAppFoundationLogEntry(
            timestamp: .now,
            level: event.level,
            label: label,
            message: String(describing: event.message),
            metadata: formattedMetadata
        )

        Task { @MainActor in
            MacAppFoundationLogStore.shared.append(entry)
        }
    }
}
#endif
