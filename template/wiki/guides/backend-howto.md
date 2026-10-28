---
title: Adding backend functionality (example — NestJS + Postgres with RLS)
class: compiled
covers: []                 # fill when adopting: guards, current-user decorator, DB service, main.ts
last-verified: never
verified-by: boilerplate
sources: []
---

# Adding backend functionality

> **Example — adapt to your backend.** This page and the database/security pages that follow are the
> worked example of a real backend behind the contract in [`api-contract.md`](./api-contract.md): a
> NestJS service in `{{BACKEND_DIR}}` over Postgres with row-level security, used by clients through
> a hosted data API. If your backend is different (Express, Fastify, a managed platform), keep the
> *rules and their reasons*, and replace the names. Where the project has only a mock server today,
> read this as what the real backend must do when it arrives.

What follows is project behaviour a generic framework tutorial will not tell you — and in several
cases will tell you the opposite of.

## Do you need an endpoint at all? The default data path

**Default: clients talk to the data layer directly, under row-level security (RLS).** A backend
endpoint is justified only when the operation needs one of:

1. **A multi-statement transaction across tables.** RLS gives row-level authorization, not
   cross-table atomicity. (Inserting into two tables from the client leaves a window where the first
   succeeds and the second fails.)
2. **A privileged role that bypasses RLS** — e.g. an admin view that must see every user's rows.
3. **An operation only a privileged API can perform** — creating a user with a password.
4. **A side effect:** email/SMS, an external API call, a queued job, a scheduled task.

If none applies, an endpoint is not "a cleaner API": it is a second hand-rolled implementation of
authorization that RLS already does, plus a network hop. **Every endpoint that merely proxies a
table is a second copy of the authorization rules, and two copies drift** — which is why the
justification must come from something RLS structurally cannot do. There is no fifth reason called
"consistency".

The cost is easy to under-estimate: a privileged-role endpoint inherits **none** of the filtering
RLS would have given a client read — per-row auth, test-data isolation, live updates all have to be
re-implemented by hand. Typical failure: an admin list read through a privileged endpoint shows
leftover end-to-end test rows in the production view, because the privileged role bypasses the
isolation clause. The fix is to move the *read* to a direct RLS-respecting client query (and add the
table to the realtime publication) and leave only the *writes* server-side.

False positive to recognise: a handler touching one table is not automatically a violation. An
admin-wide read (reason 2) and a "single-field" DTO hiding real merge logic are not shortcuts. The
audit question is whether the body is a passthrough, or does something RLS cannot express —
`{{CODE_QUERY_TOOL}}` finds the candidates (controllers touching exactly one table and calling no
other service); it does not give verdicts.

## Migrations, RLS and realtime

- Authoring and running migrations: [`database-operations.md`](./database-operations.md),
  [`migrations.md`](./migrations.md). Policies, grants and definer functions:
  [`security-database-checklist.md`](./security-database-checklist.md),
  [`security-rls-checklist.md`](./security-rls-checklist.md),
  [`security-grants-checklist.md`](./security-grants-checklist.md).
- If the test suite isolates its own rows with a marker column, a new table needs the marker (and the
  clause in every policy) *only if* it lacks a cascading FK back to a table that already carries it;
  where cascade covers it, adding a marker is dead weight. Shared helper functions used by policies
  (`is_admin()`, the isolation predicate) are defined once — new policies call them, not re-derive
  the claims logic inline.
- **Realtime is per-table opt-in** (the publication line goes in the migration that creates the
  table). Forgetting it is a silent gap, not an error
  ([`realtime-and-live-updates.md`](./realtime-and-live-updates.md)).
- **RLS silently filters realtime.** If a policy blocks a row from `SELECT`, that client never
  receives change events for it. Concretely: an admin soft-deletes a user (`deleted_at = now()`); a
  naive select policy requiring `deleted_at IS NULL` hides the user's own row from them, the delete
  event is filtered out before it reaches their client, and they stay logged in indefinitely. The
  fix: the select policy special-cases `id = auth.uid()` to always pass, and only the
  *other-users* arm filters `deleted_at`. Apply the same "always visible to self" carve-out to any
  table a user subscribes to for their *own* state (profile, session, membership); do not apply it
  to tables listing other people's rows — there, hiding soft-deleted rows is correct.

## Guarding endpoints

Authorization is a stack of **narrow per-concern guards**, applied after the authentication guard
has established `request.user`: one for global admin role, one for ownership of the tenant, one for
tenant selection, one per verification tier. Compose only the guards whose concern applies. Do not
invent a roles table and a generic `@Roles()` decorator to replace this unless you are prepared to
migrate every guard — a hybrid is worse than either. Read the caller through a `@CurrentUser()`
parameter decorator, not `@Req() req`: it centralises the shape of the authenticated-user object
instead of every controller doing its own cast. Guard order matters, and the audit question for a
guardless controller is "is the absence intentional?" — see
[`security-app-checklist.md`](./security-app-checklist.md).

## DTO validation is not automatic — the sharpest gotcha

If the application registers **no global `ValidationPipe`**, then `class-validator` decorators on a
DTO (`@IsString()`, `@IsEnum()`) do nothing on their own. A handler gets validation only if it binds
one explicitly on the `@Body()` parameter:

```typescript
create(@Body(new ValidationPipe({ transform: true, whitelist: true })) dto: CreateOrderDto) {}
```

Miss it and the DTO *looks* validated while the endpoint silently accepts anything, including the
extra fields `whitelist` would have stripped. There is no framework-level safety net to catch the
absence — so either register the pipe globally (the safer default for a new project) or add a lint
rule/spec that fails any `@Body()` without it.

⚠️ **`@IsInt()` is not a bound, and on a money field that matters.** It accepts any integral number,
`2 ** 53` included; past `Number.MAX_SAFE_INTEGER` arithmetic on a minor-unit amount silently loses
precision. Pair it with `@Max(Number.MAX_SAFE_INTEGER)` on anything monetary. Be honest about what
that buys: if the function behind the route re-derives its own bound from the row it locks, the
decorator is not what protects the money — it changes the *failure mode*, a 400 naming the field
instead of a bound-check error further down about a number that was never what the caller sent.

## Testing

Unit tests mock the data service and check business logic in isolation. **Integration tests hit a
real database and are what actually exercises RLS, triggers and constraints** — a mocked unit test
cannot catch a policy or migration bug. Every endpoint needs integration coverage for five cases:
success, 401 (no/invalid token), 403 (wrong role/tenant), 400 (invalid body), 404 (missing
resource). That is a coverage policy, not a suggestion: the RLS and guard bugs above are exactly the
class only a test across a real auth token surfaces. Use the existing test-user helpers rather than
hand-rolling one, and never sign in on the shared service client (it poisons that client for every
later caller). The rest — isolation, fixtures, what a green run proves — is in [`testing.md`](./testing.md), [`writing-tests.md`](./writing-tests.md) and
[`test-isolation.md`](./test-isolation.md).

**Cleanup ordering.** Tenant-scoped children whose FK to the tenant row is `RESTRICT` (not
`CASCADE`/`SET NULL`) must be deleted *before* the tenant row; because the tenant delete is one atomic
multi-row `DELETE`, a single uncleaned `RESTRICT` child orphans **every** tenant under that test
marker, not just its own. Make the cleanup throw loudly instead of swallowing — a silently failed
delete leaks tenants and their dependants across runs. Adding a tenant-scoped table means
deciding `CASCADE` vs `RESTRICT` deliberately.

## Small patterns worth keeping

- **Soft delete, always, for user-facing data:** set `deleted_at`, never issue a real `DELETE`.
  Policies and ordinary queries filter `deleted_at IS NULL`; nothing downstream expects a row to
  disappear. (Hence the "always visible to self" carve-out above.)
- **Skip empty updates.** If the computed update payload is empty (only a password changed, handled
  separately), skip the `UPDATE` and just re-fetch the row — an empty-payload write still bumps
  `updated_at`.
- **Money in minor units, as integers, with an explicit upper bound** at the edge and again in the
  function that moves it.
- **Scheduled work:** [`scheduled-jobs.md`](./scheduled-jobs.md).
