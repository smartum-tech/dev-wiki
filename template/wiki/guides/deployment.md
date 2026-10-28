---
title: Deployment — environments, config surfaces and the decisions behind them
class: compiled
covers: []                 # fill when adopting — e.g. the prod compose file, the deploy script, nginx conf
last-verified: never
verified-by: boilerplate
sources: []
---

# Deployment

This page owns the **decisions**: which config feeds what, what order things come up in, what a
production image must be given back, how the reverse proxy behaves, and what shape a deploy has.
It is not a runbook of one server — keep the host-specific step list next to the deploy script
(`tools/deploy.sh help` lists subcommands) and the per-variable reference next to `.env.example`,
where **`.env.example` wins** over any prose copy. How images get built before they arrive is
[`ci-cd.md`](./ci-cd.md); how native apps ship is [`native-builds.md`](./native-builds.md).
Backend-specific material below is marked *(example — adapt to your backend)*.

## Config surfaces: there is no single `.env`

Several files feed several consumers, and a value in the wrong file is silently invisible:

| surface | file | consumed by |
|---|---|---|
| application stack | root `.env` (copy of `.env.example`) | prod compose → backend container; publish/provision scripts |
| data/auth stack *(example)* | `<stack>/.env` | the compose of the database/auth services |
| host-built statics | `{{FRONTEND_DIR}}/.env.production` | the static build run on the host — compose injects nothing; Vite reads the package-local file |
| mobile bundles | `{{MOBILE_DIR}}/.env.production` (copy of `.env.production.example`) | PWA build and native release builds. Ships **inside the bundle**: public URLs and public keys ONLY |
| ops/tooling stack | `ops/.env` | its own compose project (build portal, error tracker), so `up` of the app never restarts it |

Rules that repeatedly bite:

- **A knob that reaches only a `.env` file is not necessarily in the container** — compose
  forwards an explicit list ([`docker-workflow.md`](./docker-workflow.md)).
- **`VITE_*` values are baked at build time.** Changing them means rebuilding the static bundle,
  not restarting a container — unless the image resolves them at container start
  ([`ci-cd.md`](./ci-cd.md)).
- **Vite gives `process.env` precedence over its own `.env` files.** A build script that sources a
  dev env first bakes `localhost` into a release; clear `VITE_*` from the environment before a
  production build ([`native-builds.md`](./native-builds.md)).
- **Only fill what has no default.** List which variables have no default and misbehave without a
  value (identity keys, public origins, seeded admin credentials, webhook secrets). Everything else
  has a working default; defaults for business knobs are the ratified values, changed only when the
  product decision changes.

## Production-safety defaults worth deciding explicitly

- **Credentials of an internet-facing service have no default, and the service refuses to boot
  without them** (unset, empty, still the dev default, or still the example's `change-me`). Log
  the offending *names*, never the values. Under a restart policy that is a crash-loop with the
  reason in the logs, chosen over serving open. Pass such variables bare in compose — no `:-`
  (a second published password) and no `:?` (compose interpolates the whole file on *every*
  command, so it would also break `status` and the rollback `down` on a host that has not set them
  yet). The refusal belongs in the service. Treat blank as unset in every environment.
- **Mock/real switches must be set explicitly in production**, because prod defaults often invert
  dev's. Know the cascade: a master "use mock" flag makes dependent mocks default to mocked when
  unset; going real later with unset credentials should *refuse the boot* where silently skipping
  would be worse (payments, payouts).
- **Dev-only helper endpoints** (echoing a one-time code to testers, test-data seeding) must not
  depend on `NODE_ENV` alone; enable them only on a stand that truly needs them, and read what the
  endpoint returns *beyond its intended use* (the newest code of any purpose).
- **Treat a `NODE_ENV` override as a deliberate act.** If prod compose reads
  `${NODE_ENV:-production}`, a value in `.env` reaches production, and anything other than
  `production` turns on every `NODE_ENV !== 'production'` branch.
- **CORS must carry the native WebView origins** as well as the web ones: Capacitor sends
  `https://localhost` (Android) and `capacitor://localhost` (iOS). Without them every direct API
  call from the installed app is blocked — the response arrives without
  `Access-Control-Allow-Origin`, so it presents as a broken app, not a CORS misconfiguration.
- **Optional push/alerting channels left unset should run `simulated`**, with nothing leaving the
  box. A wrong push environment flag (sandbox vs production APNs) disables every device it touches
  rather than failing — leave it to the compose default.

## Order of operations (template)

```bash
deploy.sh setup      # runtime, package manager, shared docker network
deploy.sh install    # frozen-lockfile install (host-built statics only)
# fill the data stack env (generate keys with the stack's own script), then the root .env
deploy.sh up         # data stack, then backend build + up; migrations run AT BOOT behind a gate
<run-once provisioning CLI inside the backend container>     # once per environment
# fill ops/.env;  deploy.sh ops   # build portal / error tracker (own compose project)
# fill front/mobile .env.production
deploy.sh front      # static builds, served by the reverse proxy
deploy.sh mobile     # PWA static build
```

Provisioning steps a migration cannot do (registering the platform with a third party that issues
an id only they can) are **run-once-per-environment CLIs**. In production run them *inside* the
backend container *(example — adapt)*: the prod image has no `ts-node`, so the CLI is compiled JS,
and the runtime deps, cache and DB are in reach. Env they read must already be forwarded into the
container, i.e. in `.env` before `up`. With a mocked third party the CLI records a synthetic id —
**run it again when the environment goes real**. Missing provisioning should refuse affected
operations loudly (an admin banner), not fail obscurely.

## The production image *(example — adapt to your backend)*

A plain-Node image (no `ts-node`, no `tsconfig-paths`) has to be given back everything dev
provided implicitly:

- **Pin the package manager version to `package.json`'s `packageManager` in every build stage.**
  An unpinned newer install sees the pin, tries to self-switch, and an integrity policy can then
  refuse the native binary. Bump the pin and the Dockerfile together.
- **A tsconfig `paths` alias for a shared package is not a dependency.** `tsc` emits
  `require("@scope/types")` verbatim and plain `node dist/…` cannot resolve it. Bridge it (a
  symlink into `node_modules`, or a bundler); a second alias needs the same treatment and fails
  only at runtime, in production.
- **Copy non-code assets explicitly** (email templates, static folders) — `tsc` doesn't carry them
  into `dist`.

## Reverse proxy (nginx) lessons

- **Symlinking vhosts from the checkout makes the live config a tracked file.** A `git pull`
  changes it and nothing applies it until `nginx -t && reload`; `certbot --nginx` (without
  `certonly`) rewrites the vhost it finds, dirtying the tree and blocking the next pull. Commit
  certbot's diff; don't `checkout --` it (that reverts the live config). A new subdomain sharing a
  certificate needs both a DNS record and `certonly --expand` before it serves — neither happens as
  a side effect of the deploy script.
- **Two vhosts claiming the same `server_name` collide silently.** Whichever link was made last
  decides what the public site serves. If a preview and a production config share a name, a rule
  the public site needs goes into both files.
- **Location matching bites.** A regex location (static-extension caching) beats a plain prefix, so
  `location /assets/` never applies to `.js`/`.css` — use `^~`. An exact `location = /404.html`
  beats everything. A location with its own `add_header` **drops every server-level `add_header`**
  (security headers, `X-Robots-Tag`); repeat them there. If shared presets are included by absolute
  path, the precedence is invisible from the repo — read the preset's locations before adding one.
  None of these show as an error, only as a wrong header or cache lifetime.
- **`proxy_pass` with a trailing slash strips the prefix; without one it preserves it.** Strip for
  a container that serves at its root (`/api/`); preserve for a bundle built with a matching `base`
  whose asset URLs already carry the prefix. Express redirects with root-relative `Location`
  headers escape a stripped prefix unless `proxy_redirect` fixes them. A surviving
  `location /assets/` pointing at an old directory returns 200 for pages and 404 for every script.
  After any change, run a real nginx in front of the real image and request the HTML **and** an
  asset from each surface.
- **Never add a slash-stripping rewrite on top of canonical trailing-slash URLs**: prerendered
  `<page>/index.html` already makes nginx 301 `/blog` → `/blog/`, and a rewrite loops it.
- **Upload ceilings must agree.** A proxy `client_max_body_size` below the service's own limit
  produces a 413 the publisher reports as a failed publish while the service never sees the
  request. Raise the proxy figure — the binding one.
- Public preview hosts: send `X-Robots-Tag: noindex, nofollow`; noindex never shows if
  `robots.txt` disallows the URL.

## Deploy shape: downtime window or rolling

*(Example — adapt to your backend.)* With one backend process and a fixed `container_name`, `up` is
stop → start → migrate at boot → serve: a **downtime** window, never a mixed-version one. Decide
this deliberately, because other rules lean on it: a migration may change an RPC/function signature
in place only because no old-code process serves once the new schema exists, and a boot gate that
serialises migrations across replicas keeps that true. Rolling or zero-downtime deploys, or booting
a rolled-back image after a signature-changing migration, break it — adopt a written
expand/contract rule *before* moving to either. Scheduled jobs behind a leader lock make replica
count a non-issue for cron duplication; the deploy *shape* remains the decision.

## Deploy branches and the host

- **Document the branch the deploy script pulls.** A script that pulls a branch nobody else
  mentions makes "merged" and "deployed" different facts without anyone knowing. With a long-lived
  deploy branch on the host, merging to `{{MAIN_BRANCH}}` deploys nothing until a
  `{{MAIN_BRANCH}}` → deploy-branch PR lands, and that PR conflicts whenever the server is
  committed to *from the server*; resolve toward the live versions.
- **A preview host served off a branch nothing merges back** is invisible drift: a change typed
  into a remote session is live on the public site while existing on no other branch. Measure the
  gap (`git rev-list --left-right --count origin/{{MAIN_BRANCH}}...origin/<branch>`) instead of
  trusting the sync; deploy/sync commands should refuse on a dirty tree.
- **Pull-based staging**: CI builds images, the host pulls and starts them, nothing compiles there,
  TLS terminates upstream (the host proxy stays plain HTTP and forwards `X-Forwarded-Proto`), and
  containers bind `127.0.0.1` only. For sub-path vs subdomain: tooling that renders absolute paths
  needs a base-path variable prefixing every link, with the proxy stripping the prefix on the way in.

## Tooling stacks leave the app host

A stack with no coupling to the backend, database or app network (build portal, error tracker) is
the first thing meant to move to a small server of its own. Keep it its own compose project and env
file; a move is then a checkout, a copy of the env file and data directory, the vhosts, and DNS.
Moving it into its own project on an existing host is a **one-time step**: the old container stays
running as an orphan (compose warns, doesn't remove it) still holding the name and port, so the
deploy script must remove the container started from the old compose file — matched by compose
file, so a dev stack's container of the same name is left alone.
