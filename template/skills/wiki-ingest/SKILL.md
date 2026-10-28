---
name: wiki-ingest
disable-model-invocation: false
description: >
  Compile a merged change into the wiki/ knowledge tree. Takes a push range, merged PRs or a bare
  commit, reads the realized diff and the current code, and makes surgical edits to modules/,
  guides/, architecture/, index.md and log.md. Where a merge trigger is configured it dispatches
  this skill to a separate session, so an agent that has just merged its own work confirms the run
  instead — by finding the wiki/log.md entry whose Range covers the merge commit. Use when: a merge
  trigger invoked you, "ingest PR N", "update the wiki for <feature>", or to clear a
  PENDING-INGEST, DRIFT, UNINGESTED or PAST-HORIZON finding from /wiki-lint.
---

# Wiki Ingest Skill

You compile a real, **merged** engineering change into `wiki/`. Your output is current-state
encyclopedia pages — how the system works *now*, distilled. Not a changelog (that is
`change-log.md`), not what a spec planned, not a summary of the diff.

## Settings

Read `wiki/dev-wiki.yml` first. This skill is copied byte-identical into several agent
directories, so every project-specific value comes from that file:

- the main branch (`project.main-branch`) — `<main-branch>` below;
- the code-query tool (`project.code-query-tool`) — `<code-query-tool>` below;
- every directory listed in `skill-dirs`, and every file listed in `context-files`.

If `project.main-branch` is `~`, stop and tell the user to run `/wiki-bootstrap`; do not guess a
branch name. If `project.code-query-tool` is `~`, there is no code query tool: orient with
Read/Grep and mark the run `degraded` (Step 1).

## Contract

Read `wiki/CONTRIBUTING.md` next: it is the contract you are writing under, and several rules
below are only summarised here. `wiki/README.md` is the reader-facing half; `wiki/index.md` is
the catalogue you must keep correct.

## Step 0: Resolve the range

You are given some combination of:

| Argument | Meaning |
|---|---|
| `--pr N` (repeatable) | merged PRs in this push |
| `--commit SHA` | a commit that reached `<main-branch>` with no PR |
| `--range base..after` | the push range, when the caller knows it |
| *(empty)* | resolve it yourself, below |

**The unit of work is the push, not the PR.** A push can carry several PRs, a PR plus a direct
commit, or commits with no PR at all — and the last case is exactly the one a PR-keyed pipeline
drops silently.

With no arguments, derive the range from the tree's own registry: the newest `Range:` line in
`wiki/log.md` gives the last covered SHA, and `HEAD` is the other end. With no `Range:` line yet,
the `Baseline:` line of the bootstrap entry is the lower bound. With neither, ask for a range
rather than ingesting the whole history — except in autonomous mode (§ *Autonomous runs*), where
you take the last 20 first-parent commits and say so in the report.

```bash
grep -m1 -E '^(Range|Baseline):' wiki/log.md     # newest first, so the first hit is the latest
```

Record the resolved range now. You will need it in `log.md` whatever happens.

## Step 1: Read the realized change

**Sources, in descending authority. There are six, and the sixth is not a source.**

**1. The realized diff and the current code.** Authoritative for how it works now.

```bash
gh pr diff <N>                       # a merged PR — preferred (or your host's equivalent)
git diff <merge>^1 <merge>           # the same thing from git alone, for a --no-ff merge
git show <sha>                       # a commit that arrived without a PR
git diff <base>..<after>             # the whole push
```

Then read the **current** version of the files that matter. The diff tells you what moved; the
page describes the present state, and those are different questions. A merge commit's own
`git show` is empty on fast-forward and a combined diff on `--no-ff` — never read it as the
change; diff against its first parent instead.

**2. Comments in the code.** Their value is that they explain **why** the code is shaped this
way, and lifting a durable *why* from a line to a page is a large part of this job. For
*behaviour* they are not authoritative: comments rot, and a commit whose whole purpose is to
reconcile stale comments with the code they sit on is a common sight in any history. Where a
comment and the code disagree, the code wins and the disagreement goes in the report.

The harder judgement here is not comment-versus-code but **which generation of the comment**.
Docblocks sometimes carry their own retractions — a later paragraph saying an earlier claim in
the same block was false. Take the surviving text, and treat the retraction itself as knowledge:
*what people believed and why it was wrong* is exactly the kind of thing no query returns, and it
is usually the most valuable paragraph on the page you are about to write.

**3. The change-log entry for this range**, if there is one (`change-log.md` at the repository
root). It is not a source about the code — the code is — but it is where a human wrote down the
*consequence* of a change, and it routinely carries the one finding the diff cannot show: what
broke, what it cost, and which investigation produced it. Skipping it is how a run misses the
best item in its own range.

**4. Journal entries that arrived with this push.**

```bash
git diff --name-only <base>..<after> -- wiki/journal/
```

These carry what the diff cannot: what was tried, what failed, the incident behind a guard. An
entry may be new or an older one somebody extended — both count.

**5. PR bodies and review comments** (`gh pr view <N> --comments`, or your host's equivalent).
This is where reviewers' findings settle. Attribute them as *a reviewer said*, not as *the code
does* — they are claims about the code, and you have the code. A bare commit has no such layer;
the commit message is what is left, which makes for a thinner run but not a skipped one.

**6. `specs/` is not a source.** Only ever to record that reality diverged from the intention.
Never copy a claim out of a spec: specs describe things that were not built, or built otherwise.

Use `<code-query-tool>` to orient — what the change touches, what depends on it — before
grepping. **Never build or rebuild an index yourself**: it is slow, it writes outside `wiki/`, and
a shared index other sessions read is not yours to replace. If the tool is unavailable, continue
with Read/Grep and mark the run `degraded` in the report; it often is unavailable in a sub-agent.
Do not treat that as crippling — in-source docblocks are frequently richer than a call graph, and
orientation from them is not a degraded substitute so much as a different one.

## Step 2: Decide which pages the change touches

Map the changed paths onto pages through each page's `covers:` frontmatter — that is the only
copy of the domain map, and `wiki/modules/CONTRIBUTING.md` explains why.

```bash
grep -rn -A12 '^covers:' wiki/modules wiki/guides wiki/architecture
```

- Domain code → the `modules/` page whose `covers:` contains its directory.
- Everything without a module page by design (client apps, shared libraries, e2e, tooling — as
  `wiki/modules/CONTRIBUTING.md` draws the line) → the `guides/` pages whose `covers:` reaches it.
- A cross-cutting pattern that outlives this feature → a `guides/` page, possibly a new one.
- A changed path no page's `covers:` reaches is a gap — name it in the report; lint reports it
  as UNCOVERED.

**Do not re-cut the domain map.** Re-cutting means changing *which domain a directory belongs
to*: moving a directory between pages, or inventing a domain. If the code has stopped fitting the
current split, say so in the report and let a human decide. A split a human chose beats a better
one you did.

**Splitting one domain across two pages is a different act, and it is allowed.** When a domain
grows past what one page can hold, split it by topic, keep the same `covers:` on both halves, and
name the split in the report. That is not a re-cut — the map still says the same directory
belongs to the same domain — it is the budget rule (Step 3) doing its job, and it is the only
alternative to a page that is over budget or a page that drops what would not fit. Two pages
sharing a `covers:` entry is legal and expected; the consequence is that a drift finding on that
directory fires on both, which is intended, not a defect.

A change may touch **no** page. That is a normal outcome (a dependency bump, a CI tweak, a
refactor that moved nothing conceptual) and it still gets a `log.md` line.

**The tree maintaining itself is the special case of that, and you must recognise it.** If the
range touches nothing outside `wiki/`, the directories in `skill-dirs` and the files in
`context-files`, no code changed — somebody edited the wiki by hand, or a skill was updated. Log the range, say so, and
stop. Compiling a diff *of the pages you would be editing* produces churn that looks like an
update, and this happens often: a merge trigger's loop guard recognises only the tree's own
`wiki/ingest-*` branches, so every human edit to `guides/` arrives here as an ordinary push.

```bash
git diff --name-only <base>..<after> -- . ':(exclude)wiki' ':(exclude)<skill-dir>' ':(exclude)<context-file>'
```

Repeat the `:(exclude)` pathspec once per entry in `skill-dirs` and in `context-files`.

**`wiki/journal/` is the exception inside the exception.** A journal entry pushed on its own is
raw material arriving, not the tree editing itself — that is a full run, and it is one of the
two ways knowledge reaches this tree at all.

Beware the near-miss: a range that is *mostly* wiki churn but also rewrites paths or comments in
source files is **not** this case, and it is the one most likely to fool you. Read those source
changes. If they are comment-only, say so in the report and change nothing — a page describes
behaviour, and a renamed path in a comment is not behaviour.

## Step 3: Write

**Surgical edits — `Edit`, not `Write`.** Rewriting a page whole loses accumulated knowledge
behind the appearance of an update. Touch only the sections the change actually altered.

For each affected page:

- update `Invariants`, `States and transitions`, `Boundaries`, `Gotchas` as the change requires;
- fold in what the journal entry and the review comments taught, distilled;
- set `last-verified:` to today (`date +%F` — never hardcode), `verified-by: ingest`, and
  **`verified-at:` to the `after` end of your resolved range** — the short SHA on
  `<main-branch>` the page was just checked against. That field is what the drift check
  actually reads: it turns "has this page gone stale" into an exact question (*did any commit
  between it and `HEAD` touch a `covers:` path*) instead of a date comparison that cannot see
  same-day drift. You already know the value — it is the right-hand side of the `Range:` line
  you are about to write into `log.md`;
- add the journal path to `sources:` if one fed the page;
- **only move the date if every claim on the page still holds.** Advancing on a partial check
  manufactures confidence, and the freshness horizon then lies about the whole tree. Checked one
  section of five? Leave the date and file the rest as a finding — or, where the rest *cannot* be
  checked on this host, record that in the page's `partial:` field (`CONTRIBUTING.md` §4).

  This will feel wrong — you will leave freshly verified content sitting under an old date, and a
  reader cannot tell the two apart on the page. Leave it anyway. The date's job is to make the
  drift check fire on a page that still holds unverified claims, and that page does. **Where
  "what became fresh today" is recorded is `log.md`**, which is why the entry names pages and what
  each gained. Do not invent per-section frontmatter to resolve the tension.

- **Check the claims in the section you touch, not only the ones you add.** A page you are
  editing is a page you are vouching for locally. The typical miss is a flatly false neighbouring
  sentence left standing — a guide saying an artifact is generated on one platform when every
  committed copy of it is named for another, which one `ls` would have settled. Cheap to
  check, and a correction is worth more than an addition.

Creating a page is allowed when the change genuinely introduces a domain or a cross-cutting
subject that no page covers. A new page **must** be added to `index.md` in the same run — a page
nothing points at will never reach a prompt, and the tree gains an orphan instead of an answer.
Run every `covers:` path you write once, at the moment you write it
(`git ls-files -- '<path>' | head -1`): a path that matches nothing reads as coverage.

### The four things you may not do

1. **Never write inventory.** No file listings, directory trees, "key files" tables, exported
   symbols, import maps, endpoint catalogues. `<code-query-tool>` answers those from the code as
   it is now; a bootstrap spends most of its effort removing exactly this, and you do not get to
   put it back. A file may be named only to anchor a claim that is not derivable — *the retry
   budget lives in `payments-http.client.ts` and is deliberately below the vendor's 10 rps* —
   never as documentation of where things live.

   The converse matters as much: where the code *claims* something the running system does not
   honour, the real state **is** knowledge. See `wiki/CONTRIBUTING.md` §2 — a migration that
   REVOKEs from PUBLIC while per-role grants survive it is the shape of that case.

2. **Never touch `curated` provenance.** In `target/` you may do exactly one thing: delete a
   *where the code disagrees* paragraph when the diff proves that divergence closed. Not the
   decision, not the reason, and never a new page. Nothing in `not-doing/`, `guides/ai-*.md` or
   `product-overview.md` either.

   **Never edit a rule to match the code.** When a `target/` or `guides/` page and the code
   disagree, the code is in violation — say so in the report and leave the page alone. A page
   describing how the system *is* built is the opposite case: there the code wins and the page
   is what you fix. Getting these two backwards turns this skill into a machine that erases the
   tree's rules as the code drifts away from them.

   A rule you think should exist goes to `specs/drafts/`, one file per finding, where a human
   prioritises it. Two things are worth proposing: a conflict you can see coming, and a good
   pattern applied locally that deserves to be general.

3. **Never edit a `reference/` page.** Those are transcriptions; a stale one is fixed by
   re-fetching the whole file, which is a separate deliberate act.

4. **Never create a journal entry.** You have the diff and nothing else; an entry written from
   the diff would contain only what the diff already says. Stamping one you *consumed* is the
   opposite case and is required — see Step 4.

### Budget

A `modules/` or `guides/` page is ≤ 2–3k tokens (`wc -c / 4`), because a page that cannot be
pasted whole cannot be pushed into a sub-agent's prompt, and a page that cannot be pushed will not
be read. Over budget → split by topic (Step 2 says when that is legal) or cut derivable content,
and **name the split in the report**. Never "kept because it is all useful".

**Measure. Do not estimate.** Running over and reporting it as "trimmed twice" is the failure mode
here: prose compression buys ~5% and the ceiling needs a split.

A page may exceed the budget **only** if it is a lookup table rather than a narrative — something
a reader greps for one row instead of reading — and only if it **says so in its own opening
lines**. That exception is not available to a page that is merely long: the budget exists so a
*narrative* page can be inlined, and trimming a lookup table to fit would delete exactly the rows
nobody happened to need this week. A shipped page that declares its own exception in its opening
lines (the agent constitution does) keeps it; an ingest does not grant one.

The always-read core has its own ceiling, and its own definition of the set, in
`wiki/CONTRIBUTING.md` §3 — read both from there. A new `guides/` page spends against it; a
`modules/` page does not.

Compiled pages are English-only.

## Step 4: Close the loop

**Journal entries you consumed.** Tick their `- [ ]` Wiki-impact items and set `consumed` in the
entry's own frontmatter. The processing status belongs to the item — otherwise `/wiki-lint`
resolving pending work becomes a join against a separate registry.

**`index.md`.** Refresh the line of every page you touched (summary and date), and add a line for
any page you created.

**`wiki/log.md` — one entry, at the top (directly below the `---` separator), on every run,
including the empty ones.** This inverts the usual instinct to stay quiet when there is nothing to
say: silence here is indistinguishable from "ingest never started" or "ingest crashed", and the
intake-completeness check in `/wiki-lint` reads this file as an append-only registry of runs.

```markdown
## [YYYY-MM-DD] ingest | PR #NN, #MM — 2 pages

Range: a1b2c3d..e4f5a6b
Core: +N/-M (net +K) — cut the restated retry incident from `guides/backend-howto.md`,
which `journal/YYYY-MM-DD-retry-storm.md` and `modules/payments.md` both hold in full.
- Updated: `modules/payments.md` (refund states, two gotchas),
  `guides/testing.md` (the limiter is off in the unit lane).
- Created: none.
- `target/<page>.md` divergence → closed (diff proves it); paragraph deleted.
- Consumed: `journal/YYYY-MM-DD-retry-storm.md`.
```

**The `Core:` line is mandatory whenever your edits add net tokens to the always-read core**
(`wiki/CONTRIBUTING.md` §3 defines the set). Measure before and after — `cat` the core set,
`wc -c`, divide by four, the same arithmetic §3 uses — and state what the `-M` was, or why
nothing could be cut. **"Nothing could be" is a legitimate answer; omitting the line is not.**

Two things this rule is not. It is **not a quota**: no ingest is ever blocked for growing the
core, and you must **never drop a real claim to balance the arithmetic** — trading knowledge for
a number is the exact failure mode §3 warns about. And it is **not a licence to skip the cut
that is actually there**: the usual case is a fact you just wrote that some other page already
holds, and finding it is a duplication check you owe anyway (`CONTRIBUTING.md` §5b holds the same
one-reason-one-home rule for rejections). The rule exists because the core grows through many
individually reasonable ingests, none of which trips a budget: the per-page ≤3k brake fires only
after a page is over, and 200 tokens spread across eight pages trips nothing at all.

The **`Range:` line is mandatory and machine-read**. Completeness is measured by whether the
union of ranges covers every first-parent commit on `<main-branch>`; PR numbers cannot measure
it, because commits arrive without PRs. An empty run says so and still carries its range:

```markdown
## [YYYY-MM-DD] ingest | PR #NN — no knowledge found

Range: e4f5a6b..f0e1d2c
- Dependency bumps and a CI matrix change; nothing a page makes claims about.
```

## Step 5: Report

State, in this order: the range and what was in it; which pages changed and what each gained;
anything you created and where you catalogued it; **conflicts** (comment vs code, reviewer vs
code, journal vs code — and which one you followed); domain-map strain; splits you made;
claims you could not confirm; and what needs a human.

An unconfirmable claim is dropped, or kept marked `(unverified)` and named in the report. It is
never quietly asserted.

## Autonomous runs

**This whole section applies only when a merge trigger invoked you** — a CI job or a webhook
handler that starts a session on every push to `<main-branch>`, if the project has one. A human
who called you directly sets the terms — if they said not to commit, do not commit, and say in
your report that you skipped write-back because you were told to. Nothing below overrides a
caller.

On the merge trigger, **ask nothing** — not because a question disappears (it may well reach a
human as a notification) but because **the PR body is a better channel for the same
information.** It is asynchronous, it collects every doubt of the run in one place, it reaches the
human at the moment they are already looking at the result, and it does not hold a worktree open
in the meantime. A question mid-run hands them one doubt out of context and demands a context
switch now.

So everything that needs a human goes into a `Requires confirmation` section of the PR body.
Where the session outlives the run, a reply in the PR comes back to you and you amend the same
PR. Stopping to ask is right in exactly one case: when proceeding without the answer would
produce something whose wrongness the review cannot see.

A split of one domain into two pages goes in that section every time. It is legal (Step 2) and
you should make the call rather than dropping content, but it is the most consequential judgement
in a run and the human deserves to see it stated rather than buried in a diff.

Write-back is yours, not the trigger's:

- staged content is `wiki/` and nothing else. A stray edit outside the tree may die with a
  throwaway worktree, but do not rely on that — it is a net, not a rule;
- the diff touches anything besides `log.md` → commit to `wiki/ingest-<short-sha>`, push, open
  the PR, and put the report in its body;
- the diff is **only** `log.md` → push straight to `<main-branch>`, no PR. There is nothing to
  review in "a run happened and found nothing", and a one-line PR on every dependency bump is a
  PR people stop opening within a week.

The `wiki/ingest-` branch prefix is what the trigger's loop guard must recognise as the tree's own
work, so that merging an ingest PR does not start an ingest of the ingest. Under merge commits it
is the **only** signal that works: branch commit bodies never reach the first-parent commit a
guard reads, so a trailer in them is invisible to it. Still end every commit message with
`Wiki-Ingest: true` on its own final line: it costs one line and becomes the guard's cheap path
under squash merges — but it is redundancy, not the mechanism. Change the prefix and every merge
of your own PR costs a wasted run.

Three things you never do on this trigger. **Nothing may stop you** — an unattended session often
runs without the tool-call policy an interactive one has, so these are not backed up by a refusal
the way you may be used to. They hold because you follow them:

- **never merge anything** — the human's merge is the confirmation, and an agent that merges its
  own compilation has removed the only review this tree gets;
- **never force-push**, and never push to the base branch except the `log.md`-only case above;
- **never run git against the repository your worktree was made from.** If that clone is the
  checkout `<code-query-tool>` indexes or other sessions work in, a `reset`, `checkout` or
  `worktree` command aimed at it corrupts what everything else reads from, and you will not be
  the one who notices.

## Rules

1. **Surgical over wholesale.** The tree's value is stability and accuracy, not churn.
2. **Present tense, current state.** History is `journal/`; released changes are `change-log.md`.
3. **The code wins** on a page that describes it — against a comment, a reviewer, a journal
   claim, a spec — every time, and the disagreement is reported rather than smoothed over. On a
   page that states a rule, the code is in violation instead (Step 3, item 2).
4. **Don't fabricate.** No claim you cannot trace to code you read, or to a source you name.
5. **Always `last-verified` + `verified-by:` + a `log.md` line.** A page with no marker is
   invisible to drift detection, which is worse than being stale: it looks maintained.
6. **Stay in scope.** Only the pages this change affects. Opportunistic rewrites of unrelated
   pages are a different job and they hide inside this one's diff.
