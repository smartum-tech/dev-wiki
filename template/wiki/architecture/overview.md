---
title: Architecture Overview
class: compiled
covers: []                 # fill when adopting: the root package.json, each app's package.json,
                           # the dev compose file — the files whose change could make this page wrong
last-verified: never
verified-by: boilerplate
sources: []
---

# Architecture Overview

<!-- HOW TO FILL THIS PAGE
     The system at the scale of the whole repository: why it is shaped the way it is, and the
     few facts about the stack that its manifests do not say. It is core — read on every
     planning pass — so keep it ≤ 2–3k tokens.
     - Do NOT tabulate versions, ports or packages. Those live in the manifests and the compose
       file, and a copy here rots. Name the file to read, then write only what it does not say.
     - Every claim here is about the code, so every file whose change could make one false goes
       into `covers:`. Stamp `last-verified` / `verified-at` only once every claim is checked.
     - A system-scale DECISION (one the code follows and that many directories depend on) gets
       its own curated page in this folder — see TEMPLATE.md — and a one-line link from
       "Key invariants" below.
     Delete every prompt comment once its section is written. -->

## Shape of the repo

<!-- The top-level packages/apps and WHY they are separate: different audiences, release
     cadences, runtimes, deploy targets. One bullet each:
     - **`{{FRONTEND_DIR}}`** — who it serves, how it ships.
     - **`{{MOBILE_DIR}}`** — …
     - **`{{BACKEND_DIR}}`** — …
     Then the shared packages and why they are packages rather than folders inside one app
     (one source of truth for types or UI across surfaces), and where `{{E2E_DIR}}` sits and why.
     The reasons are the content; the list itself is derivable. -->

## System diagram

<!-- A small ASCII diagram: clients, the API (or mock), data stores, external services, and
     which arrows carry what. Follow it with the default data-access path in one or two
     sentences, and when a request is allowed to leave it. -->

```
<client surfaces>
      │
      ▼
<API / mock server>  ──▶  <external services>
      │
      ▼
<data store>
```

## External dependencies, and what is mocked

<!-- Each external system the product depends on (payments, maps, auth, push, …): how dev and
     test reach it — the real service, its sandbox, or our own mock — and why. Then the
     consequence worth carrying: what nothing validates except production. A mock agrees with
     our understanding by construction, including where our understanding is wrong; say which
     guide lists where the mock diverges and which `reference/` artifacts describe the real
     contract. -->

## Tech stack

<!-- One line on where versions live: each app's `package.json`, pinned in the lockfile
     (`{{PACKAGE_MANAGER}}`) — read those rather than a table here, and say where two apps that
     look alike differ. Then ONLY what those files do not say, e.g.:
     - something hand-rolled where a reader would look for a library (and so conclude "absent");
     - a library used in a deliberately restricted way, with a link to the decision page;
     - a runtime or toolchain constraint (a minimum OS, a browser floor, a Node version pin). -->

## Dev environment and ports

<!-- Where the ports and services are defined (the dev compose file, `.env.example`) — grep
     those, do not copy them. Then what they do not say: which containers are tooling rather
     than the application, which also run in production, how the stack is started
     ({{DEV_URL}} is the usual entry point), and which commands are forbidden and why — or a
     link to the guide that owns that. -->

## Key invariants

<!-- The few system-scale decisions this shape exists to hold, one line each with a link to
     its decision page in this folder (or to a target/ page where the code disagrees). If there
     are none yet, say so in one line rather than inventing any. -->

## Further reading

<!-- Links to the guides a newcomer needs next: the dev workflow, testing, the data layer. -->
