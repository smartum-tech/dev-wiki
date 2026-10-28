---
title: Docker Workflow
class: compiled
covers: []                 # fill when adopting — e.g. the dev compose file and the stack scripts
last-verified: never
verified-by: boilerplate
sources: []
---

# Docker Workflow

How to work with the Docker dev environment, and what not to do to it. A change to any script that
drives Docker is a docker-workflow change even when its path never contains the word "docker"
(`ai-instructions.md` U-9).

Typically three stacks exist, each started by a different script: **local dev** (compose file with
fixed container names and ports — one instance per machine), **production** (separate compose
file(s), driven by a deploy script, see [`deployment.md`](./deployment.md)), and optionally a
**preview/staging sandbox**. Tooling services (build portal, code index) are their own pages:
[`dist-server-portal.md`](./dist-server-portal.md), [`code-query-tool.md`](./code-query-tool.md).

## Forbidden — will crash Docker Desktop or fight the container

- **Never kill anything by port.** Any signal, not just `-9`: `lsof -ti:4000 | xargs kill`,
  `kill <pid-on-docker-port>`. On a Docker-published port the PID `lsof` returns is Docker
  Desktop's own port forwarder, not the server inside the container; killing it takes Docker
  Desktop down on macOS — every container at once, not just this project's. The signal is
  irrelevant (`-9` appears in every example of the mistake, so the rule gets misread as "`-9` is
  the dangerous part"). **Killing by port is the dangerous part.**

  Instead, target the process you started, by its command: `pkill -f "tsx src/index.ts"`. If the
  port is still busy a second later, wait — a just-killed Node process releases it shortly.
  `EADDRINUSE` is a reason to look at what is holding the port (`lsof -nP -i:<port>`, read-only,
  always safe), never a reason to kill. Recovery after the mistake: restart Docker Desktop, then
  bring the stack up again.
- **Never run the dev servers on the host while the containers are up** — `cd {{FRONTEND_DIR}} && {{PACKAGE_MANAGER}} dev`.
  The containerized instance already owns the port; a second listener either fails to bind or
  serves stale code beside the container, and you end up debugging the wrong one.
- **Never run a manual production build for local dev.** The dev containers rebuild from source on
  save (HMR/watch), so a manual `build` produces an output dev mode never reads.

## Starting, stopping, reading

Use the root scripts, not raw `docker compose` — they pick the compose file and service subset:

```bash
{{PACKAGE_MANAGER}} run up       # bring the dev stack up in the background
{{PACKAGE_MANAGER}} up:build     # rebuild images first (new dependency, Dockerfile change)
{{PACKAGE_MANAGER}} down         # stop and remove containers
{{PACKAGE_MANAGER}} logs         # all services, following; logs:<service> for one
docker ps                        # what is up (check before starting anything)
docker logs -t -f <container> --tail 50
```

**`pnpm up` is not "docker up".** `up` is a built-in alias for `pnpm update`, and a built-in always
wins over a script of the same name: typing it updates every dependency to the newest version its
range allows and rewrites `package.json` and the lockfile, with no hint that it did something else.
Write `pnpm run up`. Scripts named `up:build` and `down` are safe — neither is a built-in. If it
happens: `git checkout -- package.json pnpm-lock.yaml && pnpm install --frozen-lockfile`. Check
every script name you add against the package manager's built-in command list.

## HMR — why you don't rebuild

Vite dev servers (HMR, near-instant) and Node watchers (`tsx watch`, Nest `--watch`; a second or
few) bind-mount source into the container, so a saved file rebuilds in place. Timing varies with
machine and file, so don't trust a number — watch the logs for the confirmation
(`[vite] hmr update …`, "Compilation complete"). Rebuild the image only for dependency changes,
build-time env changes, Dockerfile edits, compose edits, or a changed volume layout.

⚠️ **The dev-server config file is outside its own watch, and the failure is a blank page rather
than a stale one.** A dev server does not restart on `vite.config.ts`, so an edit there ships only
after restarting the container — and a newly added `define:` constant is *undefined* until then,
which throws on first reference and renders nothing. Reading that as a component bug and editing
the component is the trap; the config edit simply has not landed. The same applies to CSS or map
code that appears not to update: if HMR seems silent, restart the service and verify by measuring
(computed style, DOM), not by eyeballing a screenshot. After editing a component that owns a
singleton (a map instance, a socket), reload the page — Fast Refresh can build a second one.

## What is mounted, and `node_modules`

Mount `src/`, `public/`, the tool configs and shared workspace packages; **do not** mount `node_modules` —
the host's would overwrite the container's, and the container may be a different platform. Because
dev images build from the **repo-root context** and run `pnpm install --frozen-lockfile --filter
<pkg>` against the root lockfile, container versions equal the host's; the consequence is that
adding a dependency on the host is not enough — rebuild (`up:build`). A stale image shows up as
"Failed to resolve import" for a freshly added package. If compose leaves an old container running
after a rebuild, force it: `docker compose -f docker-compose.dev.yml up -d --force-recreate`.

Every dev module needs its own `.dockerignore` excluding `node_modules` and `dist`: the dev
Dockerfiles end with `COPY . .`, and without it the host's pnpm-workspace `node_modules` (symlinks
into a store that doesn't exist in the image) overwrites the freshly installed one — "module not
found" at runtime.

If a folder must be mounted in several places, list it per container explicitly. A hand-listed
subset of a directory means a file outside the list is invisible to the container no matter how
often you save it; the symptom is an edit that does nothing, not an error.

## Compose environment: restart does not re-read it

- **`docker compose restart` does not apply changes to `environment:` or `env_file`.** The
  container keeps the environment it was created with. After editing compose env or the `.env`
  it references, run `up -d` (which recreates changed services); use `restart` only to bounce a
  process whose container definition has not changed. Stale env after a "restart" is a common
  reason a change "does nothing" — and in a stale-URL case, a map or API pointing at a dead host.
- **A value that reaches only a `.env` *file* is not necessarily in the container.** Compose
  forwards an explicit list (`environment:` block); a variable not listed never arrives. Config
  read at module load (cron expressions, feature switches) can see a different value than config
  read later from a service, and a backend that refuses to boot on the mismatch is doing its job.
  Pruning `environment:` entries on the grounds that "the app has a default" turns a documented
  knob into a silent no-op; check what reads each one first.
- **Never inline a default containing a brace into `${…}`** — `${VAR:-hello {name}}` corrupts
  the *override* (value `X{name}` arrives as `X{name}}`), not the default. Put the default in
  code and write `${VAR:-}`. Every cheap check passes (the default path is correct, the value is
  still short), so it breaks the first time an operator uses the knob. Corollary: `${VAR:-}`
  delivers an **empty string**, never an absent variable, so config readers must treat `''` as
  unset explicitly rather than leaning on `||`/`??`.
- `docker compose config` settles any interpolation question. It addresses the project of the
  directory you are in — on a stack shared between checkouts, run it through the sandbox script like any other compose
  command, so it cannot address another checkout's project.

## Which checkout is running the stack

Fixed `container_name`s are global to the Docker daemon, so only one checkout — main or any
worktree — can run the stack at a time. Ask the containers, never a note or lock file (a label
cannot go stale, a file can). A sandbox script (`{{SANDBOX_SCRIPT}}`) typically offers three subcommands:

- `where` — prints the path of the checkout currently running the stack, or exits non-zero with a
  reason; "nobody is running it" and "Docker unreachable" are deliberately different answers.
- `up` / `down` — stop the stack wherever it runs, link this worktree's env files and
  `node_modules`, start it here (`down` reverses it, back to the main checkout). `up` and `where`
  share one resolver so the query and the switch can never disagree.
- `link-env` — only symlinks the gitignored `.env`/`node_modules` into a worktree; touches no
  container, safe any time. Run it once in the checkout that owns `.env` for appends: `>>` writes
  through the symlink.

## Gotchas worth knowing

- **Everything on `localhost` shares cookies across ports.** Every app on every port reads the same
  cookie jar; chunked session cookies from several apps grow the `Cookie` header, and a realtime
  WebSocket handshake or gateway can start rejecting it (431/400) with no UI error — screens that
  update only via a socket just freeze. Strip cookies on the realtime route at the gateway
  (realtime authenticates by token, not cookie), raise the header buffers for REST, and recreate
  the gateway (its entrypoint re-reads config only at start). If it recurs with the config
  confirmed, check realtime delivery, not cookies; a polling fallback during transitional states
  is the safety net.
- **Bind-mount ownership differs by OS.** Docker Desktop on macOS mounts host paths with a
  `fakeowner` layer, so uid mismatches between host and container user are *unreachable* there and
  appear only on Linux/CI. "Works on my Mac" proves nothing about file ownership; test on the
  container's own filesystem. A fix is to run the service as the host's uid
  (`user: '${DOCKER_UID:-10001}:${DOCKER_GID:-10001}'`), with the values in untracked `.env`
  holding digits — compose interpolates `${…}` but never executes `$(id -u)`.
- **Hand-duplicated config drifts.** If compose files or gateway config are copied between
  sibling repos by hand, a fix lands in one and rots in the others; say in the page that owns the
  config which copies exist.
- **Troubleshooting order:** services up (`docker ps`) → logs → `down && run up` →
  `up:build` after dependency changes → Docker Desktop running → disk space (Docker wants ~10 GB)
  → restart Docker Desktop (last resort).

## Machines and budgets

If agents or the stack run on more than one machine, keep the inventory (which host runs what,
addresses, memory budgets) in `reference/`, not here — it is a fact about the organisation's
infrastructure, not a rule. Two rules do transfer. *Establish which machine you are on before
diagnosing a missing tool* (`hostname`): a tool present on one host is absent on the next, and an
address that resolves from one does not from another — see [`code-query-tool.md`](./code-query-tool.md).
And *re-measure a resource budget rather than remembering it*: a small shared box can be exhausted
by leaked sub-processes of crashed agent sessions nobody reaps, and swap exhaustion ends in
processes that stop answering signals, not in a failed command. Reverse-proxy and certificate
lessons from public preview servers are in [`deployment.md`](./deployment.md).
