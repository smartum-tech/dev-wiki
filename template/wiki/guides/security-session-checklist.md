---
title: Security checklist — authentication and sessions
class: compiled
covers: []                 # fill when adopting: the sign-out helper, auth provider, native manifest/config
last-verified: never
verified-by: boilerplate
sources: []
---

# Security checklist — authentication and sessions

> **Example — adapt to your backend.** Written against a hosted auth provider (JWT access token +
> refresh token) used from a browser app and a Capacitor shell. The rules about who can revoke what,
> what a failed revoke must still clear, and where tokens may live carry over to any token-based setup.

Sibling pages: [`security-app-checklist.md`](./security-app-checklist.md) (authz, secrets,
validation, headers) and [`client-state-races.md`](./client-state-races.md) (the UI half of logout).

## Delegated, therefore verified elsewhere

Password hashing, token expiry/rotation and login rate limiting are delegated to the auth provider —
there is no custom session code in the backend to audit. Verify them in the provider's **project
configuration**, not by grepping the backend. Open the settings page and write down what is set;
"configured" is not "assumed".

## Do not plan a control around revoking someone's session: you may not be able to

Check what your SDK version actually offers. Common finding: there is **no admin-side revocation of
another user's sessions** — the admin sign-out call takes the *target's own* token, which a server
never holds — so the only lever that ends a session from your side is banning the whole account.
Every "cut their access now" answer must therefore be an **authorization change the backend re-reads
per request**, not a session kill, and its residual window is one access-token TTL. (Worked case:
removing a user from a tenant — revoke the membership row, re-checked per request, rather than the
session.)

## A client logout must remove the stored session even when the server revoke fails

The library's `signOut()` alone does not: many auth SDKs remove the stored session only on success
or on a 401/403/404, **keep it on any other failure** (offline, 5xx, a WebView fetch that never
lands), and **resolve** `{ error }` rather than rejecting — so a `.catch()` on it never runs. The
result: login screen shown, token still stored, next cold start signed straight back in.

So every sign-out in the app goes through **one helper** that, on a failed revoke, clears the local
session by whatever route the SDK offers (if the only route is a private method, pin the SDK version
and cover it with a spec that drives the *real* client, so a rename fails there; at runtime a missing
method must throw rather than silently keep the session). Know the open gap: if the revoke is
awaited with no time limit, the local clear runs only after it settles — bound it.

**A hung refresh can resurrect a session after sign-out.** Some SDK versions save whatever a hung
refresh returns even after a sign-out. It bites on a "stalled boot" escape hatch: a local-only clear
with **no** revoke (a signOut waits on the lock the hung request holds, and a late revoke would
remove the *next* sign-in). The guard is your own: after a local clear, a session arriving through any
event **but a sign-in** is removed again, keyed on the token's session id — a sign-in takes no lock in
that version, so "disarm on the next sign-in" would let the old session, possibly another account's,
overwrite the new one. Both gone fails closed to the login screen. Upgrading the SDK is the real
fix; request it and record the spec.

A second client (an admin app) may keep a plainer logout — then say so, and note that any staff gate
which signs out non-admin profiles is **UX, not the boundary**: RLS and the server-side admin guard
remain the boundary.

## Where the token may live

- **Browser:** prefer HttpOnly or SSR-aware cookies over web storage. Two reasons, the second easy to
  miss: a token in web storage is readable by any script that reaches the page, including one that
  arrives through a dependency; and web storage does not travel with a server-rendered request, so
  "logged in" means one thing to the client and another to the server — a bug class that reproduces
  only in production.
- **Native shell exception:** WKWebView does not persist `document.cookie` for a custom scheme, so a
  cookie-backed session survives only while the app is warm; `localStorage` persists. Switching the
  shell to `localStorage` (choose the adapter **once, at module load**, by protocol or the platform
  check) is a reasonable, *accepted-not-answered* trade: the first risk — a script that reaches the
  WebView, including one from your own dependency tree, can read the refresh token — remains. Record
  that acceptance as a decision.
- ⚠️ **`localStorage` is not durable on a phone** (the OS may clear it), and a native store behind the
  same adapter would fix the eviction but **not the exposure**: a script in the WebView can call any
  plugin exactly as your code does. Encryption at rest (Keychain/Keystore-backed plugin) defends
  against extraction from the device, not against that script.
- Nothing automated exercises the shell's storage branch if the e2e suite drives desktop Chromium: a
  regression there is found on a device or not at all.
- Web storage is fine for anything that is **not** an auth credential (a pending invite token, a
  selected-tenant context, an i18n cache). The rule is about session material.

## Android: `allowBackup="false"`

The shell's session sits in WebView storage; with Auto Backup on it goes into the user's cloud backup,
restorable onto any device on the same account. Set `android:allowBackup="false"`. Check what the
flag does for your target SDK: on recent targets it may stop cloud backup but **not**
device-to-device transfer, and data-extraction rules are what exclude it.

**Checklist**
- [ ] Token expiry, refresh rotation and failed-login/OTP rate limits are configured in the provider
      project (written down, not assumed)
- [ ] Password-reset tokens expire quickly
- [ ] Any "revoke access immediately" requirement is met by a per-request authorization check, not by
      an assumed session kill
- [ ] Every client sign-out removes the stored session whatever the revoke returned; the resurrection
      guard exists wherever a local-only clear exists
- [ ] The token storage choice per surface is recorded as a decision, with its accepted exposure
- [ ] Android backup is disabled (or data-extraction rules exclude the session store)
