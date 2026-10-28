---
title: Realtime Channel Testing on Devices
class: compiled
covers: []   # fill when adopting: the realtime client, its debug panel, the server-side channel endpoint and its debug logging
last-verified: never
verified-by: boilerplate
sources: []
---

# Realtime Channel Testing on Devices

A test plan for a long-lived realtime channel (WebSocket, Server-Sent Events, or a hub library
layered on them) on real iOS and Android builds. Desktop-browser verification against a local mock
cannot answer what the OS does when it takes the app away, when the radio changes, and when the phone
decides an idle socket is not worth keeping. What is being tested is a **connection**, so almost
every scenario is "put the connection in a state the OS controls, then check both ends agree about
what happened". Automated reconnect and delivery behaviour in the browser is
[e2e-writing.md](./e2e-writing.md) (park the observer before the trigger); this page is the manual,
on-device half. Terms used below: "server" is whatever terminates the channel (a hub, a gateway, a
broker); "push" is a message the server sends unprompted.

## What "working" means: an accelerator, never a transport

Design the channel as an **accelerator**. A missed event costs latency and nothing else: a periodic
poll of the authoritative state and the poll on each async command both still run and stay
authoritative. Then a scenario fails only when the app ends up **wrong**, not slow:

- **Bug:** the screen shows an entity that has ended, or hides one that is running, and stays that way.
- **Bug:** a command spins forever, or reports failure for something that succeeded.
- **Bug:** the app signs the user out on resume.
- **Not a bug:** the update took a few seconds longer. **Not a bug:** the socket dropped — it is
  supposed to, and to come back.

Record slow cases anyway: a scenario that is always slow tells you the socket is dead in that state,
which you want to know before the real backend is in the loop. If the channel is *not* an accelerator
in your design (it is the only transport), the pass criteria get stricter and this page's "slow is
fine" does not apply — decide that first.

## Setup

- **Build** against the API base whose realtime endpoint is derived from it; no separate WebSocket
  setting should exist. Mind the proxy prefix (the proxy may strip it).
- **Server debug logging**: a default level that logs mutations, failures and everything the channel
  does, and a verbose level adding every read and ping — for chasing a specific case, not a whole
  session.
- **Token lifetime on the test box**: if the server closes a socket when its token expires, a short
  local default produces dozens of reconnects an hour and buries the kind of drop you are looking
  for. Raise it on the test box.
- **Watch the server** (container logs) **and the phone**: ship an in-app **debug panel** with a
  status pill, connection id, connect/failure counts, event counts, a running log of the last N
  connection events, and three buttons — **Reconnect** (the only way to force one without waiting),
  **Reset** (zero counters before a scenario), **Copy** (the whole report as text, for pasting into a
  bug). Diagnostics may be English and unstyled; it is tooling, so gate it behind a debug flag and
  remove it once the channel is stable.

## Reading the two logs together

A healthy server sequence: connection accepted (upgrade ok) → authenticated → subscribed or
handshake ok → HTTP mutation → push(es). Lines worth knowing by sight:

- *token from query* is the browser path (the browser WebSocket API cannot set an `Authorization`
  header); *token from header* would mean a non-browser client.
- **`DROPPED … no socket connected`** — the server had something to say and nobody was listening.
  Expected while the app is backgrounded or offline, and covered by the re-read on reconnect. It is
  **a real bug only if the phone's panel says online at that moment**: then the two ends disagree, the
  socket is a zombie, and nothing but the poll is saving the screen.
- Close codes: 1000 clean, 1001 usually the app going to the background, 1006 died without a close
  frame (a proxy, a tunnel, the radio).
- "up 14m, 56 pings" on a disconnect line is a socket that lived and talked; "0 pings" means it never
  really worked.

Phone side, the same story reads `connected → disconnected → connect-failed 401 → token-refreshed ok
→ connected`. That cycle at the token lifetime is normal if the server enforces "a socket must not
outlive its token".

**If your channel is SignalR (ASP.NET Core)**, three details change how the logs read:

- A connection starts with an HTTP *negotiate* request before the transport upgrade, so a healthy
  sequence is negotiate ok → upgrade ok → connected → handshake ok. A failure at negotiate is an HTTP
  status (401, a proxy 502) and never reaches the socket.
- Browser clients pass the access token as an `access_token` query-string parameter for WebSockets
  and SSE; the server must be configured to read it from there for hub routes, and the URL then
  appears in proxy and server access logs — redact it.
- The server closes a socket on token expiry only if it is configured to
  (`CloseOnAuthenticationExpiration`); without it a socket outlives its token and the "cycle at the
  token lifetime" described here never shows up.

## Scenario matrix

Capture for each: the panel's Copy output, the matching slice of the server log, and a screenshot if
something looked wrong. Nothing else is meaningful until block A passes.

| Block | Scenarios | Expected |
|---|---|---|
| **A Baseline** | install, sign in, open panel; start/stop an entity from a second device; start/stop one on the phone | online, a connection id, unprompted updates within ~1 s, push lines in the log, counters rise |
| **B Token lifecycle** | stay open past the token lifetime; stay open an hour; sign out and in | the reconnect cycle repeats cleanly, failures-since stays 0, no sign-out; old socket closed, new one under the new token |
| **C App lifecycle** | background 30 s / 5 min / 30+ min / overnight; lock screen 10 min; change state from another device **while backgrounded**; force-quit; phone call; app switcher; Android back-out and reopen | either the socket survived or it reconnects in a second or two, **and the screen is correct** — the reconnect re-reads state, it does not wait for the next poll. An app that returns offline and stays offline is a bug |
| **D Network** | airplane mode; Wi-Fi ↔ cellular; lossy signal (lift, metro); captive portal; VPN on/off; server killed for 2 minutes then restarted | reconnect once the radio is back; attempts back off rather than hammering; **a captive portal (requests "succeed" with the portal's HTML) must not sign the user out**; the app recovers by itself after a server restart |
| **E Correctness without the socket** | start a command then background immediately; start a command then airplane mode for 20 s; mash Reconnect; two phones on one account; phone plus desktop browser on one account | the command settles correctly or fails cleanly with a retry — never a wrong result; no duplicate sockets per device on the server; every device gets every push |
| **F Wear** | an hour foregrounded; low-power mode; Android battery "optimised" vs "unrestricted"; split screen | connects count about one per token lifetime and battery drop; whether power settings change block C |

Notes that decide order of work: block C passing does not imply longer waits pass, because iOS
suspension and Android Doze escalate with time, not linearly; battery-optimisation settings can change
results silently and testers' phones will not all be set the same; E is the block that decides whether
any of this is safe — a command in flight when the connection dies must settle correctly or fail
cleanly, never report the wrong outcome.

## Known and expected — do not report these

- A reconnect every token lifetime, when the server closes expired-token sockets by design.
- One 401 per reconnect (the client learning the token died) — one wasted request, not an error.
- A brief "connecting" after any resume.

## What to do with the results

Anything in C or D that ends with the app **wrong** rather than slow is a client bug. Anything that
turns out to depend on how the backend is configured — how long tokens live, whether the server
closes on expiry, what it replays after a reconnect (nothing, on most servers) — goes into the notes for
the backend team: device behaviour is the best argument you will have for answering those questions
one way or the other. Keep a dated results section on the page listing what passed, what was not run
and *why* (by judgement, e.g. an hour of token cycles adds only a leak, which the wear block would
catch better), and what is still open in the order worth doing.
