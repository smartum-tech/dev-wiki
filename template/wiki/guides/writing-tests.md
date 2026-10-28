---
title: Writing a Test That Holds
class: compiled
covers: []   # none: this page states rules a spec must follow, and no commit can make it false
last-verified: never
verified-by: boilerplate
sources: []
---

# Writing a Test That Holds

Strategy and lanes are in [testing.md](./testing.md). This page is the other half: whether a spec
that is green actually proves anything. Migrations have their own page
([migration-testing.md](./migration-testing.md)); client tests are in
[frontend-testing.md](./frontend-testing.md); E2E in [e2e-writing.md](./e2e-writing.md).

## The basics

- Descriptive names, one behaviour per test, arrange/act/assert.
- Independent tests — no ordering dependencies between `it` blocks.
- Don't test implementation details; never commit `.only` or `.skip`.
- Every error path gets a case, not just the happy path.
- **Keep parsing helpers free of `expect`.** A helper that throws fails every test at once, which is
  unreadable as a kill. Assertions belong in tests so a broken behaviour fails **by name**.

## Red at the merge base is not enough

A regression spec that is red before the fix can still fail to pin the fix. A fix with two parts
can ship with a spec of three arms, each red before and green after, that all stay green when half
the fix is reverted — because none of them ever built the state that separates the full fix from the
half fix. Red-then-green proves the bug was there; only **mutating each part of the fix
independently** and watching a named test go red proves the spec holds it down. Do this by hand
before calling a regression test done.

## Name the property your test double cannot observe

Before trusting a green spec, ask what its double is incapable of seeing.

- **A mock that replays results in call order cannot see a wrong-row bug.** If a database mock is a
  queue (each query consumes the next prepared result regardless of its filters), the suite stays
  green whether the code fetched the row it validated or whichever happened to be newest. To pin row
  *selection*, use a fixture that applies the filters — a small in-memory table honouring
  `eq`/`order`/`limit`, seeded with **both** the legitimate row and the adversary's — so the
  assertion is "the payload carries the submitted identity", not "the payload carries what we
  queued". Worth writing only where selection *is* the behaviour under test.
- **A matrix that hard-codes its own expected values has a side it cannot fail on.** A rule
  duplicated in two languages (an allow-list in application code and the predicate mirroring it in
  SQL) was checked by a matrix with its own expected arrays: widening the SQL turned it red,
  widening the application code did not, because the test agreed with a third copy. Iterate the
  **complete** catalogue (every status, every role) and derive the expectation from the one shared
  exported constant, so drift in either direction fails.
- **Per-case pins fail only on cases someone imagined.** A gate pinned with one spec per status
  somebody thought about survives the quiet deletion of an admitted status. One table-driven test
  over the whole enum asserting *admitted ⇔ in the list* bites in both directions.

## The assertion you want in the abstract can be the one that cannot fail

A refresh-after-reconnect must reload **at least** what each event handler would have loaded, so
"the refresh is a superset of every handler" is the property a review asks for. As an assertion it
is one-sided and the surviving mutants sit on the side it does not cover: a handler mutated to a
no-op invalidates nothing, the empty set is a subset of anything, and the superset check passes
against exactly the defect that motivated it. **Equality is what the implementation actually
guarantees** (one function object is handed to every handler and to the refresh), so assert
equality: it fails on a shrunken handler *and* on a shrunken refresh. Where one site legitimately
does more than the others, it owes its own assertion with the reason written beside it.

Variants of the same mistake:

- **Asserting through one entry point leaves the construction unpinned.** If every pin reaches the
  channel only through its status callback, handing it a narrower function or deleting a
  registration outright keeps the suite green. Write the list of registrations out **by hand** at the
  call site; a list derived from the code under test agrees with every mutation of it.
- **Guard against vacuity explicitly.** If the refresh invalidates nothing, every
  handler-versus-refresh comparison is vacuously true. One assertion that the refresh's own set is
  non-empty holds the rest up.
- **Against a live gate, the guard is a control arm, and it runs on the same fixture.** "The removed
  member gets an empty list" passes just as well when the fixture never built the row. Mutate the
  one thing the gate reads (a soft-delete flag), assert the refusal, restore it, and assert the
  *positive* answer is back with nothing else touched. An isolation or permission test without a
  positive control proves nothing. Restore in a `finally`: a failed assertion otherwise leaves the
  mutation standing, and in a suite that shares a fixture that turns one red test into a file of
  them, all pointing away from the cause.

## An assertion must make the same timezone decision as its production counterpart

The rule is about measurement, not about "pin the zone in tests" — and it breaks both ways.

An assertion built its expected string with a locale date formatter and **no** `timeZone`, then
compared it against a production formatter that pins UTC. The two agree exactly when the test
process runs in UTC (every CI box and sandbox) and disagree by one calendar day whenever the
instant falls between the two midnights — found only on a developer laptop, after every automated
run had been green. Another formatter in the same codebase deliberately does *not* pin, because
nothing knows the user's timezone and a hardcoded zone would only move which users are wrong; the
assertions comparing *its* output are correct because they do not pin either, and adding a zone
there turns a green test red for no defect.

In production the pin decides which day to name; in a test it is what makes the two sides of an
equality the same measurement. Where a spec restates a formatting contract instead of importing it,
restate the zone decision too, and keep one deliberately-offset control case so the assertion is
known to discriminate at all. Run the suite once under a non-UTC `TZ` when touching date code.

## A fixture that inserts straight into a state manufactures states no writer produces

A fixture that inserts a record directly into a timed status, skipping the transition that would
have written the deadline, yields a status with **no timer** — a shape the application cannot
construct. Guards written against real rows then meet an input the system never produces, and a
test built on it proves nothing about production.

**Setting one column of a multi-column state is the same defect.** A fixture set a verification flag
without the submitted application that a verified account implies; when the code under test began to
read from that row, the main branch went red from a merge touching neither file. Seed the rest of the
state, and never soften the new failure — it was correct.

Where a case depends on a value being *absent*, make the absence an explicit argument at the call
site, never something inherited from whatever the fixture happened not to insert. Two features that
fix the same fixture incompatibly produce a merge conflict that is a **collision of decisions, not
of text**: taking either side wholesale silently changes what the other's assertions mean.

## After merging two features that lived in parallel in one file, a green `tsc` proves nothing

A helper whose *contract* changed — same arity, same types, different meaning — merges cleanly
because the two edits sat in different regions, type-checks, and fails at runtime. Run the suite.
And read a red test's **precondition**, not only its subject: a case that moved the clock by a
hardcoded number of days silently encoded the rule the merge had just replaced. The subject was
still right; the setup had to be re-derived from the fixture instead of stated as a number.
