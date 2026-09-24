import Foundation

struct AppAnalyticsClientContext: Sendable {
    let osVersion: String
    let appBuild: String?
    let deviceFamily: String
    let architecture: String?

    static func current() -> AppAnalyticsClientContext {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

        #if arch(arm64)
        let architecture: String? = "arm64"
        #elseif arch(x86_64)
        let architecture: String? = "x86_64"
        #else
        let architecture: String? = nil
        #endif

        return AppAnalyticsClientContext(
            osVersion: osVersion,
            appBuild: appBuild,
            deviceFamily: "mac",
            architecture: architecture
        )
    }
}

private actor AppAnalyticsInstallationGate {
    static let shared = AppAnalyticsInstallationGate()

    private var lockedKeys: Set<String> = []
    private var waiters: [String: [CheckedContinuation<Void, Never>]] = [:]

    func acquire(_ key: String) async {
        if lockedKeys.insert(key).inserted { return }
        await withCheckedContinuation { continuation in
            waiters[key, default: []].append(continuation)
        }
    }

    func release(_ key: String) {
        guard lockedKeys.contains(key) else { return }
        guard var queued = waiters[key], !queued.isEmpty else {
            lockedKeys.remove(key)
            waiters.removeValue(forKey: key)
            return
        }
        let next = queued.removeFirst()
        if queued.isEmpty {
            waiters.removeValue(forKey: key)
        } else {
            waiters[key] = queued
        }
        next.resume()
    }
}

public actor AppAnalyticsClient {
    private enum Limits {
        static let maxDaysPerBatch = 7
        static let maxOfflineAgeDays = 6
        static let maxEventsPerDay = 50
        static let maxEventCountersPerBatch = 100
        static let maxEventCountPerDay = 500
        static let maxTotalEventCountPerDay = 2_000
        static let maxErrorsPerDay = 20
        static let maxErrorCountersPerBatch = 140
        static let maxTotalErrorCountPerDay = 100
        static let maxSessionsPerDay = 1_000
        static let maxSessionSecondsPerDay = 86_400
        static let maxEventNameLength = 48
        static let maxDimensionLength = 64
        static let maxAppVersionLength = 64
        static let maxNativeContextLength = 32
        static let maxErrorTokenLength = 48
        static let maxBodyBytes = 32 * 1024
        static let sessionTimeout: TimeInterval = 30 * 60
        static let defaultRateLimitBackoff: TimeInterval = 60
    }

    private struct EventState: Codable, Sendable {
        var name: String
        var dimension: String?
        var count: Int
    }

    private struct ErrorState: Codable, Sendable {
        var code: String
        var component: String
        var severity: AppAnalyticsErrorSeverity
        var count: Int
    }

    private struct DayState: Codable, Sendable {
        var appVersion: String?
        var osVersion: String?
        var appBuild: String?
        var deviceFamily: String?
        var architecture: String?
        var sessions: Int = 0
        var sessionSeconds: Int = 0
        var events: [String: EventState] = [:]
        var errors: [String: ErrorState]?
    }

    private struct SessionState: Codable, Sendable {
        var lastActivityAt: Date
        var activeSince: Date?
    }

    private struct PersistedState: Codable, Sendable {
        var days: [String: DayState] = [:]
        var session: SessionState?
        var lastUploadAt: Date?
        var nextUploadAttemptAt: Date?
    }

    private struct BatchEvent: Encodable, Sendable {
        let name: String
        let dimension: String?
        let count: Int

        enum CodingKeys: String, CodingKey {
            case name
            case dimension
            case count
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            if let dimension {
                try container.encode(dimension, forKey: .dimension)
            }
            try container.encode(count, forKey: .count)
        }
    }

    private struct BatchError: Encodable, Sendable {
        let code: String
        let component: String
        let severity: AppAnalyticsErrorSeverity
        let count: Int
    }

    private struct BatchDay: Encodable, Sendable {
        let day: String
        let platform = "macos"
        let appVersion: String?
        let osVersion: String?
        let appBuild: String?
        let deviceFamily: String?
        let architecture: String?
        let sessions: Int
        let sessionSeconds: Int
        let events: [BatchEvent]
        let errors: [BatchError]

        enum CodingKeys: String, CodingKey {
            case day
            case platform
            case appVersion
            case osVersion
            case appBuild
            case deviceFamily
            case architecture
            case sessions
            case sessionSeconds
            case events
            case errors
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(day, forKey: .day)
            try container.encode(platform, forKey: .platform)
            if let appVersion {
                try container.encode(appVersion, forKey: .appVersion)
            }
            if let osVersion {
                try container.encode(osVersion, forKey: .osVersion)
            }
            if let appBuild {
                try container.encode(appBuild, forKey: .appBuild)
            }
            if let deviceFamily {
                try container.encode(deviceFamily, forKey: .deviceFamily)
            }
            if let architecture {
                try container.encode(architecture, forKey: .architecture)
            }
            try container.encode(sessions, forKey: .sessions)
            try container.encode(sessionSeconds, forKey: .sessionSeconds)
            try container.encode(events, forKey: .events)
            try container.encode(errors, forKey: .errors)
        }
    }

    private struct Batch: Encodable, Sendable {
        let schemaVersion = 1
        let requestId: String
        let days: [BatchDay]
    }

    private struct BatchResponse: Decodable, Sendable {
        let ok: Bool
        let requestId: String
        let acceptedDays: [String]
    }

    private struct ServerErrorEnvelope: Decodable {
        struct Detail: Decodable {
            let code: String
            let message: String
            let retryAfter: String?
        }

        let error: Detail
    }

    private let configuration: AppAnalyticsConfiguration
    private let transport: any AppAnalyticsTransport
    private let stateStore: any AppAnalyticsStateStoring
    private let secureStore: AppAnalyticsSecureStore
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let now: @Sendable () -> Date
    private let clientContext: AppAnalyticsClientContext
    private var automaticUploadTask: Task<Void, Never>?
    private var uploadInFlight = false
    private var uploadWaiters: [CheckedContinuation<Void, Never>] = []

    public init(
        configuration: AppAnalyticsConfiguration,
        transport: any AppAnalyticsTransport = URLSessionAppAnalyticsTransport()
    ) {
        self.configuration = configuration
        self.transport = transport
        self.stateStore = UserDefaultsAppAnalyticsStateStore(
            storageKey: configuration.stateStorageKey
        )
        self.secureStore = AppAnalyticsSecureStore(service: configuration.keychainService)
        self.encoder = Self.makeEncoder()
        self.decoder = Self.makeDecoder()
        self.now = Date.init
        self.clientContext = .current()
    }

    public init(
        configuration: AppAnalyticsConfiguration,
        transport: any AppAnalyticsTransport,
        stateStore: any AppAnalyticsStateStoring
    ) {
        self.configuration = configuration
        self.transport = transport
        self.stateStore = stateStore
        self.secureStore = AppAnalyticsSecureStore(service: configuration.keychainService)
        self.encoder = Self.makeEncoder()
        self.decoder = Self.makeDecoder()
        self.now = Date.init
        self.clientContext = .current()
    }

    init(
        configuration: AppAnalyticsConfiguration,
        transport: any AppAnalyticsTransport,
        stateStore: any AppAnalyticsStateStoring,
        now: @escaping @Sendable () -> Date,
        clientContext: AppAnalyticsClientContext = .current()
    ) {
        self.configuration = configuration
        self.transport = transport
        self.stateStore = stateStore
        self.secureStore = AppAnalyticsSecureStore(service: configuration.keychainService)
        self.encoder = Self.makeEncoder()
        self.decoder = Self.makeDecoder()
        self.now = now
        self.clientContext = clientContext
    }

    public func track(
        _ name: String,
        dimension: String? = nil,
        count: Int = 1
    ) async throws {
        try Self.validateEvent(name: name, dimension: dimension, count: count)
        let timestamp = now()
        var state = try await loadState()
        pruneExpiredDays(in: &state, relativeTo: timestamp)
        checkpointActiveSession(in: &state, at: timestamp)

        let dayKey = Self.dayKey(for: timestamp)
        var day = dayState(in: state, for: dayKey)
        let eventKey = Self.eventKey(name: name, dimension: dimension)

        let previousCount = day.events[eventKey]?.count ?? 0
        let nextCount = min(Limits.maxEventCountPerDay, previousCount + count)
        let currentTotal = day.events.values.reduce(0) { $0 + $1.count }
        let nextTotal = currentTotal - previousCount + nextCount
        guard nextTotal <= Limits.maxTotalEventCountPerDay else {
            throw AppAnalyticsError.invalidEvent(
                "A UTC day may contain at most \(Limits.maxTotalEventCountPerDay) total event occurrences."
            )
        }

        if var event = day.events[eventKey] {
            event.count = nextCount
            day.events[eventKey] = event
        } else {
            guard day.events.count < Limits.maxEventsPerDay else {
                throw AppAnalyticsError.invalidEvent(
                    "A UTC day may contain at most \(Limits.maxEventsPerDay) event/dimension counters."
                )
            }
            day.events[eventKey] = EventState(
                name: name,
                dimension: dimension,
                count: nextCount
            )
        }

        state.days[dayKey] = day
        try await saveState(state)
        scheduleAutomaticFlush(at: timestamp)
    }

    public func trackError(
        _ code: String,
        component: String,
        severity: AppAnalyticsErrorSeverity = .error,
        count: Int = 1
    ) async throws {
        try Self.validateError(
            code: code,
            component: component,
            count: count
        )

        let timestamp = now()
        var state = try await loadState()
        pruneExpiredDays(in: &state, relativeTo: timestamp)
        checkpointActiveSession(in: &state, at: timestamp)

        let dayKey = Self.dayKey(for: timestamp)
        var day = dayState(in: state, for: dayKey)
        var errors = day.errors ?? [:]
        let key = Self.errorKey(code: code, component: component, severity: severity)
        let previousCount = errors[key]?.count ?? 0
        let currentTotal = errors.values.reduce(0) { $0 + $1.count }
        let nextCount = min(Limits.maxTotalErrorCountPerDay, previousCount + count)
        let nextTotal = currentTotal - previousCount + nextCount

        guard nextTotal <= Limits.maxTotalErrorCountPerDay else {
            throw AppAnalyticsError.invalidError(
                "A UTC day may contain at most \(Limits.maxTotalErrorCountPerDay) total error occurrences."
            )
        }

        if var error = errors[key] {
            error.count = nextCount
            errors[key] = error
        } else {
            guard errors.count < Limits.maxErrorsPerDay else {
                throw AppAnalyticsError.invalidError(
                    "A UTC day may contain at most \(Limits.maxErrorsPerDay) error counters."
                )
            }
            errors[key] = ErrorState(
                code: code,
                component: component,
                severity: severity,
                count: nextCount
            )
        }

        day.errors = errors
        state.days[dayKey] = day
        try await saveState(state)
        scheduleAutomaticFlush(at: timestamp)
    }

    public func applicationDidBecomeActive(at timestamp: Date = Date()) async throws {
        var state = try await loadState()
        pruneExpiredDays(in: &state, relativeTo: timestamp)

        if state.session?.activeSince != nil {
            try await saveState(state)
            scheduleAutomaticFlush(at: timestamp)
            return
        }

        let shouldResume: Bool
        if let session = state.session {
            let gap = timestamp.timeIntervalSince(session.lastActivityAt)
            shouldResume = gap >= 0 && gap <= Limits.sessionTimeout
        } else {
            shouldResume = false
        }

        if shouldResume, var session = state.session {
            session.lastActivityAt = timestamp
            session.activeSince = timestamp
            state.session = session
        } else {
            let dayKey = Self.dayKey(for: timestamp)
            var day = dayState(in: state, for: dayKey)
            day.sessions = min(Limits.maxSessionsPerDay, day.sessions + 1)
            state.days[dayKey] = day
            state.session = SessionState(
                lastActivityAt: timestamp,
                activeSince: timestamp
            )
        }

        try await saveState(state)
        scheduleAutomaticFlush(at: timestamp)
    }

    public func applicationWillResignActive(at timestamp: Date = Date()) async throws {
        var state = try await loadState()
        pruneExpiredDays(in: &state, relativeTo: timestamp)
        if state.session?.activeSince != nil {
            checkpointActiveSession(in: &state, at: timestamp)
            if var session = state.session {
                session.lastActivityAt = timestamp
                session.activeSince = nil
                state.session = session
            }
        }
        try await saveState(state)
        scheduleAutomaticFlush(at: timestamp)
    }

    public func flush() async throws {
        if let automaticUploadTask {
            await automaticUploadTask.value
        }

        await acquireUploadSlot()
        defer { releaseUploadSlot() }
        try await performFlush(at: now(), force: true)
    }

    public func resetLocalState() async throws {
        try await stateStore.remove()
    }

    func pendingDayCount() async throws -> Int {
        var state = try await loadState()
        pruneExpiredDays(in: &state, relativeTo: now())
        return state.days.count
    }

    func waitForAutomaticUpload() async {
        while let automaticUploadTask {
            await automaticUploadTask.value
        }
    }

    private func scheduleAutomaticFlush(at timestamp: Date) {
        guard automaticUploadTask == nil else { return }

        automaticUploadTask = Task { [weak self] in
            guard let self else { return }
            await self.runAutomaticFlush(at: timestamp)
        }
    }

    private func runAutomaticFlush(at timestamp: Date) async {
        await acquireUploadSlot()
        try? await performFlush(at: timestamp, force: false)
        releaseUploadSlot()
        automaticUploadTask = nil
    }

    private func acquireUploadSlot() async {
        if !uploadInFlight {
            uploadInFlight = true
            return
        }

        await withCheckedContinuation { continuation in
            uploadWaiters.append(continuation)
        }
    }

    private func releaseUploadSlot() {
        guard uploadInFlight else { return }

        if uploadWaiters.isEmpty {
            uploadInFlight = false
            return
        }

        let next = uploadWaiters.removeFirst()
        next.resume()
    }

    private func performFlush(at timestamp: Date, force: Bool) async throws {
        var snapshot = try await loadState()
        pruneExpiredDays(in: &snapshot, relativeTo: timestamp)
        checkpointActiveSession(in: &snapshot, at: timestamp)

        guard !snapshot.days.isEmpty else {
            snapshot.nextUploadAttemptAt = nil
            try await saveState(snapshot)
            return
        }

        if !force {
            if let nextUploadAttemptAt = snapshot.nextUploadAttemptAt,
               timestamp < nextUploadAttemptAt {
                try await saveState(snapshot)
                return
            }
            if let lastUploadAt = snapshot.lastUploadAt,
               timestamp.timeIntervalSince(lastUploadAt) < configuration.uploadInterval {
                try await saveState(snapshot)
                return
            }
        }

        try Self.validateConfiguration(configuration)
        let currentDay = Self.dayKey(for: timestamp)
        if snapshot.days[currentDay] != nil {
            snapshot.days[currentDay] = dayState(in: snapshot, for: currentDay)
        }

        let batches = try makeBatches(from: snapshot)
        guard !batches.isEmpty else {
            try await saveState(snapshot)
            return
        }

        // Persist checkpoint/prune mutations before any network suspension. From this point
        // onward the snapshot is immutable upload input; completion merges into latest state.
        try await saveState(snapshot)
        let installationID = try await installationID()
        var acceptedHistoricalDays: Set<String> = []

        do {
            for batch in batches {
                try Task.checkCancellation()
                try await send(batch, installationID: installationID)
                acceptedHistoricalDays.formUnion(
                    batch.days.lazy.map(\.day).filter { $0 != currentDay }
                )
            }
        } catch {
            let completionTimestamp = now()
            let retryDate = Self.automaticRetryDate(
                for: error,
                relativeTo: completionTimestamp
            )
            try? await mergeUploadResult(
                acceptedHistoricalDays: acceptedHistoricalDays,
                completedAt: completionTimestamp,
                retryDate: retryDate,
                succeeded: false
            )
            throw error
        }

        try await mergeUploadResult(
            acceptedHistoricalDays: acceptedHistoricalDays,
            completedAt: now(),
            retryDate: nil,
            succeeded: true
        )
    }

    private func mergeUploadResult(
        acceptedHistoricalDays: Set<String>,
        completedAt timestamp: Date,
        retryDate: Date?,
        succeeded: Bool
    ) async throws {
        var latest = try await loadState()
        pruneExpiredDays(in: &latest, relativeTo: timestamp)

        for day in acceptedHistoricalDays {
            latest.days.removeValue(forKey: day)
        }

        if succeeded {
            latest.lastUploadAt = timestamp
            latest.nextUploadAttemptAt = nil
        } else if let retryDate,
                  latest.nextUploadAttemptAt.map({ $0 < retryDate }) ?? true {
            latest.nextUploadAttemptAt = retryDate
        }

        try await saveState(latest)
    }

    private func send(_ batch: Batch, installationID: String) async throws {
        let body = try encoder.encode(batch)
        guard body.count <= Limits.maxBodyBytes else {
            throw AppAnalyticsError.invalidConfiguration(
                "Analytics batch exceeds the \(Limits.maxBodyBytes)-byte server limit."
            )
        }

        var request = URLRequest(
            url: Self.endpointURL(baseURL: configuration.baseURL, path: "/v1/analytics/batch")
        )
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.appID, forHTTPHeaderField: "X-App-ID")
        if let appKey = configuration.appKey {
            request.setValue(appKey, forHTTPHeaderField: "X-App-Key")
        }
        request.setValue(installationID, forHTTPHeaderField: "X-Installation-ID")
        request.setValue(batch.requestId, forHTTPHeaderField: "X-Request-ID")
        if let version = resolvedAppVersion() {
            request.setValue(version, forHTTPHeaderField: "X-App-Version")
        }
        if let build = clientContext.appBuild.flatMap(Self.validNativeVersion) {
            request.setValue(build, forHTTPHeaderField: "X-App-Build")
        }

        var transportAttempts = 0
        while true {
            do {
                let (data, response) = try await transport.data(for: request)
                guard (200..<300).contains(response.statusCode) else {
                    throw Self.decodeServerError(
                        data: data,
                        response: response,
                        decoder: decoder
                    )
                }
                let decoded: BatchResponse
                do {
                    decoded = try decoder.decode(BatchResponse.self, from: data)
                } catch {
                    throw AppAnalyticsError.invalidResponse
                }
                guard decoded.ok,
                      decoded.requestId == batch.requestId,
                      decoded.acceptedDays == batch.days.map(\.day) else {
                    throw AppAnalyticsError.invalidResponse
                }
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError where error.code == .cancelled {
                throw CancellationError()
            } catch let error as AppAnalyticsError {
                switch error {
                case .transport where transportAttempts < configuration.transportRetryCount:
                    transportAttempts += 1
                    continue
                default:
                    throw error
                }
            } catch {
                if transportAttempts < configuration.transportRetryCount {
                    transportAttempts += 1
                    continue
                }
                throw AppAnalyticsError.transport(error.localizedDescription)
            }
        }
    }

    private func installationID() async throws -> String {
        let account = "\(configuration.appID).installation"
        let gateKey = "installation|\(configuration.keychainService)|\(configuration.appID)"
        await AppAnalyticsInstallationGate.shared.acquire(gateKey)
        do {
            try Task.checkCancellation()
            let value: String
            if let stored = try await secureStore.string(for: account) {
                value = stored
            } else {
                let generated = UUID().uuidString.lowercased()
                do {
                    try await secureStore.set(generated, for: account)
                    value = generated
                } catch {
                    if let racedValue = try? await secureStore.string(for: account) {
                        value = racedValue
                    } else {
                        throw error
                    }
                }
            }
            await AppAnalyticsInstallationGate.shared.release(gateKey)
            return value
        } catch {
            await AppAnalyticsInstallationGate.shared.release(gateKey)
            if let analyticsError = error as? AppAnalyticsError {
                throw analyticsError
            }
            throw AppAnalyticsError.storage("Secure analytics installation storage is unavailable.")
        }
    }

    private func loadState() async throws -> PersistedState {
        guard let data = try await stateStore.load() else { return PersistedState() }
        do {
            return try decoder.decode(PersistedState.self, from: data)
        } catch {
            try? await stateStore.remove()
            return PersistedState()
        }
    }

    private func saveState(_ state: PersistedState) async throws {
        do {
            try await stateStore.save(encoder.encode(state))
        } catch let error as AppAnalyticsError {
            throw error
        } catch {
            throw AppAnalyticsError.storage(error.localizedDescription)
        }
    }

    private func dayState(in state: PersistedState, for dayKey: String) -> DayState {
        var day = state.days[dayKey] ?? DayState()
        if let version = resolvedAppVersion() {
            day.appVersion = version
        }
        day.osVersion = Self.validNativeVersion(clientContext.osVersion)
        day.appBuild = clientContext.appBuild.flatMap(Self.validNativeVersion)
        day.deviceFamily = Self.validNativeToken(clientContext.deviceFamily)
        day.architecture = clientContext.architecture.flatMap(Self.validNativeToken)
        return day
    }

    private func checkpointActiveSession(in state: inout PersistedState, at timestamp: Date) {
        guard var session = state.session,
              let activeSince = session.activeSince,
              timestamp >= activeSince else { return }

        addActiveInterval(from: activeSince, to: timestamp, state: &state)
        session.activeSince = timestamp
        session.lastActivityAt = timestamp
        state.session = session
    }

    private func addActiveInterval(
        from start: Date,
        to end: Date,
        state: inout PersistedState
    ) {
        guard end > start else { return }
        var cursor = start
        let calendar = Self.utcCalendar

        while cursor < end {
            let startOfDay = calendar.startOfDay(for: cursor)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                return
            }
            let segmentEnd = min(end, nextDay)
            let seconds = max(0, Int(segmentEnd.timeIntervalSince(cursor)))
            if seconds > 0 {
                let key = Self.dayKey(for: cursor)
                var day = dayState(in: state, for: key)
                day.sessionSeconds = min(
                    Limits.maxSessionSecondsPerDay,
                    day.sessionSeconds + seconds
                )
                state.days[key] = day
            }
            cursor = segmentEnd
        }
    }

    private func pruneExpiredDays(in state: inout PersistedState, relativeTo timestamp: Date) {
        let today = Self.utcCalendar.startOfDay(for: timestamp)
        state.days = state.days.filter { key, _ in
            guard let date = Self.date(fromDayKey: key) else { return false }
            let age = Self.utcCalendar.dateComponents([.day], from: date, to: today).day ?? Int.max
            return age >= 0 && age <= Limits.maxOfflineAgeDays
        }

        if let session = state.session,
           session.activeSince == nil,
           timestamp.timeIntervalSince(session.lastActivityAt) > Limits.sessionTimeout {
            state.session = nil
        }
    }

    private func makeBatches(from state: PersistedState) throws -> [Batch] {
        let sortedDays = state.days.keys.sorted()
        var result: [Batch] = []
        var pending: [BatchDay] = []
        var pendingEventCounters = 0
        var pendingErrorCounters = 0

        func finishPending() {
            guard !pending.isEmpty else { return }
            result.append(
                Batch(
                    requestId: "native-\(UUID().uuidString.lowercased())",
                    days: pending
                )
            )
            pending = []
            pendingEventCounters = 0
            pendingErrorCounters = 0
        }

        for key in sortedDays {
            guard let day = state.days[key] else { continue }
            var remainingEventOccurrences = Limits.maxTotalEventCountPerDay
            let events = day.events.values
                .sorted {
                    if $0.name != $1.name { return $0.name < $1.name }
                    return ($0.dimension ?? "") < ($1.dimension ?? "")
                }
                .compactMap { event -> BatchEvent? in
                    guard remainingEventOccurrences > 0 else { return nil }
                    let count = min(
                        max(0, event.count),
                        Limits.maxEventCountPerDay,
                        remainingEventOccurrences
                    )
                    guard count > 0 else { return nil }
                    remainingEventOccurrences -= count
                    return BatchEvent(name: event.name, dimension: event.dimension, count: count)
                }

            let errors = (day.errors ?? [:]).values
                .sorted {
                    if $0.code != $1.code { return $0.code < $1.code }
                    if $0.component != $1.component { return $0.component < $1.component }
                    return $0.severity.rawValue < $1.severity.rawValue
                }
                .map {
                    BatchError(
                        code: $0.code,
                        component: $0.component,
                        severity: $0.severity,
                        count: min(max(0, $0.count), Limits.maxTotalErrorCountPerDay)
                    )
                }
                .filter { $0.count > 0 }

            guard events.count <= Limits.maxEventsPerDay else {
                throw AppAnalyticsError.invalidConfiguration(
                    "Stored analytics exceeds the per-day event-counter limit."
                )
            }
            guard errors.count <= Limits.maxErrorsPerDay,
                  errors.reduce(0, { $0 + $1.count }) <= Limits.maxTotalErrorCountPerDay else {
                throw AppAnalyticsError.invalidConfiguration(
                    "Stored analytics exceeds the per-day error limits."
                )
            }

            if !pending.isEmpty,
               (pending.count >= Limits.maxDaysPerBatch
                || pendingEventCounters + events.count > Limits.maxEventCountersPerBatch
                || pendingErrorCounters + errors.count > Limits.maxErrorCountersPerBatch) {
                finishPending()
            }

            pending.append(
                BatchDay(
                    day: key,
                    appVersion: day.appVersion,
                    osVersion: day.osVersion,
                    appBuild: day.appBuild,
                    deviceFamily: day.deviceFamily,
                    architecture: day.architecture,
                    sessions: min(day.sessions, Limits.maxSessionsPerDay),
                    sessionSeconds: min(day.sessionSeconds, Limits.maxSessionSecondsPerDay),
                    events: events,
                    errors: errors
                )
            )
            pendingEventCounters += events.count
            pendingErrorCounters += errors.count
        }

        finishPending()
        return result
    }

    private func resolvedAppVersion() -> String? {
        let candidate = configuration.appVersion
            ?? (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)
        guard let candidate,
              !candidate.isEmpty,
              candidate.count <= Limits.maxAppVersionLength,
              Self.isValidAppVersion(candidate) else { return nil }
        return candidate
    }

    private static func validateConfiguration(_ configuration: AppAnalyticsConfiguration) throws {
        guard isValidAppID(configuration.appID) else {
            throw AppAnalyticsError.invalidConfiguration(
                "appID must match the server app identifier format."
            )
        }
        if let appKey = configuration.appKey {
            guard appKey.count >= 16, appKey.count <= 512 else {
                throw AppAnalyticsError.invalidConfiguration(
                    "appKey must contain between 16 and 512 characters when provided."
                )
            }
        }
        guard configuration.baseURL.scheme == "https"
                || configuration.baseURL.host == "localhost" else {
            throw AppAnalyticsError.invalidConfiguration("baseURL must use HTTPS.")
        }
    }

    private static func validateEvent(name: String, dimension: String?, count: Int) throws {
        guard count > 0, count <= Limits.maxEventCountPerDay else {
            throw AppAnalyticsError.invalidEvent(
                "Analytics event count must be between 1 and \(Limits.maxEventCountPerDay)."
            )
        }
        guard name.count <= Limits.maxEventNameLength, isValidEventName(name) else {
            throw AppAnalyticsError.invalidEvent(
                "Analytics event names must be lowercase snake_case and at most \(Limits.maxEventNameLength) characters."
            )
        }
        if let dimension {
            guard dimension.count <= Limits.maxDimensionLength, isValidDimension(dimension) else {
                throw AppAnalyticsError.invalidEvent(
                    "Analytics dimensions must use the server-safe character set and be at most \(Limits.maxDimensionLength) characters."
                )
            }
        }
    }

    private static func validateError(
        code: String,
        component: String,
        count: Int
    ) throws {
        guard count > 0, count <= Limits.maxTotalErrorCountPerDay else {
            throw AppAnalyticsError.invalidError(
                "Analytics error count must be between 1 and \(Limits.maxTotalErrorCountPerDay)."
            )
        }
        guard code.count <= Limits.maxErrorTokenLength, isValidErrorToken(code) else {
            throw AppAnalyticsError.invalidError(
                "Analytics error codes must be lowercase snake_case and at most \(Limits.maxErrorTokenLength) characters."
            )
        }
        guard component.count <= Limits.maxErrorTokenLength, isValidErrorToken(component) else {
            throw AppAnalyticsError.invalidError(
                "Analytics error components must be lowercase snake_case and at most \(Limits.maxErrorTokenLength) characters."
            )
        }
    }

    private static func automaticRetryDate(for error: Error, relativeTo timestamp: Date) -> Date? {
        guard let analyticsError = error as? AppAnalyticsError else { return nil }
        guard case .server(let code, _, let retryAfter) = analyticsError,
              code == "rate_limited" || code == "http_429" else { return nil }

        let seconds: TimeInterval
        if let retryAfter,
           let parsed = TimeInterval(retryAfter.trimmingCharacters(in: .whitespacesAndNewlines)),
           parsed >= 0 {
            seconds = parsed
        } else {
            seconds = Limits.defaultRateLimitBackoff
        }
        return timestamp.addingTimeInterval(seconds)
    }

    private static func decodeServerError(
        data: Data,
        response: HTTPURLResponse,
        decoder: JSONDecoder
    ) -> AppAnalyticsError {
        if let envelope = try? decoder.decode(ServerErrorEnvelope.self, from: data) {
            return .server(
                code: envelope.error.code,
                message: envelope.error.message,
                retryAfter: envelope.error.retryAfter
                    ?? response.value(forHTTPHeaderField: "Retry-After")
            )
        }
        return .server(
            code: "http_\(response.statusCode)",
            message: HTTPURLResponse.localizedString(forStatusCode: response.statusCode),
            retryAfter: response.value(forHTTPHeaderField: "Retry-After")
        )
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func dayKey(for date: Date) -> String {
        let components = utcCalendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private static func date(fromDayKey key: String) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }
        return utcCalendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    private static func eventKey(name: String, dimension: String?) -> String {
        "\(name)\u{0}\(dimension ?? "")"
    }

    private static func errorKey(
        code: String,
        component: String,
        severity: AppAnalyticsErrorSeverity
    ) -> String {
        "\(code)\u{0}\(component)\u{0}\(severity.rawValue)"
    }

    private static func validNativeVersion(_ value: String) -> String? {
        guard !value.isEmpty,
              value.count <= Limits.maxNativeContextLength,
              let first = value.unicodeScalars.first,
              isAlphaNumericASCII(first) else { return nil }
        let extra: Set<UInt32> = [46, 95, 43, 45]
        guard value.unicodeScalars.dropFirst().allSatisfy({
            isAlphaNumericASCII($0) || extra.contains($0.value)
        }) else { return nil }
        return value
    }

    private static func validNativeToken(_ value: String) -> String? {
        guard !value.isEmpty,
              value.count <= Limits.maxNativeContextLength,
              let first = value.unicodeScalars.first,
              isLowercaseASCII(first) || isDigitASCII(first) else { return nil }
        guard value.unicodeScalars.dropFirst().allSatisfy({
            isLowercaseASCII($0) || isDigitASCII($0) || $0.value == 95
        }) else { return nil }
        return value
    }

    private static func isValidErrorToken(_ value: String) -> Bool {
        guard !value.isEmpty,
              let first = value.unicodeScalars.first,
              isLowercaseASCII(first) else { return false }
        return value.unicodeScalars.dropFirst().allSatisfy {
            isLowercaseASCII($0) || isDigitASCII($0) || $0.value == 95
        }
    }

    private static func isValidAppID(_ value: String) -> Bool {
        guard value.count >= 2, value.count <= 64,
              let first = value.unicodeScalars.first,
              isLowercaseASCII(first) || isDigitASCII(first) else { return false }
        return value.unicodeScalars.dropFirst().allSatisfy {
            isLowercaseASCII($0) || isDigitASCII($0) || $0.value == 45
        }
    }

    private static func isValidEventName(_ value: String) -> Bool {
        guard !value.isEmpty,
              let first = value.unicodeScalars.first,
              isLowercaseASCII(first) else { return false }
        return value.unicodeScalars.dropFirst().allSatisfy {
            isLowercaseASCII($0) || isDigitASCII($0) || $0.value == 95
        }
    }

    private static func isValidDimension(_ value: String) -> Bool {
        guard !value.isEmpty,
              let first = value.unicodeScalars.first,
              isAlphaNumericASCII(first) else { return false }
        let extra: Set<UInt32> = [46, 95, 58, 47, 43, 45]
        return value.unicodeScalars.dropFirst().allSatisfy {
            isAlphaNumericASCII($0) || extra.contains($0.value)
        }
    }

    private static func isValidAppVersion(_ value: String) -> Bool {
        guard !value.isEmpty,
              let first = value.unicodeScalars.first,
              isAlphaNumericASCII(first) else { return false }
        let extra: Set<UInt32> = [46, 95, 43, 40, 41, 45]
        return value.unicodeScalars.dropFirst().allSatisfy {
            isAlphaNumericASCII($0) || extra.contains($0.value)
        }
    }

    private static func isLowercaseASCII(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 97 && scalar.value <= 122
    }

    private static func isUppercaseASCII(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 65 && scalar.value <= 90
    }

    private static func isDigitASCII(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 48 && scalar.value <= 57
    }

    private static func isAlphaNumericASCII(_ scalar: Unicode.Scalar) -> Bool {
        isLowercaseASCII(scalar) || isUppercaseASCII(scalar) || isDigitASCII(scalar)
    }

    private static func endpointURL(baseURL: URL, path: String) -> URL {
        let relativePath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return baseURL.appending(path: relativePath)
    }
}
