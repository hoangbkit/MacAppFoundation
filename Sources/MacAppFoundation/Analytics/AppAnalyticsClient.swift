import Foundation

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
        static let maxEventCountPerDay = 100_000
        static let maxSessionsPerDay = 1_000
        static let maxSessionSecondsPerDay = 86_400
        static let maxEventNameLength = 48
        static let maxDimensionLength = 64
        static let maxAppVersionLength = 64
        static let maxBodyBytes = 32 * 1024
        static let sessionTimeout: TimeInterval = 30 * 60
    }

    private struct EventState: Codable, Sendable {
        var name: String
        var dimension: String?
        var count: Int
    }

    private struct DayState: Codable, Sendable {
        var appVersion: String?
        var sessions: Int = 0
        var sessionSeconds: Int = 0
        var events: [String: EventState] = [:]
    }

    private struct SessionState: Codable, Sendable {
        var lastActivityAt: Date
        var activeSince: Date?
    }

    private struct PersistedState: Codable, Sendable {
        var days: [String: DayState] = [:]
        var session: SessionState?
        var lastUploadAt: Date?
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

    private struct BatchDay: Encodable, Sendable {
        let day: String
        let platform = "macos"
        let appVersion: String?
        let sessions: Int
        let sessionSeconds: Int
        let events: [BatchEvent]

        enum CodingKeys: String, CodingKey {
            case day
            case platform
            case appVersion
            case sessions
            case sessionSeconds
            case events
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(day, forKey: .day)
            try container.encode(platform, forKey: .platform)
            if let appVersion {
                try container.encode(appVersion, forKey: .appVersion)
            }
            try container.encode(sessions, forKey: .sessions)
            try container.encode(sessionSeconds, forKey: .sessionSeconds)
            try container.encode(events, forKey: .events)
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
    }

    init(
        configuration: AppAnalyticsConfiguration,
        transport: any AppAnalyticsTransport,
        stateStore: any AppAnalyticsStateStoring,
        now: @escaping @Sendable () -> Date
    ) {
        self.configuration = configuration
        self.transport = transport
        self.stateStore = stateStore
        self.secureStore = AppAnalyticsSecureStore(service: configuration.keychainService)
        self.encoder = Self.makeEncoder()
        self.decoder = Self.makeDecoder()
        self.now = now
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

        if var event = day.events[eventKey] {
            event.count = min(Limits.maxEventCountPerDay, event.count + count)
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
                count: min(count, Limits.maxEventCountPerDay)
            )
        }

        state.days[dayKey] = day
        try await saveState(state)
        try? await flushIfDue(at: timestamp)
    }

    public func applicationDidBecomeActive(at timestamp: Date = Date()) async throws {
        var state = try await loadState()
        pruneExpiredDays(in: &state, relativeTo: timestamp)

        if state.session?.activeSince != nil {
            try await saveState(state)
            try? await flushIfDue(at: timestamp)
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
        try? await flushIfDue(at: timestamp)
    }

    public func applicationWillResignActive(at timestamp: Date = Date()) async throws {
        var state = try await loadState()
        pruneExpiredDays(in: &state, relativeTo: timestamp)
        checkpointActiveSession(in: &state, at: timestamp)
        if var session = state.session {
            session.lastActivityAt = timestamp
            session.activeSince = nil
            state.session = session
        }
        try await saveState(state)
        try? await flushIfDue(at: timestamp)
    }

    public func flush() async throws {
        try await flush(at: now(), force: true)
    }

    public func resetLocalState() async throws {
        try await stateStore.remove()
    }

    func pendingDayCount() async throws -> Int {
        var state = try await loadState()
        pruneExpiredDays(in: &state, relativeTo: now())
        return state.days.count
    }

    private func flushIfDue(at timestamp: Date) async throws {
        try await flush(at: timestamp, force: false)
    }

    private func flush(at timestamp: Date, force: Bool) async throws {
        var state = try await loadState()
        pruneExpiredDays(in: &state, relativeTo: timestamp)
        checkpointActiveSession(in: &state, at: timestamp)

        guard !state.days.isEmpty else {
            try await saveState(state)
            return
        }

        if !force, let lastUploadAt = state.lastUploadAt,
           timestamp.timeIntervalSince(lastUploadAt) < configuration.uploadInterval {
            try await saveState(state)
            return
        }

        try Self.validateConfiguration(configuration)
        let installationID = try await installationID()
        let batches = try makeBatches(from: state)
        guard !batches.isEmpty else {
            try await saveState(state)
            return
        }

        let currentDay = Self.dayKey(for: timestamp)
        for batch in batches {
            try Task.checkCancellation()
            try await send(batch, installationID: installationID)
            for day in batch.days where day.day != currentDay {
                state.days.removeValue(forKey: day.day)
            }
        }

        state.lastUploadAt = timestamp
        try await saveState(state)
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
        request.setValue(configuration.appKey, forHTTPHeaderField: "X-App-Key")
        request.setValue(installationID, forHTTPHeaderField: "X-Installation-ID")
        request.setValue(batch.requestId, forHTTPHeaderField: "X-Request-ID")
        if let version = resolvedAppVersion() {
            request.setValue(version, forHTTPHeaderField: "X-App-Version")
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
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
                      Set(decoded.acceptedDays) == Set(batch.days.map(\.day)) else {
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
           timestamp.timeIntervalSince(session.lastActivityAt) > Limits.sessionTimeout {
            state.session = nil
        }
    }

    private func makeBatches(from state: PersistedState) throws -> [Batch] {
        let sortedDays = state.days.keys.sorted()
        var result: [Batch] = []
        var pending: [BatchDay] = []
        var pendingEventCounters = 0

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
        }

        for key in sortedDays {
            guard let day = state.days[key] else { continue }
            let events = day.events.values
                .sorted {
                    if $0.name != $1.name { return $0.name < $1.name }
                    return ($0.dimension ?? "") < ($1.dimension ?? "")
                }
                .map { BatchEvent(name: $0.name, dimension: $0.dimension, count: $0.count) }

            guard events.count <= Limits.maxEventsPerDay else {
                throw AppAnalyticsError.invalidConfiguration(
                    "Stored analytics exceeds the per-day event-counter limit."
                )
            }

            if !pending.isEmpty,
               (pending.count >= Limits.maxDaysPerBatch
                || pendingEventCounters + events.count > Limits.maxEventCountersPerBatch) {
                finishPending()
            }

            pending.append(
                BatchDay(
                    day: key,
                    appVersion: day.appVersion,
                    sessions: min(day.sessions, Limits.maxSessionsPerDay),
                    sessionSeconds: min(day.sessionSeconds, Limits.maxSessionSecondsPerDay),
                    events: events
                )
            )
            pendingEventCounters += events.count
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
        guard configuration.appKey.count >= 16, configuration.appKey.count <= 512 else {
            throw AppAnalyticsError.invalidConfiguration(
                "appKey must contain between 16 and 512 characters."
            )
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
