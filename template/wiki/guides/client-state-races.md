---
title: Client-side state races
class: compiled
covers: []                 # fill when adopting: the auth/session providers (every claim is about them)
last-verified: never
verified-by: boilerplate
sources: []
---

# Client-side state races

Rules for React client code that awaits something a **listener** finishes. Auth is the worked case
(sign-in, profile load, sign-out), but none of the rules is auth-specific. They were all paid for
by one defect pattern: a login button that sits on "Loading…" forever with the session in fact
established, found intermittently and never on a clean single-tab run.

## The vendor fires its listeners inside the call you are awaiting

**Auth SDKs commonly dispatch the `SIGNED_IN` event to `onAuthStateChange` subscribers from inside
`signIn(...)`, before the promise that call returns has resolved.** Nothing in your code says so, and
the natural reading of `await signIn(...)` is that nothing else can have happened yet.

A function that signs in and *then* registers a waiter for the listener to settle has registered it
after the only thing that would ever have settled it. It hangs: no error, no further network,
spinner for good — and a reload lands the user logged in, because the session was created. A second
tab broadcasting its session produces the same interleaving, which is why such reports are
intermittent.

**Await your own work, never a callback slot you fill after the await.** The robust shape: `login()`
awaits the profile load *it starts itself*, so settlement does not depend on which side of the
`await` the event landed. The smaller repair, where a stashed waiter must stay: register it
**before** the sign-in call, and settle it through one function that clears both resolve and reject
refs before calling either, so it settles at most once. A stale-session ref should stop a load that
lands after the session changed from signing out whoever is signed in now — but note that guards
only the deny path; a stale *successful* load can still set the previous user's state, so a
latest-wins guard on the success path is needed too.

## A sequence guard answers «did MY read win?», not «is the state settled?»

The "latest wins" counter — bump on entry, compare on return, drop the write if a newer read has
started — is the right answer to the first question and the wrong answer to the second. A superseded
call wrote nothing, and reporting that as a bare `undefined` makes it indistinguishable from a
completed load: a caller awaiting settlement reports the **newer** load's success. If that newer
load fails and its own call site is fire-and-forget, the failure is swallowed and the user is
navigated into the app with `profile === null` and no error shown anywhere.

Have a load report what it **did** (`'loaded' | 'superseded'`), and have the caller that needs
settlement follow the chain to the load that actually settled state. Note which way this cuts: if a
rejected waiter used to make the same interleaving fail *loudly*, then resolving on "superseded" is
a regression against that behaviour, not merely a rough edge.

## A read that bumps the shared counter must publish itself, in the same synchronous step

The chain only arrives somewhere if **every** writer of the counter also publishes its own promise as
the newest load, before the bumped sequence can be observed by anything else. **Sharing half of a
two-part protocol is worse than not sharing it at all**: the counter announces "somebody newer owns
the state" while the chain has no way to reach that somebody, so a superseded caller follows it back
to *itself*, stops, and reports a settlement that never happened.

The second writer is not hypothetical. A reconnect heal that re-reads the profile on every channel
(re)join ([`realtime-and-live-updates.md`](./realtime-and-live-updates.md)) fires on every *login*,
not only on a reconnect, so it supersedes the login's own load every time. Give both reads the
publish structurally — run each body in a shared `run()` helper that assigns the returned promise —
and keep a stop-on-self guard in the chain-following loop as a safety valve. That guard is a way to
*survive* a broken invariant, not to fix one.

## An invariant about a shared variable needs every writer, not one read carefully

A termination argument that declares the follow-the-chain-back-to-myself branch unreachable in
normal flow usually comes from reading one function and never asking who **else** writes the
counter; one grep for the counter's name shows every writer. Read every writer before you claim a
property of the variable. And state the invariant once, **on the shared ref**, as a rule binding every read that
touches it — not as a property of whichever function happened to be written first, which is how it
stayed phrased for as long as it was false.

## Logout clears this device in `finally`, and a second press joins the first

A `logout()` that rethrows a failed server revoke *before* clearing React state leaves every query
empty while `user` stays set, so the route guard never redirects — a half-logged-out app. Clear state
in `finally`, whatever the revoke did (the stored-session half of the same rule is in
[`security-session-checklist.md`](./security-session-checklist.md)). Consequences for the UI:

- keep the in-flight promise in a ref, so a second tap **joins** it rather than starting a second
  revoke; `isLoggingOut` is the pending state of whichever control started it;
- every logout control navigates to the login route with `replace: true` in its own `finally`,
  rather than relying on the route guard re-rendering; keep any drawer open until the logout settles
  — closing it first made a tap look like nothing happened;
- that navigation unmounts the control, so a "removed on this device, not revoked on the server"
  notice is mounted **once at the app root**, beside the routes. Its copy must not call this a
  failed logout: the user *is* logged out on this device;
- a fire-and-forget sign-out with no pending gate (a "your account was deleted" heal) can settle
  after a **different** account has signed in on the device, and a late success removes whatever
  session is stored then. It fails closed, but gate it if the window is reachable.

## The widened rejection surface reaches the user as one sentence

When `login()` can reject on its own read failing, on the load that superseded it failing, and on
the heal finding the account deleted, call sites that collapse every rejection into one message
("Wrong login or password") tell a deleted account its password is wrong. The outcome is right —
they cannot sign in, and were signed out — and the wording is not. Either distinguish the cases or
record the collapse as a deliberate UX choice somewhere a reader will find it; code alone records
nothing.

## Making an interleaving deterministic in a test

Reproduce it with controllable deferred promises: resolve the listener *inside* the mocked
sign-in call, hold the superseding load open, then fail it. Assert on state read **after** the
flush, not inside the `.then` — see [`frontend-testing.md`](./frontend-testing.md).
