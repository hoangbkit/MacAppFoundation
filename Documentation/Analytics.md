# Analytics

`MacAppFoundation` includes a lightweight first-party analytics client for the native `/v1/analytics/batch` contract in `ai-proxy-server`.

It is intentionally small: apps explicitly record product events while the foundation handles stable installation identity, foreground session accounting, local cumulative counters, bounded offline storage, and batched uploads.

## Server requirements

A native analytics-only app can be configured without commerce and without App Attest. It still needs a server app ID and app key.

Example server shape:

```yaml
analytics:
  enabled: true
  webOrigins: []
attestMode: disabled
capabilities: []
products: []
creditProducts: []
```

The native request uses:

- `X-App-ID`
- `X-App-Key`
- `X-Installation-ID`
- `X-App-Version` when available
- `X-App-Build` when available

No StoreKit transaction or entitlement is required for analytics ingestion.

## Setup

Create one client at app scope:

```swift
private let analytics = AppAnalyticsClient(
    configuration: AppAnalyticsConfiguration(
        appID: "my-app",
        appKey: "your-native-app-key",
        baseURL: URL(string: "https://api.example.com")!
    )
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
- 32 KiB maximum request body
- 1 transport retry

Automatic uploads are best effort. Tracking and lifecycle calls suppress upload errors so analytics cannot block normal product behavior. Call `flush()` when an explicit upload operation should surface an error:

```swift
try await analytics.flush()
```

Successful historical days are removed locally. The current UTC day remains cumulative so later uploads can safely send an updated snapshot.

## Installation identity

The client creates a random installation UUID and stores it in Keychain under `<appID>.installation`. The raw identifier is sent only to your server, which hashes it before analytics persistence.

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

## Privacy boundary

The client does not automatically collect screen names, text content, device fingerprints, IP addresses, contacts, files, prompts, or purchase receipts. Apps decide which bounded event names and dimensions to record.

Review each shipping app's App Privacy answers and privacy policy based on the events that app actually sends; adding this package does not make every possible analytics field appropriate to collect.
