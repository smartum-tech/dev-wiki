---
title: Third-Party (Vendor) Mocks
class: compiled
covers: []   # fill when adopting: the in-memory vendor client mock, the dev-only fixture routes that drive it
last-verified: never
verified-by: boilerplate
sources: []
---

# Third-Party (Vendor) Mocks

Patterns for an in-memory double of an external service (a bank, a payment processor, a map or
messaging provider) swapped in for tests and local development. Your own backend's mock is a
different animal: [mock-server.md](./mock-server.md).

## Why the divergence list matters more than the mock's convenience

If the vendor's sandbox is unusable for routine testing (requires mutual TLS, shares state, is
absent, or checks nothing), the mock becomes the only thing the suite exercises, and **nothing
validates the real contract except production.** The mock agrees with your understanding by
construction, including wherever that understanding is wrong. So the page that documents the mock
carries a **"what the mock does NOT reproduce"** list, and keeping it honest matters more than
keeping the mock convenient. Calling the real sandbox by hand is a provisioning or
certificate-rotation check, never a step in a loop; a spec written against it is skipped unless an
explicit env flag is set and runs in no routine pass.

## Switching it on: fail closed, twice

Gate the mock on an exact env string (`USE_MOCK=true`; unset, `1`, `TRUE` leave it off). If two
independent places read the same variable — the DI factory that picks the client, and the guard on the
dev-only fixture routes — keep them in sync deliberately: they move together only while they key off
the same variable, and splitting one boolean into two reads is how they diverge. Rules:

- **Production disables the dev surface unconditionally**, regardless of the flag.
- **Dev routes answer 404, not 403, when disabled**, so a production deployment does not reveal that
  the surface exists.
- A separate flag per vendor surface (a second client for invoicing, say) falls back to the main
  flag only when unset — do not assume one flag mocks every surface of one vendor.
- The mock satisfies the client's injection token by structural typing (same methods, same
  signatures); no interface or abstract class is needed, and none can drift from the real one except
  through the type checker.

## Selecting a scenario: deterministic sentinels

Failure and edge paths are driven by **sentinel inputs** rather than randomness or a test-only
parameter, so the same request means the same thing on every run:

- a suffix of an identifier (for example the last digits of a phone number) selects the outcome of a
  screening or scoring call; any suffix the mock does not name passes;
- a magic amount selects a payment outcome (fail, hang, succeed late);
- a magic name on a create call returns a 422 to drive the failure path.

Keep each constant with its meaning in a trailing comment in the source and do not keep a second
copy of the catalogue on a wiki page. What the constants do *not* say and you need to know:

- **A sentinel keys on what one leg of the call carries, not on your business object.** The mock has
  no notion of, say, a "settlement", only of a payment or transfer amount, so three sentinels can
  live on three different legs of one row, and choosing one means computing backwards through your
  fee split.
  Provide a fixture route that does that for you: find the smallest gross whose split lands on the
  sentinel, seed the mock's balance, and create the row **through the same function production uses**
  — never a hand-written ledger row. That is what makes the fixture worth using over an INSERT.
- **Asynchronous flows stay asynchronous.** A hosted-form step (card binding, redirect checkout)
  returns `PENDING` with a URL to a real dev-hosted form and stays pending until that form or its
  completion endpoint is driven. Completing twice replays the recorded outcome rather than flipping
  state again. Code written against an "instant success" assumption will hang.

## What a mock typically does NOT reproduce

Write these down per vendor; read them before trusting a green dev/e2e run.

- **Failure is sentinel-only.** Any input without a sentinel succeeds instantly, so code that assumes
  every call eventually fails or stalls is never exercised by an arbitrary test value.
- **Scoring/risk is deterministic on a test convention**, with zero relationship to real data.
- **Non-contract statuses used to prove robustness.** A stuck state the real API never documents may
  be stamped through a deliberate widening cast, to prove a worker's guard handles a status it does
  not recognise — that is not a reproduction of a real vendor state.
- **No latency, TLS or rate limiting**, except where a scenario simulates a delay. Timeout and retry
  code outside that path is never exercised by running against the mock.
- **Validation checks only what the mock models.** If the real call runs two checks (arithmetic *and*
  whether the funds exist) and the mock implements the first, the second is unmodelled and **no test
  can fail on it** — nor can an unused sandbox. Seeding the store cannot fix it: the check that
  would have to fail does not exist in the mock. Document it as "stands documented and never
  observed".
- **A guard state no mock operation can produce.** A status the mock accepts as a guard condition but
  never produces by driving its public methods requires seeding the store directly in a test.
- **No HTTP reset.** `reset()`/`getStore()` are for a unit test that instantiates the mock directly.
  The dev/e2e backend's instance is a process-lifetime singleton with no reset route: its state
  persists across requests until the process restarts (a hot reload counts). E2E presets that re-run
  against a live backend must re-seed; they cannot assume a clean store.
- **A restart forgets every entity the database still points at**, and only the paths designed to
  forgive it do. Decide per method: materialising an unknown id as a bare stub ("known, no children
  yet", with a warning) keeps flows alive after a restart, but a *read-by-id* that is part of the
  contract (provisioning must throw on a dead recorded entity rather than report it alive; a queue
  spec uses the 404 as its non-retryable probe) must keep returning 404. Widening a lookup helper to
  fix one flow once turned two such tests red — narrow it back, per method. The real vendor never
  loses an entity.

## Faithful to the real contract, on purpose

- **Idempotency-key dedup**: a repeated POST with the same key replays the original created entity
  rather than re-executing the mutation, because the retry-safety of your workers depends on it. Only
  successful creates are recorded; a failed attempt is never deduped, matching the vendor.
- **State-machine guards mirror the real API's rules**, not a simplification: edits require the draft
  state, completion requires the accepted state, the last step completing completes the whole,
  deleting a draft cascades.

## Use the mock for fixtures too

A dev-only fixture surface built on top of the mock (seed a funded account, create a process in a
given state) must go through the **same code paths production uses**. A hand-written row that no
production writer could produce is the fixture defect described in
[writing-tests.md](./writing-tests.md).
