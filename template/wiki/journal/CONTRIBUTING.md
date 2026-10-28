# journal/ — append-only record of what actually happened

The **raw** layer of this wiki (`../CONTRIBUTING.md` §1): dated, factual, never rewritten. It
is the primary source the compiled pages are built from, alongside the realized code in git.

## What this folder is

**Raw material, not knowledge.** An entry is input to `/wiki-ingest`, which distills it into
the compiled pages people and agents actually read. In normal operation **nobody reads
`journal/` except ingest**.

Two things follow from that, and they are the opposite of what the folder looks like:

- **Write long.** Entries are never pushed into an agent's prompt, so the page budget does
  not apply here. Under-recording is the failure mode: detail you leave out because it felt
  obvious is exactly what cannot be reconstructed six months later.
- **An un-ingested entry is knowledge that landed nowhere.** It is not "filed" — it is
  sitting in an inbox. That is why `/wiki-lint` reports pending entries and why the Wiki
  impact checklist at the bottom is mandatory.

## The threshold: not derivable from the diff

The folder takes material **the diff does not contain**. That is the whole test, and it is
strict.

The canonical case is a production incident: we spent a day on strange behaviour, worked out
how an external system actually behaves under that condition, and now know both that it
happened and how the system has to be handled because of it. None of that is in the code, and
none of it ever will be.

Qualifying entries:

- **prod-investigation** — an incident or postmortem: symptom, root cause, what the external
  system really does, what we must do differently. The main reason this folder exists.
- **finding** — something durable learned during a feature that the code cannot show: an
  approach that was tried and rejected and why, a non-obvious invariant, a constraint imposed
  by a vendor. Reviewers surface most of these during the feature; the entry arrives with the
  merge.

**A summary of what a feature did is not an entry.** The diff is already in git, and what
shipped is already in the root `change-log.md`. Without this threshold the folder becomes a
second change-log within six months.

## Who writes an entry

**Whoever was there.** Usually that is an agent — writing up a pair-programming session, or an
incident it worked through with a human over hours or days. The `/wiki-journal` skill exists
for exactly that, and writing the entry a day or two after the fact is normal (set
`journaled:` to the authoring date and keep `date:` on the event).

The line is participation, not authorship. **The unattended merge pipeline does not write
here.** `/wiki-ingest` reads this folder and never adds to it, because it was not present for
the thing being recorded — it has a diff, and a diff is precisely what these entries exist to
supplement. An entry written by something that only read the diff would contain only what the
diff already says.

### Under an orchestrator, findings are routed rather than filed

Implementers and reviewers surface most of what ends up here, and they were there — but they
**recommend rather than write**. Each sees its own slice of the feature, and deciding what a
finding *is* needs the whole picture:

- durable knowledge the code cannot show → the orchestrator files it here as an entry;
- work somebody should do → `specs/drafts/`, one file per finding, where a human prioritises it;
- a rule the code is about to violate → also `specs/drafts/`, as a candidate for `target/`
  (see [`../CONTRIBUTING.md`](../CONTRIBUTING.md) §1).

The orchestrator writes the entry because it ran the feature and can see across the reviewers;
that satisfies "whoever was there" without letting three sub-agents file three overlapping
entries about the same afternoon.

## A recurring problem accumulates a thread

Related entries are not merged or superseded — a recurrence gets its own dated entry that
cites its predecessors and says what is *new* about this occurrence. A typical thread: a disk
that keeps filling, four entries across two months, each a different failure mode of the same
symptom — retention logic, then a vacuum variant, then a corrupted script header that silently
made the cleanup cron a no-op for weeks.

That thread is the highest-value structure in the folder, and no other artifact can hold it.
An entry like the third one may carry `modules: []` — it touches no application code at all, and
its `commits:` is a hotfix script. Ingest reading that diff would learn nothing; the entry is
where the knowledge actually lives.

## What does NOT go here

- **Plans, specs, drafts** → `specs/`. A spec is an intention; it is often dropped or built
  differently. **`specs/` is explicitly not a wiki source.**
- **Distilled current-state knowledge** → `../modules/`, `../guides/`. The journal is the
  chronological log; those are the compiled encyclopedia.
- **Release notes** → the root `change-log.md`. A change-log entry says what shipped in three
  lines and links back here; the detail lives in this folder.
- **Source code** → git. The realized diff is the *other* source. Do not paste code here.

## Rules

1. **Append-only.** An entry is not edited after the fact (typos aside). New facts = a new
   entry that references the old one by filename. The one machine edit allowed is ingest
   ticking a Wiki impact item and recording `consumed:`.
2. **One event = one file**, named `YYYY-MM-DD-<slug>.md`. The date is when the event
   happened (`git show -s --format=%cs <sha>`), not when it was written; use `journaled:` in
   the frontmatter for retroactive entries.
3. **Always link the realized change** — commit SHA(s) or PR number. The journal is the index
   *into* the diff.
4. **Always end with "Wiki impact"** — the `modules/*` / `guides/*` pages this entry should
   create or update, as unchecked `- [ ]` items. An entry with no items gives `/wiki-ingest`
   nothing to do and will not be picked up as pending work.
5. **Frontmatter is the writer's, not ingest's.** An entry that arrives without some field is
   left without it, and flagged; an ingest inferring `type` or `outcome` would be manufacturing
   provenance.
6. **English** when machine-written. Human entries may be in any language.

See [`TEMPLATE.md`](./TEMPLATE.md).

## How this feeds the wiki

```
merge to {{MAIN_BRANCH}} ──▶ the diff, the code, its comments ──┐
                                                                ├──▶ INGEST ──▶ modules/, guides/,
an incident / a finding ──▶ wiki/journal/<file> ────────────────┤              index.md, log.md,
                                                                │              target/ divergence
specs/ (intentions) ─── excluded ───────────────────────────────┘
```

A journal entry pushed on its own is an event in its own right: the automation must ingest it
rather than mistake it for the wiki's own write-back.
