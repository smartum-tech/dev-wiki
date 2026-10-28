---
title: Testing a migration, and changing a function's signature (example)
class: compiled
covers: []                 # fill when adopting: the migration service, the migration specs, the one re-sign set
last-verified: never
verified-by: boilerplate
sources: []
---

# Testing a migration, and changing a function's signature

> **Example — adapt to your backend.** Postgres + a name-tracked migration runner; stored functions
> called by clients through an RPC layer. How migrations apply, roll back and get named is
> [`database-operations.md`](./database-operations.md).

A migration has physics a normal test does not: the thing under test runs **once per database**, so
every database you can point a test at has already applied it.

## The boundary: a test never hands a live connection to a migration

A spec never passes a live `Pool` to a migration's `up()` or `down()`. A suite that tears a schema
down and rebuilds it to prove reversibility runs `DROP TABLE … CASCADE`, which destroys foreign keys
belonging to *other* migrations and, separately, resurrects
pre-change function signatures (below). A rule phrased "a test never calls `up()`" is the wrong
rule, though; see the recorder.

### The recorder: call the direction, do not execute it

Replace the executed round trip with a fake pool that records SQL and resolves:

```ts
const issued: string[] = [];
const fake = { query: async (text: string) => { issued.push(text); return { rows: [] }; } } as unknown as Pool;
await up(fake);
```

It **calls** the direction; it does not read the file as text. The rule is therefore about
*executing on a database*, not about calling `up()` — otherwise it condemns the very pattern it
recommends, and a rule that forbids its own prescription gets those tests deleted by the next
reviewer. What the recorder gives you is what a **fresh** database would receive, which is the
property that actually ships, and nothing running concurrently can move it.

### The recorder resolves everything, so nothing proves the SQL is valid

`query()` returns `{ rows: [] }` for any string. A recorder spec proves *what would be issued* and
never that it **runs** — not that it parses, not that statements are ordered so each dependency
exists, not that a referenced object is there. Nothing else covers it: the runner never re-runs an
applied migration, so every live-catalog assertion reads a catalog migrated under the file's **old**
body, and a syntax error introduced into an old migration stays green on every database that could
notice, surfacing on the next **fresh** one — production. The mitigation is the human
`BEGIN … ROLLBACK` run before review ([`database-operations.md`](./database-operations.md)); a
docblock claiming "source level is what the claim needs" does not cover it.

## Compare the two sets; do not count names

Assert that *everything `up()` creates* equals *everything `down()` drops*, against a list written out
by hand. Counting catalog rows for five hard-coded names misses a sixth object added to `up()` and
forgotten in `down()`; comparing sets is red in both directions. **That only holds if the extraction
sees every spelling the folder writes**: `CREATE FUNCTION` appears with and without `OR REPLACE`,
schema-qualified and bare, with arbitrary whitespace (newlines) before the parenthesis. Count files
per spelling before writing the regex. An allow-list that misses a spelling **fails open on exactly
the drift it exists to catch** — the new object is absent from the extracted set *and* the
hand-written one, so they still agree.

## Guarding a schema invariant takes two specs, not one

A migration that establishes a security property (a grant, a `search_path` pin) needs a
**source-level** spec and a **live-catalog** spec; neither substitutes for the other.

- The runner never re-runs a migration, so on any database that applied it every database-backed
  assertion stays green whatever the source is edited to say — including deleting the clause. Only a
  source-level spec protects the *fresh* database where it will run.
- **`CREATE OR REPLACE` preserves a function's config and ACL; `DROP` + `CREATE` does not.**
  Functions get re-created routinely, so the property reopens silently each time. Only a spec reading
  the live catalog sees that — and it is red exactly when the source spec is green.

Pair a catalog assertion with a behavioural one (the first says the clause is *present*, the second
that it still *does something*): plant the attack inside a transaction that is rolled back, with
**control arms** — one showing the victim is not privileged without the plant, one showing the plant
really shadows. A live-catalog assertion on a shared stand also measures a moving object, since
nothing isolates the catalog the way a marker isolates rows.

### When you assert over source text, make the region and the claim coincide

A recurring failure: inspect a derived *region* and make a claim about *the whole thing that runs*. A
commented-out clause satisfies a `toContain`; a renamed dollar-quote delimiter sends a slice past the
end of one function to borrow the next one's pin; an `ALTER FUNCTION … RESET search_path` appended
after the block's terminator is invisible to a test named "touches no GRANT, REVOKE or ALTER".

- Prefer **allow-lists** ("the batch is exactly one `DO` block"; "every `EXECUTE` runs a dollar-quoted
  literal, and those literals are exactly these two statements") over deny-lists of forbidden
  strings, which cannot be made complete against concatenation. Say in the test which one it is.
- The region decides the claim: a *positive* claim must read what would execute (strip comments); a
  *negative* one is safer against raw text, where a commented-out mention fails — a false alarm
  beats a silent pass.
- A comment stripper is an approximation: one that filters lines starting `--` lets `/* … */` blocks
  and trailing `--` comments through, and widening it is not the fix (`--` is legal inside a string
  literal). State its exact reach in its docblock; a helper that raises the bar reads as one that
  closed the hole.
- **A negative property has no allow-list form.** "This guard does not freeze the counter" tripwired
  by a regex naming one operator is walked past by a freeze written `<>`; widening the list is the
  same trap one level up. Keep the regex narrow and prove the property **live** — one UPDATE raising
  the counter and accepted, one lowering it and rejected — and say which case is the tripwire and
  which the proof.
- Keep parsing helpers free of `expect`: a helper that throws fails every test at once, which is
  unreadable as a kill; assertions belong in tests so a mutant fails **by name**.

## Changing a function's signature in place

Adding a parameter makes a new *function*, so the idiom is `DROP FUNCTION IF EXISTS <old exact
signature>` then `CREATE`, in one migration (`CREATE OR REPLACE` leaves the old overload alive with
its grants — [`security-database-checklist.md`](./security-database-checklist.md)). Between the `DROP`
and the moment every process running the old code has stopped, **a caller compiled against the other
arity has no matching function** — PostgREST answers `PGRST202`, an error classifier that does not
match on it rethrows, and a valid request becomes a 500.

The invariant that keeps the window shut is not the replica count: **no process compiled against the
old signature ever serves against the new catalog.** Replicas alone don't break it — migrations run at
boot behind an advisory lock and losers wait for the winner — so under stop-everything-then-start a
replica never serves before the catalog is new. What breaks it is old code left *serving* after the
catalog moved.

**The rule:**

1. `DROP` + `CREATE` in one migration stays the idiom **while deploys stop every old process before
   new code migrates** — any replica count, one downtime window.
2. **The day deploys become rolling / zero-downtime, every signature change ships as two releases:**
   create the new overload and move callers in the first, drop the old one in the second. Old pods
   keep serving through a rolling deploy by design, so no boot-time gate can reach them; the catalog
   must stay compatible with both versions for the mixed window.
3. **Never boot an older image against a catalog whose signature-changing migration has applied** —
   the old image sees no pending migrations and calls the dropped signature for its lifetime.
   Recovery is roll-forward only: a re-sign *set* is unrevertable as soon as its **last-sorting**
   file declines its `down()`, because the functions move as a unit while the runner reverts one file
   at a time.

Caveat on the boot gate: a loser that reads a free lock as "migrations complete" without re-checking
for pending ones, with the lock not pinned to a connection (both calls through a pool that can reap
idle sessions), holds only because one process runs the whole boot and nothing else touches that
pool. Know that before relying on clause 1.

**A migration-reversibility suite is the caller you would not think of.** A teardown-and-rebuild
re-runs the *old* files' `CREATE OR REPLACE`, resurrecting the pre-change signature as a **second
overload** beside the live one (the old `DROP` names the old signature, so it no-ops against the new
one), and every named-notation call in the rest of the run is then ambiguous. Do not patch that with
a "re-run the signature-changing migration at the end" tail — forbid the rebuild.

**Re-signing is never one function.** Stored functions compose by forwarding arguments into a
primitive; a parameter dropped from the primitive must be dropped from every wrapper that forwards it,
in the same migration run — otherwise a live wrapper calls across the gap and fails at execution time
(plpgsql resolves a callee at **execution**, so the migration applies clean). Enumerate the callers
from `pg_proc.prosrc`, not from the spec: a spec that names two functions can hide a blast radius of
five.
