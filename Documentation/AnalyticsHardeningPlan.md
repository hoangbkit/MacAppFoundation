# Analytics Hardening Plan

This plan hardens the native macOS analytics client in PR #3 against the production `ai-proxy-server` analytics contract. The goal is reliability and server compatibility, not new analytics product features.

## Phase 1 — Retry, Backoff, and Failure Safety

Goal: make automatic uploads safe under rate limiting and transient server/network failure.

- [x] Persist an automatic-upload backoff timestamp (`nextUploadAttemptAt`).
- [x] Respect server `429 rate_limited` responses and `Retry-After` before another automatic upload attempt.
- [x] Keep explicit `flush()` forceful: it may bypass the opportunistic upload schedule and must surface errors to the caller.
- [x] Preserve pending analytics data after transport failures, 4xx/5xx responses, malformed responses, cancellation, or a partially failed multi-batch upload.
- [x] Keep successful retries idempotent with the server's cumulative `MAX()` snapshot model.

Tests:
- [x] automatic upload respects the normal upload interval
- [x] 429 sets backoff and subsequent automatic flushes do not hit transport until expiry
- [x] explicit `flush()` still attempts immediately and surfaces the server error
- [x] transient transport failure retries according to `transportRetryCount`
- [x] exhausted retries preserve local data
- [x] server failure preserves local data
- [x] partial multi-batch success/failure remains safely retryable
- [x] cancellation does not discard pending state

Exit criteria: repeated events during a server outage/rate-limit window continue to accumulate locally without creating a request storm or losing data.

**Status:** implementation and deterministic regression coverage are complete. Repository CI is manual-only; the three-lane execution pass remains part of Phase 4 final validation.

## Phase 2 — Cumulative Snapshot and Lifecycle Correctness

Goal: prove the client emits the cumulative daily snapshots the server's idempotent upsert model expects.

- [x] Verify same-day event counters are monotonic and cumulative across multiple uploads.
- [x] Verify each `name + dimension` pair accumulates independently.
- [x] Verify session count and session seconds remain cumulative across uploads.
- [x] Verify retries/resends never convert cumulative snapshots into deltas.
- [x] Verify active session duration is split correctly at UTC midnight.
- [x] Verify the 30-minute inactive gap resumes or creates a new session at the exact boundary.
- [x] Verify duplicate activation/resign notifications do not create phantom sessions or duration.
- [x] Verify state survives recreation of `AppAnalyticsClient` over the same state store.

Tests:
- [x] two same-day event uploads: second snapshot contains the cumulative count
- [x] same event with multiple dimensions produces separate counters
- [x] later session snapshot has non-decreasing sessions and session seconds
- [x] retrying/resending a snapshot produces equivalent cumulative data
- [x] session crossing UTC midnight splits seconds between two day snapshots
- [x] inactivity at <= 30 minutes resumes; > 30 minutes starts a new session
- [x] duplicate lifecycle calls are harmless
- [x] persisted state reload continues cumulative accounting
- [x] uninterrupted foreground sessions longer than 30 minutes are not expired by the inactive-session timeout

Exit criteria: generated snapshots match the server's retry-safe cumulative `MAX(existing, incoming)` storage semantics.

**Status:** implementation and deterministic regression coverage are complete. Phase 2 also fixed two lifecycle bugs found during hardening: duplicate resign notifications no longer move the inactive-session boundary, and the 30-minute timeout now expires only inactive sessions so long-running foreground sessions cannot lose duration.

## Phase 3 — Contract Limits, Retention, Identity, and Response Validation

Goal: lock the Swift client to the server's v1 validation and identity rules.

Server v1 limits to mirror:
- 32 KiB request body
- 7 days per batch
- today + previous 6 UTC days
- 50 event/dimension counters per day
- 100 event counters per batch
- 100,000 count per event/day
- 1,000 sessions per day
- 86,400 session seconds per day
- 48-character event names
- 64-character dimensions
- 64-character app versions

- [x] Test all relevant boundary values rather than only invalid event names.
- [x] Verify old days are pruned before they can be rejected by the server.
- [x] Verify 7-day and 100-counter limits produce valid batches.
- [x] Verify event/session values saturate at server caps without overflowing.
- [x] Verify `requestId` and `acceptedDays` responses match the submitted batch before data is considered accepted.
- [x] Verify structured server errors preserve code, message, and `Retry-After`.
- [x] Verify corrupt persisted state recovers to a clean state without crashing.
- [x] Verify `resetLocalState()` clears counters/session state while preserving installation identity.
- [x] Verify installation ID stays stable across client instances and concurrent first access cannot create divergent IDs.

Tests:
- [x] day age boundary: 6 days old accepted locally; 7 days old pruned
- [x] exactly 50 counters succeeds; 51st unique counter fails
- [x] 100-counter batching and seven-day upload-window boundary
- [x] event count saturation at 100,000
- [x] session count and duration saturation
- [x] event name/dimension/app-version format and length boundaries
- [x] body-size rejection before transport
- [x] mismatched response request ID rejected
- [x] missing/extra accepted days rejected
- [x] structured 401/403/429/503 error decoding
- [x] corrupt state recovery
- [x] reset semantics
- [x] stable/concurrent installation ID creation

Exit criteria: payloads produced through the public client API remain within the current server v1 contract, malformed server responses cannot cause local data to be dropped, and installation identity remains stable across resets, recreation, and concurrent first access.

**Status:** deterministic Phase 3 contract coverage is complete in `AppAnalyticsContractTests.swift`. The tests are grounded against the production `ai-proxy-server/src/analytics-contract.ts` constants and validators. Repository CI remains manual-only; execution on all three configured macOS lanes is deferred to Phase 4 final validation.

## Consolidation Pass — Cross-Phase Review

Goal: review the complete analytics diff as one system, remove stale assumptions, and tighten integration seams before final validation.

- [x] Review the full PR diff across client, lifecycle bridge, Demo integration, documentation, and all analytics regression suites.
- [x] Require `acceptedDays` to exactly equal the submitted ordered day list before any historical state is dropped; set-equivalent, reordered, duplicated, missing, or extra responses are rejected.
- [x] Add a regression proving malformed reordered acceptance does not drop pending historical state.
- [x] Add a regression proving `X-Request-ID` matches the body `requestId`.
- [x] Reconcile App Attest language everywhere: it is intentionally out of scope and the supported analytics-only server configuration uses `attestMode: disabled`.
- [x] Make analytics discoverable in the root README as a first-class package area with setup and documentation links.
- [x] Keep the reliability, lifecycle, contract, and consolidation test files separated by concern instead of introducing a shared test abstraction that would couple otherwise independent regression suites.
- [x] Preserve the no-XCUITest policy; analytics validation remains deterministic package/unit testing plus the existing Demo launch screenshot smoke test.

Review outcome: no cross-phase architecture rewrite is needed. Retry/backoff, cumulative snapshots, lifecycle accounting, retention/batching, installation identity, and Demo integration remain compatible. The only production behavior change from consolidation is stricter successful-response acceptance.

**Status:** complete. Final execution validation remains in Phase 4.

## Phase 4 — Integration Surface, Documentation, and Final Validation

Goal: make adoption safe for real Mac apps, keep analytics independent from App Attest, and complete release validation.

- [ ] Review `.managesAnalytics(_:)` lifecycle integration for duplicate app activation notifications and multi-window usage.
- [ ] Add a lightweight deterministic integration test for the lifecycle bridge if it can be done without flaky UI automation.
- [x] Document that native analytics authentication uses app ID, app key, installation ID, request ID, and optional app/build headers.
- [x] Keep App Attest out of scope for `AppAnalyticsClient`; no signing/attestation hook will be added for analytics.
- [x] Document the supported server policy: analytics apps using this client must not require App Attest; `attestMode: disabled` is the recommended analytics-only configuration.
- [x] Update `Documentation/Analytics.md` with retry/backoff, cumulative snapshot semantics, UTC retention, reset behavior, and limits.
- [x] Add analytics to the root README and Demo overview.
- [ ] Run the repository's manual CI workflow on:
  - macOS 15 Intel
  - macOS 15 Apple Silicon
  - macOS 26 Apple Silicon

Exit criteria: tests are green on all three supported CI lanes, lifecycle integration is covered without flaky UI automation, and documentation matches the server/client behavior.

## Completion Target

PR #3 is merge-ready when Phases 1–3 and the consolidation pass are complete, Phase 4 lifecycle integration/documentation work is complete, and the manual three-lane CI run succeeds.
