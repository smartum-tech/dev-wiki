---
title: E2E Testing (Playwright Suite)
class: compiled
covers: []   # fill when adopting: playwright config, global setup/teardown, env loader, target fixture, compose/CI files
last-verified: never
verified-by: boilerplate
sources: []
---

# E2E Testing (Playwright Suite)

Architecture, running and data for the browser suite in `{{E2E_DIR}}`. Rules for writing a test:
[e2e-writing.md](./e2e-writing.md). Screenshots: [e2e-visual-regression.md](./e2e-visual-regression.md).
Running against an environment we do not own: [real-backend-testing.md](./real-backend-testing.md). Client
unit tests own localization; E2E does not test it (screenshots are taken in whatever language the app
defaults to).

The suite has one project per surface (for example `web` desktop and `mobile` viewport), declared in
one Playwright config. Workers are 1 and `fullyParallel` is off **by default**: suites that are
stateful across `test()` blocks in one file break under parallelism, and a shared stand tolerates
one run at a time (below). Raising it is an explicit decision per suite, not a perf cleanup.

**`browser.newContext()` inherits the project's `use` options — viewport and `baseURL` both.** A
hand-written `newContext({ viewport })` in a multi-party test is not *supplying* the mobile viewport
but **overriding** the project's, silently opting that context out of any small-screen sweep. Pass
no viewport unless the context is deliberately another device, and say so in a comment.

## The one idea: the runner starts nothing

The runner is handed its targets — a base URL per surface, an API URL, a token — and that is its
entire contract with the world. **There is no `webServer` block in the Playwright config and there
must not be one**: it would tie the suite to one way of bringing the stack up, and the point is that
the same image runs against local compose, a CI-managed stand, staging, and the real backend once
the mock retires.

- **No `depends_on` for the runner.** It would tie the runner to services *in one compose file* and
  stop working against a stand another job deployed. Global setup instead polls the health endpoint
  and each surface root at whatever URLs it was given: waiting **by address rather than by service
  name** is what makes "point it anywhere" possible.
- **The system under test is the replaceable part.** Put the stack behind a compose profile so you
  can *not* start it, and run the runner against someone else's URLs by parameter. When the mock
  gives way to the real backend, the mock and local frontends leave the file; the runner, the reports
  and every test stay.
- **Runner and report host share a volume, not a network.** The runner writes reports to a named
  volume; a stateless static server (nginx) hands them out. The report host need not be up before the
  run, the history survives rebuilding or replacing it, and only `down -v` destroys it. Keep each
  run's report at a stable URL and send JUnit XML to the CI server for the trend graph. Archiving the
  HTML report into the CI server itself usually fails: the report is a single-page app with inline
  scripts, which the CI's default content-security policy strips, and the symptom is a blank page.

## Running

Provide the commands as scripts: bring the stack up, run the suite, tear down, plus a host-run
debugger. Two details earn their keep:

- **Recreate containers on up.** `up --build` can rebuild an image and leave the old container
  running, assembling a stack from two commits: a fresh bundle calling endpoints the stale API does
  not have. That failure reads as a batch of broken tests, not a half-built stand.
- **`--ui` / `--headed` / `--debug` run from the host** with the browser on your machine, and must
  target the **dev** stack, not the containerised one. The containerised stack is configured with
  container network names (the served bundle carries an API URL only the runner can resolve), so a
  host browser sees static pages render, the one test needing no API pass, and everything behind
  sign-in fail on "element not found" — which reads as broken tests rather than an unreachable API.
  The dev stack serves a dev build with its own affordances (dev-only buttons, local API); good
  enough to **write and debug** a test, never the verdict. The verdict, and visual comparison, come
  from the containerised run.
- **Keep the Playwright package version and the base image tag moving together.** A mismatch shows
  up as "Executable doesn't exist at …/chromium-…"; make the image build check the pair.

A `dbg` helper that picks a test by typing a few words, runs it under the Inspector, and remembers
the pick (`-r` repeat, `-f` whole file for suites stateful across tests, `-l` print the command) is
worth the hour it takes to write.

**One stack, one run at a time — two runs on the same machine included.** Two mechanisms poison a
concurrent pair and neither reports itself: global setup's leftover-sweep deletes the *other* run's
in-flight fixtures, and any mock that sleeps inside queue jobs on a bounded worker lets one run's
sleeps starve every other run's, surfacing as an unrelated suite's realtime assertion timing out,
never as a queue error. Rule it out first on a day of drifting timeouts — the second process is
easy to miss (a long-forgotten `--debug` inspector counts).

## Where configuration comes from

Three layers, strongest first:

| Layer | Source | Used by |
|---|---|---|
| environment variables | compose `environment:`, CI parameters, a shell prefix | the container runner, CI, remote stands |
| `.env.<name>` overlay | selected with `E2E_ENV=<name>` | a personal machine with unusual addresses |
| `.env` | file | host-launched runs (`--ui`, `--headed`, `--debug`) |

The top layer always wins: `dotenv` does not overwrite a value already set, and the overlay loader
must explicitly skip keys that came from the environment. A CI parameter then cannot be silently
overridden by a committed file. **`.env` is for host runs only**; a remote machine has none and needs
none. Print the resolved addresses at the start of every container run so which layer won is visible
in the log. Neither `.env` nor the overlays may reach an image (exclude them **by name** in
`.dockerignore`; the root `.env` rule does not descend). If a shared stand ever wants a committed
profile, put **URLs only** in it — the token always comes from the environment.

## Targets

A single `E2E_TARGET` switch (`local` | `<real-stand>`) selects the stand: URLs, the sign-in method,
and the accounts. The mock target signs in with a dev-only code header; a real backend needs the real
sign-in and fails fast, saying so, if it is not configured. Keep this in one fixture file so a test
never knows which stand it is on.

## Test data on a stand you do not control

Applies when the suite must also run on a shared real environment (no presets, no reset, no clock
control — and never will). Such a suite obeys one rule: **no test depends on a test-only endpoint,
not even on localhost.** A test green only because the mock has a back door is a test that cannot
move to the real stand without rewriting. A suite that only ever runs against a mock you own may
use the mock's test handles freely; the rest of this section is then optional.

- **Accounts are permanent**, one per purpose (auth screens, a data-entry account, a
  payments-and-history account). Their state is whatever the previous run left.
- **Arranging goes through the product's public API** as that account — the same endpoints the app
  calls: create an order, start a job. Never click through the UI to arrange state, and never write
  raw rows when a real flow exists.
- **Own data is marked** (a fixed prefix plus a unique key); a test cleans up after itself and a
  setup step removes leftovers of crashed runs before it starts. Cleanup runs in `afterAll`, never
  `afterEach`; one file per marker.
- **Balances cannot be zeroed**: assert on changes, not on absolute amounts.
- **Time is the browser's only** — the server clock cannot be moved (see [e2e-writing.md](./e2e-writing.md)).
- When the backend cannot produce a state on command (an outage, an empty balance, a slow answer), a
  request layer in the test patches, fails, delays or holds the **browser's request**, on contract
  paths so it behaves the same on the mock and the real stand.
- A local wipe of the mock (`E2E_RESET=1`) is a speed-up, **off by default** so the suite keeps proving
  it does not need it. Mount the mock's test handles only when an explicit enable flag and a token are
  both set.

**Fabricate environment state by real flows.** For manual debugging or bug reproduction, a helper
that builds a verified user, a funded account or an in-flight process should reuse the exact
fixtures the suite uses (real registration, real API calls), and fall back to a dev-only injection or
a direct status write only where no real flow exists. Reproducing a bug by narrating UI clicks is
slow and unrepeatable; faking state with raw writes hides the bug.

## Native shell

The mobile project drives the same bundle that is packaged into the native apps, in a mobile
viewport under Chromium. That covers UX logic but **not the native shell**: plugins, push
registration, local notifications, permissions, deep links, WebView origin quirks. Testing those on
real emulators needs a native-capable driver (Appium for hybrid/Capacitor apps; Detox targets React
Native). Treat it as a separate project with another runner, not an extension of this one, and cover
the device-dependent behaviour with manual plans like [realtime-testing.md](./realtime-testing.md).

## CI

Images (app, runner, report host) are built by the build pipeline, one per image. A deploy pipeline
brings up a stand and a second pipeline runs the suite against it. The suite is hermetic: it needs
only the URLs and the token.
