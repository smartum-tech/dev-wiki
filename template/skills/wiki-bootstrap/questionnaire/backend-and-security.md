# Questionnaire — backend and security

Guides covered: backend-howto, database-operations, migrations, scheduled-jobs, security-app-checklist,
security-session-checklist, security-database-checklist, security-rls-checklist, security-grants-checklist.
Three gates decide pruning. **A** = a real backend lives in the repo (`{{BACKEND_DIR}}` exists and is not
only a mock server). **B** = that backend uses Postgres. **C** = RLS is used or client roles reach the
database directly. Check A first; the prune sets below name exactly which pages go together.

**Prune sets.** No A (client-only, or only `{{MOCK_SERVER_DIR}}`): prune *all seven* of backend-howto,
database-operations, migrations, scheduled-jobs, security-database-checklist, security-rls-checklist,
security-grants-checklist; keep security-app-checklist and security-session-checklist (they apply to any
client with auth). A but not B: keep backend-howto, security-app and security-session; prune
security-database, security-rls and security-grants as a trio (all three are Postgres-only); keep
database-operations + migrations as a pair only if the migration tool tracks files by name, else adapt.
B but not C: prune security-rls + security-grants together, keep security-database if definer functions
exist. After any prune, strip the now-dangling links from the pages that remain (security-app §1, §3, §5
and its intro link to backend-howto, security-rls, security-database, security-grants).

## guides/backend-howto.md — Adding backend functionality

**Applies when:** gate A — `test -d {{BACKEND_DIR}}` and it has a server entry point and dependencies:
`git ls-files {{BACKEND_DIR}} | grep -E "(main|server|app|index)\.(ts|js|py|go|rb)$"`.
**Otherwise:** prune — with no backend the page is rules for code that does not exist. (keep-as-reference
only if the user says a real backend is planned; the page already reads as "what the backend must do".)

**Detect, don't ask:**
- Framework — read `{{BACKEND_DIR}}/package.json` (nestjs / express / fastify / hono) or the equivalent manifest
- Do clients reach the data layer directly? — `git grep -lE "createClient\(|supabase|postgrest" -- {{FRONTEND_DIR}} {{MOBILE_DIR}}`
- Controllers vs guarded controllers — `git grep -c "@Controller" -- {{BACKEND_DIR}}` against `git grep -c "@UseGuards" -- {{BACKEND_DIR}}`
- Global validation pipe registered? — `git grep -nE "useGlobalPipes|APP_PIPE" -- {{BACKEND_DIR}}`
- Soft delete in use — `git grep -c "deleted_at" -- {{BACKEND_DIR}}`
- Integration tests exist and hit a real DB — `git ls-files {{BACKEND_DIR}} | grep -E "\.(e2e-)?spec\.|integration"`
- Realtime publication used — `git grep -c "supabase_realtime" -- {{BACKEND_DIR}}`
- Money columns — `git grep -nE "amount|price|balance" -- {{BACKEND_DIR}}`

**Decide:**
1. **Where does business logic and authorization live?** — decides whether the "do you need an endpoint"
   section is a rule or noise.
   - Ours: clients use the data layer directly under RLS; an endpoint exists only for a multi-table
     transaction, a privileged role, a privileged-API operation or a side effect — a proxy endpoint is a
     second, drifting copy of the authorization rules.
   - Also common: every call goes through the backend API and authorization lives in the app layer, DB
     is private (fits teams without Postgres RLS expertise, or non-Postgres stores); database functions
     (RPC) hold the transactional logic and the backend is thin (fits Supabase-style stacks).
   - Evidence: direct-client-access and controller counts.
   - Lands in: "Do you need an endpoint at all?"; "Migrations, RLS and realtime" (delete if the DB is private).
2. **How is endpoint authorization composed?** — one convention, or hybrids drift.
   - Ours: narrow per-concern guards after the auth guard, caller read through one current-user decorator;
     no generic roles table unless every guard migrates.
   - Also common: roles/permissions table with one policy decorator (fits many roles); a policy library such
     as CASL (fits per-resource rules).
   - Evidence: guard count and names.
   - Lands in: "Guarding endpoints".
3. **Validation: global pipe or per handler?** — a DTO decorator without a pipe validates nothing.
   - Ours: no global pipe means every `@Body()` binds one explicitly; global registration is the safer default for a new project.
   - Also common: global pipe plus a lint rule; schema validation at the edge (zod/ajv) instead of decorators.
   - Evidence: the global-pipe grep.
   - Lands in: "DTO validation is not automatic".
4. **Delete policy for user-facing data?**
   - Ours: soft delete (`deleted_at`) always; policies filter it; no real `DELETE`.
   - Also common: hard delete with an audit table (fits privacy-erasure duties); soft delete for some entities only.
   - Evidence: `deleted_at` count.
   - Lands in: "Small patterns worth keeping"; the soft-delete carve-out under "RLS silently filters realtime".
5. **Integration coverage required per endpoint?**
   - Ours: five cases each — success, 401, 403, 400, 404 — against a real database and real tokens.
   - Also common: required for mutating endpoints only; a contract-test suite generated from the API spec.
   - Evidence: the integration-test detect.
   - Lands in: "Testing".

**Web, on request:** known issues for the detected framework version's validation/guard order; the
hosted data API's current RLS + realtime behaviour; migration-boot patterns for the detected framework.

## guides/database-operations.md — How migrations apply, roll back, and get named

**Applies when:** gate A and a migrations folder with a runner — `git ls-files | grep -iE "migrations?/"`
and a tool in the manifest (umzug, knex, typeorm, prisma, drizzle, flyway, alembic, supabase CLI).
**Otherwise:** prune together with migrations.md (the pair stands or falls together); keep-as-reference
never — it is about a runner that tracks applied files by name.

**Detect, don't ask:**
- Migration tool — manifest scan: `git grep -nE "umzug|knex|typeorm|prisma|drizzle|flyway|alembic|supabase" -- '*package.json' '*requirements*.txt' '*.toml'`
- Applied at boot, by CLI or by CI — `git grep -nE "onModuleInit.*migrat|migrate:up|umzug|migrate deploy|db push" -- {{BACKEND_DIR}} package.json` plus CI files (`git ls-files | grep -E "workflows|pipelines|gitlab-ci"`)
- File naming in use — list the folder tail: `git ls-files {{BACKEND_DIR}} | grep -i migrations | sort | tail -5`
- Migrations without a `down` — `git grep -L "down" -- {{BACKEND_DIR}}/**/migrations/*`; ones whose `down` throws — `git grep -lE "throw new Error" -- {{BACKEND_DIR}}/**/migrations/*`
- Applied migrations edited after the fact — `git log --oneline --diff-filter=M -- {{BACKEND_DIR}}/**/migrations/` (each hit is a conversation)
- Advisory lock for concurrent boot — `git grep -n "advisory_lock" -- {{BACKEND_DIR}}`

**Decide:**
1. **Migration policy: forward-only or reversible?** — decides whether `down()` is a decision per file
   and whether editing an applied file is ever allowed.
   - Ours: reversible by default, but `down()` is a decision — decline when the inverse would re-open a
     security hole, destroy data or delete accounting history; a one-way undo is a new forward
     migration; editing an applied migration does nothing and is allowed only if it never reached
     the main branch.
   - Also common: strictly forward-only, no `down()` at all (Flyway-, Prisma-, Supabase-style; fits teams
     that fix forward in prod); fully reversible on every file (fits non-financial apps with small data).
   - Evidence: the no-`down` and throwing-`down` counts; the edited-after-apply log.
   - Lands in: "`down()` is a decision, not boilerplate"; "Editing an applied migration does nothing".
2. **Who applies migrations to production, and how?** — the page assumes every boot.
   - Ours: migrations apply themselves at boot behind an advisory lock; CLI only for status and rollback.
   - Also common: a CI/CD step before the deploy (fits rolling deploys); a human runs it with prod
     credentials (fits regulated teams); a platform command (`prisma migrate deploy`, `supabase db push`).
   - Evidence: where the detect found the apply call.
   - Lands in: "Migrations apply themselves".
3. **Do destructive database operations need a human?** — rollbacks and ledger edits change state every
   branch and developer shares.
   - Ours: yes — approval before `down` / `down:all`; the ledger is only touched through the CLI's own
     unlog; never run DDL by hand to "catch up".
   - Also common: agents may run anything against a local throwaway DB, never against a shared or prod
     one; also require a second person for `DROP`/`TRUNCATE` in any migration.
   - Evidence: whether shared dev/stage databases exist (env files, compose).
   - Lands in: "Migrations apply themselves"; the "already in that hole" procedure.
4. **How is a migration reviewed before merge?**
   - Ours: its emitted SQL is executed once inside `BEGIN … ROLLBACK`, printed from the migration itself,
     before review; backfills are separate, idempotent migrations.
   - Also common: CI applies every migration to a throwaway database (best when CI has Postgres); a
     second human reviewer for security-relevant migrations.
   - Evidence: CI files that start a database service.
   - Lands in: "A migration nobody has run has never had its SQL parsed"; "Backfills".
5. **Naming and ordering convention?**
   - Ours: rename the scaffolded wall-clock name to the next free day slot (`YYYY.MM.DDT00.00.NN`);
     parallel agents use the slot they were handed.
   - Also common: tool timestamps untouched (Prisma, Knex); sequential integers (Flyway `V12__`).
   - Evidence: the folder tail listing.
   - Lands in: "Naming: take the next free slot".

**Web, on request:** known issues of the detected migration tool's version (advisory locking,
checksum/ledger behaviour, rollback semantics); the platform's guidance for DDL in transactions.

## guides/migrations.md — Testing a migration, and changing a function's signature

**Applies when:** database-operations applies. The signature half applies only if stored functions exist
— `git grep -c "CREATE \(OR REPLACE \)\?FUNCTION" -- {{BACKEND_DIR}}`.
**Otherwise:** prune together with database-operations.md; with no stored functions keep the page and
mark its signature section not applicable.

**Detect, don't ask:**
- Existing migration specs — `git ls-files {{BACKEND_DIR}} | grep -iE "migrat.*\.(spec|test)\."`
- A spec handing a live connection to a migration — `git grep -nE "\.(up|down)\((pool|client|db)" -- {{BACKEND_DIR}}`
- Stored functions called through RPC — `git grep -lE "\.rpc\(" -- {{FRONTEND_DIR}} {{MOBILE_DIR}} {{BACKEND_DIR}}`
- Deploy model (rolling vs stop-then-start) — `git grep -nE "RollingUpdate|maxSurge|replicas|restart:" -- '*.yml' '*.yaml'`
- Security-property migrations (grants, `search_path`) — `git grep -lE "REVOKE|search_path" -- {{BACKEND_DIR}}`

**Decide:**
1. **How are migrations tested?** — decides whether a recorder spec, a throwaway-DB lane, or nothing is the norm.
   - Ours: a spec never executes a migration on a live database; a recorder (fake pool) captures the SQL
     that `up()`/`down()` would issue; `up` set equals `down` set against a hand-written list.
   - Also common: CI applies and reverts all migrations on a disposable database (needs a DB in CI);
     no migration tests, review only.
   - Evidence: existing specs and CI database services.
   - Lands in: "The boundary"; "Compare the two sets".
2. **Does a security-property migration need two specs?**
   - Ours: yes — a source-level spec (protects fresh databases) and a live-catalog spec (catches
     `DROP`+`CREATE` resets), paired with a behavioural control.
   - Also common: an apply-time `DO` assertion only; or a periodic catalog audit.
   - Evidence: the REVOKE/`search_path` grep.
   - Lands in: "Guarding a schema invariant takes two specs".
3. **Deploy model for signature changes?** — decides one migration or two releases.
   - Ours: `DROP`+`CREATE` in one migration while deploys stop every old process before new code
     migrates; the day deploys go rolling, two releases (add new overload, then drop old).
   - Also common: always two releases (safe default for any team that may go rolling soon).
   - Evidence: deploy-model grep.
   - Lands in: "Changing a function's signature in place".

**Web, on request:** version-specific error codes of the RPC layer for missing or ambiguous overloads;
the detected migration tool's transaction-per-migration behaviour.

## guides/scheduled-jobs.md — Scheduled jobs and the leader lock

**Applies when:** the backend runs recurring work — `git grep -lE "@Cron|node-cron|cron\.schedule|bullmq|agenda|pg_cron|CronJob|schedule\(" -- {{BACKEND_DIR}} '*.yml' '*.yaml' '*.sql'`.
**Otherwise:** prune (and delete the "Scheduled work" bullet in backend-howto) — the page is about
decisions that only exist once something fires on a timer.

**Detect, don't ask:**
- Which scheduler — `git grep -nE "@Cron|ScheduleModule|node-cron|BullModule|Queue\(|agenda|pg_cron|cron\.schedule|kind: CronJob" -- {{BACKEND_DIR}} '*.yml' '*.yaml'` and the manifest
- Number of jobs — `git grep -c "@Cron" -- {{BACKEND_DIR}}`
- Replicas — `git grep -nE "replicas|instances|scale" -- '*.yml' '*.yaml'`
- Existing lock — `git grep -nE "advisory_lock|redlock|SET .* NX|runAsLeader|leader" -- {{BACKEND_DIR}}`
- Schedules read from env — `git grep -nE "process\.env\.[A-Z_]*(CRON|SCHEDULE|INTERVAL)" -- {{BACKEND_DIR}}`
- Jobs disabled under test — `git grep -nE "disabled:.*test|NODE_ENV.*test" -- {{BACKEND_DIR}}`

**Decide:**
1. **Which scheduler owns recurring work?** — decides whether the page is rewritten or kept as is.
   - Ours: in-source `@Cron` (NestJS), one process-level scheduler per replica; schedules live in code,
     not as repeatables persisted in a datastore (those outlive a rename and fire jobs nobody owns).
   - Also common: persisted queue schedulers (BullMQ repeatable, Agenda, Sidekiq-cron — survive restarts,
     orphan on rename); database-native (`pg_cron` — logic next to data, no app lock); platform cron
     (Kubernetes CronJob / cloud scheduler calling an endpoint — one run per tick, no leader lock).
   - Evidence: the scheduler detect; keep the page's lock and idempotency rules whatever the choice.
   - Lands in: the banner paragraph; "The shape every scheduled job has".
2. **How are duplicate ticks across replicas handled?**
   - Ours: a lock wraps the tick from outside (fails closed, compare-and-delete release, long TTL), and
     jobs where a duplicate does damage additionally use claim-first or idempotent writes.
   - Also common: claim-first writes only, no lock (fits idempotent jobs); a single worker replica for all jobs.
   - Evidence: replicas and existing-lock detects.
   - Lands in: "What the lock promises, and what it does not".
3. **Which jobs would do damage if they ran twice?** — decides where claim-first is mandatory.
   - Ours: billing, sweeps that decide an outcome, outbox publishers — claim before acting. (none shipped
     for the adopter's own jobs; list them.)
   - Evidence: the job list from the detect.
   - Lands in: "A tick can still run on two replicas".
4. **May a schedule come from the environment?**
   - Ours: yes, read once at module load and shared by the decorator and the config reader (the
     cross-check kept); a malformed expression refuses the boot.
   - Also common: schedules fixed in code (fewest moving parts); per-environment config files.
   - Evidence: env-schedule grep.
   - Lands in: "A schedule that comes from the environment is read twice".
5. **Registrations spec required?**
   - Ours: one spec asserts every entry point's scheduler metadata, lock names, and no decorator on the body.
   - Also common: none, rely on staging smoke.
   - Evidence: existing spec grep: `git grep -lE "getMetadata|SchedulerRegistry" -- {{BACKEND_DIR}}`.
   - Lands in: "Why a spec asserts the registrations themselves".

**Web, on request:** known issues of the detected scheduler/lock library version (missed-fire,
timezone/DST, TTL and clock behaviour, graceful-shutdown handling).

## guides/security-app-checklist.md — Security checklist: application

**Applies when:** the repo has an authenticated client or a backend — `git grep -liE "login|signIn|authorization|bearer" -- {{FRONTEND_DIR}} {{MOBILE_DIR}} {{BACKEND_DIR}}`.
Needs no backend: sections 2 (secrets), 4 (dependencies) apply to any client.
**Otherwise:** prune only if there is neither auth nor user data (a static site); otherwise keep, and
mark inapplicable sections rather than deleting them.

**Detect, don't ask:**
- Controllers with and without guards — `git grep -c "@Controller" -- {{BACKEND_DIR}}`, `git grep -c "@UseGuards" -- {{BACKEND_DIR}}`
- Caller-writable metadata read for authz — `git grep -n "user_metadata" -- {{BACKEND_DIR}} {{FRONTEND_DIR}} {{MOBILE_DIR}}`
- Privileged key near clients — `git grep -nE "SERVICE_ROLE|service_role" -- {{FRONTEND_DIR}} {{MOBILE_DIR}}`
- Raw HTML sinks — `git grep -cE "dangerouslySetInnerHTML|innerHTML" -- {{FRONTEND_DIR}} {{MOBILE_DIR}}`
- `.env` ignored, none tracked — `git check-ignore .env`; `git ls-files | grep -E "(^|/)\.env"`
- Secret scanner or dependency bot in CI — `git ls-files | grep -iE "gitleaks|trufflehog|dependabot|renovate"`
- Audit script available — `{{PACKAGE_MANAGER}} audit` (record the result and whether CI runs it)
- CORS and headers — `git grep -nE "enableCors|ALLOWED_ORIGINS|helmet|X-Frame-Options" -- {{BACKEND_DIR}}`; proxy configs `git ls-files | grep -iE "nginx|caddy|traefik"`
- Object storage — `git grep -lE "storage\.buckets|createBucket|S3Client|\.storage\.from" -- .`

**Decide:**
1. **Which sections apply?** (multi-select; default all seven.) — an inapplicable section turns into a
   permanent false "pass".
   - Ours: 1 API authorization, 2 secrets and exposure, 3 input validation, 4 dependencies, 5 object
     storage, 6 pointer to sessions, 7 CORS/headers.
   - Also common: client-only app — keep 2, 4 (and 6); a backend with no storage — drop 5; an API behind
     a gateway that sets headers — keep 7 as "verify at the gateway".
   - Evidence: gate A; storage detect; proxy detect.
   - Lands in: delete or mark each unselected section.
2. **Authorization default: opt-in guards or a global guard?**
   - Ours: page is written for opt-in (a guardless controller is reachable by anyone; the audit
     question is "is the absence intentional?"); the alternative inverts the question — pick one and say which.
   - Also common: global guard plus an explicit public marker (safer default for a new service).
   - Evidence: controller/guard counts.
   - Lands in: §1.
3. **How are secrets and dependencies policed?**
   - Ours: nothing assumed — record whether a secret scanner and a dependency bot run; cadence:
     functions/RLS/API/frontend per release, dependencies weekly, storage monthly.
   - Also common: automated in CI on every PR (fits any team with CI); a manual quarterly review (fits small teams).
   - Evidence: scanner/bot detect and the audit run.
   - Lands in: §2 checklist, §4, "Cadence".
4. **Where do CORS and security headers live?**
   - Ours: CORS allow-list from an env list with exact matching, never `*` with credentials; headers may
     live in the reverse proxy — check the deployed proxy, not just the backend.
   - Also common: a gateway/CDN sets everything; Helmet in the app.
   - Evidence: CORS/headers detect.
   - Lands in: §7.

**Web, on request:** known advisories for the detected backend framework and auth SDK versions;
current guidance on token claims vs live membership for the detected auth provider.

## guides/security-session-checklist.md — Security checklist: authentication and sessions

**Applies when:** users sign in — `git grep -lE "signIn|signOut|logout|refreshToken|getSession" -- {{FRONTEND_DIR}} {{MOBILE_DIR}} {{BACKEND_DIR}}`.
Needs no backend (any client with auth).
**Otherwise:** prune — no login, no session rules. Native sections (storage exception, `allowBackup`)
stay only if `{{MOBILE_DIR}}` is a native shell.

**Detect, don't ask:**
- Auth provider or library — manifest scan: `git grep -nE "supabase-js|firebase|auth0|clerk|next-auth|cognito|jsonwebtoken|passport" -- '*package.json'`
- Token storage — `git grep -nE "localStorage|sessionStorage|document\.cookie|Preferences|Keychain|SecureStorage" -- {{FRONTEND_DIR}} {{MOBILE_DIR}}`
- Sign-out call sites (should be one helper) — `git grep -nE "signOut\(|logout\(" -- {{FRONTEND_DIR}} {{MOBILE_DIR}}`
- Native shell — `git ls-files {{MOBILE_DIR}} | grep -E "capacitor\.config|AndroidManifest\.xml|Info\.plist"`
- Android backup flag — `git grep -n "allowBackup" -- '*AndroidManifest.xml'`
- Provider config kept in the repo (token TTL) — `git ls-files | grep -E "supabase/config\.toml"` and `git grep -nE "jwt_expiry|expiresIn|ACCESS_TOKEN_TTL"`
- Second client (admin app) — `git ls-files | grep -iE "admin"` at app level

**Decide:**
1. **Session and token policy?** — numbers the checklist says must be written down, not assumed.
   - Ours: expiry, refresh rotation, login/OTP rate limits and reset-token lifetime are delegated to the
     auth provider and recorded from its project configuration.
   - Also common: custom JWT with short access token (5-15 min) plus rotating refresh token; server-side
     sessions with idle and absolute timeouts; long-lived "remember me" on trusted devices only.
   - Evidence: provider detect and any config in the repo.
   - Lands in: "Delegated, therefore verified elsewhere"; first checklist item.
2. **How is "cut their access now" met?**
   - Ours: an authorization change the backend re-reads per request (e.g. revoke the membership row);
     residual window is one access-token TTL; no plan relies on killing another user's session.
   - Also common: a session-version claim checked per request; a token denylist; ban the account.
   - Evidence: whether the SDK offers admin revocation (check the detected SDK version).
   - Lands in: "Do not plan a control around revoking someone's session".
3. **Where may the token live, per surface?**
   - Ours: browser — HttpOnly or SSR-aware cookies, not web storage; native shell — `localStorage` as an
     accepted, recorded trade (WKWebView drops cookies for custom schemes); web storage only for
     non-credentials.
   - Also common: in-memory access token plus HttpOnly refresh cookie (fits SPAs with own backend);
     native secure store (Keychain/Keystore) when extraction from the device is the main concern.
   - Evidence: the storage detect.
   - Lands in: "Where the token may live"; checklist item on recorded storage decision.
4. **Sign-out when the server revoke fails?**
   - Ours: one helper per client that always clears the local session, plus a resurrection guard after a
     local-only clear; a second client may keep a plainer logout if recorded.
   - Also common: best-effort revoke then clear (fits SDKs that always clear locally).
   - Evidence: number of sign-out call sites.
   - Lands in: "A client logout must remove the stored session".
5. **Android backup (native Android only):** `allowBackup="false"`, or data-extraction rules excluding the
   session store?
   - Ours: `android:allowBackup="false"`; verify the flag against the target SDK.
   - Also common: keep backup on with explicit `dataExtractionRules`/`fullBackupContent` exclusions.
   - Evidence: manifest detect.
   - Lands in: "Android: allowBackup".

**Web, on request:** known sign-out/refresh races in the detected auth SDK's version; current platform
behaviour for cookies and storage in the WebView; Android backup rules for the target SDK level.

## guides/security-database-checklist.md — SECURITY DEFINER, search_path, registry

**Applies when:** gate B — Postgres with stored functions: `git grep -lE "SECURITY DEFINER" -- {{BACKEND_DIR}}`
(or the platform's migrations folder) returns files, or clients call the DB via a REST/RPC layer.
**Otherwise:** prune — as a trio with security-rls-checklist and security-grants-checklist; not
applicable to a non-Postgres backend. Postgres with no definer functions and no direct client access:
keep-as-reference only if more are planned.

**Detect, don't ask:**
- Definer functions — `git grep -c "SECURITY DEFINER" -- {{BACKEND_DIR}}`
- Definer files that never pin `search_path` — compare `git grep -l "SECURITY DEFINER" -- {{BACKEND_DIR}}` with `git grep -l "search_path" -- {{BACKEND_DIR}}`
- Client roles exposed by the platform — `git grep -lE "\banon\b|\bauthenticated\b" -- {{BACKEND_DIR}}`
- Default privileges rules — `git grep -n "ALTER DEFAULT PRIVILEGES" -- {{BACKEND_DIR}}`
- Apply-time assertions already in use — `git grep -c "has_function_privilege" -- {{BACKEND_DIR}}`
- Existing registry page — `git ls-files | grep -iE "registry|definer"`

**Decide:**
1. **Pin `search_path` on every definer function, or only the exploitable ones?**
   - Ours: pin at creation (`public, pg_temp`, `pg_temp` last) — cheaper than arguing it is unnecessary;
     the exploitability test (unpinned + definer + unqualified relation + reachable) is for triage of old functions.
   - Also common: pin only functions that clear all three properties (fewer edits to legacy migrations);
     `SET search_path = ''` with fully qualified names for new code.
   - Evidence: the unpinned-files comparison.
   - Lands in: §2 and the last two checklist items.
2. **What is the evidence that a grant is in force?**
   - Ours: the live catalog, asserted at apply time in both directions inside the same migration; a
     green test suite is not evidence about a grant.
   - Also common: a periodic live-ACL audit query; CI job diffing `proacl` against a registry.
   - Evidence: the assertion count.
   - Lands in: "A read that must stay client-callable has a settled shape"; checklist.
3. **Keep a function registry page?**
   - Ours: a lookup table of every definer function (signature, definition, grants in force, `search_path`
     status), declared vs live marked, recounted by grep — no totals in prose.
   - Also common: generated by a script that fails CI on drift; no registry when there are only a few functions.
   - Evidence: definer-function count and any existing registry.
   - Lands in: §3.

**Web, on request:** current default-privilege behaviour of the detected hosted Postgres platform; known
issues of the RPC layer for overloaded functions; Postgres-version notes on `search_path` and `pg_temp`.

## guides/security-rls-checklist.md — Security checklist: RLS policies

**Applies when:** gates B and C — `git grep -lE "ENABLE ROW LEVEL SECURITY|CREATE POLICY" -- {{BACKEND_DIR}}` (or the
platform migrations folder) returns files.
**Otherwise:** prune together with security-grants-checklist (and security-database-checklist unless
definer functions exist). Not applicable to a non-Postgres backend. Postgres without RLS: prune, or
keep-as-reference if the user plans to expose tables to clients.

**Detect, don't ask:**
- Policies and RLS-enabled tables — `git grep -cE "CREATE POLICY" -- {{BACKEND_DIR}}`; `git grep -cE "ENABLE ROW LEVEL SECURITY" -- {{BACKEND_DIR}}` against `git grep -cE "CREATE TABLE" -- {{BACKEND_DIR}}`
- Permissive checks — `git grep -nE "WITH CHECK \(true\)|USING \(true\)" -- {{BACKEND_DIR}}`
- Token claims in policies — `git grep -nE "auth\.jwt\(\)|request\.jwt\.claims|app_metadata" -- {{BACKEND_DIR}}`
- Policy helpers — `git grep -nE "is_admin|auth\.uid\(\)" -- {{BACKEND_DIR}}`
- Storage policies — `git grep -n "storage.objects" -- {{BACKEND_DIR}}`
- Test-row isolation marker — `git grep -nE "test_marker|is_test|e2e_run" -- {{BACKEND_DIR}}`
- Run the live "tables without RLS" and "all policies" queries on the page against a dev database (ask before connecting).

**Decide:**
1. **Membership in policies: live row or token claim?**
   - Ours: prefer a live `EXISTS (… FROM memberships …)`; a claim grants access for the token's
     lifetime, not the relationship's; converting widens visibility, so check client filters first.
   - Also common: tenant claim in the JWT when the token TTL is very short and the stale window is accepted
     and written down (fits read-heavy multi-tenant dashboards with perf constraints).
   - Evidence: token-claim grep.
   - Lands in: "A token claim is not a membership".
2. **How is a policy shown to do what was meant?**
   - Ours: every isolation assertion set has a named positive control; a migration reads back its stored
     `pg_policies.qual` and refuses if wrong.
   - Also common: integration tests with real user tokens only; manual audit of `pg_policies` per release.
   - Evidence: existing isolation specs.
   - Lands in: "An isolation test with no positive control proves nothing"; checklist.
3. **Object-storage ownership model** (storage only).
   - Ours: files attached to a relationship (an order, a shared document) are keyed by relationship id
     in the path and read through a join; backend-written buckets carry no write policies (write-once).
   - Also common: per-uploader folder (`<user_id>/…`) for private files; signed URLs only, no policies.
   - Evidence: storage-policy grep.
   - Lands in: "A storage policy whose object belongs to a relationship, not to a person".

**Web, on request:** current RLS behaviour of the detected platform version (policy evaluation order, storage
schema, realtime filtering); known planner issues with casts inside policies.

## guides/security-grants-checklist.md — Security checklist: table and column write privileges

**Applies when:** gates B and C and client roles can write tables — `git grep -lE "GRANT .*(anon|authenticated)|ALTER DEFAULT PRIVILEGES" -- {{BACKEND_DIR}}`,
or a PostgREST/Supabase setup (`git ls-files | grep -E "supabase/config\.toml"`), with client code issuing
`.insert(`/`.update(`/`.upsert(`.
**Otherwise:** prune together with security-rls-checklist. Not applicable to a non-Postgres backend, or to
a Postgres backend where clients never write directly.

**Detect, don't ask:**
- Column-level grants in use — `git grep -nE "GRANT UPDATE \(" -- {{BACKEND_DIR}}`
- Default privileges — `git grep -n "ALTER DEFAULT PRIVILEGES" -- {{BACKEND_DIR}}`
- Guard triggers — `git grep -nE "BEFORE UPDATE" -- {{BACKEND_DIR}}`
- Partitioned tables — `git grep -n "PARTITION OF" -- {{BACKEND_DIR}}`
- Client writes — `git grep -nE "\.(insert|update|upsert)\(" -- {{FRONTEND_DIR}} {{MOBILE_DIR}}` (read the sites; upserts need UPDATE too)
- Live check: `pg_class.relacl` / `pg_attribute.attacl` on a dev database (ask before connecting)

**Decide:**
1. **What is the client write surface?**
   - Ours: column-level GRANT default-deny plus a `BEFORE UPDATE` diff trigger as the survival layer;
     tables written only by the backend are closed with `REVOKE ALL`, RLS on, `WITH CHECK (false)`.
   - Also common: no client writes at all, everything through the backend (simplest to reason about);
     table-level grants plus RLS only (accept the escalation risk, state it).
   - Evidence: column-grant and trigger counts; client write sites.
   - Lands in: "Taking write access away from a client role"; "Closing a table to clients".
2. **What does a new table start with?**
   - Ours: default ACLs hand client roles table-level grants on new tables; each new table is handled
     explicitly and the default ACL itself is cleaned by one superuser session if out of reach.
   - Also common: `ALTER DEFAULT PRIVILEGES … REVOKE` once at setup (fits greenfield); per-migration
     explicit grants only.
   - Evidence: default-privileges grep.
   - Lands in: "Default ACLs decide what a table is born holding".
3. **Where is a grant migration verified?**
   - Ours: an apply-time `DO` block asserts both polarities (no stray grant, every kept grant present,
     partitions have RLS, default ACL clean).
   - Also common: a CI check on a disposable database; manual catalog read before merge.
   - Evidence: apply-time assertion count.
   - Lands in: "Verify both polarities at apply time".

**Web, on request:** current default-privilege and PostgREST upsert behaviour of the detected platform
version; Postgres notes on `attacl` and partition inheritance.
