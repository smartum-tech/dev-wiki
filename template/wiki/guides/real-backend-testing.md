---
title: Testing Against a Real Backend Environment
class: compiled
covers: []   # fill when adopting: front-end image/nginx config, runtime env template, CORS config of the environment, env examples
last-verified: never
verified-by: boilerplate
sources: []
---

# Testing Against a Real Backend Environment

Running the app — dev server, container image or e2e runner — against a real test or staging
environment (the "stand"), owned by another team or by a later phase of your own project, instead of
the mock. Two audiences: **you**, pointing a local app at the stand to check something or give a
demo, and **the stand's operators**, whom you hand a front-end image and a list of requirements. If
you operate the stand yourself, the integration note below is still the checklist for whoever sets it
up next. The mock side is [mock-server.md](./mock-server.md); the suite side is
[e2e-testing.md](./e2e-testing.md).

## What the stand has to give you, and what you have to give it

Hand the backend team one page (the "integration note") that answers, in this order:

1. **What is shipped**: one image per web surface — a static server on a plain port with **no TLS**.
   Certificates, domain and proxying to the backend stay on the stand's outer reverse proxy; say
   which port is container-internal and which is published, and how to attach it (same container
   network or host-published port).
2. **Routing**: which paths go to your container (`/`, any embedded sub-apps served in frames) and
   which go to their gateway (`/api/`). The image routes its own sub-paths, so the outer proxy
   needs two locations. Whether it strips the API prefix is decided by a trailing slash on
   `proxy_pass` — state it, because "the app calls `/api/v1/x` and the gateway serves `/v1/x`" is the
   single most common misconfiguration. Do **not** put a trailing slash on the location that must
   pass the full path through.
3. **WebSockets**: a realtime endpoint needs `Upgrade` and `Connection` headers forwarded and a long
   read timeout, or the proxy drops the socket.
4. **Runtime configuration**: environment variables are substituted **at container start, not at
   build**, so one image works in any environment and a change is a restart. Give a table (variable,
   required, example, purpose, which surface reads it). A missing variable should degrade to an
   explicit "not configured" placeholder, never crash the container.
5. **Third-party keys and domain whitelists**: a browser-side provider (maps, analytics, payments)
   often accepts a key only when the request's Referer is on its whitelist. If the provider is loaded
   from an iframe on *your* path of the stand's domain, the **stand's domain** must be whitelisted —
   and a key shipped to the browser is public, so it should carry the narrowest scope the provider
   offers. Anything privileged goes through a private key held by the backend.
6. **What does not work yet**: a surface still on an old contract, an endpoint the gateway does not
   expose. Write it down so nobody files it as a bug.
7. **A verification checklist** (open `/`, open each embedded path, the embedded content actually
   loads rather than showing a placeholder, `/api/...` answers the gateway and not your container).

**Native apps are not in the compose file.** Unlike the web image, the API URL in a native build is
**baked at build time**, so the stand's final URL is an input to your build. *If you ship a
Capacitor-style WebView shell:* the WebView origin is `https://localhost` (Android) or
`capacitor://localhost` (iOS), so the gateway sees cross-origin requests: allow those origins and the
headers you send (`Authorization`, `Content-Type`, tracing headers). If the app uses no cookies, a
wildcard allow-origin is fine.

## Running a local app against the stand

Needed to check something against real data or to demo from a laptop without Docker or the whole
repository.

- Fetch only the folders you need (a sparse checkout); shared workspace packages are required, and a
  package manager that understands workspace dependencies (not plain `npm`) too.
- Put a `.env` at the **repository root**, not in the app folder. It carries the API-version switch
  (without it the app may run against the mock's contract or an older UI), the supported languages,
  the URLs of any embedded frames served by the stand, and the public third-party keys.
- **The port is part of the contract.** The stand's CORS allows exactly one dev origin, e.g.
  `http://localhost:{{DEV_PORT}}`. Another port, or `127.0.0.1` instead of `localhost`, makes the
  browser block the requests. A symptom list worth keeping: network/CORS errors mean wrong origin;
  old UI means the version switch is missing; an empty embedded frame means the stand's frame URL
  does not open; "port in use" means a container dev environment holds it.
- If the app has an environment or region picker, state which entries use the mock server and which
  use the stand.
- **Payments leave the app** (when the product takes them). The checkout opens in a new tab and
  returns to the *stand's* return URL, not to localhost; close that tab and return — the balance
  refreshes by itself, usually within a minute. Keep a documented test card and say any future
  expiry/CVC works.
- **Embedded frames come from the stand's deployed version**, not from your clone. If the stand lags
  the repository they may not open; check once before a demo.
- To update: pull, reinstall, restart the dev server.

## Testing rules that follow from "the stand is not ours"

- No test depends on a test-only endpoint, not even on localhost; no test depends on the server clock
  or on a reset ([e2e-testing.md](./e2e-testing.md)).
- **Probe, don't read.** The stand's published schema can type a field as an opaque object and hide a
  version difference. Write a probe request and compare, or a contract test against the stand, before
  assuming the mock's answer shape holds.
- A stand in a different region may be **geo-blocked** from your network: a gateway-level 5xx from the
  wrong country is a block, not an outage. Retry from the right region (a proxy or VPN) before
  filing a bug.
- **Exact-match origin lists are deployed configuration.** When a remote browser or a new host cannot
  call the API, the first thing to check is the preflight response for that origin — see
  [browser-automation.md](./browser-automation.md).
- Keep the debug surfaces (dev-only buttons, mock-only fixture routes) off on the stand by checking a
  condition that is false there; tests must not rely on them.
- Know what the mock gives for free that the stand does not: instant async commands, no throttling,
  a movable clock, a reset. A scenario that passes only because of one of those has not been run.
