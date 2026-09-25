import MacAppFoundation
import SwiftUI

@MainActor
struct AnalyticsShowcaseView: View {
    let analytics: AppAnalyticsClient

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
                    Text("Exercise the same app-scoped AppAnalyticsClient used by the Demo and its MacAppFoundation-owned surfaces.")
                        .foregroundStyle(.secondary)
                }

                GroupBox("Connection") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("Server", value: "analytics.133043.xyz")
                        LabeledContent("App ID", value: "maf")
                        LabeledContent(
                            "App Key",
                            value: Bundle.main.bundleIdentifier ?? "Unavailable"
                        )

                        Text("The Demo uses its bundle identifier as the native app key and shares this one analytics client across the app.")
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
                        .disabled(isSending || trimmed(eventName).isEmpty)
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
                                || trimmed(errorCode).isEmpty
                                || trimmed(errorComponent).isEmpty
                        )
                    }
                    .padding(6)
                }

                GroupBox("Local Test State") {
                    HStack {
                        Text("Clear the Demo app's local cumulative analytics snapshot.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Reset Local State", role: .destructive) {
                            Task { await resetLocalState() }
                        }
                        .disabled(isSending)
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
            let dimension = trimmed(eventDimension)
            try await analytics.track(
                trimmed(eventName),
                dimension: dimension.isEmpty ? nil : dimension,
                count: eventCount
            )
            try await analytics.flush()
            return "Event '\(trimmed(eventName))' accepted by the analytics server."
        }
    }

    private func sendError() async {
        await perform {
            let severity: AppAnalyticsErrorSeverity = errorSeverity == "fatal" ? .fatal : .error
            try await analytics.trackError(
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
            try await analytics.resetLocalState()
            return "Local analytics state reset for 'maf'."
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

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
