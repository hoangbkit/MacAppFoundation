# Analytics

`MacAppFoundation` includes a lightweight first-party analytics client for the native `/v1/analytics/batch` contract in `analytics-server`.

It is intentionally small: apps explicitly record product events while the foundation handles stable installation identity, foreground session accounting, local cumulative counters, bounded offline storage, and batched uploads.

## Server requirements

Register the app in `analytics-server` with the `macos` platform enabled. `AppAnalyticsClient` supports an optional native app key and intentionally does not send App Attest data. If the server requires native app-key authentication, configure `appKey`; otherwise the SDK omits `X-App-Key` entirely.

The native request uses:

- `X-App-ID`
- `X-App-Key` when `appKey` is configured
- `X-Installation-ID`
- `X-Request-ID`
- `X-App-Version` when available
- `X-App-Build` when available

No StoreKit transaction, entitlement, or App Attest assertion is sent with analytics.

## Setup

Create one client at app scope:

```swift
private let analytics = AppAnalyticsClient(
    configuration: AppAnalyticsConfiguration(
        appID: "my-app",
        baseURL: URL(string: "https://api.example.com")!
    )
)
```

When the server requires a native key, pass it explicitly:

```swift
AppAnalyticsConfiguration(
    appID: "my-app",
    appKey: "your-native-app-key",
    baseURL: URL(string: "https://api.example.com")!
)
```

Attach lifecycle management to the main app content:

```swift
ContentView()
    .managesAnalytics(analytics)
```

On macOS, lifecycle tracking uses `NSApplication.didBecomeActiveNotification` and `NSApplication.willResignActiveNotification`. It is application-level rather than window-level, so moving between windows inside the same app does not end a session.

## Events

Events are explicit:

```swift
try await analytics.track("export_completed")
try await analytics.track("generation_completed", dimension: "nano")
try await analytics.track("purchase_started", dimension: "yearly")
```

Event names must be lowercase snake case. Dimensions use the server-safe character set and are intended for bounded categories such as model, plan, feature, or export type. Do not put free-form user content, prompts, filenames, email addresses, or other high-cardinality/private values in dimensions.


## Native context

Each daily macOS snapshot automatically includes bounded runtime context when available:

- `osVersion` — for example `26.0.1`
- `appBuild` — `CFBundleVersion`
- `deviceFamily` — `mac`
- `architecture` — `arm64` or `x86_64`

`appVersion` continues to come from the explicit configuration override or `CFBundleShortVersionString`.

These values are stored with the local daily snapshot so offline uploads preserve the context associated with that day. MacAppFoundation does not collect a hardware model, serial number, RAM amount, hostname, or other device fingerprint.

## Errors

Use the dedicated bounded error stream for stable product diagnostics:

```swift
try await analytics.trackError(
    "model_load_failed",
    component: "generation"
)

try await analytics.trackError(
    "unexpected_termination",
    component: "app",
    severity: .fatal
)
```

Error `code` and `component` must be lowercase snake case. Severity is `.error` or `.fatal`. Counters are cumulative per UTC day, using the same retry-safe semantics as normal events.

Do not send exception messages, `localizedDescription`, stack traces, filesystem paths, URLs, prompts, filenames, or arbitrary metadata as error identifiers. Map failures to a small stable vocabulary such as `model_load_failed`, `database_open_failed`, or `export_failed`.

## Sessions

A session starts when the application becomes active. If the app becomes active again within 30 minutes, the existing session resumes; after a longer gap, a new session is counted.

Only active application time contributes to `sessionSeconds`. Time while another app is active is excluded.

## Upload behavior

The client stores cumulative UTC-day snapshots locally and uploads opportunistically. Defaults are aligned with the server contract:

- 6-hour upload interval
- 7 UTC days per batch
- 6-day offline age plus the current day
- 50 event/dimension counters per day
- 100 event counters per batch
- 500 maximum occurrences per event/day
- 2,000 total event occurrences per day
- 20 error counters per day
- 140 error counters per batch
- 100 total error occurrences per day
- 1,000 sessions per day
- 86,400 session seconds per day
- 32 KiB maximum request body
- 1 transport retry

Automatic uploads are best effort. Tracking and lifecycle calls suppress upload errors so analytics cannot block normal product behavior. Call `flush()` when an explicit upload operation should surface an error:

```swift
try await analytics.flush()
```

The server stores cumulative snapshots using retry-safe maximum semantics. The client therefore keeps the current UTC day cumulative and may safely resend it. Successful historical days are removed locally after acceptance.

If the server returns HTTP `429 rate_limited`, automatic uploads persist and respect the server's `Retry-After` window before trying again. Events continue accumulating locally during that backoff. Explicit `flush()` bypasses the opportunistic schedule and surfaces the server error to the caller.

## Installation identity

The client creates a random installation UUID and stores it in Keychain under `<appID>.installation`. The opaque identifier is sent to `analytics-server` so cumulative snapshots from the same app installation can be associated. It is an installation identifier, not a human identity.

The default Keychain service is:

```text
com.hoangbkit.MacAppFoundation.AppAnalytics
```

Override `keychainService` when an app needs to share the same installation identity with another native client layer.

## Local state

Daily counters use `UserDefaults` by default. Supply an `AppAnalyticsStateStoring` implementation when the app needs a different local store or deterministic tests.

To clear local counters without changing the installation identity:

```swift
try await analytics.resetLocalState()
```

Corrupt local analytics state is discarded safely rather than crashing the app. The installation identity remains in Keychain and is not affected by `resetLocalState()`.

## Privacy boundary

The client automatically collects only the bounded native context documented above: OS version, app build, `mac` device family, and CPU architecture. It does not collect screen names, text content, hardware model, serial number, hostname, IP addresses, contacts, files, prompts, exception text, stack traces, or purchase receipts. Apps decide which bounded event names, dimensions, and error codes to record.

Review each shipping app's App Privacy answers and privacy policy based on the events that app actually sends; adding this package does not make every possible analytics field appropriate to collect.
