# Questionnaire: testing

Covers `guides/testing.md`, `testing-quickstart.md`, `writing-tests.md`, `test-isolation.md`,
`migration-testing.md`, `frontend-testing.md`. The runner is detected, never asked.
`test-isolation.md` and `migration-testing.md` need a database: prune them together with the backend
example pages (`migrations.md`, `database-operations.md`, `security-database-checklist.md`,
`security-rls-checklist.md`, `security-grants-checklist.md`) when there is none.

## guides/testing.md — Testing strategy

**Applies when:** the repo has any automated test: `git ls-files | grep -E "\.(spec|test)\.[jt]sx?$|_test\.go$|(^|/)test_.*\.py$"`
returns anything, or a `test` script exists in any `package.json`.
**Otherwise:** keep-as-reference — no tests yet; the page is the target layout. Ask only decisions 1, 4, 5.

**Detect, don't ask:**
- runner and version per workspace — `git grep -l -E "\"(vitest|jest|mocha|ava|@playwright/test)\"" -- "*package.json"`; Python/Go/others: `test -f pytest.ini`, `test -f pyproject.toml`, `git ls-files "*_test.go"`
- runner configs and whether there are two lanes — `git ls-files | grep -E "(vitest|jest)\.[a-z.]*config|jest-.*\.json"`; read the `test*` scripts in `{{BACKEND_DIR}}/package.json`
- spec counts per layer — `git ls-files "{{BACKEND_DIR}}" | grep -c -E "\.(spec|test)\."`, same for `{{FRONTEND_DIR}}`, `{{MOBILE_DIR}}`, `{{E2E_DIR}}`; integration naming (`*.int-spec.*`, `*.e2e-spec.*`, `/integration/`)
- whether integration specs boot the app against a database — `git grep -l -E "createTestingModule|supertest|testcontainers|new Pool\(|createClient\(" -- "{{BACKEND_DIR}}"`
- retry / worker settings in the configs — `git grep -n -E "retry|retries|maxWorkers|--runInBand|forceExit|fileParallelism" -- "*config*" "*package.json"`
- env guard in the setup file — `git grep -n -E "setupFiles|globalSetup" -- "*config*"`, then read the file for a required-variable assertion
- CI test step and what it runs — `git ls-files | grep -E "\.github/workflows|\.gitlab-ci|azure-pipelines|Jenkinsfile"`, read the test job
- coverage config and thresholds — `git grep -n -E "coverageThreshold|coverage:|thresholds|--cov|fail_under" -- ":!*.md"`
- generated scenario index — `git grep -n -E "generate-docs|scenario-index" -- "*package.json"`

**Decide:**
1. **Where does the pyramid put its weight?** Decides which layer owns a rule and where the next test is written.
   - Ours: a rule lives in the cheapest layer that can fail on it — localization in client unit tests, data and permission rules in backend integration tests, reachability and cross-service flows in E2E; thin E2E.
   - Also common: unit-heavy (pure-logic domain, little I/O); integration-heavy / "trophy" (thin services, logic lives in queries); E2E-heavy (small team, little backend code).
   - Evidence: spec counts per layer; the E2E lane's size against the others.
   - Lands in: "The layers" table and the paragraph after it; drop rows for layers the project does not have.
2. **Do integration tests hit a real database?** Decides whether the two-lane section applies at all.
   - Ours: yes — the real app against a real database over HTTP; third parties doubled; unit lane never reaches it.
   - Also common: ephemeral database per run (container, scratch schema) — then serial lane and isolation relax; in-memory/fake database (fast, drifts from production behaviour); mocked data layer only (no integration layer — say so and drop "Unit versus integration").
   - Evidence: the "boots the app against a database" detect item.
   - Lands in: "Unit versus integration", "Two lanes".
3. **Is every endpoint required to have the integration matrix?** The hard coverage floor of the page.
   - Ours: every endpoint covers success, unauthenticated, wrong role, invalid input, not found.
   - Also common: matrix only for endpoints that mutate or expose user data; contract tests generated from the API schema.
   - Evidence: count of route files against integration specs (`git ls-files "{{BACKEND_DIR}}" | grep -c -E "controller|routes?/"` against integration spec count).
   - Lands in: the paragraph "All new functionality is covered. Every backend endpoint…".
4. **What must pass before a merge?** Decides what "green" means in review.
   - Ours: both lanes green (a red unit lane hides the integration lane), plus E2E on the stand; the regenerated scenario index committed with the test change.
   - Also common: unit + lint + typecheck required, integration and E2E nightly only; E2E required only for labelled changes; all required checks enforced by branch protection.
   - Evidence: the CI test job and the branch-protection checks it feeds.
   - Lands in: a short "Before a merge" list added under "Two lanes" (none shipped; page only says "read both halves").
5. **What is the coverage policy?** Stops both "no one looks" and "chase the number".
   - Ours: (none shipped beyond "all new functionality is covered" and the endpoint matrix) — no numeric threshold.
   - Also common: threshold on changed lines only (diff coverage), enforced in CI; global floor that may only ratchet up; reported but never enforced.
   - Evidence: the coverage detect item.
   - Lands in: a "Coverage" paragraph under "The layers".
6. **How are flaky tests handled?** A silent retry hides real defects; no retry makes the gate unusable.
   - Ours: integration specs only, a small fixed retry count with every failed attempt logged; units never retried; serial integration lane because contention is environmental, not a code bug; force-exit as a known symptom.
   - Also common: quarantine tag with an owner and a deadline, excluded from the gate; zero tolerance, a flaky test is a bug fixed or deleted the same week; retry in CI only, never locally.
   - Evidence: the retry/worker detect item; any `skip`/`fixme` markers — `git grep -c -E "\.skip\(|\.fixme\(|xit\(|xdescribe\(" -- "{{E2E_DIR}}" "{{BACKEND_DIR}}"`.
   - Lands in: "Why the integration lane is serial" (retry sentence) and a new "Flaky tests" note.

**Web, on request:** known issues of the detected runner version: path-ignore replaces defaults,
serial and worker flags being mutually exclusive, open-handle/force-exit behaviour, retry semantics
and per-project config merging for the detected major version.

## guides/testing-quickstart.md — Testing quick start

**Applies when:** any workspace has a test script: `git grep -l "\"test" -- "*package.json"`.
**Otherwise:** prune — nothing to quick-start; the page only holds traps around existing commands.

**Detect, don't ask:**
- test commands per workspace — read the `scripts` of `{{BACKEND_DIR}}`, `{{FRONTEND_DIR}}`, `{{MOBILE_DIR}}`, `{{E2E_DIR}}` `package.json`
- test env files and their example siblings — `git ls-files | grep -E "\.env.*example|\.env\.test"`, `git check-ignore -v .env.test`
- host-versus-container split — `git ls-files | grep -E "docker-compose|compose\.ya?ml|Dockerfile"` and whether a second env file names service hostnames
- whether the integration lane touches a shared dev database — read the DB host in the example env file

**Decide:**
1. **How does a fresh worktree or clone get its test env?** Skipped env fails far from the cause.
   - Ours: copy from the `.example` siblings by hand; never hand-edit the generated files to make a test pass.
   - Also common: a bootstrap script that copies and fills them; values from a secret manager or `direnv`; env checked in for test-only, non-secret values.
   - Evidence: the env-files detect item.
   - Lands in: §1.
2. **Is there a cap on workers for a targeted run on a small dev host?** Without one a run can push the machine into swap.
   - Ours: call the runner directly with an explicit worker cap, or serial for one spec — never both flags.
   - Also common: a wrapper script that carries the cap (fine if it passes flags through); no cap on CI-only runs.
   - Evidence: the test scripts detect item (is there a wrapper that swallows flags).
   - Lands in: "Don't", wrapper-script bullet.

**Web, on request:** none.

## guides/writing-tests.md — Writing a test that holds

**Applies when:** the repo has any automated test (see `testing.md`).
**Otherwise:** keep-as-reference — it is written for whoever writes the first spec.

**Detect, don't ask:**
- table-driven or parametrised style in use — `git grep -c -E "it\.each|test\.each|describe\.each|@pytest.mark.parametrize|t\.Run\(" -- ":!node_modules"`
- fixture factories or builders — `git ls-files | grep -E "fixtures?|factories|builders|test-utils|testing/helpers"`
- timezone handling in test config — `git grep -n -E "TZ=|process\.env\.TZ|timezone" -- "*config*" "*package.json" "*setup*"`
- committed `.only` — `git grep -n -E "(it|test|describe)\.only\(" -- ":!*.md"`

**Decide:**
1. **How is a regression test proven to pin its fix?** Red-before/green-after is not enough for multi-part fixes.
   - Ours: mutate each part of the fix independently, by hand, and watch a named test go red, before calling it done.
   - Also common: red-at-merge-base only (cheap, weaker); mutation-testing tool (Stryker, mutmut) on changed files in CI; required only for security and money paths.
   - Evidence: none — ask directly; show whether a mutation tool is in `package.json`/dev dependencies.
   - Lands in: "Red at the merge base is not enough".
2. **What is the timezone policy for test runs?** Date code is green on CI (UTC) and red on a laptop otherwise.
   - Ours: restate the production zone decision in the assertion; keep one deliberately offset control case; run once under a non-UTC `TZ` when touching date code.
   - Also common: pin `TZ=UTC` in the runner config for everyone (simple, hides local-time bugs); fake timers and fixed instants only.
   - Evidence: the timezone detect item and whether production date code pins a zone.
   - Lands in: "An assertion must make the same timezone decision…".
3. **May a fixture insert directly into a state, or must it go through the real transition?** Decides how much a fixture can lie.
   - Ours: seed the rest of the state a real writer would; absence is an explicit argument at the call site.
   - Also common: factories/builders that call the real service; direct inserts allowed only in read-path tests.
   - Evidence: the fixtures detect item — read how rows are created.
   - Lands in: "A fixture that inserts straight into a state…".

**Web, on request:** none.

## guides/test-isolation.md — Test isolation (marker pattern)

**Applies when:** tests run against a database that is shared with something else (a dev stack,
other workers, or a real environment): any `git grep -n -E "test_marker|TEST_DATABASE|DATABASE_URL" -- "{{BACKEND_DIR}}" "{{E2E_DIR}}" "*.env*example"`
hit, a migrations folder, and no per-run database in the test setup.
**Otherwise:** prune — together with `migration-testing.md` and the backend example pages
(`migrations.md`, `database-operations.md`, `security-database-checklist.md`,
`security-rls-checklist.md`, `security-grants-checklist.md`). If there is a database but each run owns
a fresh one, keep-as-reference: only the principles survive.

**Detect, don't ask:**
- an existing marker column or policy — `git grep -l -E "test_marker|is_test|tenant_test" -- "{{BACKEND_DIR}}"`
- which isolation exists today — `git grep -n -E "testcontainers|CREATE DATABASE|CREATE SCHEMA|ROLLBACK|BEGIN;|beforeEach.*truncate|TRUNCATE" -- "{{BACKEND_DIR}}" "{{E2E_DIR}}"`
- row-level security in use — `git grep -l -i -E "ENABLE ROW LEVEL SECURITY|CREATE POLICY" -- "{{BACKEND_DIR}}"`
- cleanup helpers — `git grep -l -E "afterAll|globalTeardown|cleanup" -- "{{BACKEND_DIR}}" "{{E2E_DIR}}"`, and permanent fixtures seeded in `globalSetup`
- privileged clients that bypass policies — `git grep -l -E "service_role|SERVICE_KEY|superuser|admin client" -- "{{BACKEND_DIR}}"`

**Decide:**
1. **What is the isolation strategy?** Everything else on the page follows from it.
   - Ours: a nullable marker column plus a row-level predicate and a stamping trigger, so test rows are invisible to production and each other's mess is shared only among test sessions.
   - Also common: a database or schema per run (strongest, costs boot time); transaction rollback per test (fast, cannot cover multi-connection or E2E flows); truncate-and-reseed in a dedicated test database (simple, serial only).
   - Evidence: the existing-marker and isolation detect items.
   - Lands in: the opening callout; if not the marker pattern, keep only the "catalog is not isolated" and "client pollution" sections.
2. **May tests ever run against a shared or real environment?** Decides whether leaked rows are a production risk or only a nuisance.
   - Ours: yes — hence the marker, and the rule that integration tests never execute a migration.
   - Also common: never; tests only touch databases they created.
   - Evidence: the example env file's DB host; the E2E overlay envs.
   - Lands in: opening callout; "The marker isolates rows, not the catalog".
3. **How is test data cleaned up?** A leaked fixture slowly corrupts every later run.
   - Ours: permanent markers for read-only seeded fixtures; per-run temporary markers cleaned in `afterAll` by one helper that throws if a delete is blocked; new tables owed by a parent are added to that helper.
   - Also common: drop the database/schema at the end of the run; nightly sweep job deleting anything older than N hours; no cleanup (fresh stack per run).
   - Evidence: the cleanup-helpers detect item.
   - Lands in: "Marker values in practice".
4. **How must a new privileged read treat test rows?** The leak recurs here.
   - Ours: it filters the marker by hand, reproducing the whole visibility matrix (not `eq(marker)`).
   - Also common: privileged reads are forbidden in list endpoints; privileged client always reads through a view that applies the filter.
   - Evidence: the privileged-clients detect item.
   - Lands in: "The two 'yes' answers that are not isolation".

**Web, on request:** if RLS is in use, the detected database's version-specific behaviour of policies
under `SECURITY DEFINER` functions, `CASCADE` drops and trigger ordering.

## guides/migration-testing.md — Testing a migration

**Applies when:** the repo has a migrations folder: `git ls-files | grep -i -E "migrations?/"` returns files, or
`git grep -l -E "up\(|down\(|alembic|flyway|knex|typeorm.*migration|prisma migrate"`.
**Otherwise:** prune — together with `test-isolation.md` and the backend example pages
(`migrations.md`, `database-operations.md`, `security-database-checklist.md`,
`security-rls-checklist.md`, `security-grants-checklist.md`). Overlaps `migrations.md`
(boundary and recorder); do not merge, keep both or prune both.

**Detect, don't ask:**
- migration tool and runner — `git ls-files | grep -i -E "migrations?/"`, `git grep -l -E "typeorm|knex|prisma|sequelize|alembic|flyway|goose" -- "*package.json" "*requirements*" "*go.mod"`
- migration file format (TS `up()/down()`, plain SQL, ORM schema diff) — read two files
- migration specs and whether they execute against a pool — `git grep -l -E "\.up\(|\.down\(|runMigrations|migrate\(" -- "*.spec.*" "*.test.*" "*_test.*"`
- a recorder-style fake pool — `git grep -n -E "issued|queries\.push|as unknown as Pool" -- "{{BACKEND_DIR}}"`
- a CI job that builds a scratch database from zero — `git grep -n -i -E "migrat" -- ".github" ".gitlab-ci.yml" "azure-pipelines*" "Jenkinsfile"`
- security properties set by migrations (grants, policies, `search_path`) — `git grep -l -i -E "GRANT |REVOKE |CREATE POLICY|search_path" -- "*migrat*"`

**Decide:**
1. **May a test ever run a migration?** The page's central boundary.
   - Ours: no, never against a live connection pool; use a fake pool that records SQL, or assert the live catalog for properties that may be stale.
   - Also common: yes, on a scratch database the test itself creates and drops (then the boundary moves from "never execute" to "never execute on a database you did not create").
   - Evidence: the migration-specs-executing detect item and the isolation strategy chosen in `test-isolation.md`.
   - Lands in: "The boundary".
2. **Is there a fresh-database gate?** Applied migrations are never re-run, so syntax and ordering errors in old files only surface on production.
   - Ours: a deliberate CI job that builds a scratch database from zero and runs every migration.
   - Also common: run on every PR; nightly only; restore a production snapshot and migrate it (catches data-dependent failures).
   - Evidence: the CI-job detect item.
   - Lands in: "The recorder resolves everything…".
3. **Which migrations need the two-spec guard (source + live catalog)?** Cost grows per migration.
   - Ours: every migration that establishes a security property (grant, policy, `search_path` pin).
   - Also common: all migrations touching auth or money tables; none (tests only the end state).
   - Evidence: the security-properties detect item.
   - Lands in: "Guarding a schema invariant takes two specs".

**Web, on request:** none for the page's rules; for the detected migration tool, its documented
rollback semantics and what `CASCADE`/`CREATE OR REPLACE` preserve in the detected database version.

## guides/frontend-testing.md — Frontend unit and component testing

**Applies when:** a client workspace has a runner: `git grep -l -E "\"(vitest|jest)\"" -- "{{FRONTEND_DIR}}/package.json" "{{MOBILE_DIR}}/package.json"`.
**Otherwise:** prune if there is no client workspace; keep-as-reference if there is one but no runner yet.

**Detect, don't ask:**
- runner, DOM environment and Testing Library — read `{{FRONTEND_DIR}}/package.json` (`vitest`, `jest`, `jsdom`, `happy-dom`, `@testing-library/react`)
- harness per workspace — `git ls-files "{{FRONTEND_DIR}}" "{{MOBILE_DIR}}" | grep -E "setup|test-utils|renderWithProviders|vitest\.config|jest\.config"`
- localization library and languages — `git grep -l -E "i18next|react-intl|formatjs|lingui" -- "*package.json"`; `git ls-files | grep -E "locales?/.*\.json"`
- how existing specs query — counts of `git grep -c -E "getByRole|getByLabelText" ...` against `getByTestId` and `getByText`
- module mocking and native plugin mocks — `git grep -l -E "vi\.mock\(|jest\.mock\(" -- "{{FRONTEND_DIR}}" "{{MOBILE_DIR}}"`; Capacitor — `git grep -l "@capacitor/" -- "{{MOBILE_DIR}}/package.json"`
- shared UI library with or without its own `test` script — read its `package.json`

**Decide:**
1. **How is localization tested?** Decides how many specs a copy change breaks.
   - Ours: per-file i18n instance backed by the real bundle; assert each language; a separate locale spec writes expected sentences out a second time with fallback disabled.
   - Also common: key-only assertions (cheap, assert nothing a user reads); snapshot of rendered text per language; pseudo-locale pass in E2E only.
   - Evidence: the localization detect item and how existing specs mock the i18n library.
   - Lands in: "Localization". Skip when the app has one language.
2. **Which queries are allowed for finding elements?** A stable selector policy stops copy changes breaking specs.
   - Ours: role and label first; test id only when no semantic query distinguishes the element.
   - Also common: test ids everywhere (stable, ignores accessibility); text queries for simple apps.
   - Evidence: the query-count detect item.
   - Lands in: "What to assert".
3. **Where does the unit/E2E boundary sit for UI?** Prevents double coverage or gaps.
   - Ours: unit tests own localization and component logic; E2E owns cross-service flows and visual regression.
   - Also common: components covered by visual/component tests in a browser (Storybook, Playwright component testing) instead of jsdom; no unit layer for UI.
   - Evidence: spec counts per client workspace against `{{E2E_DIR}}`.
   - Lands in: the second paragraph and "What to assert".
4. **Does the shared UI library need its own harness?** Decides whether components in it can regress unseen.
   - Ours: no — exercised only through client specs, and the workspace README says so.
   - Also common: own runner with component tests (when several apps consume it); visual snapshot tests in a story tool.
   - Evidence: the shared-UI-library detect item.
   - Lands in: second paragraph under the intro.

**Web, on request:** version-specific known issues of the detected runner and Testing Library major
(hoisting of module mocks, jsdom gaps such as `ResizeObserver`/`matchMedia`, act-environment
warnings, router test utilities for the detected router version).
