---
title: Testing Strategy
class: compiled
covers: []   # fill when adopting: the test runner configs and setup files (not the specs themselves)
last-verified: never
verified-by: boilerplate
sources: []
---

# Testing Strategy

Which layer tests what, how the runner is split into lanes, and the ways a green run can lie. This
is the map; the details are one page each:

- commands that look right and do the wrong thing — [testing-quickstart.md](./testing-quickstart.md)
- whether a green spec proves anything — [writing-tests.md](./writing-tests.md)
- test data that must stay invisible to production — [test-isolation.md](./test-isolation.md)
- testing schema migrations — [migration-testing.md](./migration-testing.md)
- client unit/component tests — [frontend-testing.md](./frontend-testing.md)
- browser end-to-end — [e2e-testing.md](./e2e-testing.md), [e2e-writing.md](./e2e-writing.md),
  [e2e-visual-regression.md](./e2e-visual-regression.md)
- the API double — [mock-server.md](./mock-server.md), [vendor-mocks.md](./vendor-mocks.md)
- the real test stand — [real-backend-testing.md](./real-backend-testing.md)
- realtime channels on devices — [realtime-testing.md](./realtime-testing.md)
- which browser an agent may drive — [browser-automation.md](./browser-automation.md)

## The layers

| Layer | Real | Mocked | Owns |
|---|---|---|---|
| Unit | the unit | everything else, no I/O | business logic, error paths |
| Integration (backend) | the app, the database, HTTP | third parties | auth, validation, permissions, data rules |
| Client unit/component | the component tree (jsdom) | the network, native plugins | rendering states, localization, component logic |
| E2E | the whole stack through a real browser | nothing the user cannot see (third parties may be doubled) | cross-service flows, visual regression |
| Device / realtime | the app on a phone | — | what the OS does to a connection or a process |

The boundary between layers is deliberate. A rule lives in the cheapest layer that can fail on it:
localization in client unit tests (every key, every language, in milliseconds), data and permission
rules in backend integration tests, reachability and cross-service flows in E2E. An E2E test that
queries the database to assert is in the wrong layer; so is a unit test that mocks the whole world
to "prove" a permission rule.

All new functionality is covered. **Every backend endpoint is a hard requirement for integration
tests** covering success, unauthenticated, wrong role, invalid input and not found. That matrix is
the project's actual security and regression net, not an extra.

## Unit versus integration: what the name has to mean

- **Unit**: every dependency mocked, no I/O.
- **Integration**: boots the real application against a real database (and cache, queue) and
  drives the endpoint over HTTP the way a client would — not by calling a service method. Auth,
  validation, guards and row-level rules are exercised for real.

**Exception: queue workers and scheduled jobs have no route to hit.** They still get integration
tests against a real database, but call the service/processor directly.

**A suite whose endpoints enqueue jobs must claim a private queue/cache namespace** (a separate
Redis db index, a key prefix). The default namespace is shared with the running dev stack and with
every other suite's leak-prone worker; either steals the jobs and runs them against a different
mock store, which surfaces as a flaky assertion about the store, never as a queue error. Set it
before the application module is compiled (the queue module reads it at compile time), restore it
afterwards, and keep the allocation list where a grep finds all of it: an allocation made through
a config override is invisible to a grep for the env var, so the "free" index you pick may be taken.

## Two lanes, and the split lives in config on purpose

Run unit and integration specs through **two runner configs**, and make the safe one the default:

- the default config is the **unit lane**: it excludes integration specs, runs in parallel;
- the integration config selects only integration specs and runs serially.

Being the default is the entire point: a bare `{{PACKAGE_MANAGER}} exec <runner> <path>` — what
people type to run one file — then cannot reach the shared database, by construction rather than by
remembering a flag. A constraint kept in config survives an invocation that forgets it; a flag does
not.

Ways to break the pair while both lanes stay green:

- A path-ignore option often **replaces** the runner's default instead of extending it, so
  `node_modules` has to be repeated in both configs.
- The integration config must *reset* the ignore pattern it inherits. Inheriting the base's
  "ignore integration specs" cancels its own selector and selects **zero suites**, and a lane that
  runs nothing reports success.
- A combined script (`unit && integration`) short-circuits: **a red unit lane hides the
  integration lane entirely.** "The suite is green" means reading both halves.
- Watch, coverage and debug scripts that pass no config are **unit-lane only**. Watch mode will
  never pick up the integration spec you are editing and will not say so.
- Serial-run and worker-count flags are often mutually exclusive on the runner CLI. If a script
  already carries one, appending the other aborts the invocation, sometimes with exit code 0 after
  printing help. Read the tally, not the exit code.

**The split is by filename, and it fails open.** Nothing checks that a spec touching a real
database client is named as an integration spec; a misnamed one joins the unit lane, hits the
shared database at full parallelism, and the run stays green. Re-verify the classification by
reading specs: grep cannot tell a real client from a mock of the same name.

**Why the integration lane is serial**: those suites boot the full application against *one* shared
stack, not a fresh one per suite. Concurrently, it intermittently throws spurious errors under load
at a setup helper. That is environmental contention, not a code bug. As a second line of defence,
auto-retry integration specs (never units, which are deterministic) a small fixed number of times
with every failed attempt logged, so a genuinely broken test, which fails all tries, stays visible.

**Splitting the slow lane out makes it honest, not fast.** If every integration spec boots the
whole application, that boot is what the duration is made of.

**Force-exit is a symptom, not a fix.** A booted application holds scheduler, queue and cache
connections that `close()` may not release quickly enough for the runner to see zero open handles,
so the process hangs *after the tests have passed*, which reads as a deadlock. Pass force-exit in
every script that boots the app, including the container-flavoured one, and know that this is what
it is hiding.

## Missing environment must fail loudly, once, by name

Test env files are gitignored, so a fresh worktree has none. A silent dotenv load then lets the
application boot with empty config, and the first symptom is far away: an injector turning a
constructor throw into unbounded recursion, "Maximum call stack size exceeded", aborting *every
remaining suite* with a trace that names no variable and reads like a circular dependency. Put a
guard in the runner's setup file, before any module boots, that asserts the required variables and
fails the suite with a message naming the file and the variables. This binds the unit lane too if
the setup file is shared.

## E2E and the generated scenario index

E2E specs carry numbered titles (`1.1 - description`) and a scenario index is **generated** from
them, not hand-maintained. After adding or renaming a test, regenerate it and commit it with the
test change, or the index silently drifts from the suite.
