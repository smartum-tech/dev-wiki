---
title: Testing a Migration
class: compiled
covers: []   # fill when adopting: the migration runner, the migrations folder, the canonical recorder spec
last-verified: never
verified-by: boilerplate
sources: []
---

# Testing a Migration

> **Worked example — adapt to your backend.** Written for a SQL database whose migrations are
> TypeScript files with `up()` / `down()` run by a migration runner that records applied names and
> never re-runs one. The rules about *where a test may point* and *what source-text assertions can
> and cannot prove* generalise to any migration tool; the recorder snippet is the part to adapt.

Strategy: [testing.md](./testing.md). Whether a green spec proves anything at all:
[writing-tests.md](./writing-tests.md). The migration case has physics of its own: the thing under
test runs **once** per database, so every database you can point a test at has already applied it.

## The boundary: integration tests never execute a migration

**Never hand a live connection pool to a migration's `up()` or `down()`.** An integration suite
earns its name by being runnable against a real environment; one that rolls the schema back and
forward cannot be, because it will damage the data there — and on a shared database it damages the
*other* workers' view of the schema too ([test-isolation.md](./test-isolation.md)).

The boundary is the **database**, not the function call. Both of these are fine, and both are the
replacement for an executed round trip:

- **invoke a direction against a fake pool that records the SQL**;
- **assert against the live catalog** without re-applying anything — but only for a property that
  may be stale, never for one that must hold on a fresh database.

Phrase the rule against *executing on a database*, not against calling `up()`/`down()`: a rule that
reads "a test never calls `up()`" condemns the recorder pattern it prescribes, and a rule that
forbids the practice it recommends gets those tests deleted by the next reviewer. When existing
violators are known, list them as do-not-copy, and clean them up as scheduled work in their own
change — rewriting them inside an unrelated PR puts a test-infrastructure change into a diff nobody
is reviewing for it.

## The recorder

```ts
const issued: string[] = [];
const fake = {
  query: async (text: string) => { issued.push(text); return { rows: [] }; },
} as unknown as Pool;
await up(fake);
```

It calls the direction; it does not read the migration file as text. What it gives you is what a
**fresh** database would receive — the property that actually ships — and nothing running
concurrently can move it. For a reversibility or a source-shape claim it is the stronger
measurement, not a consolation prize.

## The recorder resolves everything, so nothing proves the SQL is valid

`fake.query()` returns an empty result for any string. A recorder spec proves *what would be issued*
and never that it **runs**: not that it parses, not that statements are ordered so each one's
dependencies exist, not that a referenced object is there at all. Executing the statements used to
prove that as a side effect, and dropping the execution dropped it.

Nothing else covers it: because applied migrations are never re-run, every live-catalog assertion
reads a catalog migrated under the file's **old** body. A syntax or ordering error introduced into
an old migration stays green on every database that could have noticed, and surfaces on the next
**fresh** one — which is production. Close the gap with a deliberate gate (a CI job that builds a
scratch database from zero and runs every migration), and do not read a spec's docblock saying
"source level is what the claim needs" as covering it.

## Compare the two sets; do not count names

Assert that *everything `up()` creates* equals *everything `down()` drops*, against a list written
out by hand. A check that counts catalog rows for five hard-coded names is blind to a sixth object
added to `up()` and forgotten in `down()`; comparing the sets is red in both directions.

**That only holds if the extraction sees every spelling the folder actually writes, so count them
before writing the regex:** `CREATE FUNCTION` appears with and without `OR REPLACE`,
schema-qualified and bare, with arbitrary whitespace including newlines before the parenthesis. A
set-comparison allow-list that misses a spelling **fails open on exactly the drift it exists to
catch**: the new object written the unmatched way is absent from the extracted set *and* from the
hand-written one, so the two agree and the spec stays green.

## Guarding a schema invariant takes two specs, not one

A migration that establishes a security property (a grant, a `search_path` pin, a policy) needs a
**source-level** spec and a **live-catalog** spec, and neither substitutes for the other.

- **Applied migrations are never re-run.** On any database that already applied it, every
  database-backed assertion stays green however the source is edited, including deleting the clause.
  Only a source-level spec protects the *fresh* database where the migration will actually run.
- **`CREATE OR REPLACE` preserves per-function settings and ACLs; `DROP` + `CREATE` does not.** If
  functions are re-created routinely, the property silently reopens each time. Only a spec reading
  the live catalog sees that, and it goes red exactly when the source spec is green.

Pair a catalog assertion with a behavioural one: the first says the clause is *present*, the second
that it still *does something*. Plant the attack (a temp table shadowing a real one) inside a
transaction that is rolled back, and keep the control arms — one showing the victim is not
privileged without the plant, one showing the plant really shadows. Without them a passing result is
unattributable.

## Assertions over source text: make the region and the claim coincide

Assertions that inspect a derived *region* and then claim something about *the whole thing that
runs* get defeated in review, repeatedly: a commented-out clause satisfied a `toContain`; a renamed
dollar-quote delimiter sent a slice past the end of one function to borrow the next one's pin; a
statement appended after the block's own terminator was invisible to a test named "touches no GRANT,
REVOKE or ALTER".

- Prefer **allow-lists** ("the batch is exactly one `DO` block and nothing else"; "every `EXECUTE`
  runs a dollar-quoted literal, and those literals are exactly these two statements") over
  deny-lists of forbidden strings, which cannot be made complete against string concatenation. Say
  in the test which of the two a given assertion is.
- **Which of the two also decides the region.** A *positive* claim must read what would execute
  (comments stripped), or a commented-out clause satisfies it. A *negative* claim is safer against
  the raw text, where a commented-out mention fails — a false alarm, against a silent pass.
- A comment stripper is only an approximation of what runs. One that drops lines starting with `--`
  lets a `/* … */` block and a **trailing** `--` comment after code walk through. Widening it is not
  the fix, because `--` is legal inside a string literal and a naive strip corrupts the SQL. State
  its exact reach in its own docblock: a helper that raises the bar reads as one that closed the
  hole.

**A negative property has no allow-list form, so source text cannot pin it at all.** "This guard
does not freeze the counter" tripwired by a regex naming one operator is walked past by the same
condition spelled another way — and widening the list is the same trap one level up, because the
next spelling is always the one nobody enumerated. Keep the regex deliberately narrow and prove the
property where no spelling reaches it: a live pair, one UPDATE raising the counter and accepted, one
lowering it and rejected. Say in the test which case is the tripwire and which is the proof.
