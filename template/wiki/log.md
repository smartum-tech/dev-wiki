# Wiki operations log

Every `/wiki-bootstrap`, `/wiki-ingest`, `/wiki-lint` and `/wiki-audit` pass appends one entry
here.

**Newest first.** Insert new entries directly below the `---` separator, above the most
recent existing entry. Never append at the bottom.

This file is also the **append-only registry of ingest runs**, which is why an ingest entry
carries a machine-readable `Range: <base>..<after>` line and is written even when the run found
nothing. Completeness is measured by whether the union of those ranges covers every first-parent
commit on `{{MAIN_BRANCH}}`; PR numbers cannot measure it, because commits reach
`{{MAIN_BRANCH}}` without one. A missing entry is indistinguishable from a run that never
started.

An entry that changes the always-read core carries a `Core:` line — what it added, what it cut,
and the net (`CONTRIBUTING.md` §3). "Nothing could be cut, because …" is a valid second half;
leaving the line out is not.

The bootstrap entry carries a `Baseline: <sha>` line — the commit the tree was first compiled
against. It is the lower bound `/wiki-lint` and `/wiki-ingest` count coverage from; without it,
coverage would be measured against the whole history of the repository.

---

<!-- EXAMPLE ENTRY — the shape, not a real run. Delete this comment block when the first real
     entry (normally the bootstrap's) is written above it. The machine-read lines below are
     indented on purpose, so `grep '^Range:'` does not mistake the example for a run.

## [YYYY-MM-DD] ingest | PR #NN — 3 pages, 1 created

    Range: a1b2c3d..e4f5a6b
    Core: +2.1k/-0.6k bytes (net ≈ +380 tokens; core ≈ NNk). Cut: the duplicated retry explanation
in `guides/backend-howto.md` (a pointer now; `modules/payments.md` holds it). The rest is the
new rate-limit gotcha, which exists on no other page.
- PR #NN (042 rate limiter): sliding-window limiter in the payments client. PR body, review
  comments and change-log entry read; the limiter checked against the client and its spec.
- Updated (stamped e4f5a6b): `modules/payments.md` (the limit sits below the vendor's, and why),
  `guides/backend-howto.md` (RATE_LIMITED is not a generic failure).
- Updated (not stamped — one section checked): `guides/testing.md` (the limiter is disabled in
  the unit lane).
- Created: `guides/vendor-rate-limits.md` (indexed).
- Consumed: `journal/YYYY-MM-DD-payments-rate-limiter.md` (both items).

A run that found nothing still gets an entry:

## [YYYY-MM-DD] ingest | commit f0e1d2c (no PR) — no knowledge found

    Range: e4f5a6b..f0e1d2c
- Version bump only; no page changed. No change-log or journal entry in range.
-->
