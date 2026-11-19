# PLAN v1.8.0

## Goal

Bring this repo's analytics to feature parity with the platform-neutral parts of AppFoundation's 1.7.0 analytics release, and show the new capabilities in the Demo app. Decide the implementation yourself — inspect the code and follow the repo's existing patterns.

## Reference

`/Users/hoangbkit/Developer/AppFoundation` at tag `1.7.0` (commit `c8a2575`, "Improve analytics lifecycle, storage, and runtime controls"). That release added a runtime enable/disable API, an opt-in in-memory storage mode with an in-memory state store and installation ID, and a shorter default upload interval. Read it as a reference; don't copy it blindly.

## Required outcomes

- **Runtime on/off.** Users can enable or disable analytics at runtime without reinstalling the client. Disabling takes effect immediately, clears pending local data, performs no final upload, and leaves the installation identity unchanged.

- **In-memory storage mode.** Opt-in mode keeps the install ID and daily counters entirely in memory, touches neither Keychain nor UserDefaults, and yields a fresh ID and empty counters for each new client. Persisted mode stays the default and unchanged. An explicitly injected state store must still win over the storage mode.

- **Faster uploads.** Default upload interval becomes 20 seconds. Keep existing retry/backoff, batching, retention, and best-effort automatic upload behavior intact.

- **Safe disable.** Turning analytics off mid-flight must not let in-flight work write or upload afterwards. Preserve source compatibility — all new parameters must be defaulted.

- **Tests.** Update or add tests in `Tests/MacAppFoundationTests` covering the new behaviors.

- **Demo app.** Add a user-facing analytics On/Off toggle in `DemoSettingsView` using the new runtime API. In Developer Tools → Analytics inspector, add a Storage Mode picker (Persisted / In Memory), a Send Test Event button, and a Flush Now button, with a short explanation of in-memory lifetime. Because storage mode is chosen at client creation, make the Demo's client replaceable and re-inject it into every scene that currently calls `.managesAnalytics`, so switching modes takes effect everywhere.

- Backward compatibility matters: existing initializers must keep compiling unchanged.

## Notes

- Update changelog and readme when finish.
- Do not run builds or tests, I'll handle that myself. 
- Do not commit or push.
