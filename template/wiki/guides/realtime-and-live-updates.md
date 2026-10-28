---
title: Realtime and live updates on the client
class: compiled
covers: []                 # fill when adopting: the realtime helper, the query client defaults
last-verified: never
verified-by: boilerplate
sources: []
---

# Realtime and live updates on the client

How a React client consumes a push channel (a database-change feed over websockets, a hub or SSE
stream, a push notification) without ending up showing yesterday's state. Examples use a
database-change subscription (a Postgres-changes feed, e.g. Supabase Realtime); the rules are
transport-agnostic. The server half — a table must be
opted into the feed, and row-level security gates each event — is in
[`backend-howto.md`](./backend-howto.md) and [`security-rls-checklist.md`](./security-rls-checklist.md).

## The governing rule: the push is an accelerator, the query is the truth

Delivery on these channels is fire-and-forget: an event reaches the sockets connected at that
instant and is never replayed. A backgrounded tab's throttled timers let the heartbeat slip, the
socket is dropped, the client rejoins, and every change that fired *inside the gap* is gone for
good. So:

- **No screen may depend on an event arriving.** Events *invalidate queries*; they do not carry
  state into the UI. (A hub that sends "state changed, refetch" is the clean form.)
- **Keep the polling that settles an operation** even when a push exists. A failed or rejected
  command often emits no event at all, so a socket-only client hangs forever on exactly the
  errors.
- **Refetch on every (re)subscribe.** The subscribe-status callback fires on the first join *and*
  on each rejoin; wrap every subscription in one helper that invalidates the query there. A bare
  `.subscribe()` is the defect. Error and teardown statuses deliberately do not refetch.
- **Two heal contours, neither replaces the other.** The client's refetch-on-window-focus fires only
  when the user *returns* to the tab; the rejoin refetch repairs a screen that stayed focused
  through the gap. Do not remove one because the other exists.

## A heal narrower than its handler is worse than no heal

Hoist **one named `invalidate` closure** and hand the *same reference* to every event handler and to
the rejoin helper, so the two cannot drift apart. A subscription whose heal is a different function
drifts: if its re-read filters out soft-deleted rows, an entity deleted inside a socket gap comes
back as "no row", and the app routes the user to "finish registering" instead of signing them out.
**"Deleted" and "absent" are different facts with opposite consequences**, so a heal that re-reads
a soft-deletable row must not filter the flag its handler branches on.

The rejoin heal is also not a rare interleaving: the first-join status fires on every sign-in, so a
profile re-read runs on every login and, if it shares a "latest wins" counter with the login's own
load, supersedes it every time ([`client-state-races.md`](./client-state-races.md)).

## One topic, one subscriber

Many channel servers serve a single channel per topic name per socket. A second component joining
the same topic evicts the first, which rejoins, which evicts it back — an endless loop, and each
rejoin fires the refetch helper, so it presents as a **re-render storm** (an e2e "element was
detached" timeout), not as an error anywhere near the channel.

- Exactly one owner subscribes. Every passive reader takes a **query-only variant of the same hook**
  (`useStatus` owns the channel; `useStatusQuery` only reads), sharing the query key so it still
  sees every update the owner writes. A component that only displays state never opens a channel.
- **A topic reused across a remount fails silently instead.** Channel removal is async and drops
  *by topic*, so when the old cleanup and the new effect share a commit, the stale removal evicts
  the new channel, which never joins. Make the topic per-mount (`mountTopic(base)` appends a
  counter). Only a test against the real client library catches this; a mocked channel cannot.

## Two subscription shapes — pick by what is watched

1. **List invalidate.** Any insert/update/delete on the table invalidates the query key wholesale.
   Cheap to write, refetches on every change: for lists other users can affect, not for
   high-frequency tables.
2. **Filtered, direct state update.** Subscribe with a row filter (`id=eq.<id>`) and apply the
   payload straight into local state. Used for the current user's own profile, where refetching the
   whole session on every unrelated change elsewhere would be wasteful. With no query to
   invalidate, its heal has to re-read the row and feed it to the *same* branch function the event
   handler runs.

## Gotchas that look like client bugs

- **Enabling the feed is a prerequisite, not a detail.** A subscription connects and reports
  `SUBSCRIBED` even when the table is not in the publication — and then never receives an event.
  Nothing errors; the feature just looks like it does nothing. Put the opt-in in the same migration
  that creates the table.
- **Row-level security gates realtime.** A row invisible to a client under RLS produces *nothing* on
  that client's subscription — no error, no close event. Both a live sign-out and the rejoin
  re-read fail silently if the policy hides the user's own (just soft-deleted) row from them. If
  realtime looks dead specifically for a row a mutation just hid from its own owner, check the
  policy before the client code.
- **A push for an event you do not recognise must not crash the screen.** Treat the payload like any
  other server value ([`api-contract.md`](./api-contract.md) — never trust the union).
- **Authentication on the socket.** A browser cannot set headers on a WebSocket handshake, so the
  token travels as a query parameter; the gateway must read it from there, and access logs must
  not record that parameter.

## Checklist

- [ ] Every subscription goes through the helper that refetches on subscribe
- [ ] One named invalidate function is shared by all handlers and the helper
- [ ] Exactly one subscriber per topic; passive readers use the query-only hook
- [ ] The table is in the feed's publication, in the same migration that creates it
- [ ] A settled operation does not wait on an event: it polls or refetches
- [ ] Per-mount topics wherever a component can remount within one commit
