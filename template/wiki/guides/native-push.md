---
title: Native push — the Capacitor plugin and the app's half
class: compiled
covers: []                 # fill when adopting — e.g. the push plugin, the client push module, entitlements
last-verified: never
verified-by: boilerplate
sources: []
---

# Native push: the plugin and the app's half

How the mobile app gets a push address and gives it back. The backend half (outbox, senders, device
registry) is a module page; building the native projects at all is
[`native-builds.md`](./native-builds.md); Apple-side capability registration is
[`native-ios-release.md`](./native-ios-release.md).

## Own plugin or the official one

The official `@capacitor/push-notifications` plugin pulls Firebase messaging into the Android build
unconditionally, and `cap sync` registers every plugin on every platform. If a product must not
contain Firebase (regional store, policy, or a deliberate vendor choice), write a small in-repo
plugin: iOS talks to APNs directly, Android uses the chosen vendor's push SDK and nothing else.
Otherwise use the official plugin and skip the rest of this section.

A plugin in the repo is a **real package**, not a shared-lib alias: `cap sync` finds plugins only
among the app's dependencies, so it is a workspace member the app depends on via `link:`, plus a
path pod in the Podfile. In the dev container mount only the plugin's `package.json` and `src` —
mounting the package root also mounts the host's `node_modules` — and make the app's Vite config
dedupe `@capacitor/core`, so there is one core instance (one plugin registry).

## Installing the plugin is the whole job

Neither platform should ask the app to edit anything, deliberately: an app that adds the plugin and
forgets a manual step builds, runs, and silently never gets a token — and whoever debugs it starts
by suspecting the server.

- **iOS** grafts the remote-notification delegate methods onto the `AppDelegate` at runtime,
  **add-only**: if a future `AppDelegate` implements one, the plugin leaves it alone and logs so
  (swapping implementations is more general and carries a recursion hazard review cannot catch).
  Foreground presentation goes through Capacitor's notification router, never by taking the single
  `UNUserNotificationCenter` delegate slot — that silently disconnects whichever plugin set it
  first, depending on load order.
- **Android** merges everything from the plugin's manifest. If the vendor SDK initialises through an
  `androidx.startup` provider, it runs before `Application.onCreate()` returns; the app needs no
  `Application` subclass, and the SDK may start its messaging service in a process with no Activity
  or WebView.

## Platform traps

- **iOS: a missing `aps-environment` is a runtime error, not a build one.** It lands in the
  registration-failure delegate as "no valid aps-environment entitlement string". The entitlement is
  in `App.entitlements`, and the App ID also needs the Push Notifications capability.
- **Android `minSdkVersion` follows the vendor SDK**, which may be higher than Capacitor's default;
  the manifest merger refuses a lower floor.
- **A vendor maven repository must be declared in the app's root `build.gradle`**, though only the
  plugin names the artifact: a transitive of a project dependency resolves against the *consumer's*
  repositories. Scope it to the vendor's group so unrelated cache misses never wait on it.
- **A project id baked at `cap sync` can ship empty.** If the Capacitor config reads a vendor
  project id from the environment into `plugins.<Name>`, the native initializer reads it back from
  the generated `capacitor.config.json` in the APK's assets. Build scripts export the root `.env`,
  so they carry it; **a hand-run `cap sync` without it ships an empty id**, and push then reports
  `unsupported` — a log line, no crash. The project id is not a secret; the service token is.
- Vendors may want the SHA-256 of **every** signing certificate (the debug one too, if the
  "release" APK is debug-signed) and may deliver only to a build that passed store moderation —
  verify before blaming the plugin.
- **Android 13+ needs `POST_NOTIFICATIONS`** before a notification can show; a token is issued
  without it and is useless, so `register()` asks first. A refusal resolves, it does not reject.
- **Keep unavailability reasons separate** — vendor app not installed, user not signed in to it,
  vendor barred from the background. They concern a *different app* on the phone and their fixes
  have nothing in common. A vendor SDK may raise them from more than one exception family; matching
  only the first turns every availability answer into `unknown`.
- Foreground pushes are **shown** on both platforms; a badge elsewhere is not live outside the
  notifications screen.

## Taps

The tap carries an **address** (`notification_id`, `route`), never content; the app marks the row
read and navigates. On Android the tap lands in a translucent trampoline activity that reads the
deep link (not exported: the PendingIntent is created in our own process). **Both platforms retain a
tap until a listener consumes it**: a tap that cold-starts the app arrives before the web layer
subscribes, and dropping it opens the home screen instead of the target. The bootstrap component
keeps its handlers in refs so the subscription depends only on who is signed in — re-subscribing per
render would drop a retained tap between `remove()` and the next `addListener()`.

The route arrives from outside the app, so accept only an absolute in-app path (`/…`, never `//host`
or a scheme) and fall back to a safe screen.

## Registration is a stream

Push starts only once the user's registration is complete (before that there is no account a
notification could be about) and restarts when the user changes, so the next account re-registers
the token and the backend moves the row. `registration` is a listener that re-posts, not a one-off:
reinstall, backup restore or the transport rotating the token can change it at any time. A failed
POST is not retried — the next launch registers again.

## Sign-out detaches the phone

Sign-out must unregister push **first**, while the access token is still valid. Without it the next
notification for this user lands on a phone someone else may be holding. Two layers inside a short
time box (about 3 s) that never throws:

- the native unregister — on iOS it stops delivery with no network at all; on Android it is the
  vendor's `deleteToken`, which needs the vendor's servers, and offline its failure is swallowed;
- the `DELETE` of the device row, whose id survives restarts in `localStorage`, **plus every
  registration POST still in flight**: sign-out bumps a session counter, a late `registration` event
  from the old session is ignored, and an in-flight POST that answers inside the box deletes the row
  it created instead of remembering it. Only inside the box: after it, the API client sends whatever
  credentials are current — possibly the next account's, which owns the same row once it registers
  the same token.

**Accepted gaps** (write yours down): a POST answering after the box leaves its row, and so does an
offline Android sign-out. The backend re-points the row at whoever registers the token next. The box
adds latency before the revoke call, whose own lack of a time limit is a gap to track in the
[`security-session-checklist.md`](./security-session-checklist.md).
