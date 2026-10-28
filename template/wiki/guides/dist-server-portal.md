---
title: Internal build-distribution portal (APKs, TestFlight links)
class: compiled
covers: []                 # fill when adopting — e.g. the portal's server dir, its compose service
last-verified: never
verified-by: boilerplate
sources: []
---

# Internal build-distribution portal

**Applies when** the repo contains its own small web service that hosts mobile builds for testers
(APK files, TestFlight join links) — a server package plus a publish script. If testers install from
a third-party channel (Firebase App Distribution, Play internal testing, TestFlight alone), this
page does not apply; prune it.

Where testers install from: the half of [`native-builds.md`](./native-builds.md) that is not a
build. That page owns producing an APK or IPA; this one owns the service the result is published
to. The per-endpoint and per-variable reference is the service's own README and the `.env.example`
files; what is here is what those cannot tell you.

## What it is

A standalone web service in its own workspace package (the notes below assume Node/Express) —
internal tooling, not part of the product, **independent of the app↔backend API contract**;
nothing in the app talks to it. It hosts:

- **Android** — the `.apk` files directly.
- **iOS** — a **TestFlight** join link per build (the IPA lives in TestFlight).

Builds are published from a developer machine or CI through a **bearer-token API** and shown on
**basic-auth** pages: latest build on top, history below. iOS and Android are independent (not
released in lock-step), and `dev` and `release` channels are separate pages — dev builds live-reload
from a LAN bundle and are useless to external testers. iOS has no `dev` page by design
([`native-builds.md`](./native-builds.md)). Operations: publish (multipart upload), reset (wipes
metadata *and* APK files, per platform/channel or all), and an index page with a QR code of
whichever origin the request arrived on (scan from a phone). The publish wrapper scripts
(`build:android:dev|release`, `build:ios:release`) are the normal writers; **the publish script is
the portal's one writer**, and the empty-TestFlight-link behaviour belongs to that script, not to
the portal.

Storage is a JSON metadata file plus APKs on disk, under a gitignored `data/` mounted as a volume in
dev and prod, so builds survive restarts.

## Operating notes

- ⚠️ **The two upload ceilings disagree.** The proxy's `client_max_body_size` (say 300 MB) vs the
  service's own limit (say 500 MB): an APK between the two is rejected by the proxy with a 413 that
  the publish script reports as a failed publish, and the service never sees the request. Raise
  the proxy figure — the binding one.
- **The store is hydrated once at module load** and the whole file is rewritten on every mutation,
  so a hand edit to the JSON under a running container is lost at the next publish, and a second
  replica would clobber the first. One instance, deliberately.
- **In dev the port is published on every interface**, unlike a loopback-bound sidecar, and that is
  intentional: a tester's phone on the same Wi-Fi has to reach it. The shipped dev defaults are
  weak (`admin`/`admin`, `dev-token`), so anything on that network can list and download dev builds
  until the root `.env` overrides them.
- **In prod it binds `127.0.0.1`** behind its own subdomain (base path empty) or under a sub-path
  of an existing host. It renders absolute paths (`/assets/…`, `/downloads/…`), so it cannot sit
  behind a blindly stripped prefix: set the base-path variable so it prefixes every link it emits,
  and let the proxy's trailing-slash `proxy_pass` strip the prefix on the way in. When publishing
  from CI, point the server URL at the full prefixed URL. Standing the vhost up (DNS, certificate
  expansion) is a deployment step: [`deployment.md`](./deployment.md).
- **In prod it runs in the ops/tooling stack**, not with the backend — its own compose project and
  env file, meant to move to a small server of its own. The portal's credentials come from that
  env file; the root `.env`'s copies feed only the dev container and the publish scripts, and the
  publishing machine's token must equal the server's.

## In production the credentials have no defaults, and the service refuses to boot without them

The portal answers from the open internet and its basic auth is the **only** gate — the proxy
terminates TLS and adds no `auth_basic`, allowlist or rate limit. So under `NODE_ENV=production`
the three variables (user, password, API token) have no fallback, and config load throws, naming
every offending variable, when one is unset, still its dev default, or still the example's
`change-me`. Names go to the log, never values. Under `restart: unless-stopped` that is a crash-loop
with the reason in `docker logs`, chosen deliberately over serving the portal open. Outside
production nothing changes.

Three details decide whether that gate fires:

- **Empty is not a value.** Compose hands the container `''` for a variable the host never defined,
  and `??` does not fire on `''` — an empty credential would reach the auth gate, where an empty
  login form matched it. Every read trims and treats blank as unset, in every environment.
- **Compose passes the three bare, with no `:-` and no `:?`.** `:-` would be a second published
  password. `:?` looks right and is not: compose interpolates the whole file on *every* command, so
  it would also break `status` and the rollback `down` on a host that hasn't set them, and — for
  secrets of an inactive profile — stop the portal from starting while the optional service is
  switched off. The refusal belongs in the service, where it fires on a start and stays out of the
  way of a stop.
- **The service's `NODE_ENV` is a literal `production` in prod compose**, not an overridable
  default, so the gate cannot be switched off from the root `.env`.

## Gate coverage

A tooling package like this one should be inside the root lint and format gates, with its own ESLint
config — a `lint` script with no config in its ancestry exits 2 and nobody sees it unless the root
chain invokes it ([`coding-standards.md`](./coding-standards.md)). It does not need to extend the
formatter-compat config if it has no stylistic rules to silence: that dependency would be installed
into a production image whose install includes devDependencies, for nothing.
