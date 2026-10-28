---
title: Test Isolation (Marker Pattern)
class: compiled
covers: []   # fill when adopting: the isolation policy/function migrations, the test helpers, services that hand-roll marker filters
last-verified: never
verified-by: boilerplate
sources: []
---

# Test Isolation (Marker Pattern)

> **Worked example — adapt to your backend.** The principles below are general: tests that run
> against a database shared with something else need a mechanism that keeps their rows invisible to
> production and their reads invisible to each other's mess. The *mechanism* described here — a
> nullable `test_marker` column, a row-level-security predicate and an insert trigger — is one way
> to build it on a relational database with row-level security. If your project isolates by a
> separate database per run, a schema per run, or transaction rollback, keep the principles and drop
> the machinery.

Strategy and lanes: [testing.md](./testing.md). This page is for the **test author**: why a test
that looks broken usually is not, and what a spec must do so its rows stay visible to it.

## Read this before assuming a test is broken

**A 403 or an empty result from a real client in a test is usually correct behaviour, not a bug.**
Row-level policies gate rows with a predicate that compares the *record's* `test_marker` column
against the *caller's* `test_marker` claim in its token:

| Token marker | Row marker | Visible? |
|---|---|---|
| NULL (real user) | NULL | yes |
| NULL | NOT NULL | no |
| NOT NULL (test user) | NULL | no |
| NOT NULL | NOT NULL | yes |
| privileged service role | any | always sees everything |

Production users never see test rows, test users never see production rows, and a test user sees
*any* test-marked row (test data is mutually visible across test sessions, not only its own). A
context with no token at all — migrations, raw connections — also passes. If a call comes back empty
or denied in a test, check whether the row actually carries a marker before blaming the policy or
the test.

## The two "yes" answers that are not isolation

The predicate returns `true` for two cases that are **bypasses**, and reading them as isolation is
how rows leak:

- **Privileged role → always true.** A privileged query does not get test filtering for free. A
  read served through such a path surfaces leftover test rows in a production admin list; the fix
  is to move the read to a user-scoped client so policies apply again. **Any new privileged read
  must filter the marker by hand**, and it recurs — filtering on the domain key alone ("rows of
  this parent, not deleted") reads as complete and is not.

  **A hand-rolled filter has to reproduce the matrix above, and `eq(marker)` does not.** The
  obvious filter — *show the caller their own marker's rows* — is **stricter** than the policy it
  replaces: a marked caller passes against **any** non-null marker, and has to, because each E2E run
  mints a fresh temporary marker while the permanent admin keeps a permanent one. The correct pair
  is `marker IS NOT NULL` for a marked caller and `marker IS NULL` for a production one. The
  over-strict variant empties the list for every test admin, invisible until a per-run marker meets
  the permanent-marker admin.

  **A child inheriting its parent's marker cannot be filtered through an embedded join on a
  write:** some query layers apply the parent filter to a SELECT and silently ignore it on an
  UPDATE. Resolve the ids with a read first.
- **No token at all → true.** A fallback for non-API contexts, not a security boundary on the API
  path.

## The stamping trigger is per-table, and most tables do not have it

An insert trigger can read the caller's token and stamp new rows automatically, but each table's own
migration decides whether to install it. Which tables have it is one grep over the migrations
folder and is not copied here.

A table whose migration added the column and the policy clauses but no trigger needs its marker
**set explicitly** when a privileged client inserts (that client carries no user token, so a trigger
would no-op anyway); otherwise the row is invisible, under policies, to the very user the test logs
in as — including that user's own record. Child tables may carry no marker at all and inherit
visibility through the join to the parent: do not go looking for a marker to set on them.

**Never attach the stamping trigger to a table only the privileged role writes.** The trigger returns
the row unchanged both with no token and with the privileged role, and on a table with zero client
policies every possible writer is one of those two. It reads like coverage and does nothing. Give the
table an explicit marker argument and let specs pass it.

The failure mode can be worse than a no-op. On a singleton-per-world table (a partial unique index
pins one row where marker IS NULL), a spec that forgets its marker does not get an untagged row — it
gets **the production singleton**. Pin such a decision from both sides, because neither sees the
other: a **source-level** spec reading the migration file (the only thing protecting a fresh
database, since a migration runner never re-runs an applied migration) and a **live-catalog** spec
asserting an **allow-list** of trigger names rather than the absence of one name, so any future
addition fails it too. See [migration-testing.md](./migration-testing.md).

## The marker isolates rows, not the catalog

Everything above is row-level. **Nothing here isolates the schema.** Test workers in one run share a
database and therefore one catalog, so a spec that changes schema is outside this mechanism entirely
and no other worker can see it happen.

A typical failure shape: a spec asserting a table has a given set of foreign keys finishes a moment
before a spec whose migration `down()` ends in `DROP TABLE … CASCADE`, which takes one of those keys
with it.
`CASCADE` reaches constraints that live on **other** tables and belong to **later** migrations,
which the matching `up()` cannot restore because they are not its objects. The suite is green and
the key is gone by the end of the same run; which worker finishes first decides the outcome, and
nothing in either file expresses an ordering.

Generalised: **on a shared database a catalog assertion measures a moving object.** A green catalog
test proves the catalog was right at *some* instant during the run, never that it is right now.
Where a property must hold on a **fresh** database, assert the migration's source instead. The
destructive half is closed by rule: integration tests never execute a migration.

## Client pollution after signing in

A test that signs in as an admin and then needs to act as the privileged role again cannot reuse the
client it signed in with — that client now carries the admin's session. Create a fresh privileged
client for every capacity switch (admin login → privileged write → user-scoped read). A shared
helper that walks create-user → stamp-profile → stamp-claims in that order, on a fresh client each
time, exists so specs cannot get the ordering wrong; prefer it over reimplementing the dance.

## Marker values in practice

- `NULL` — production.
- a **permanent** value — E2E fixtures seeded once by global setup and never deleted; read-only
  scenarios share them.
- a **temporary** value (`test-<timestamp>-<random>`) — generated per run, cleaned up in `afterAll`
  by a helper that resolves the marker to user ids and deletes them from the auth store as well as
  the application tables, in FK order, and **throws loudly** if a delete is blocked by an uncleaned
  restrictive child. A new table owed by a parent must be added to that helper.

The two kinds are not interchangeable. Code that auto-propagates "the tenant's marker" to a new
member must **explicitly exclude the permanent value**, and a fixture must never overwrite a
permanent user's marker (set it only when currently null, never `if (marker !== mine)`): that
pattern renames the permanent marker to a throwaway, which the next cleanup then deletes, breaking
every later test that signs in as that user.

## Writing a migration for a marked table

There is no shared switch: each owning table's migration adds its own marker column, its own
predicate clause in its SELECT/UPDATE policies and — only where a client can write the table — its
own stamping trigger. Child tables inherit through the join, so a `CASCADE` drop of a parent column
can silently take child policies with it and leave the table deny-all. Before dropping any column
with `CASCADE`, check for policies elsewhere that reference it.
