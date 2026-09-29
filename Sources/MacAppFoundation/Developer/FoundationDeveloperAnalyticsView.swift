#if DEBUG
import AppKit
import SwiftUI

@MainActor
struct FoundationDeveloperAnalyticsView: View {
    @Environment(\.macAppTheme) private var theme

    let analytics: AppAnalyticsClient?

    @ObservedObject private var activityStore = AppAnalyticsDeveloperActivityStore.shared
    @State private var snapshot: AppAnalyticsDeveloperSnapshot?
    @State private var loadError: String?
    @State private var actionStatus: String?
    @State private var actionStatusIsError = false
    @State private var isFlushing = false
    @State private var resetConfirmationPresented = false

    private let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    var body: some View {
        Group {
            if let analytics {
                configuredView
                    .task {
                        await refreshLoop(analytics)
                    }
            } else {
                ContentUnavailableView(
                    "Analytics Not Connected",
                    systemImage: "chart.bar.xaxis",
                    description: Text(
                        "Attach the app-scoped analytics client to the Developer Tools scene with .managesAnalytics(analytics)."
                    )
                )
                .background(theme.canvas)
            }
        }
        .toolbar {
            if let analytics {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        Task { await refresh(analytics) }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Refresh the local analytics snapshot")

                    Button {
                        Task { await flush(analytics) }
                    } label: {
                        if isFlushing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Flush", systemImage: "arrow.up.circle")
                        }
                    }
                    .disabled(isFlushing)
                    .help("Flush pending analytics to the configured server")

                    Button {
                        copySnapshot()
                    } label: {
                        Label("Copy Snapshot", systemImage: "doc.on.doc")
                    }
                    .disabled(snapshot == nil)
                }
            }
        }
        .confirmationDialog(
            "Reset Local Analytics State?",
            isPresented: $resetConfirmationPresented
        ) {
            Button("Reset Local State", role: .destructive) {
                if let analytics {
                    Task { await resetLocalState(analytics) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears locally stored analytics counters and session state. The installation identity is preserved.")
        }
    }

    @ViewBuilder
    private var configuredView: some View {
        if let snapshot {
            List {
                configurationSection(snapshot.configuration)
                runtimeSection(snapshot.runtime)
                liveActivitySection
                storedDaysSection(snapshot.days)
                developerActionsSection
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(theme.canvas)
        } else if let loadError {
            ContentUnavailableView(
                "Analytics Snapshot Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text(loadError)
            )
            .background(theme.canvas)
        } else {
            ProgressView("Loading analytics…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.canvas)
        }
    }

    private func configurationSection(
        _ configuration: AppAnalyticsDeveloperSnapshot.Configuration
    ) -> some View {
        Section("Configuration") {
            LabeledContent("Enabled", value: configuration.enabled ? "Yes" : "No")
            copyableValue("App ID", configuration.appID)
            copyableValue("App key", configuration.appKey ?? "Not configured")
            copyableValue("Server", configuration.baseURL.absoluteString)
            copyableValue("Batch endpoint", configuration.endpointURL.absoluteString)
            LabeledContent(
                "Configured app version",
                value: configuration.configuredAppVersion ?? "Automatic"
            )
            LabeledContent(
                "Resolved app version",
                value: configuration.resolvedAppVersion ?? "Unavailable"
            )
            LabeledContent(
                "Upload interval",
                value: durationLabel(configuration.uploadInterval)
            )
            LabeledContent("Transport retries", value: "\(configuration.transportRetryCount)")
            copyableValue("State storage key", configuration.stateStorageKey)
            copyableValue("Keychain service", configuration.keychainService)
        }
    }

    private func runtimeSection(
        _ runtime: AppAnalyticsDeveloperSnapshot.Runtime
    ) -> some View {
        Section("Runtime") {
            copyableValue("Installation ID", runtime.installationID ?? "Not created")

            if let installationIdentityError = runtime.installationIdentityError {
                LabeledContent("Installation identity error") {
                    Text(installationIdentityError)
                        .foregroundStyle(theme.destructive)
                        .textSelection(.enabled)
                }
            }

            LabeledContent("OS", value: runtime.osVersion)
            LabeledContent("Build", value: runtime.appBuild ?? "Unavailable")
            LabeledContent("Device family", value: runtime.deviceFamily)
            LabeledContent("Architecture", value: runtime.architecture ?? "Unavailable")
            LabeledContent("Active session", value: runtime.activeSession ? "Yes" : "No")
            LabeledContent(
                "Session active since",
                value: dateLabel(runtime.sessionActiveSince)
            )
            LabeledContent(
                "Last session activity",
                value: dateLabel(runtime.sessionLastActivityAt)
            )
            LabeledContent("Stored UTC days", value: "\(runtime.pendingDayCount)")
            LabeledContent("Last upload", value: dateLabel(runtime.lastUploadAt))
            LabeledContent(
                "Next automatic attempt",
                value: dateLabel(runtime.nextUploadAttemptAt)
            )
            LabeledContent(
                "Automatic upload task",
                value: runtime.automaticUploadScheduled ? "Scheduled" : "Idle"
            )
            LabeledContent(
                "Upload pipeline",
                value: runtime.uploadInFlight ? "In flight" : "Idle"
            )
        }
    }

    private var liveActivitySection: some View {
        Section {
            if activityStore.entries.isEmpty {
                Text("No analytics activity captured yet.")
                    .foregroundStyle(theme.textSecondary)
            } else {
                ForEach(activityStore.entries.reversed()) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(timestampFormatter.string(from: entry.timestamp))
                                .font(.caption.monospaced())
                                .foregroundStyle(theme.textMuted)

                            Text(entry.kind.rawValue)
                                .font(.caption.weight(.semibold))

                            Text(entry.title)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)

                            Spacer()
                        }

                        if let detail = entry.detail {
                            Text(detail)
                                .font(.caption.monospaced())
                                .foregroundStyle(theme.textSecondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            HStack {
                Text("Live Activity")
                Spacer()
                Text("\(activityStore.entries.count) / 500")
                    .font(.caption)
                    .foregroundStyle(theme.textMuted)
            }
        } footer: {
            Text("Debug-only stream of analytics events, errors, lifecycle changes, uploads, resets, and failures captured by the live AppAnalyticsClient.")
                .foregroundStyle(theme.textSecondary)
        }
    }

    private func storedDaysSection(
        _ days: [AppAnalyticsDeveloperSnapshot.Day]
    ) -> some View {
        Section("Persisted Cumulative State") {
            if days.isEmpty {
                Text("No locally stored analytics counters.")
                    .foregroundStyle(theme.textSecondary)
            } else {
                ForEach(days) { day in
                    DisclosureGroup {
                        LabeledContent("Sessions", value: "\(day.sessions)")
                        LabeledContent("Session seconds", value: "\(day.sessionSeconds)")
                        LabeledContent("App version", value: day.appVersion ?? "Unavailable")
                        LabeledContent("OS", value: day.osVersion ?? "Unavailable")
                        LabeledContent("Build", value: day.appBuild ?? "Unavailable")
                        LabeledContent("Device", value: day.deviceFamily ?? "Unavailable")
                        LabeledContent("Architecture", value: day.architecture ?? "Unavailable")

                        if !day.events.isEmpty {
                            Text("Events")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.textSecondary)

                            ForEach(day.events) { event in
                                LabeledContent(eventTitle(event)) {
                                    Text("\(event.count)")
                                        .monospacedDigit()
                                }
                            }
                        }

                        if !day.errors.isEmpty {
                            Text("Errors")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.textSecondary)

                            ForEach(day.errors) { error in
                                LabeledContent(errorTitle(error)) {
                                    Text("\(error.count)")
                                        .monospacedDigit()
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(day.day)
                                .font(.body.monospaced())
                            Spacer()
                            Text(
                                "\(day.events.count) events · \(day.errors.count) errors · \(day.sessions) sessions"
                            )
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var developerActionsSection: some View {
        Section("Developer Actions") {
            Button("Clear Live Activity", systemImage: "eraser") {
                activityStore.clear()
                actionStatus = "Live analytics activity cleared."
                actionStatusIsError = false
            }
            .disabled(activityStore.entries.isEmpty)

            Button("Reset Local State", systemImage: "trash", role: .destructive) {
                resetConfirmationPresented = true
            }

            if let actionStatus {
                Label(
                    actionStatus,
                    systemImage: actionStatusIsError
                        ? "xmark.circle.fill"
                        : "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(actionStatusIsError ? theme.destructive : theme.success)
                .textSelection(.enabled)
            }
        }
    }

    private func refreshLoop(_ analytics: AppAnalyticsClient) async {
        while !Task.isCancelled {
            await refresh(analytics, updateStatus: false)
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func refresh(
        _ analytics: AppAnalyticsClient,
        updateStatus: Bool = true
    ) async {
        do {
            snapshot = try await analytics.developerSnapshot()
            loadError = nil
            if updateStatus {
                actionStatus = "Analytics snapshot refreshed."
                actionStatusIsError = false
            }
        } catch {
            loadError = error.localizedDescription
            if updateStatus {
                actionStatus = error.localizedDescription
                actionStatusIsError = true
            }
        }
    }

    private func flush(_ analytics: AppAnalyticsClient) async {
        isFlushing = true
        actionStatus = nil
        defer { isFlushing = false }

        do {
            try await analytics.flush()
            await refresh(analytics, updateStatus: false)
            actionStatus = "Analytics flush completed."
            actionStatusIsError = false
        } catch {
            await refresh(analytics, updateStatus: false)
            actionStatus = error.localizedDescription
            actionStatusIsError = true
        }
    }

    private func resetLocalState(_ analytics: AppAnalyticsClient) async {
        do {
            try await analytics.resetLocalState()
            await refresh(analytics, updateStatus: false)
            actionStatus = "Local analytics state reset. Installation identity preserved."
            actionStatusIsError = false
        } catch {
            actionStatus = error.localizedDescription
            actionStatusIsError = true
        }
    }

    private func eventTitle(
        _ event: AppAnalyticsDeveloperSnapshot.Event
    ) -> String {
        if let dimension = event.dimension {
            return "\(event.name) [\(dimension)]"
        }
        return event.name
    }

    private func errorTitle(
        _ error: AppAnalyticsDeveloperSnapshot.TrackedError
    ) -> String {
        "\(error.code) [\(error.component) · \(error.severity.rawValue)]"
    }

    @ViewBuilder
    private func copyableValue(_ title: String, _ value: String) -> some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                Text(value)
                    .textSelection(.enabled)
                Button {
                    copyToPasteboard(value)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy \(title.lowercased())")
            }
        }
    }

    private func durationLabel(_ interval: TimeInterval) -> String {
        if interval == 0 { return "Immediate" }
        if interval.truncatingRemainder(dividingBy: 60) == 0 {
            return "\(Int(interval / 60)) min"
        }
        return "\(Int(interval)) sec"
    }

    private func dateLabel(_ date: Date?) -> String {
        guard let date else { return "None" }
        return timestampFormatter.string(from: date)
    }

    private func copySnapshot() {
        guard let snapshot else { return }

        var lines = [
            "Analytics",
            "Enabled: \(snapshot.configuration.enabled)",
            "App ID: \(snapshot.configuration.appID)",
            "App key: \(snapshot.configuration.appKey ?? "Not configured")",
            "Server: \(snapshot.configuration.baseURL.absoluteString)",
            "Endpoint: \(snapshot.configuration.endpointURL.absoluteString)",
            "State storage key: \(snapshot.configuration.stateStorageKey)",
            "Keychain service: \(snapshot.configuration.keychainService)",
            "Installation ID: \(snapshot.runtime.installationID ?? "Not created")",
            "Active session: \(snapshot.runtime.activeSession)",
            "Last upload: \(dateLabel(snapshot.runtime.lastUploadAt))",
            "Next automatic attempt: \(dateLabel(snapshot.runtime.nextUploadAttemptAt))",
            ""
        ]

        for day in snapshot.days {
            lines.append("UTC day \(day.day)")
            lines.append("  sessions=\(day.sessions) sessionSeconds=\(day.sessionSeconds)")
            for event in day.events {
                lines.append("  event \(eventTitle(event)) = \(event.count)")
            }
            for error in day.errors {
                lines.append("  error \(errorTitle(error)) = \(error.count)")
            }
        }

        copyToPasteboard(lines.joined(separator: "\n"))
        actionStatus = "Analytics snapshot copied."
        actionStatusIsError = false
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
#endif
