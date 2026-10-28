---
title: Database operations — how migrations apply, roll back, and get named (example)
class: compiled
covers: []                 # fill when adopting: the migration runner/service, the CLI, the migrations folder
last-verified: never
verified-by: boilerplate
sources: []
---

# Database operations — how migrations apply, roll back, and get named

> **Example — adapt to your backend.** Written for a Node backend whose migration runner tracks
> applied files **by name** in a ledger table (Umzug-style) and runs pending ones at boot. If your
> tool tracks checksums or versions, keep the reasoning and replace the mechanics.

Authoring tests and signature changes are [`migrations.md`](./migrations.md); what a security-relevant
migration must assert is [`security-database-checklist.md`](./security-database-checklist.md).

## Migrations apply themselves

**Adding a migration file is the normal way to apply one.** The backend's migration service runs on
every boot (`onModuleInit`); in a container's watch mode a new file restarts the process, which
re-runs migrations. Multiple instances booting at once do not race: each tries a Postgres advisory
lock before running, and a loser polls until the winner releases it.

The CLI scripts exist for the cases where that is *not* what you want: checking status (read-only),
or rolling back. Rolling back is destructive because it changes schema state that every branch and
every other developer's stack shares — **get approval before `down` or `down:all`**. The Docker
variants reach only whichever stack is actually running, not necessarily the one serving your code
if you are on a worktree; a variant that reads a different env file reports a different database, so
status can legitimately differ until you run it against the environment you meant.

## Editing an applied migration does nothing

The runner records "already run" **by filename only**. Pending = all discovered files minus recorded
names; if the name did not change, editing the body only changes what would run *next time the file
is new to a database*, not what already ran. To fix an applied migration, **write a new migration**.
The old body is simply never re-executed — this is not a lint-only suggestion.

**If you are already in that hole, there is a procedure, and it is not "run the DDL by hand".**
Unlog the row through the CLI's own storage contract (`DELETE FROM migrations WHERE name = '<file>'`,
exactly what the runner's unlog does), then re-run the CLI's `up`, so the CLI stays the only thing
that ever executes a migration body against a shared database. Hand-writing the objects to "catch
up" is how a catalog and a ledger come to disagree, and the disagreement is invisible afterwards.
The load-bearing consequence either way: **a database already carrying the name is not brought into
line by `migrate:up`** — verify deployed objects against the file *from the live catalog* instead of
assuming.

An edit of an applied file is defensible only when the file **never reached the main branch** (every
production database applies it once with the final content) and the only environment carrying an
earlier body is a single shared development one. Reproduce that measurement before allowing it, and
put the justification and the verification queries in the file's header.

**A superseded migration stays in the tree, and its header becomes a trap.** Deleting an applied
file does not unapply it, and a fresh database must replay it to reach the same catalog. What is left
is a header describing behaviour that is not live, sorting *earlier* than its replacement and so
first to a grep. A replaced file carries a **retraction at the very top naming its successor**.

## `down()` is a decision, not boilerplate

Some migrations must refuse their own inverse. The test is not "can an inverse be written" but
**what the inverse would do**:

- **It would re-open a security hole** (hand back revoked grants, drop a policy guard, reset a
  `search_path` pin) → decline. The `down()` throws a message naming what it would restore — the
  shape to copy. A migration that adds a guard *alongside* other work keeps the guard in its `down()`;
  one whose only content is the guard can only decline.
- **It would destroy data** — null a column whose values are indistinguishable from ones the app
  wrote, or restore a storage policy under which nobody can read their own files → decline.
- **It would destroy accounting history** — a `down()` that refuses *on the data* (raises while
  ledger or issued-document rows exist) rather than on principle. Deleting history is not a
  rollback's call.
- Extending a guard is the exception: the inverse of "extend a guard" is still a guard, so a narrower
  body restore is fine.

The abort itself is clean: the runner throws "does not export 'down'" **before** unlogging, so
schema and ledger are left exactly as they were and nothing older is reverted in its place. If a
one-way migration genuinely has to be undone, that is a **new forward migration** naming what it
re-opens and why.

**Which migration a bare rollback actually hits is a moving fact, and any page that lists the
refusers goes stale.** The runner reverts the *highest applied name*, so the tripwire belongs to
whichever migration currently sorts last — a by-product of what landed most recently, not a design.
If that migration has a working `down()`, a bare `migrate:down` **succeeds and silently drops a live
object**, the dangerous case because the CLI gives no error. **Re-check after adding any
migration**: the sort order (`ls <migrations>/*.ts | sort | tail -1`) and the count of one-way files
(grep the folder for the two shapes: no `down` export, and a `down` that throws). Re-count from the
folder; never restate a number from a roster.

## Naming: take the next free slot

The scaffolding command stamps **wall-clock** time into the filename. Rename to the project's slot
convention before committing — e.g. `YYYY.MM.DDT00.00.NN`, `NN` counting that day's migrations up
from `00`. Migrations apply in lexicographic order, so a wall-clock name orders yours against
everyone else's by the minute you ran the command — nobody's intended order. Duplicate prefixes
appear when two authors reach for the same slot: git merges both cleanly and the real order falls out
of the rest of the filename. Check the tail of the folder listing and take the next free `NN`; when
several agents work in parallel branches, use the slot you were handed.

## A migration nobody has run has never had its SQL parsed

Review reads intent; Postgres reads syntax. **Before a migration goes to review, execute its
emitted batch inside `BEGIN … ROLLBACK`, printing the SQL from the migration itself** rather than
retyping it — a retyped statement proves the reviewer can write valid SQL, not that the file emits
it. Nothing commits. This is a human check that a statement parses and orders correctly; it is
distinct from a *test* handing a live connection to `up()`/`down()`, which is forbidden
([`migrations.md`](./migrations.md)). A storage policy that admits nobody passes review
precisely when nobody parses it.

## Backfills and data migrations

Treat a backfill as its own migration, separate from the schema change, idempotent (re-running it
finds nothing to do), batched when the table is large, and with a `down()` that declines when the
values it wrote are indistinguishable from app-written ones. State in the header how to verify it
from the catalog/data, since the runner will not re-run it.
