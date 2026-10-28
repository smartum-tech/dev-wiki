---
date: YYYY-MM-DD              # when it happened, not when written
journaled:                    # authoring date — normal, entries are usually written after
type: module-dev | code-change | prod-investigation
modules: [payments]           # wiki/modules/ pages this touches; [] is valid for infra/ops
commits: [a1b2c3d]            # realized change — SHA(s); may be a bare hotfix or empty
pr:                           # PR number, if any
outcome: shipped | fixed | partial | reverted | inconclusive
---

# <Short title of what happened>

<!-- If this is a recurrence, open with a blockquote naming the prior entries and what is
     NEW this time — a different failure mode of the same symptom is the usual case.
> **3rd recurrence** of the <family> (journal/<earlier>.md, journal/<earlier>.md), but a new
> failure mode: <what differs>. Runbook: wiki/guides/<page>.md
-->


## Context
What triggered this — the problem, request or goal, in one short paragraph. Link the spec if
one exists (`specs/NNN-…`), remembering it is not authoritative.

## What we actually did
The realized change, bulleted, citing files. If the result diverged from the spec, say how
and why.

## Findings
What we learned that is **not** obvious from the code: root cause, gotchas, why an approach
was rejected, production behaviour, a non-obvious invariant. This is the highest-value
section — it is the part that would otherwise be lost, and the part `/wiki-ingest` mines for
`modules/` gotchas and `target/` constraint candidates.

## Outcome
Did it work, and verified how? Any follow-up left open.

## Wiki impact
- [ ] `wiki/modules/<name>.md` — create/update: <what>
- [ ] `wiki/guides/<name>.md` — update: <what>
- [ ] `wiki/target/` — does this close a divergence, or argue for a new page (via `specs/drafts/`)? <which>
- [ ] new concept page worth extracting? <which>
