# Questionnaire: e2e and mocks

Covers `guides/e2e-testing.md`, `e2e-writing.md`, `e2e-visual-regression.md`, `mock-server.md`,
`vendor-mocks.md`, `real-backend-testing.md`, `realtime-testing.md`. The three `e2e-*` pages prune
together; `mock-server.md` and `vendor-mocks.md` are checked separately (a vendor double can exist
without an own-backend mock, and the reverse).

## guides/e2e-testing.md — E2E testing (Playwright suite)

**Applies when:** the repo has a browser e2e suite — `git ls-files | grep -E '(^|/)(playwright|cypress)\.config\.'`
returns a file, or `git grep -lE '"(@playwright/test|cypress)"' -- '*package.json'` matches.
**Otherwise:** prune — also prune `e2e-writing.md` and `e2e-visual-regression.md` (all `e2e-*`).
If the suite uses Cypress rather than Playwright, keep-as-reference: the architecture sections
(runner starts nothing, config layers, targets, test data) hold; offer to reword the Playwright-specific lines.

**Detect, don't ask:**
- Test runner and version — `git grep -nE '"(@playwright/test|cypress)"' -- '*package.json'`
- Projects (surfaces) in the config — `git grep -nE 'name:|devices\[|viewport' -- '{{E2E_DIR}}/playwright.config.*'`
- Whether the config starts a server itself — `git grep -n 'webServer' -- '{{E2E_DIR}}'`
- Workers / parallelism — `git grep -nE 'workers|fullyParallel' -- '{{E2E_DIR}}'`
- Target switch and env loading — `git grep -nE 'E2E_TARGET|E2E_ENV|baseURL|dotenv' -- '{{E2E_DIR}}'`
- Containerised runner and compose profile — `git ls-files | grep -iE 'compose.*\.ya?ml|Dockerfile'` then `git grep -n 'depends_on' -- '*compose*'`
- Test-only endpoints used by tests — `git grep -nE 'reset|preset|__test|/test/|debug' -- '{{E2E_DIR}}'`
- Native-shell tests (Appium/Detox) — `git grep -lE 'appium|detox|wdio' -- '*package.json'`

**Decide:**
1. **What does e2e run against: a mock, a real backend, or both?** — this sets how many targets the
   fixture knows about and whether a `mock` target exists at all.
   - Ours: the runner is handed URLs and starts nothing; one `E2E_TARGET` switch selects the stand
     (local mock or a real stand), kept in one fixture file so a test never knows which it is on — so
     the same suite survives the mock retiring.
   - Also common: mock only, hermetic, started by the same compose file (simplest; fine while there is
     no stable real environment); real backend only (no mock exists; slower, needs permanent accounts).
   - Evidence: target switch and `webServer`/`depends_on` detect items.
   - Lands in: "The one idea", "Targets".
2. **Must the suite also run on a shared real environment?** — if yes, tests may not depend on a
   test-only endpoint, a reset, presets or server-clock control, even on localhost.
   - Ours: yes, assume it will — no test depends on a test-only endpoint; mock test handles are a
     speed-up, off by default, mounted only with an enable flag plus a token — because a test that is
     green only through a back door cannot move to the real stand without rewriting.
   - Also common: mock-only, back doors allowed (reset/presets/clock control make tests faster and
     deterministic; the suite is then not portable); both, with a tagged subset that runs on the real stand.
   - Evidence: "Test-only endpoints used by tests" detect item.
   - Lands in: "Test data on a stand you do not control" (keep or mark optional), and
     `mock-server.md` "The mock must not carry test-only back doors".
3. **Workers and parallelism?** — parallel runs corrupt stateful files and shared stands.
   - Ours: workers 1, `fullyParallel` off; raising it is an explicit per-suite decision — because
     tests are stateful across `test()` blocks and a shared stand tolerates one run at a time.
   - Also common: parallel across files with per-file markers and isolated accounts (hermetic mock,
     large suite); sharded across CI machines each with its own stack.
   - Evidence: "Workers / parallelism" detect item.
   - Lands in: second paragraph, "One stack, one run at a time".
4. **Is the native shell (plugins, push, deep links) in scope for automated tests?** — decides whether
   the "Native shell" section stays as guidance or becomes a project.
   - Ours: no — the mobile project drives the bundle in a mobile viewport under Chromium; native
     behaviour is covered by manual plans — because it needs a different runner (Appium for hybrid apps).
   - Also common: a separate native test project (Appium, Maestro; Detox for React Native) with its own CI job.
   - Evidence: "Native-shell tests" detect item; `test -d {{MOBILE_DIR}}`.
   - Lands in: "Native shell". Skip the question when there is no `{{MOBILE_DIR}}`.

**Web, on request:** release notes and open issues for the detected Playwright version (container
image tag vs package version mismatch, report-host/CSP issues of the detected CI server, `--ui` against
containerised stacks); Playwright Docker image guidance for the detected version.

## guides/e2e-writing.md — Writing e2e tests

**Applies when:** same check as `e2e-testing.md`.
**Otherwise:** prune with the other `e2e-*` pages.

**Detect, don't ask:**
- Selector usage — `git grep -c 'getByTestId' -- '{{E2E_DIR}}'` versus `git grep -c 'getByRole' -- '{{E2E_DIR}}'`
  (and `getByLabel`, `getByText`) — report as "N of M locators use test ids"
- Custom test-id attribute — `git grep -n 'testIdAttribute' -- '{{E2E_DIR}}'`
- Test ids in the app code — `git grep -lE 'data-testid|data-test-id|data-cy' -- '{{FRONTEND_DIR}}'`
- Extended `test` fixture vs direct import — `git grep -c "from '@playwright/test'" -- '{{E2E_DIR}}'`
- In-app `page.goto` calls — `git grep -nE 'page\.goto\(.[/]\w' -- '{{E2E_DIR}}'`
- Fake clock use — `git grep -lE 'clock\.(install|fastForward|setFixedTime)' -- '{{E2E_DIR}}'`
- Request layer (`route`) — `git grep -c 'page.route\|context.route' -- '{{E2E_DIR}}'`
- Third-party checkout, canvas/map, realtime assertions — `git grep -liE 'checkout|canvas|iframe|websocket|reconnect' -- '{{E2E_DIR}}'`
- E2E spec files in prose — `git ls-files | grep -E '(e2e-spec|\.spec)\.md$'`

**Decide:**
1. **Selector strategy: role and accessible name, or test ids?** — couples tests to either copy or markup.
   - Ours: role + accessible name first (headings, labelled inputs), a test id only if the project uses
     them and then it ranks above role/name where the name is a translated string, exact text last;
     decide once project-wide and do not mix by accident — because a broken test on a changed label is
     a fair alarm when copy is the contract with the user.
   - Also common: test ids everywhere (multilingual product, marketing copy changes often, designers
     own the text); role/name only (accessibility-first teams, single-language product).
   - Evidence: the selector-usage and test-id-in-app detect items.
   - Lands in: "Selectors" and the "test-id-free" bullet in "The shape of a test".
2. **Spec first, then code — with a human approval between?** — decides whether a prose spec is a required artefact.
   - Ours: yes, always; implementation never adds, removes or reorders scenarios, and stops to ask when
     the app disagrees with the spec — because reviewing code checks selectors while the argument worth
     having is coverage.
   - Also common: spec only for new features, direct tests for regressions (small teams); spec in the issue/PR description instead of a file.
   - Evidence: spec files detect item.
   - Lands in: "Spec first, then code".
3. **May tests deep-link with `page.goto('/route')`?** — deep links are faster; clicking through is a free route-exists assertion.
   - Ours: never, except the route guard and screens with no navigation — enter at `/` and click through helpers.
   - Also common: deep links allowed for setup, click-through only in dedicated navigation tests (large suites where nav changes break too many tests).
   - Evidence: "In-app `page.goto` calls" detect item.
   - Lands in: rule 1.
4. **Which conditional rules apply to this product?** — drop what the product cannot meet.
   - Ours: all stay — realtime park rules (4, 5), fake clock (6), server-clock pricing (7), third-party
     checkout (9), canvas/map pixels (10), no-made-up-data (11), ledger history (12).
   - Also common: prune the rules whose feature the product lacks (no realtime, no payments, no map).
   - Evidence: "Third-party checkout, canvas/map, realtime" and fake-clock detect items.
   - Lands in: "Rules worth the day they cost" (delete the inapplicable numbered rules).

**Web, on request:** locator and `page.clock` API availability for the detected Playwright version
(the clock API arrived in a recent minor — check the detected version before relying on it); known
strict-mode and `getByRole` issues for the detected component library's dialog/alert roles.

## guides/e2e-visual-regression.md — E2E visual regression (screenshots)

**Applies when:** the suite takes screenshots — `git grep -lE 'toHaveScreenshot|toMatchSnapshot|matchImageSnapshot' -- '{{E2E_DIR}}'` matches.
**Otherwise:** prune — offer deleting the page if the team does not want visual regression; if they
might later, keep-as-reference.

**Detect, don't ask:**
- Screenshot assertions count — `git grep -c 'toHaveScreenshot' -- '{{E2E_DIR}}'`
- Global threshold settings — `git grep -nE 'maxDiffPixels|maxDiffPixelRatio|threshold' -- '{{E2E_DIR}}'`
- Snapshot platform suffix — `git ls-files '{{E2E_DIR}}' | grep -E '\-(darwin|linux|win32)\.png$'` (suffixed means developer-machine baselines)
- Committed baselines — `git ls-files '{{E2E_DIR}}' | grep -E '\.png$'`
- Enable flag for comparison — `git grep -nE 'VISUAL|updateSnapshots|snapshotPathTemplate' -- '{{E2E_DIR}}'`
- Screenshot stylesheet and masks — `git grep -nE 'stylePath|mask:' -- '{{E2E_DIR}}'`
- Viewports per project — `git grep -n 'viewport' -- '{{E2E_DIR}}/playwright.config.*'`

**Decide:**
1. **Visual regression on or off?** — baselines cost re-shoot effort on every UI change.
   - Ours: on, folded into the functional scenarios (not a separate suite); a new UI state ships with
     its screenshot, optional for nobody — because a separate suite means clicking through every screen twice.
   - Also common: off (design in flux, small team; delete this page); on only for a few key screens
     (cheaper, weaker); delegated to a hosted service (Percy/Chromatic-style) instead of in-repo baselines.
   - Evidence: "Screenshot assertions count".
   - Lands in: the intro; if off, prune the page and remove its links from the other e2e pages.
2. **Which platform produces baselines?** — fonts render differently on macOS and Linux.
   - Ours: container only (recommended when CI runs the suite in a container) — snapshots compared and
     recorded only where a visual-enable flag is set, one unsuffixed committed set; developer machines
     skip comparison — because a baseline is only as stable as the platform that shot it.
   - Also common: developer-machine baselines with platform suffixes (no containerised CI; regenerate locally).
   - Evidence: "Snapshot platform suffix" and "Enable flag" detect items.
   - Lands in: "One platform produces the baselines".
3. **Threshold policy: how much diff is tolerated, and how strict is a mismatch?**
   - Ours: a small global `maxDiffPixels` for anti-aliasing slack, an optional per-call ratio on top;
     flakes are fixed by masking, freezing or normalising, never by raising the threshold; the snapshot
     helper may be a soft assertion so a pixel diff is reported while the scenario still checks logic.
   - Also common: zero tolerance (pixel-exact, only with one controlled rendering platform); a global
     ratio (`maxDiffPixelRatio`) on large pages; hard assertions in CI, soft locally.
   - Evidence: "Global threshold settings".
   - Lands in: the intro paragraph, "Five tools" (tool 2's pixel-budget remark) and the soft-assertion line.
4. **Which viewports get baselines?** — each adds a baseline set to re-shoot.
   - Ours: one per project (mobile viewport, desktop viewport); small-screen sweeps ignore snapshots
     and prove reachability only — because two more sets triple the cost of every UI change.
   - Also common: desktop only; one extra tablet set; every breakpoint (design-system teams).
   - Evidence: "Viewports per project".
   - Lands in: "Baselines are one viewport per project".

**Web, on request:** `toHaveScreenshot` options and `stylePath`/`animations`/`caret` behaviour for the
detected Playwright version; font-rendering differences of the detected Docker image's OS; known flakes
for canvas and web-font loading.

## guides/mock-server.md — Contract-first mock server

**Applies when:** the repo has a mock of its own backend — `test -d {{MOCK_SERVER_DIR}}`, or
`git grep -lE '"(msw|json-server|@mswjs/data|prism|@stoplight/prism-cli)"' -- '*package.json'` matches,
or a mock folder exists next to an API contract file (`test -f {{API_CONTRACT_FILE}}`).
**Otherwise:** prune — also prune `vendor-mocks.md` if the repo has no third-party doubles either;
keep `vendor-mocks.md` otherwise. If the team plans a mock, keep-as-reference.

**Detect, don't ask:**
- Contract file present and format — `test -f {{API_CONTRACT_FILE}}`; `git grep -lE '^(openapi|swagger):' -- '{{API_CONTRACT_FILE}}'`
- Shared types package — `test -d {{TYPES_DIR}}`; `git grep -c '{{TYPES_DIR}}' -- '{{MOCK_SERVER_DIR}}'`
- Mock framework and routes layout — `git ls-files '{{MOCK_SERVER_DIR}}' | head -40`, then read `{{MOCK_SERVER_DIR}}/package.json`
- Types generated from the contract — `git grep -lE 'openapi-typescript|orval|openapi-generator|swagger-codegen' -- '*package.json'`
- Contract validation in CI — `git grep -nE 'spectral|openapi.*(lint|validate)|dredd|schemathesis|pact' -- '*package.json' '*.yml' '*.yaml'`
- Persistence — `git ls-files '{{MOCK_SERVER_DIR}}' | grep -iE 'seed|runtime|store|\.json$'` and `git check-ignore -v {{MOCK_SERVER_DIR}}/runtime`
- Test handles mounted in the mock — `git grep -nE 'reset|preset|clock|__test' -- '{{MOCK_SERVER_DIR}}/src'`

**Decide:**
1. **Who owns the mock, and how does it stay in sync with the API contract?** — a mock the owner of
   the backend does not maintain drifts into a story the frontend tells itself.
   - Ours: the contract file is the single source of truth and every change goes contract -> shared
     types -> mock handler -> fixtures/store -> client, in that order; the frontend team maintains the
     mock; a contract test against the real stand is what keeps it honest — because the mock agrees
     with your understanding by construction, including wherever that is wrong.
   - Also common: the backend team owns the contract and generates the mock from it (Prism, MSW
     handlers generated from the spec — no hand-written handlers, but no stateful behaviour);
     consumer-driven contracts (Pact: the mock is the consumer's expectations, verified on the provider);
     types generated from the contract instead of hand-written.
   - Evidence: contract-file, generated-types and validation-in-CI detect items.
   - Lands in: "Principle" and "Adding an endpoint".
2. **How often is the mock verified against the real backend?** — the only defence against drift.
   - Ours: a contract test against the real stand ("probe, don't read" — a published schema can hide a
     version difference); no cadence shipped.
   - Also common: on every CI run (costly, strongest); nightly or weekly; manual before a release;
     none while the backend does not exist yet.
   - Evidence: "Contract validation in CI".
   - Lands in: "Principle" (add the cadence and the command).
3. **Stateful or stateless mock?** — stateful costs a store and persistence; stateless is simpler but cannot test multi-step flows.
   - Ours: stateful — a per-entity store keyed by user id, persisted to JSON; committed read-only seed
     separate from gitignored runtime state; all reads scoped by the authenticated user.
   - Also common: in-memory only, reset on restart (hermetic CI); stateless fixtures (static UI work).
   - Evidence: "Persistence" detect item.
   - Lands in: "Two kinds of data".
4. **May the mock expose test handles (reset, presets, clock control)?**
   - Ours: yes as a convenience, never a dependency — mounted only when an explicit enable flag and a
     token are both set, off by default, and no test needs them (mirrors question 2 of
     `e2e-testing.md`; keep the two answers consistent).
   - Also common: no test handles at all (strictest); always-on in a local-only mock that can never
     reach a shared stand.
   - Evidence: "Test handles mounted in the mock".
   - Lands in: "The mock must not carry test-only back doors that tests depend on".

**Web, on request:** current tooling to generate a mock or types from an OpenAPI document (version
and maintenance status of the detected generator); contract-testing tools compatible with the
detected contract format and CI.

## guides/vendor-mocks.md — Third-party (vendor) mocks

**Applies when:** the code has an in-memory or fake double of an external service — `git grep -liE 'class (Mock|Fake|InMemory)\w+(Client|Gateway|Service|Provider)|USE_MOCK|MOCK_\w+=' -- '{{BACKEND_DIR}}'` matches, or a mock-switch variable appears in `.env.example`.
**Otherwise:** prune — if the team uses the vendors' own sandboxes only, offer deleting the page.

**Detect, don't ask:**
- Vendors with a double — the files matched above, list class names
- Mock switch variables and where they are read — `git grep -nE 'USE_MOCK|MOCK_[A-Z_]+|process\.env\.\w*MOCK' -- '{{BACKEND_DIR}}'` (report how many places read each)
- Production guard — `git grep -nE 'NODE_ENV|production' -- '{{BACKEND_DIR}}'` near the dev routes
- Dev-only fixture routes — `git grep -nE "router\.(get|post)\(['\"]/(dev|test|fixtures)" -- '{{BACKEND_DIR}}'`
- Sentinel constants — `git grep -nE 'SENTINEL|MAGIC_|FAIL_(AMOUNT|SUFFIX)' -- '{{BACKEND_DIR}}'`
- Idempotency-key handling in the double — `git grep -niE 'idempoten' -- '{{BACKEND_DIR}}'`
- Real-sandbox specs skipped by default — `git grep -nE 'skip|RUN_SANDBOX|SANDBOX' -- '{{E2E_DIR}}' '{{BACKEND_DIR}}'`

**Decide:**
1. **Per vendor: in-repo double, the vendor's sandbox, or both?** — the double is the only thing a
   routine run exercises when the sandbox is unusable (mutual TLS, shared state, absent, checks nothing).
   - Ours: the double for routine runs; the real sandbox by hand as a provisioning or certificate
     check only, with a spec that is skipped unless an explicit env flag is set — because a loop on a
     shared sandbox is flaky and slow.
   - Also common: the sandbox in CI for vendors with a good one (nightly); record/replay of real
     responses (VCR-style cassettes); contract tests against the vendor's published spec.
   - Evidence: "Vendors with a double", "Real-sandbox specs".
   - Lands in: "Why the divergence list matters" (per-vendor note).
2. **How is the double switched on?**
   - Ours: an exact env string (`USE_MOCK=true`; `1`/`TRUE` leave it off); production disables the dev
     surface unconditionally; dev routes answer 404, not 403; one flag per vendor surface falling back
     to the main flag only when unset — because it must fail closed.
   - Also common: a config profile or DI binding chosen per environment; a boolean parsed leniently
     (accepts `1`/`true`) when production gating is done elsewhere.
   - Evidence: "Mock switch variables" and "Production guard".
   - Lands in: "Switching it on: fail closed, twice".
3. **How are failure and edge paths selected?**
   - Ours: deterministic sentinel inputs (an identifier suffix, a magic amount, a magic name) with each
     constant documented only next to its definition in the source — because the same request must mean
     the same thing on every run.
   - Also common: a per-test scenario API (the test arms the double with the next outcome — expressive,
     needs a back door); randomised chaos (finds more, reproduces badly); record/replay fixtures.
   - Evidence: "Sentinel constants".
   - Lands in: "Selecting a scenario: deterministic sentinels".
4. **Who maintains the "what the mock does NOT reproduce" list, and where does it live?**
   - Ours: written down per vendor and kept honest as the mock changes; the sentinel catalogue stays in
     source comments, not on a wiki page.
   - Also common: a section in each vendor's integration doc; a table in the mock's README.
   - Evidence: whether such a list exists — `git grep -liE 'does not reproduce|not modelled|unmodelled' -- '*.md' '{{BACKEND_DIR}}'`
   - Lands in: "What a mock typically does NOT reproduce".

**Web, on request:** the detected vendors' sandbox status and documented test values (test cards,
magic amounts); the detected vendors' idempotency and webhook retry semantics.

## guides/real-backend-testing.md — Testing against a real backend environment

**Applies when:** the app, image or e2e runner is ever pointed at a non-local environment (a shared
test or staging stand) — `git grep -nE 'staging|E2E_TARGET|API_URL|VITE_API' -- '.env*' '{{E2E_DIR}}' '*.yml'`
shows a URL that is not localhost, or `test -d {{MOCK_SERVER_DIR}}` exists alongside a deploy pipeline.
**Otherwise:** keep-as-reference for a mock-only project that will meet a real backend later; prune
if the app never talks to a remote API (everything is local or static).

**Detect, don't ask:**
- Environment URLs configured — `git grep -nE 'https?://[a-z0-9.-]+' -- '.env.example' '.env.*.example' '{{E2E_DIR}}/.env*'`
- Runtime env substitution in the image — `git ls-files | grep -iE 'nginx|entrypoint|env\.template|envsubst'`
- CORS configuration of the mock or stand — `git grep -niE 'cors|allowed.?origins' -- '{{MOCK_SERVER_DIR}}' '{{BACKEND_DIR}}'`
- Dev server port and host — `git grep -nE 'port|host' -- '{{FRONTEND_DIR}}/vite.config.*'` (or the framework's config)
- Native shell — `git ls-files | grep -E 'capacitor\.config|android/|ios/'`
- Realtime endpoint through a proxy — `git grep -nE 'proxy_pass|Upgrade|proxy' -- '*.conf' '*.template'`

**Decide:**
1. **Who operates the stand, and does it need an integration note?** — decides whether the
   "what the stand has to give you" section is a checklist for others or just your own notes.
   - Ours: a one-page integration note handed to the backend team: shipped image and ports, routing,
     WebSockets, runtime config, third-party keys, what does not work yet, a verification checklist.
   - Also common: you operate the stand yourself (the note becomes a runbook); the platform team
     deploys from a standard template (keep only app-specific deltas).
   - Evidence: runtime-substitution and environment-URL detect items.
   - Lands in: "What the stand has to give you, and what you have to give it".
2. **Which origin and port may local apps use against the stand?** — exact-match CORS fails everything else.
   - Ours: exactly one dev origin, `http://localhost:{{DEV_PORT}}`; another port or `127.0.0.1` is blocked.
   - Also common: a small allow-list of ports; a wildcard on a non-credentialed stand (no cookies).
   - Evidence: "Dev server port and host", "CORS configuration".
   - Lands in: "Running a local app against the stand".
3. **Is the native app in scope for the stand?** — the API URL is baked at build time there.
   - Ours: yes, with the stand's final URL as a build input and the WebView origins allowed in CORS.
   - Also common: web only against the stand; native builds only against the mock until release.
   - Evidence: "Native shell". Skip the question when there is none.
   - Lands in: the "Native apps are not in the compose file" paragraph.
4. **Test rules on the stand: do they match `e2e-testing.md`?** — only if question 2 of that page was
   answered "must also run on a shared real environment".
   - Ours: no test-only endpoints, no server-clock or reset dependence, probe rather than read the
     published schema, debug surfaces off on the stand.
   - Also common: a dedicated stand you control, where presets and resets are allowed.
   - Evidence: answers from `e2e-testing.md`.
   - Lands in: "Testing rules that follow from 'the stand is not ours'".

**Web, on request:** reverse-proxy `proxy_pass` trailing-slash and WebSocket-upgrade behaviour for the
detected proxy (nginx/Traefik/Caddy); CORS preflight behaviour of the detected backend framework;
Referer-restriction behaviour of the detected third-party browser keys.

## guides/realtime-testing.md — Realtime channel testing on devices

**Applies when:** the app keeps a long-lived connection and ships on devices —
`git grep -liE "new WebSocket|EventSource|@microsoft/signalr|socket\.io|\bws://|\bwss://" -- '{{FRONTEND_DIR}}' '{{MOBILE_DIR}}'` matches, and a native or installable mobile build exists
(`git ls-files | grep -E 'capacitor\.config|android/|ios/|manifest\.(json|webmanifest)'`).
**Otherwise:** prune — no realtime channel means no page; a realtime channel in a desktop-only web app
means keep-as-reference (reuse blocks B and D in a browser, drop C and F).

**Detect, don't ask:**
- Channel technology — `git grep -lE "new WebSocket|EventSource|@microsoft/signalr|socket\.io|graphql-ws|pusher|ably" -- '{{FRONTEND_DIR}}' '{{MOBILE_DIR}}' '*package.json'`
  (if SignalR is found, keep the "If your channel is SignalR" note; otherwise delete it)
- Polling fallback present — `git grep -nE 'refetchInterval|setInterval|polling' -- '{{FRONTEND_DIR}}' '{{MOBILE_DIR}}'`
- Reconnect/backoff logic — `git grep -niE 'reconnect|backoff|retry' -- '{{FRONTEND_DIR}}' '{{MOBILE_DIR}}'`
- Token lifetime setting on the server — `git grep -niE 'expires.?in|token.*(ttl|lifetime)|CloseOnAuthenticationExpiration' -- '{{BACKEND_DIR}}' '{{MOCK_SERVER_DIR}}'`
- Existing debug panel — `git grep -liE 'debug.?panel|connection.?id' -- '{{FRONTEND_DIR}}' '{{MOBILE_DIR}}'`
- Proxy upgrade headers — `git grep -n 'Upgrade' -- '*.conf' '*.template'`

**Decide:**
1. **Is the channel an accelerator or the only transport?** — sets the pass criteria for every scenario.
   - Ours: an accelerator — a missed event costs latency only; a periodic poll and the poll after each
     async command stay authoritative; a scenario fails only when the app ends up wrong, not slow.
   - Also common: the channel is the only transport (chat, collaborative editing) — pass criteria get
     stricter, "slow is fine" is deleted, and the correctness block (E) gains replay/ordering checks.
   - Evidence: "Polling fallback present".
   - Lands in: "What 'working' means".
2. **Which scenario blocks apply, and on which devices?** — each block costs real-device time.
   - Ours: A baseline, B token lifecycle, C app lifecycle, D network, E correctness without the
     socket, F wear; C and D are where client bugs surface.
   - Also common: A, C, E only (small team); add a per-OS version matrix or a device-farm run
     (larger products); drop B if the server never closes sockets on token expiry.
   - Evidence: "Token lifetime setting on the server".
   - Lands in: "Scenario matrix".
3. **Ship an in-app debug panel?** — it is the only way to force a reconnect and read connection state on a phone.
   - Ours: yes — status pill, connection id, counters, event log, Reconnect / Reset / Copy; English
     and unstyled, gated behind a debug flag, removed when the channel is stable.
   - Also common: logs only (server log plus a remote-logging SDK); a hidden gesture or build-flavour
     menu instead of a panel.
   - Evidence: "Existing debug panel".
   - Lands in: "Setup".
4. **Where do dated results live?**
   - Ours: a dated results section on this page: what passed, what was not run and why, what is open.
   - Also common: in the issue tracker or a test-management tool; a release checklist page.
   - Evidence: whether the adopting repo already has a manual-test log — `git ls-files | grep -iE 'test.?(plan|log|results)'`
   - Lands in: "What to do with the results".

**Web, on request:** background-execution limits of the current iOS and Android versions the team
supports (suspension, Doze, battery optimisation); documented behaviour of the detected channel
library (reconnect policy, keepalive/heartbeat defaults, token transport for browsers).
