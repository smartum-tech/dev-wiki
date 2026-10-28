---
title: Security checklist — SECURITY DEFINER functions, search_path, and the registry pattern (example)
class: compiled
covers: []                 # fill when adopting: the migrations folder and the migration service
last-verified: never
verified-by: boilerplate
sources: []
---

# Security checklist — `SECURITY DEFINER` functions, `search_path`, and the registry pattern

> **Example — adapt to your backend.** Written for Postgres exposed to clients through a REST/RPC
> layer (PostgREST-style hosted platforms), where default privileges grant the client roles (`anon`,
> `authenticated`) rights on new objects. If clients never reach the database directly, most of the
> *exposure* disappears, but the mechanisms (ACLs, `search_path`, ledger versus catalog) still apply
> to anything your own backend calls.

Read before writing a `SECURITY DEFINER` function. Each check maps to a way this stack fails
**silently**. Siblings: policies — [`security-rls-checklist.md`](./security-rls-checklist.md); column
writes — [`security-grants-checklist.md`](./security-grants-checklist.md); guards, secrets —
[`security-app-checklist.md`](./security-app-checklist.md); how migrations apply —
[`database-operations.md`](./database-operations.md).

## The layers, and which one fails closed

| Layer | Decides | Fails |
|---|---|---|
| Table / column **grant** | which role may touch which table or column | **closed** — no grant, no access; below RLS and triggers |
| **RLS** policy | which rows, and what a row may become | open if a policy is permissive or copied wrong |
| **Trigger** | rules over the (OLD, NEW) pair | open if the grant is re-issued over it, or it is `DEFINER` |
| **Function** `EXECUTE` + body | who may call, and with whose privileges | open by default on platforms that grant new functions to client roles |

Every escalation on such a stack is a permissive layer over a missing lower one. One rule for all
four: **the migrations are not evidence of what is in force — the live catalog is.** A migration
reports intent; `pg_proc.proacl`, `pg_class.relacl`, `pg_attribute.attacl`, `pg_policies.qual` and
`pg_default_acl` report fact.

## 1. Functions (`SECURITY DEFINER`)

```bash
grep -r "SECURITY DEFINER" {{BACKEND_DIR}}/src/database/migrations/*.ts | grep -v "RETURNS TRIGGER"
```

**Risk:** a Postgres function is executable by `PUBLIC` — and on these platforms by the client roles
through explicit default-privilege grants — and is callable via RPC from the browser. `SECURITY
DEFINER` runs it with the *owner's* privileges, bypassing RLS: combine the two and any client triggers
owner-privileged writes. For every definer function walk this table in order, stop at first match:

| Question | If YES |
|---|---|
| Returns `TRIGGER`? | SAFE **for grants** — a direct call is refused (`0A000`), so its `EXECUTE` grant is inert. **Does not answer the `search_path` question (§2)**: there the way in is the DML. |
| Read-only, keyed off `auth.uid()`? | LOW RISK — even called directly it returns the caller's own data. |
| Modifies data? | Continue. |
| Accepts a user/tenant id as a **parameter** (not derived from the token)? | DANGEROUS — the caller can substitute anyone's id. Must be restricted. |

**Fix, in order of preference:** (1) revoke and re-grant to the backend role only, when the function
is backend-only; (2) derive the id from `auth.uid()` instead of a parameter, when it must stay
end-user-callable on their own data; (3) an internal `IF NOT is_admin() THEN RAISE`, when it must stay
callable but role-gated. Put the `REVOKE`/`GRANT` pair in the **same migration `up()`** that creates
the function — otherwise it is callable by any authenticated user from the moment the migration runs.

### `REVOKE … FROM PUBLIC` alone does not revoke anything

The most expensive item on this page. `ALTER DEFAULT PRIVILEGES` also grants EXECUTE to the client
roles **explicitly**, a different `proacl` entry that a `FROM PUBLIC` revoke leaves untouched. A
money-moving function can stay callable by any browser client behind a REVOKE that reads as though it
worked. Write `FROM PUBLIC, anon, authenticated`, then **verify against the database**.

### A read that must stay client-callable has a settled shape

Take the resource id as a parameter, then gate on an `EXISTS` over the caller's live membership
resolved from `auth.uid()` — never from a parameter — with **no admin arm**, so a non-member and a
genuinely empty result both return the empty set and a resource UUID cannot probe for existence. Grant
to `authenticated`, revoke `anon` **by name**, and **assert the ACL in both directions inside the same
`up()`**: a `DO $check$` over `has_function_privilege` that raises if `anon` can execute or
`authenticated` cannot. This is a deploy gate, not a test gate: no suite goes red on a wrong grant
(the unit lane skips migrations), and the failure is a backend that does not start, after merge.

### Re-granting and re-signing

- **Re-grant by resolving the signature from the catalog, never by writing it out.** A stale
  hardcoded argument list either raises (migrations run at boot — a crash loop) or matches a dead
  arity and silently leaves the reachable overload granted. Loop over `pg_proc` filtered on `proname`
  with `EXECUTE format(…, r.oid::regprocedure)`; zero rows is a clean no-op.
- **Re-signing is a `DROP` first, not a `CREATE OR REPLACE`.** With a different argument list `OR
  REPLACE` leaves an *overload* that keeps its grants and stays callable. Drop, create, then
  re-grant: a new function starts from the platform's default privileges again. PostgREST answers an
  ambiguous overload with `PGRST203`. Drop a superseded signature **explicitly** too, or a database
  that applied it and later reverts keeps it alive.
- **Re-signing a money function is never one function.** Definer functions compose by forwarding
  arguments into a primitive; enumerate callers from `pg_proc.prosrc`, not from the spec
  ([`migrations.md`](./migrations.md)).
- ⚠️ **A wrong call inside a function body migrates clean — plpgsql resolves a callee at
  EXECUTION time.** A branch calling a six-argument form of a function whose only definition takes
  twelve applies fine, keeps every suite green, and raises `42883` on first use. A spec asserting the
  function *exists* cannot catch it. Exercise the branch, or assert the callee's signature.

## 2. `search_path` — a second exposure question

The grant answers *who may call*. This answers **what the names inside the body resolve to**.

A definer function runs with the **caller's** `search_path` unless it pins its own, and Postgres
searches `pg_temp` *before* everything on that path for **relation** names unless `pg_temp` is listed
explicitly. A caller who can create a temp table chooses which table an unqualified name inside
somebody else's definer function resolves to: a planted `pg_temp.users` can make an `is_admin()`
helper return `true` for an ordinary user.

**All three must hold for it to be exploitable:**

1. the function is unpinned **and** `SECURITY DEFINER` (an INVOKER function runs with the caller's own
   privileges, so shadowing gains nothing);
2. it dereferences a **relation** unqualified. `pg_temp` shadows relations but **not** functions or
   operators, so a body whose only unqualified names are `current_setting(…)`, casts and operators
   cannot be attacked this way;
3. an untrusted caller can get the body to run under a `search_path` they control — **reachability,
   not a grant**: a **direct call** when `EXECUTE` is wider than the backend role; or **DML on an
   attached table** for a `RETURNS TRIGGER` body — a trigger runs with the `search_path` of whoever
   issued the INSERT/UPDATE, and **revoking its `EXECUTE` does not detach it.**

A candidate list filtered on ACL alone drops a trigger function precisely when somebody "hardened" it
by revoking a grant that was never the way in. A trigger function dereferencing **zero** relations is
safe for that reason only — **re-run the reasoning whenever a trigger body changes**.

**How to pin:** `SET search_path = public, pg_temp` with `pg_temp` explicit and **last**. Omit
`pg_temp` and it is implicitly *first*, so `SET search_path = public` fixes nothing; naming `pg_temp`
alone is worse than no pin. `SET search_path = ''` is stronger and only safe when every reference in
the body is schema-qualified. **Pin at creation.**

An unpinned function is an *escalation multiplier*, not a hole an ordinary user can walk (the REST
layer fixes `search_path` per request and offers no `CREATE TEMP TABLE`): it upgrades any foothold
already running attacker-chosen SQL as those roles from "read some rows" to whatever the function
guards. Property 2 is necessary, not sufficient — settle a candidate by measurement. Whether functions
that *fail* the test should pin anyway is a policy decision: write down how it was ruled.

## 3. The registry pattern: a lookup table of what is in force

Keep one page (a lookup table grouped by what each function can reach) recording, per definer
function: signature, where defined, **grants in force**, `search_path` status.

- **Declared vs live are different facts.** Mark each Grants cell "declared by the migration" or
  "asserted from the live catalog". Promote a row only when its migration carries an apply-time
  `DO $check$` assertion (re-run on every fresh database) or a human read the catalog (dated).
- **Do not write the row count into prose** — every copy goes stale. A re-signing is a replacement,
  not an addition; a SECURITY **INVOKER** function does not belong on the page.
- **Recount, don't trust a total:** `grep -rnE 'SECURITY DEFINER|ALTER FUNCTION' <migrations>/*.ts`
  is the *start* — exclude prose comments and `down()` bodies, then follow every hit *forward* for a
  later `CREATE OR REPLACE` or `DROP FUNCTION`. A script that does the full walk and fails CI on drift
  is the durable fix.

**Live ACL query:**

```sql
SELECT p.proname, array_to_string(p.proacl, ' , ')
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND p.prosecdef
 ORDER BY p.proname;
```

**Checklist**
- [ ] Every mutating definer function has `REVOKE ALL … FROM PUBLIC, anon, authenticated` + `GRANT` to
      a named role only, in the **same** migration `up()` as the function
- [ ] The revoke is verified against the live ACL (an apply-time `DO` assertion in both directions)
- [ ] Re-grants resolve signatures from `pg_proc`; a re-signed function drops its previous signature
      explicitly and is re-granted afterwards
- [ ] Functions taking a user/tenant id as a parameter derive it from `auth.uid()`, or are restricted
- [ ] `TRIGGER` functions are left alone **for grants** and separately walked through the three
      `search_path` properties
- [ ] A function clearing all three properties pins `SET search_path = public, pg_temp` at creation
- [ ] The registry is updated if you added, removed or re-granted a function
