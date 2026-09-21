import MacAppFoundation
import SwiftUI

@MainActor
struct AnalyticsShowcaseView: View {
    @State private var serverURL = "https://analytics.133043.xyz"
    @State private var appID = ""
    @State private var appKey = ""

    @State private var eventName = ""
    @State private var eventDimension = ""
    @State private var eventCount = 1

    @State private var errorCode = ""
    @State private var errorComponent = ""
    @State private var errorSeverity = "error"
    @State private var errorCount = 1

    @State private var isSending = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Analytics")
                        .font(.system(size: 30, weight: .bold))
                    Text("Exercise the real AppAnalyticsClient against any analytics-server app. App ID and app key are entered at runtime and are not hardcoded by the Demo.")
                        .foregroundStyle(.secondary)
                }

                GroupBox("Connection") {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Server URL") {
                            TextField("https://analytics.example.com", text: $serverURL)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 360)
                        }

                        LabeledContent("App ID") {
                            TextField("required", text: $appID)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 360)
                        }

                        LabeledContent("App Key") {
                            SecureField("optional", text: $appKey)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 360)
                        }

                        Text("Leave App Key empty to test keyless native ingestion. Credentials stay only in this view state.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(6)
                }

                GroupBox("Custom Event") {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Name") {
                            TextField("generation_completed", text: $eventName)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 360)
                        }

                        LabeledContent("Dimension") {
                            TextField("optional", text: $eventDimension)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 360)
                        }

                        LabeledContent("Count") {
                            Stepper("\(eventCount)", value: $eventCount, in: 1...500)
                                .frame(width: 120)
                        }

                        Button {
                            Task { await sendEvent() }
                        } label: {
                            if isSending {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Send Event", systemImage: "paperplane.fill")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSending || trimmed(appID).isEmpty || trimmed(eventName).isEmpty)
                    }
                    .padding(6)
                }

                GroupBox("Custom Error") {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Code") {
                            TextField("model_load_failed", text: $errorCode)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 360)
                        }

                        LabeledContent("Component") {
                            TextField("generation", text: $errorComponent)
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 360)
                        }

                        LabeledContent("Severity") {
                            Picker("Severity", selection: $errorSeverity) {
                                Text("Error").tag("error")
                                Text("Fatal").tag("fatal")
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }

                        LabeledContent("Count") {
                            Stepper("\(errorCount)", value: $errorCount, in: 1...100)
                                .frame(width: 120)
                        }

                        Button {
                            Task { await sendError() }
                        } label: {
                            if isSending {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Send Error", systemImage: "exclamationmark.triangle.fill")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            isSending
                                || trimmed(appID).isEmpty
                                || trimmed(errorCode).isEmpty
                                || trimmed(errorComponent).isEmpty
                        )
                    }
                    .padding(6)
                }

                GroupBox("Local Test State") {
                    HStack {
                        Text("Clear the local cumulative snapshot for the currently entered App ID.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Reset Local State", role: .destructive) {
                            Task { await resetLocalState() }
                        }
                        .disabled(isSending || trimmed(appID).isEmpty)
                    }
                    .padding(6)
                }

                if let statusMessage {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: statusIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        Text(statusMessage)
                            .textSelection(.enabled)
                    }
                    .foregroundStyle(statusIsError ? Color.red : Color.green)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                }

                Text("Send performs an explicit flush after recording so server authentication and validation errors are surfaced here. The server's cumulative MAX semantics make the resend idempotent.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .navigationTitle("Analytics")
    }

    private func sendEvent() async {
        await perform {
            let client = try makeClient()
            let dimension = trimmed(eventDimension)
            try await client.track(
                trimmed(eventName),
                dimension: dimension.isEmpty ? nil : dimension,
                count: eventCount
            )
            try await client.flush()
            return "Event '\(trimmed(eventName))' accepted by the analytics server."
        }
    }

    private func sendError() async {
        await perform {
            let client = try makeClient()
            let severity: AppAnalyticsErrorSeverity = errorSeverity == "fatal" ? .fatal : .error
            try await client.trackError(
                trimmed(errorCode),
                component: trimmed(errorComponent),
                severity: severity,
                count: errorCount
            )
            try await client.flush()
            return "Error '\(trimmed(errorCode))' accepted by the analytics server."
        }
    }

    private func resetLocalState() async {
        await perform {
            let client = try makeClient()
            try await client.resetLocalState()
            return "Local analytics state reset for '\(trimmed(appID))'."
        }
    }

    private func perform(_ operation: () async throws -> String) async {
        isSending = true
        statusMessage = nil
        defer { isSending = false }

        do {
            statusMessage = try await operation()
            statusIsError = false
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }

    private func makeClient() throws -> AppAnalyticsClient {
        let id = trimmed(appID)
        guard !id.isEmpty else {
            throw AppAnalyticsError.invalidConfiguration("App ID is required.")
        }

        let urlText = trimmed(serverURL)
        guard let url = URL(string: urlText), url.host != nil else {
            throw AppAnalyticsError.invalidConfiguration("Server URL is invalid.")
        }

        let key = trimmed(appKey)
        return AppAnalyticsClient(
            configuration: AppAnalyticsConfiguration(
                appID: id,
                appKey: key.isEmpty ? nil : key,
                baseURL: url,
                stateStorageKey: "macappfoundation.demo.analytics.test.\(id)",
                transportRetryCount: 0
            )
        )
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
