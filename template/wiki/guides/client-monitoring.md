---
title: Client monitoring — Sentry-compatible error reporting, hang detection and the scrubber
class: compiled
covers: []                 # fill when adopting — e.g. each app's monitoring init and its entry point
last-verified: never
verified-by: boilerplate
sources: []
---

# Client monitoring

Mobile and web clients report to a tracker that speaks the Sentry protocol: hosted Sentry, or a
self-hosted server implementing the same ingest API (e.g. GlitchTip) — the client SDK is the same,
only the DSN differs. The server side, if self-hosted — compose, env file, first run — is in
[`deployment.md`](./deployment.md); source maps and SDK version pinning are in
[`native-builds.md`](./native-builds.md). This page is the client half and the invariants that keep
it from becoming a liability.

The motivating case is worth keeping in mind: users can see an app hang for many minutes and
recover (typically a flaky network or an auth lock), and *nothing on the server shows it*. A hang throws nothing, so much of the code exists to
turn "it froze" into one event with a diagnosis. If your product has no such class of problem, take
the invariants and the scrubber and skip the detector.

## Invariants

- **Off unless the DSN is set at build time.** Dev, e2e, unit tests and a release built without a
  DSN send nothing, and wrapped clients (HTTP, auth lock, realtime) are constructed *exactly* as
  before — no wrapped `fetch`, no heartbeat callback. Keep the config module separate from the SDK
  wrapper so other modules can ask "is monitoring on" without importing the SDK.
- **A start-up failure equals no DSN.** `initMonitoring()` runs before the first render, outside
  every error boundary, so a throw there is a white screen. Catch it, install no sink, and leave
  every export a no-op; the diagnostics panel then reports monitoring as off.
- **Only one file imports the SDK.** Everything else reports through a small `sink` interface, so
  watchers, the stall detector and signal listeners are plain code that unit tests import without the
  SDK and that do nothing until a sink exists.
- **Observation only — no timeouts, no retries, no reconnects.** The monitored `fetch` and lock
  wrappers change nothing about the request; a fix in this layer would hide the very hypothesis the
  stall data exists to confirm. Fixes come after the data, elsewhere.
- **No `sentry-trace` / `baggage` headers** (`tracePropagationTargets: []`) unless your gateway's
  and backend's CORS allow them. They are new request headers; refused, every request fails.
- **The user is an opaque id and nothing else**, set from the auth-state listener and cleared to
  `null` on sign-out so the next person is not filed under the last.
- **Events wait for the network instead of being dropped**: native SDKs keep envelopes on disk; a
  PWA needs an IndexedDB offline transport. If the tracker shares a host with the API, the hang that
  cuts a phone off from one cuts it off from the other.

## The hang detector (if you need one)

Register every request (HTTP client, API calls, and every wait for and hold of an auth lock) from
the moment it **starts**; the SDK's own breadcrumb is written when a request ends, so a request that
never ends is invisible to it. A stall detector ticking every ~2 s while the document is visible:

- **opens** an episode when anything in the registry is ≥ ~15 s old; the episode starts at the
  oldest stuck entry's *start*, not at detection;
- **probes** at once, then every ~30 s, capped (a few probes in parallel with a short timeout);
- **closes** only after the registry has stayed clean for a further ~15 s — a failed request is
  usually retried at once and the retry hangs too, and closing on the first clean moment would
  report one 20-minute hang as a string of 15-second ones;
- **survives the app being killed**: persist the open episode to local storage every few seconds and
  report it on next launch as `(app restarted)` — a tester who swipes the app away after ten
  minutes is the case most worth hearing about.

One event per episode, fingerprinted by *diagnosis*, with the stuck requests, how each ended, the
probe rounds and a timeline of network, foreground, realtime and auth signals. Probes target your
own services plus **two hosts per external reference — either answering counts** (one probe can
fail alone; a single false ✗ would flip a diagnosis such as "regional allowlist" into "offline").
Classify a round: any of ours answers → `client-stuck` (or `auth-lock` if the lock is what is
stuck); else foreign answers → `our-host-unreachable`; else local answers → `whitelist`; else
`offline`. A cold-start spinner that turns into a "no connection" screen after ~15 s should send a
`BootStalled` event *before* probing, again with the probe result under the same fingerprint, and
wait up to ~2 s for a flush before a retry reloads the page (a reload drops what the SDK holds).

A WebView's JS runs off the native main thread, so native ANR/App-Hang detectors never see it
blocked. A 1 s timer firing late while the app stays on screen does: ≥ 3 s is a breadcrumb, ≥ 10 s
an event; skip the first tick after returning from background (late by the whole absence).

If the auth-lock wrapper must delegate to "exactly what the auth library would choose", that
equality holds for the library version you tested — **re-check the wrapper on an upgrade**.

## Gotchas

- **Avoid regex lookbehind in browser code, scrubbers included.** Older WebViews (iOS ≤ 16.3)
  throw a SyntaxError at parse time and the app white-screens. The bug showed only in builds with a
  DSN, because Rollup drops the scrubber from the others — so test a DSN build on the oldest
  supported simulator (`xcrun simctl launch --console-pty`).
- **`@sentry/capacitor` creates the JS client asynchronously, on the web too.** A capture made
  synchronously after `init()` vanishes (the first casualty is typically the abandoned-episode
  report: read, cleared from storage, lost). Start signals and the detector only once `getClient()` exists (polled,
  capped); keep the request registry SDK-independent so requests started meanwhile keep their real
  start times.
- **Wrap `<Routes>` with the SDK's router instrumentation on first render, not at import** —
  modules evaluate before `initMonitoring()` runs and the SDK silently hands back plain `Routes`
  until its integration exists. Name transactions by pattern (`/item/:id`); by URL every item is a
  performance group of its own.
- **Context deeper than three levels is flattened to `"[Object]"`.** Keep stall contexts as flat
  lists of text lines.
- **The monitored `fetch` must call `globalThis.fetch` at call time**, not a captured reference —
  the SDK patches the global after the module is evaluated.
- **A page CSP can block the probes** (`connect-src` limited to your domain), making a PWA unable to
  tell `whitelist` from `offline`. Decide whether that is acceptable; localhost and e2e have no CSP.
- **Cross-origin timing zeros**: add `Timing-Allow-Origin` on your API origins if DNS/TCP/TLS/wait
  phases should not be reported as zeros.
- **Playwright's `page.route` breaks `no-cors` fetches that carry a body** (TypeError in ~12 ms)
  while a 204 passes. In a local hang simulation the probes look broken; that is the harness.
- **Pin the SDKs.** On iOS-via-CocoaPods the native SDK package version can be a ceiling (a later
  release may drop the podspec for SPM only), and the JS SDK must equal that package's exact peer
  version. Don't move the JS SDK across a major your self-hosted tracker cannot ingest (it may drop
  a new payload format silently). Self-hosted Sentry-protocol servers lag the hosted product, so
  check the server's supported SDK range before upgrading.

## Scrubbing

Run `beforeSend`, `beforeSendTransaction` and `beforeBreadcrumb` scrubbers that remove phones,
emails, card numbers, account numbers and tokens from text; drop query strings and fragments
wholesale (filters and API keys live there); never send request bodies, headers or cookies; keep
only the scrubbed message line of console breadcrumbs. The tracker keeps events for a retention
period and the whole project reads them — a phone number in there is personal data nobody accounts
for. If two apps need the scrubber, a hand-kept copy is a drift risk: say "change both" in the code
or share it from a library. List what is *not* masked (national ids, passport numbers, unusual phone
formats) so the next author knows the limit.

## The diagnostics panel

A hidden gesture (e.g. several taps on the version line within a short window) opens a tester
panel: what is pending and for how long, probe now, "report a hang" (a user-reported event, flushed,
whose id the tester can quote), a test event, a native crash. Hidden on purpose — a tool, not a
feature. Probing works without a DSN. A marketing/SSR site loads the browser SDK lazily by dynamic
`import()` after hydration, only on the few dynamic pages that need it and only with a DSN, so
pre-rendered pages never download it; pages that catch their own `fetch` failures need the HTTP
client integration to report 5xx responses.
