# Wiki index

Every page in this tree and what it answers. This is the routing table an agent reads first, and
the file `/wiki-lint` uses to find orphans.

Each row's *What it answers* is a **territory, not a promise** — it says what a page is about so
you can decide whether to open it, and a page routinely contains more than its line says. If
your question is near a row, open the page. The cell is capped at roughly one line: it is a
hook, not an abstract, and the second and third hook per page live on the page.

**There is no `Verified`, `~tok` or `Class` column**, and re-introducing one is a mistake. Such
columns are a hand-kept second copy of each page's own frontmatter, and they rot: within weeks
most of the cells disagree with the pages they describe. The frontmatter is canonical;
`/wiki-lint` and `/wiki-ingest` read it and never read this table. Class follows the folder —
`curated` in `target/`, `not-doing/` and `guides/ai-*.md`, `reference` in `reference/`, `raw`
in `journal/`, `compiled` everywhere else — except in `architecture/`, where decision pages and
compiled pages sit side by side and the row says which.

**`TEMPLATE.md` files are not pages.** They are skeletons for a writer, listed once under
*Maintaining* below and nowhere else; they are not injected, not counted in the core, and not
drift-checked.

<!-- Fill in once /wiki-bootstrap has run, then leave it:
**Built by `/wiki-bootstrap` on {{BOOTSTRAP_DATE}} from `{{LEGACY_DOCS_DIR}}` at
`{{BOOTSTRAP_COMMIT}}`**, and maintained by `/wiki-ingest` since. -->
A claim that could not be confirmed against the code is marked `(unverified)` on the page that
carries it, not tracked in a separate list.

## Core — read whole in a planning phase ({{CORE_TOKENS}} tokens measured {{CORE_MEASURED}}; ceiling in `CONTRIBUTING.md` §3)

> Measured over the set `CONTRIBUTING.md` §3 defines — `README.md` + `index.md` +
> `product-overview.md` + `guides/` + `architecture/` + `target/` + `not-doing/`, minus
> `TEMPLATE.md` files and pages claiming the lookup-table exception (`wc -c / 4`; the command is
> in `README.md` §6). Re-measured by the ingest or audit that changes it; the per-run arithmetic
> belongs in `log.md`, not here.
>
> **A reading over the ceiling is answered by an audit, not a raise** (`CONTRIBUTING.md` §3): it
> is a prompt to audit, never a quota to trim under. If the core is over, say so in this heading
> (`— OVER`) and keep it there until `/wiki-audit` has run.
>
> **The per-page ≤3k budget is where the pressure usually is**, and raising the core does not
> relieve it: a page over it cannot be pasted into a sub-agent whatever the core total says.
> Never trust a written count of how many pages are over — re-derive it:
> `for f in wiki/{guides,architecture,modules}/*.md; do echo "$(( $(wc -c < $f)/4 )) $f"; done | sort -rn | head`

| Page                                         | What it answers                                     |
| -------------------------------------------- | --------------------------------------------------- |
| [README.md](./README.md)                     | The kinds of page, what outranks what, what to skip |
| [product-overview.md](./product-overview.md) | What we build and for whom                          |

`architecture/`, `guides/`, `target/` and `not-doing/` are core too, and are catalogued below. A
page claiming the lookup-table exception is marked on its own row — *grep, do not paste; outside
the core count* — so the carve-out is visible where the page is chosen.

## Not obvious from either end

Which pages a task needs is normally clear from this catalogue plus each page's `covers:`
frontmatter. These few are not: the page constrains work in a directory it never mentions, and
the directory gives no hint the page exists. Worth knowing before dispatching work there.

The routing pair — *Touching…* and *Also requires* — is what nothing else in the tree holds.
*Because* says only why the pairing is not obvious; the destination page carries the reasoning
in full, and that is where it belongs.

<!-- The row below is an EXAMPLE of the shape, not a real routing. Delete it once the first
     real row exists (or right away). -->

| Touching…                                        | Also requires                     | Because                                                                                                   |
| ------------------------------------------------ | --------------------------------- | --------------------------------------------------------------------------------------------------------- |
| *(example)* a migration (`backend/src/database/migrations/`) | *(example)* `guides/security-database-checklist.md` | *(example)* migrations are TypeScript under the backend, so nothing about the path suggests schema or permission review |

## Architecture — how the system is built, at system scale

| Page                                      | What it answers                                              | Class    |
| ----------------------------------------- | ------------------------------------------------------------ | -------- |
| [overview.md](./architecture/overview.md) | Stack, versions, ports, and why the repo is shaped this way  | compiled |

## Guides — how to work here

`ai-*.md` are curated — a human's decision, not compiled from the code. The rest are compiled.

Pages marked **(example)** carry an *Example — adapt to your backend* banner: they describe a
Postgres-backed API with row-level security and migrations. A project without that backend
deletes them at adoption rather than keeping them unverified — they are ~21k tokens of the core.

**AI rules and conventions**

| Page | What it answers |
|---|---|
| [ai-instructions.md](./guides/ai-instructions.md) | The constitution, the pair-vs-orchestration mode router, and the universal rules (`[U-n]`) |
| [ai-rules-pair-programming.md](./guides/ai-rules-pair-programming.md) | Rules when a human works beside you: git, asking, whose stack, logs, browser, change-log (`[PP-n]`) |
| [ai-rules-orchestration.md](./guides/ai-rules-orchestration.md) | Rules under an orchestrator: lease, worktrees, no installs, stacked PRs, briefing sub-agents (`[OR-n]`) |
| [coding-standards.md](./guides/coding-standards.md) | Naming, contract-first changes, shared types and UI, comment hygiene, formatter/linter split |
| [code-query-tool.md](./guides/code-query-tool.md) | What the code index answers and what it does not, where it is available, indexer failure modes |

**Environment and delivery**

| Page | What it answers |
|---|---|
| [docker-workflow.md](./guides/docker-workflow.md) | Running the Docker dev stack, what never to do to it (kill by port), HMR limits, compose env gotchas |
| [deployment.md](./guides/deployment.md) | Config surfaces, production-safety defaults, order of operations, the production image, proxy lessons |
| [ci-cd.md](./guides/ci-cd.md) | Why images build in CI, runtime env substitution, pipeline shape, pinned-version deploys, registry 401s |
| [native-builds.md](./guides/native-builds.md) | Capacitor Android/iOS builds: JDK pinning, tracked vs generated projects, app id, versioning, env leaks |
| [native-ios-release.md](./guides/native-ios-release.md) | Apple-side signing, identifiers, API keys and TestFlight groups, in the order the roles need them |
| [dist-server-portal.md](./guides/dist-server-portal.md) | The tester build portal: what it hosts, the publish API shape, operating limits |
| [native-push.md](./guides/native-push.md) | Capacitor push: own plugin vs official, platform traps, taps, the registration stream, sign-out detach |
| [client-monitoring.md](./guides/client-monitoring.md) | Client error-tracking invariants, the hang detector, SDK gotchas, scrubbing, the tester diagnostics panel |

**Frontend and API**

| Page | What it answers |
|---|---|
| [frontend-howto.md](./guides/frontend-howto.md) | Adding a feature to web/mobile (contract → types → hook → page → route); drawer, invalidation and state gotchas |
| [frontend-ui-patterns.md](./guides/frontend-ui-patterns.md) | Which surface carries a form or message, confirmations, back-navigation, hand-rolled-primitive traps |
| [design-system.md](./guides/design-system.md) | Where a component lives in the shared UI lib, the decision test for adding one, web divergence without forking |
| [client-state-races.md](./guides/client-state-races.md) | Auth/session listener races, latest-wins counters, logout ordering in React state |
| [native-webview-pitfalls.md](./guides/native-webview-pitfalls.md) | What breaks silently inside a Capacitor WebView that desktop-browser e2e never shows |
| [realtime-and-live-updates.md](./guides/realtime-and-live-updates.md) | Consuming a push/subscription channel without stale state: refetch on rejoin, one topic one owner |
| [api-contract.md](./guides/api-contract.md) | The contract-first order (spec → shared types → mock → client), mock parity, defending against unknown values |
| [api-version-migration.md](./guides/api-version-migration.md) | Moving the client to another API version: two screen trees, a switch, a lint boundary |
| [third-party-sdk-bridge.md](./guides/third-party-sdk-bridge.md) | Embedding an origin-restricted vendor SDK behind an iframe and a postMessage RPC bridge |
| [payments-integration.md](./guides/payments-integration.md) | A payment provider: env-gated mock, server-side settlement, provider-side setup |
| [security-app-checklist.md](./guides/security-app-checklist.md) | Authz guards, secrets, validation, dependencies, storage, CORS/headers before a release |
| [security-session-checklist.md](./guides/security-session-checklist.md) | Session revocation limits, logout on a failed revoke, resurrection guard, token storage, Android backup |

**Testing**

| Page | What it answers |
|---|---|
| [testing.md](./guides/testing.md) | Strategy: which layer tests what, the runner lanes, how a green run can lie |
| [testing-quickstart.md](./guides/testing-quickstart.md) | Commands that look right and do the wrong thing: env files, lanes, container vs host, background gates |
| [writing-tests.md](./guides/writing-tests.md) | Whether a green spec proves anything: mutate the fix, control arms, one-sided assertions, timezones |
| [frontend-testing.md](./guides/frontend-testing.md) | Client unit/component tests: harness per workspace, i18n in specs, partial mocks, jsdom troubleshooting |
| [e2e-testing.md](./guides/e2e-testing.md) | Browser-suite architecture: the runner starts nothing, config layers, targets, data on a stand you do not own |
| [e2e-writing.md](./guides/e2e-writing.md) | Spec-then-implement, selectors, and the rules that cost a day each (deep links, browser-only clock) |
| [e2e-visual-regression.md](./guides/e2e-visual-regression.md) | Stable screenshot baselines: one platform, masking vs freezing vs normalising, small-screen sweeps |
| [browser-automation.md](./guides/browser-automation.md) | Which browser an agent may drive (an isolated one, never the user's) and how browser tools answer wrong |
| [mock-server.md](./guides/mock-server.md) | Contract-first mock of your own backend: change order, owner scoping, fixtures vs store, no back doors |
| [vendor-mocks.md](./guides/vendor-mocks.md) | Doubles of third parties: fail-closed switching, sentinel scenarios, what the mock does NOT reproduce |
| [real-backend-testing.md](./guides/real-backend-testing.md) | Running the app or e2e against a real test stand: the note for the backend team, CORS/WebSocket, probe-don't-read |
| [realtime-testing.md](./guides/realtime-testing.md) | On-device test plan for a realtime channel: accelerator-not-transport criteria, scenario matrix |

**Backend — worked example**

| Page | What it answers |
|---|---|
| [backend-howto.md](./guides/backend-howto.md) | (example) When an endpoint is justified at all; guards, DTO validation, what integration tests must cover |
| [database-operations.md](./guides/database-operations.md) | (example) How migrations apply and roll back, the `down()` policy, naming, editing an applied one |
| [migrations.md](./guides/migrations.md) | (example) Testing a migration, and changing a function signature safely |
| [migration-testing.md](./guides/migration-testing.md) | (example) Never run migrations in integration tests; the SQL recorder; source vs live-catalog specs |
| [test-isolation.md](./guides/test-isolation.md) | (example) Keeping test data invisible to production on a shared DB; bypass roles; the catalog is not isolated |
| [scheduled-jobs.md](./guides/scheduled-jobs.md) | (example) Cron job shape, what the leader lock promises, why the job must be idempotent anyway |
| [security-database-checklist.md](./guides/security-database-checklist.md) | (example) `SECURITY DEFINER` grants, `search_path` pinning, the registry-of-what-is-in-force pattern |
| [security-rls-checklist.md](./guides/security-rls-checklist.md) | (example) RLS traps: `WITH CHECK`, `OLD`, self-reference, claims vs membership, positive controls |
| [security-grants-checklist.md](./guides/security-grants-checklist.md) | (example) Table/column privileges, default ACLs, partitions, verifying both grant polarities |

## Target — where the code will disagree with us

Small and meant to stay small: a page lands here only where the code violates a decision, or
where agents keep choosing the wrong thing by default. See [README §2](./README.md). An empty
table is normal, not a gap.

| Page | What it answers |
| ---- | --------------- |

## Not doing — things we could build and decided against

**Injected core, read whole on every task**, like `target/` — the cheapest place to stop a bad
idea is before somebody designs it. Entries are budget-bound (15–25 lines) because of it. The
convention is in [not-doing/README.md](./not-doing/README.md).

| Page | The decision |
| ---- | ------------ |

## Modules — pulled for the tasks that touch them, not part of the core

**The per-page catalogue is [`modules/index.md`](./modules/index.md)**, not this file: `modules/`
is outside the core (`CONTRIBUTING.md` §3), so a table here would be charged to every prompt
while only a planner uses it — and a planner reads every module page anyway.

Pages are cut by **domain**, not one per source directory. The routing that a directory name
does *not* give you stays here, in *Not obvious from either end* above; that is the half a
sub-agent needs and the half a catalogue cannot serve.

## Reference — verbatim artifacts; grep, do not read whole

**The per-artifact catalogue is [`reference/README.md`](./reference/README.md)** — it says which
artifact settles which question, which to read whole and which to grep only, and
`CONTRIBUTING.md` protects it by name for that reason. Do not duplicate it here. If an artifact
is too large to open at all, say so here too, in one line, so nobody opens it on the way to the
catalogue.

## Raw

| Page                                         | What it is                                  |
| -------------------------------------------- | ------------------------------------------- |
| `journal/*.md`                               | Dated entries, `YYYY-MM-DD-<slug>.md`       |

## Maintaining the tree — skip unless you are writing into it

Rules for `/wiki-bootstrap`, `/wiki-ingest`, `/wiki-journal`, `/wiki-lint`, `/wiki-audit` and hand
edits. Reading the wiki to do work in the codebase needs none of it, which is why it lives apart
from `README.md`.

| Page | What it answers |
|---|---|
| [CONTRIBUTING.md](./CONTRIBUTING.md) | What authorizes a page, frontmatter, budgets, the shape of a `target/` page, the workflow |
| [modules/CONTRIBUTING.md](./modules/CONTRIBUTING.md) | The module page template, and what must never appear on one |
| [journal/CONTRIBUTING.md](./journal/CONTRIBUTING.md) | What belongs in the raw layer, who may write there, and the threshold |

Templates — skeletons, not pages; listed here so lint does not report them as orphans:

| Template | For |
|---|---|
| [journal/TEMPLATE.md](./journal/TEMPLATE.md) | A dated journal entry |
| [target/TEMPLATE.md](./target/TEMPLATE.md) | A contested decision: the rule, why, where the code disagrees |
| [not-doing/TEMPLATE.md](./not-doing/TEMPLATE.md) | A refusal: the decision, why, prior requests |
| [architecture/TEMPLATE.md](./architecture/TEMPLATE.md) | A curated architecture decision page |

## Operations — not knowledge

| Path               | What it is                                                                                                                         |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| [log.md](./log.md) | Append-only registry of bootstrap, ingest, lint and audit runs, and of which commit ranges an ingest has covered. Machine-read — never read it whole |
