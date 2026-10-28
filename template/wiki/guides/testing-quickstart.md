---
title: Testing Quick Start
class: compiled
covers: []   # fill when adopting: package.json scripts per workspace, runner configs, .env.example files
last-verified: never
verified-by: boilerplate
sources: []
---

# Testing Quick Start

**The commands live in `package.json`, per workspace, and are not copied here** — `{{PACKAGE_MANAGER}}
run` in `{{BACKEND_DIR}}`, `{{FRONTEND_DIR}}`, `{{MOBILE_DIR}}` or `{{E2E_DIR}}` lists them, and a
copy on this page is one more thing to keep true. What this page holds is the ways a command that
looks right does the wrong thing. Strategy and lanes: [testing.md](./testing.md); why a test's rows
come back empty: [test-isolation.md](./test-isolation.md).

## 1. Env files are gitignored and correct as generated

Test env files (`.env.test`, `.env.test.docker`, the e2e `.env`) are not in git, so a fresh
`git worktree add` has none: copy them from the `.example` siblings. Skipping the copy does not fail
loudly unless the runner has the setup guard from [testing.md](./testing.md); otherwise you hunt a
dependency-injection bug that is not there.

**Do not hand-edit them because a test "must have the wrong URL."** One file points at `localhost`
(host-run tests), another at the container service hostnames (container-run tests); the split is
intentional. An E2E overlay (`.env.<name>`) exists for running against a remote stack — see
[e2e-testing.md](./e2e-testing.md).

## 2. Pick the backend lane by config, not by a path filter

Hand-rolling a path filter to choose unit or integration is how a run reaches the shared database.
A script that appends a path to the integration half of a chained command still runs the whole unit
lane first. Watch, coverage and debug scripts pass no integration config, so they see unit specs
and **silently no others**: a green watch run is no evidence about an integration spec.

## 3. Host-flavoured scripts do not connect from inside a container

A host script points at `localhost`. Run inside the container's network namespace, `localhost` is
the container itself, not the database service, and nothing is listening. Use the container-flavoured
script (the one reading the service-hostname env file). Check which containers are up before an E2E
run too: a run against a half-started stack reads as broken tests.

## 4. After adding or renaming an E2E test, regenerate the scenario index

Run the project's generate-docs script and commit the regenerated index with the test change.

## 5. The shared dev database is not a sample of the product

**A row count from it establishes neither that a state is reachable nor that it is not.** The
population is dominated by fixtures, and a fixture fills exactly the fields its own assertions read
— correct fixture design, not sloppiness. Absence of a counter-example says only that no test needed
that shape; presence may be a privileged insert straight past the guard that makes the state
impossible in the product. Cleaning test data does not fix this: what remains is too small to sample
either.

**Reachability is decided by reading the product paths in code**, and the database is at most an
illustration attached to a conclusion already established there. The cost of getting this wrong is a
large change built to defend against a state the product cannot reach — typically because the guard
that made it unreachable lives in a UI form component, invisible to every service and endpoint name
you grepped for.

## Don't

- Don't modify the generated env files to make a test pass.
- Don't run E2E without checking the frontend/backend containers are up.
- **Don't use a wrapper script for a targeted run on a small dev host if it hides the runner.** A
  wrapper that swallows flags (positional paths survive; list-only and worker-count flags do not)
  leaves nothing able to bound the run: the default worker count on a box with few cores can push it into
  swap, from where only an outside signal recovers it. Call the runner directly with an explicit
  worker cap, or serial for one spec — never both flags together, since they are usually mutually
  exclusive and the failure mode is help text with a misleading exit code. **A green run that
  produced no output did not run: read the tally, not the exit code.**
- **Don't read a surprising duration as a property of the spec** without recording load and free
  memory beside it. A very slow single-spec run is more often a starving machine than a slow test.
- **Don't end an agent turn while a background gate runs.** A backgrounded process emits no inbox
  event and no notification, ever, so finishing the turn puts the session to sleep with nothing able
  to wake it; wrappers that make a long run safe to *start* (timeout, one lane at a time, a memory
  fuse) do not make it safe to *leave*. Poll with short calls instead — each poll is an event, so a
  watchdog never trips and a long run survives on a dozen of them. If a turn must end with something
  outstanding, arm a repeating heartbeat first, and say out loud that you are taking that narrow
  exception to "do not use timers to check on workers" (which targets things that notify by
  themselves; a background shell job never does).
