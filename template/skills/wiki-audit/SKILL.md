---
name: wiki-audit
context: fork
disable-model-invocation: false
description: >
  Full-tree audit of wiki/ — the one job that reads the whole readable tree in a single context,
  so it can see what page-at-a-time maintenance cannot: duplicates, misplaced content, pages whose
  value no longer covers their token cost. Writes a per-page plan for the human, then executes the
  approved plan page by page, re-verifying every claim against the code and stamping verified-at
  as it goes; a completed pass dispositions every UNINGESTED commit and writes coverage into
  wiki/log.md. Use when: "audit the wiki", "compact the wiki", "re-verify the wiki", clearing
  PAST-HORIZON, NO-MARKER or UNINGESTED findings from /wiki-lint, or the always-read core is
  pressing the ceiling in wiki/CONTRIBUTING.md §3.
---

# Wiki Audit Skill

The tree's deep-maintenance pass. `/wiki-lint` detects and never fixes; `/wiki-ingest` compiles
one change and stays inside its blast radius; this skill is the third leg — it re-verifies the
pages the pipeline has moved past and restructures the tree as a whole. Model-invocable, but
heavyweight: prefer being asked over firing on your own initiative.

## Settings

Read `wiki/dev-wiki.yml` first. This skill is copied byte-identical into several agent
directories, so every project-specific value comes from that file:

- the main branch (`project.main-branch`) — `<main-branch>` below;
- the code-query tool (`project.code-query-tool`) — `<code-query-tool>` below.

If `project.main-branch` is `~`, stop and tell the user to run `/wiki-bootstrap`; do not guess a
branch name. If `project.code-query-tool` is `~`, there is no code query tool: orient with
Read/Grep.

## Contract

Read `wiki/CONTRIBUTING.md` next. Budgets, frontmatter, provenance and who may write what are
defined there, once; this file does not repeat them.

Three modes. `plan` and `apply` are one audit in two sittings, split by a human checkpoint;
`verify-only` is the lightweight standing alternative.

## `plan` — read everything, decide nothing alone

**1. Lint first.** Invoke the `wiki-lint` skill (through your harness's skill mechanism) and keep
its report: DRIFT, PAST-HORIZON, NO-MARKER, OVER-BUDGET, QUERY-DUP and UNINGESTED findings are
plan input; COPY-DRIFT, NO-CONTEXT-BLOCK and SETTINGS-UNSET findings go to the plan's for-the-human
part, because only a human decides which skill copy is right. **Tell it not to
write its own `log.md` line** — you own the log entry for this pass, and a dispatched lint
writing its own lands inside yours (its rule 1 says the same from the other side; state it
anyway, because a fork that missed the instruction corrupts an entry you then have to revert by
hand). If it cannot be invoked from here, run its checks 1, 1b, 1d and 3 yourself exactly as its
SKILL.md defines them — do not improvise variants.

**2. Read the whole readable tree.** `index.md`, `product-overview.md`, all of `guides/`,
`architecture/`, `modules/`, `target/`, `not-doing/` — whole pages, one context. Skip what
`wiki/README.md` §3 skips (`journal/`, `reference/`, `log.md`, the CONTRIBUTING files) and the
body of any page claiming the lookup-table exception — read its opening lines only. Done when
every page in `index.md` is read or named as skipped, and every `.md` the catalogue misses is
listed — those are findings in their own right.

This step needs a context window several times the size of the readable tree. Measure the tree
first (`wc -c` over the set, divided by four); if it will not fit with room to reason, say so and
stop rather than reading part of it — a duplication table built from half the tree reports the
other half's copies as canonical.

**3. Write the plan** to `specs/drafts/wiki-audit-<date>-plan.md` (`date +%F`). Three parts:

- **Per-page verdicts** — one block per content page: `keep` | `trim` | `merge into <page>` |
  `split` | `verify-only`. Every `trim` names the sections to cut and the reason — `duplicate
  of <page §>`, `derivable`, or `below value` — with measured tokens saved (`wc -c / 4`). A
  `keep` is a real verdict, not a default: it means you read the page and can say what it is for.
- **The duplication table** — claim, every page holding it, the one canonical home. This table
  is the reason the whole tree is read in one context; nothing page-at-a-time can produce it.
- **For the human** — curated pages (`target/`, `not-doing/`, `guides/ai-*.md`,
  `product-overview.md`): observations only. This skill never edits curated content in any
  mode (`CONTRIBUTING.md` §1); a restructuring idea for them is a proposal here, nothing more.
  Also here: core and per-page measurements against the §3 budgets, and anything believed
  low-value that you are not confident enough to verdict.

**Then stop.** Write the `log.md` line (below) and report. `apply` never follows `plan` in the
same run: the plan is a value audit the tree cannot run on itself, and the human's edit of it is
the calibration every later run inherits.

## `apply <plan>` — one visit per page, verify before restructure

Runs only against a plan the human has reviewed; their naming it and asking for `apply` is the
approval. Work the plan's page list, worst first. Each page gets one visit doing both jobs, in
this order — verification first, so restructuring never polishes a stale claim:

1. **Verify.** Read the page, the current code under its `covers:`, and
   `git log <verified-at>..HEAD -- <covers paths>`. Confirm every claim, not a sample. A
   descriptive claim the code has outgrown → fix the page. A rule the code violates → the page
   stands and the violation goes in the report (`CONTRIBUTING.md` §7). `(unverified)` claims are
   a point of this pass: confirm and unhedge, or delete. Orient with `<code-query-tool>` where
   it is available; never build an index yourself.
2. **Apply the verdict.** Surgical `Edit`s; a `merge` or `split` is the only wholesale act, and
   each one is named in the report. A cut justified as derivable passes the §2 test first — ask
   what a query would actually return. §2's example, a registry of grants that the migrations
   claim to have revoked, is the standing warning: it looks like a restatement of the code and is
   the only record of what is actually in force.
3. **Stamp.** `verified-at:` (current `<main-branch>` short SHA), `last-verified:`
   (`date +%F`), `verified-by: audit` — only when every claim on the page was confirmed. A
   partial check leaves the old marker and files the remainder as a finding, or in the page's
   `partial:` field where the remainder cannot be checked on this host (§4).
4. **Catalogue.** Refresh the page's `index.md` line; a merge or split updates it in the same
   visit.

Done when every page in the plan is visited and every verdict is either applied or explicitly
deferred with its reason in the report.

## `verify-only` — the standing maintenance pass

No plan, no restructuring: steps 1, 3 and 4 of `apply`, over the pages `/wiki-lint` flags as
DRIFT, PAST-HORIZON (including every `last-verified: never` page) or NO-MARKER. This is the mode
that clears a horizon backlog without waiting for a full audit — and on a freshly adopted tree,
the mode that works through the shipped pages a bootstrap could not stamp.

## Lost commits

Lint's UNINGESTED list is part of every `apply` and `verify-only` run. For each uncovered
first-parent commit: `git show --stat <sha>`. Paths under some page's `covers:` are absorbed by
the page verification above; paths no page covers get a mini-ingest judgement — read the commit
under `/wiki-ingest`'s source-authority order and either land what it teaches or record "no
knowledge". Done when every uncovered commit is dispositioned by SHA in the report.

## `log.md` and coverage

Every run writes one entry at the top of `wiki/log.md` (directly below the `---`, newest-first,
`date +%F`):

```markdown
## [YYYY-MM-DD] audit | plan — 34 pages read, 6 trim, 2 merge; core NNk

## [YYYY-MM-DD] audit | apply — 31 pages verified, 11 trimmed ~9k, 2 merged; core NNk

Range: a1b2c3d..e4f5a6b
```

A **`Range:` line is earned, not routine**: it goes in only when the run verified *every*
`modules/`, `guides/` and `architecture/` page and dispositioned *every* uncovered commit —
that is what lets `/wiki-lint` §1d count an audit as coverage. Its base is the newest `Range:`
(or the `Baseline:`) already in `log.md`; its end is the SHA the pages were stamped at. A partial
run logs without one.

## Write-back

A human invoked you, so their terms win. Defaults: a `plan` run commits nothing — the plan file
stays in the working tree for the human it is addressed to. An `apply` or `verify-only` run
commits to `wiki/ingest-audit-<short-sha>` and opens a PR; the merge is the review. The prefix is
deliberate: it is the one a merge trigger's loop guard recognises as the tree's own work, so the
audit's own merge neither triggers an ingest of its own diff nor opens an UNINGESTED hole.

## Rules

1. **Curated is read, never written.** `target/`, `not-doing/`, `guides/ai-*.md`,
   `product-overview.md`: verdicts about them go to the plan's for-human section only.
2. **Never edit a rule to match drifted code** — in any mode. The violation is the finding.
3. **Every cut names its reason** — duplicate, derivable, or below value — in the plan, before
   any apply. Compaction is the audit's by-product; a run that opens pages just to get under a
   number is the failure mode `CONTRIBUTING.md` §3 warns about.
4. **`reference/` and `journal/` untouched**, in every mode.
5. **Measure, do not estimate** — `wc -c / 4`, before and after.
