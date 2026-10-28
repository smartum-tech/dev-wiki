---
name: wiki-lint
context: fork
disable-model-invocation: false
description: >
  Health-check the wiki/ knowledge tree against the code, the journal and its own contract —
  drift, dead covers: paths, uncovered modules, budget overruns, content a code query already
  answers, provenance violations, orphans, stale references, not-doing/ entries describing
  something that now exists, commits no ingest covered, and journal entries with pending
  Wiki-impact work; also the installation itself — skill copies that disagree, context files that
  lost the wiki block, settings left unset. Read-only but for one wiki/log.md line, and not even
  that when another skill dispatched you. Use when: "lint the wiki", "is the wiki stale", after an
  ingest, before trusting the tree for a task.
---

# Wiki Lint Skill

You verify that `wiki/` still reflects reality and still obeys its own contract
(`wiki/CONTRIBUTING.md`; `wiki/README.md` is the reader-facing page). The sources of truth are
**the realized code in git** and **`wiki/journal/`** — never `specs/`. You **report**; you do not
fix pages (that is `/wiki-ingest`). The only file you may ever write is `wiki/log.md`, and even
that one is conditional — see rule 1.

## Settings

Read `wiki/dev-wiki.yml` first. This skill is copied byte-identical into several agent
directories, so every project-specific value comes from that file:

- the main branch (`project.main-branch`) — `<main-branch>` below;
- the domain directories (`project.domain-dirs`) — `<domain-dirs>` below;
- every directory listed in `skill-dirs` (each holds a copy of the wiki skills) and every file
  listed in `context-files` (each carries the wiki's context block) — checks 10 and 11.

If `project.main-branch` is `~`, stop and tell the user to run `/wiki-bootstrap`; do not guess a
branch name. Check 12 reports the other unset keys.

## Contract

Read `wiki/CONTRIBUTING.md`, `wiki/index.md` and `wiki/modules/CONTRIBUTING.md` first — the
contract defines several of the checks below.

Done when every check below has either a finding list or an explicit "none", and every count in
the summary table was derived by a command you ran in this pass.

## Checks

### 1. Drift — the headline

For each page under `modules/`, `guides/` and `architecture/` with a `covers:` list:

```bash
git log --oneline <verified-at>..HEAD -- <the page's covers paths>
```

Any output → **DRIFT**, and the output *is* the finding: those are the commits somebody has to
read. Empty → the page cannot have drifted, whatever its date says.

**Prefer `verified-at` over `last-verified`, always.** A date comparison
(`--since=<last-verified>`) cannot distinguish "verified after that commit landed" from
"verified the same day, before it", so same-day drift is invisible to it. Fall back to the date
only when the page has no `verified-at` yet.

**A `verified-at` that no longer resolves is a finding, not a crash.** A squashed or rebased
commit makes `git log <sha>..HEAD` exit non-zero with `unknown revision`. Treat that as
**DRIFT** — the page was checked against a history that no longer exists — and say so. Do not
let it abort the run.

A page with no marker of either kind → **NO-MARKER**: it cannot be drift-checked at all, which
is worse than being stale, because it looks maintained. `last-verified: never` is a marker — the
honest one for a page nobody has checked — and is not NO-MARKER: such a page is past the horizon
by definition and heads the PAST-HORIZON list (check 1b). On a freshly adopted tree that list is
long and that is expected; it is the queue `/wiki-audit verify-only` works through.

**A `partial:` field means the marker covers only part of the page** (`wiki/CONTRIBUTING.md`
§4). Report those pages as **PARTIAL**, quoting the field's first sentence, and never read such
a page's clean drift result as "verified" — the named measurement has not been taken. A carrier
is not a defect; the finding exists so the count cannot quietly grow, and so a run on a host that
*can* take one of those measurements knows which. **Derive the count, never quote one** —
`grep -rl '^partial:' wiki/ | wc -l` — because a written count goes wrong within days of being
written. Partial-ness stated only in a `#` comment beside `last-verified:` is itself a finding:
a machine does not read comments.

A stale page outranks a missing one in severity. A missing page makes an agent ask; a stale
page makes it confidently wrong.

### 1b. Freshness horizon

Drift (check 1) only fires when the code under `covers:` changed. It structurally cannot see
three things: claims that were wrong from the start (bootstrap inheritance, especially the
ones marked `(unverified)`), pages about subjects no `covers:` path captures (process,
infrastructure, an external system's behaviour), and changes under paths the page forgot to
list.

So also flag pages the repository has moved a long way past → **PAST-HORIZON**, oldest first,
with every `last-verified: never` page ahead of the dated ones.

**Measure that distance in commits, not days:**

```bash
git rev-list --first-parent --count <verified-at>..<main-branch>
```

More than **40** → past the horizon. Days are the wrong clock: they run while nobody works, so
a quiet month declares the whole tree stale for nothing. Commits only accrue when there is
something to have missed. Tune the number to roughly a month of this project's commit pace; at
any pace it is exactly zero during a pause.

For a page with only `last-verified`, fall back to **30 days**, and keep the old guard with
it: skip the count entirely if nothing outside `wiki/` has changed since the oldest date
(`git log -1 --since=<date> --format=%h -- . ':(exclude)wiki'` prints nothing).

Report the list. Re-checking a page's claims against code is a separate job — it is expensive,
and doing it here would turn a linter you can run any time into one you think twice about.

Curated pages (`target/`) use `last-reviewed` and appear in this list too, but flagged
separately — only a human can clear them.

### 1c. Reference staleness — measured against the source, not the code

`reference/` pages are transcribed from published documentation, so they go stale when the
**vendor** changes, which no amount of reading our own repository will reveal. Check them on
their own axis — the frontmatter of a markdown artifact, or the artifact's row in
`reference/README.md` for one that cannot carry frontmatter:

- `fetched:` older than **180 calendar days** (calendar, not active — a vendor ships on their
  schedule, not ours) → **REFERENCE-STALE**.
- `fetched:` missing, or `stale:` present → **REFERENCE-STALE** regardless of age.
- `source-url:` missing where `origin` describes a published web source → **NO-SOURCE**: it
  cannot be re-fetched or checked by anyone.
- An artifact whose `origin` marks it as a fixed edition (a national standard, a legal instrument
  we issued) is exempt — it does not drift.

Do **not** fetch the URL yourself. Report the list; re-fetching and diffing against the source
is a separate, deliberate act, because it rewrites a file whose value is being verbatim.

### 1d. Intake completeness — did every change reach this tree at all?

Checks 1–1c compare pages against code. None of them can see a change that **never arrived**: a
merge the ingest pipeline missed produces no drift, because no page claims anything about it. This
is the only check that catches silent loss — a crashed run, a trigger that was down, a push
nobody remembered to ingest. Webhooks are not redelivered.

Every first-parent commit on `<main-branch>` after the bootstrap baseline must be covered by the
`Range:` line of some `ingest` or `audit` entry in `wiki/log.md`:

```bash
base=$(grep -m1 '^Baseline:' wiki/log.md | cut -d' ' -f2)
comm -23 \
  <(git rev-list --first-parent "$base"..origin/<main-branch> | sort) \
  <(grep -E '^Range: [0-9a-f]+\.\.[0-9a-f]+' wiki/log.md | cut -d' ' -f2 |
      while read -r r; do git rev-list --first-parent "$r"; done | sort -u)
```

What remains → **UNINGESTED**, newest first (`git log -1 --format='%h %cs %s' <sha>` for each). A
`Range:` whose endpoints no longer resolve makes `git rev-list` fail for that line: report it,
like an unresolvable `verified-at`, rather than letting it silently cover nothing.

Four things make this implementable rather than approximate:

- **the unit is a first-parent commit, not a PR.** Commits reach `<main-branch>` without a PR,
  so PR numbers cannot measure coverage at all;
- **filter by entry type.** Only `ingest` entries — and `audit` entries carrying a `Range:` line —
  count as coverage; lint and journal never write one, so a `Range:` line is the filter. An audit
  earns its range by verifying every content page and dispositioning every uncovered commit
  (the `wiki-audit` skill's `SKILL.md`, in any directory listed in `skill-dirs`); its partial runs log without one. The shipped example
  block at the top of `log.md` carries `Range:` lines of its own — if it is still there,
  `/wiki-bootstrap` never ran its Phase F, and that is the finding;
- **the lower bound is the bootstrap's `Baseline:`**, or the report is the entire history of the
  repository. No `Baseline:` line → say so and use the oldest `Range:` base instead;
- **exempt the tree's own commits, by the same predicate the merge trigger's loop guard uses**:
  by default, a merge of a `wiki/ingest-*` branch, and a push touching nothing but
  `wiki/log.md` (`git diff --name-only <sha>^1 <sha>` prints only that path). Those never trigger
  a run, so they are not holes. **If this predicate and the guard's drift apart, this check starts
  either lying or reporting every wiki merge as a gap** — they are one rule with two readers. A
  human editing `wiki/journal/` by hand is *not* exempt: that arrives on a different branch, it is
  raw material, and it must be covered.

**Not blocking.** It is a re-ingest queue: `gh pr diff` and `git show` work just as well a week
later, so a gap is fixed by an ordinary ingest pass, exactly like a pending journal entry. And it
is an audit of the remainder — crashes, trigger downtime, handler bugs — not the delivery
mechanism. Relying on it as the way knowledge arrives means knowledge arrives only when somebody
remembers to lint.

### 2. `covers:` paths that no longer exist

`covers:` is load-bearing twice over: it drives the drift check above, and it is how an
orchestrator finds the pages a task needs. Expand every `covers:` entry against the repository:

```bash
git ls-files -- '<covers path>' | head -1     # empty = the path is gone
```

Zero matches → **DEAD-COVERS**, blocking. The page has quietly stopped being drift-checked and
stopped being findable, while still looking maintained — a directory got renamed, a module was
split, and the frontmatter kept pointing at the old name.

**An explicitly empty `covers: []` is not a finding.** A page that states rules rather than
describing code has no path that could falsify it (`wiki/CONTRIBUTING.md` §4). A *missing*
`covers:` key on a page that plainly makes claims about code still is.

### 2b. `covers:` that is too broad to mean anything

A directory-wide entry — `frontend/src`, a whole migrations folder — usually makes the drift
check fire on every commit to that area, whether or not the page could be affected. A signal that
always fires is worth exactly as much as one that never does.

Flag → **BROAD-COVERS**, not blocking: a `covers:` entry that produced drift on more than
**half** the first-parent commits in the window you are measuring
(`git rev-list --first-parent --count <window> -- <entry>` against the same count without the
path). Say which entry, and what the page actually asserts about it. The fix is to name the
specific files, or to drop the entry.

The same habit produces the opposite failure, and it is worse: a path written from habit rather
than checked. `migrations/**` where the migrations are TypeScript under the backend, or
`**/*.test.ts*` where the client tests are `*.spec.tsx`, is syntactically fine, plausible, and
matches zero files. **A path that matches nothing reads as coverage, not as a gap**, which is
what makes it worse than an omission — check 2 catches it, and it should never have been written.
Run any path expression once, at the moment you write it.

### 2c. Domain modules with no page

```bash
ls <domain-dirs>
```

`<domain-dirs>` (`project.domain-dirs` in `wiki/dev-wiki.yml`) is the directory (or directories)
whose immediate children are domain modules.
Any child named by no page's `covers:` → **UNCOVERED**. An agent working there gets the
always-pages and nothing domain-specific. New modules are the usual cause: the code lands and no
page's `covers:` is extended to reach it. A project with no domain-shaped code — `domain-dirs` is
`[]` — skips this check and says so.

### 3. Page budget

Estimate tokens as `wc -c / 4`. Over 3k tokens (12 000 bytes) for a `modules/` or `guides/` page
→ **OVER-BUDGET** (it can no longer be pasted whole into a sub-agent prompt) — unless the page
claims the lookup-table exception in its own opening lines, which you quote:

```bash
find wiki/modules wiki/guides wiki/architecture -name '*.md' -size +12000c
```

Sum the always-read core against the core ceiling in `wiki/CONTRIBUTING.md` §3 and report the
measurement even when it passes. **Read both the set and the number from §3**, never from a copy
— the ceiling and the set change by ruling, and a copy in this file would go stale on each
occasion.

**Also check that ingests are declaring their growth.** Every `ingest` entry in `log.md` whose
run added net tokens to the core owes a `Core: +N/-M (net ±K)` line naming what it cut, or why
nothing could be (`CONTRIBUTING.md` §3). An entry that grew the core with no such line →
**UNDECLARED-GROWTH**, reported under Budget. Judge only the disclosure, not the size: growth is
allowed and "nothing could be cut" is a legitimate answer, so a present line is always compliant.
This check is the whole reason the rule is not decorative — without it, the core grows through
many individually reasonable ingests and no single one trips anything.

`not-doing/` is core and grows one entry at a time, so it is also checked per entry
(`wc -l wiki/not-doing/*.md`): over **40 lines** → **OVER-BUDGET**, and the fix is never "trim the
prose". An entry that big is a `target/` rule or a deferral wearing a rejection's clothes
(`wiki/not-doing/README.md`).

### 4. Content a code query already answers

The contract's core boundary (`wiki/CONTRIBUTING.md` §2): a fact recoverable by querying the code
at read time does not belong here. Flag as **QUERY-DUP**:

- tables or lists of file paths that read as an inventory rather than an anchor for a claim;
- directory trees;
- "key files", "exports", "endpoints" sections that merely restate the code;
- import/dependency lists.

Cite page and line. Be concrete — do not flag a single file path used to anchor a real claim, and
do not flag a record of what the running system does where the code claims otherwise (§2 calls
that knowledge, not inventory).

### 5. Provenance violations

- Anything under `target/` or `not-doing/` changed by **unattended automation** (for `target/`,
  other than deleting a *where the code disagrees* paragraph) → **PROVENANCE**. Check with
  `git log --format='%h %an %s' -- wiki/target wiki/not-doing` and read the diffs. An agent
  writing here at a human's request, recording a decision that human made, is normal and is not
  a finding — the violation is a machine *originating* a curated claim, which usually reads as a
  target inferred from how the code already looks, or a rejection inferred from a feature
  nobody built.
- A change to a `reference/` body that is **not** a wholesale re-fetch → **PROVENANCE**. These
  files are replaced from the source, never edited in place: a diff touching a few sentences
  means someone translated, summarised, reconciled with our code, or fixed a typo, and the
  page no longer reproduces what the source says. A re-fetch bumps `fetched:` and rewrites the
  body; that is legitimate. Check that the two go together.
- A page whose folder and `class:` frontmatter disagree → **CLASS-MISMATCH**.

### 6. Stale target pages

For each page in `target/`:

- No stated reason for the decision → **NO-RATIONALE**, blocking: a rule without a reason can
  be lawyered around, and a compliance review cannot check intent.
- A page carrying a check expression → run it, and report whether what the page says about the
  code still holds. A check that matches nothing is itself the finding: it makes an
  unfalsifiable claim look verified.
- A stated divergence untouched for more than 90 days
  (`git log -1 --format=%cs -- wiki/target/<page>`) → **STALE-TARGET**. Not blocking, and not
  automatically wrong — some debt is knowingly parked — but a divergence nobody has revisited
  in a quarter is either fixed and unrecorded, or no longer believed.

**Never propose editing a `target/` page to match the code.** If the code diverges, that is the
finding; the page is the position we hold against it.

### 6b. `not-doing/` entries — refuted, not drifted

An entry records a decision *not* to build something (`wiki/CONTRIBUTING.md` §5b). It makes no
claim about a state, so it carries `last-reviewed` and no `covers:`, and it is **exempt from the
drift check and from the freshness horizon** — a rejection does not go stale because the
repository moved.

One check applies, and it is the one that keeps the directory trustworthy:

- **An entry describing something that now exists in the code → `FALSE-REJECTION`, blocking.**
  Each entry states its decision in the first paragraph and cites `file:line` evidence under
  `## Prior requests`; verify the negative still holds (the field is still absent, the client
  still has no retry, no scheduled job is registered). A hit means either the decision was
  reversed and nobody deleted the entry, or something shipped against a standing decision. Both
  need a human: this is the poisoned-dedup case, where the next design session is told we
  refused a thing we shipped.

Also flag **DUPLICATED-REASON**: a `modules/`, `guides/` or `architecture/` page restating the
reason an entry owns, rather than pointing at it. Cite both locations.

### 7. Dead references

```bash
roots=$(git ls-tree -d --name-only HEAD | paste -sd'|' -)
grep -rhoE "($roots)/[A-Za-z0-9_./-]+\.[A-Za-z0-9]+" wiki/ \
  --exclude-dir=journal --exclude-dir=reference | sort -u
```

`test -e` each; missing → **DEAD-REF**. Skip paths that appear only on a `sources:` line: those
record what a page was compiled *from* and are historical by design (`CONTRIBUTING.md` §7).
`journal/` is an append-only record and `reference/` a transcription; neither is corrected, so
neither is checked. Also check that intra-wiki links (`[[name]]` and relative markdown links)
resolve.

### 8. Orphans and pending journal work

- Any `.md` under `wiki/` listed in **neither** `index.md` **nor the catalogue its own folder
  owns** (`modules/index.md`, `reference/README.md`) → **ORPHAN**. Excluding any `index.md`,
  `log.md`, `README.md`, `CONTRIBUTING.md` and `TEMPLATE.md` file. A folder catalogue must itself
  be linked from `index.md`, or the folder it serves is orphaned wholesale — check that link too.
- `grep -l '\[ \]' wiki/journal/*.md` (excluding `TEMPLATE.md`) → entries with unchecked
  Wiki-impact items → **PENDING-INGEST**.

### 9. Contradictions (best-effort)

Skim pages with overlapping subjects for conflicting claims — two pages stating different
defaults, a guide contradicting a `target/` page. Flag **CONTRADICTION** with both locations.
Only concrete, citable conflicts; do not editorialise.

### 10. Skill copies

The wiki skills are installed once per agent family, into every directory in `skill-dirs`, and
must be byte-identical everywhere. A copy that drifted means two agents in the same repository
follow different procedures — one lints with a check the other does not know exists.

For every `wiki-*` folder in any `skill-dirs` entry, compare each copy against the first:

```bash
diff -r <skill-dir-A>/wiki-lint <skill-dir-B>/wiki-lint     # silent = identical; or cmp, file by file
```

A differing file, or a folder present in one directory and absent in another → **COPY-DRIFT**,
blocking. Name the folder, the file and the copy that differs, and say which copy is newer
(`git log -1 --format='%h %cs' -- <skill-dir>/<folder>`; for untracked copies say the age is
unknown). The fix is to copy the newer copy over the others, **only on the human's say-so** — lint
reports, it does not overwrite skills, and the newer copy is not always the right one (a hand edit
in one copy is a change somebody may want to keep). One entry in `skill-dirs` → nothing to
compare; say so.

### 11. Context block

Every file in `context-files` carries the block that tells that harness's agent the wiki exists:

```bash
grep -c -e '<!-- dev-wiki:start -->' -e '<!-- dev-wiki:end -->' <context-file>     # expect 2
```

A file missing, or lacking either marker, or with the end marker before the start →
**NO-CONTEXT-BLOCK**, blocking. Without the block the agent in that harness never learns the wiki
exists, so every page, rule and skill below it goes unread while the tree looks maintained. The fix
is re-inserting the block from the installer's template (or `/wiki-bootstrap`), not writing one by
hand.

### 12. Settings

`wiki/dev-wiki.yml` is what the skills read in place of per-project edits. Unset means they have
nothing to read:

- `project.name`, `project.main-branch` or `project.code-query-tool` still `~` →
  **SETTINGS-UNSET**, blocking. `/wiki-bootstrap` is the fix; a guess made here would be written
  into every later run.
- Placeholders no bootstrap pass filled in the pages:

```bash
grep -rnE '\{\{[A-Z_]+\}\}' wiki/ --exclude=TEMPLATE.md
```

  Drop hits that sit inside an HTML comment (`<!-- … -->`) — those document a placeholder, they
  do not use one. Any hit left → **UNFILLED-PLACEHOLDER**, not blocking: a page that shows a
  raw placeholder where a branch or directory belongs gives a wrong command to whoever pastes it.
  Cite page and line.

## Report format

```markdown
## Wiki Lint Report — <date>

### Blocking
- DEAD-COVERS: `modules/billing.md` covers `backend/src/modules/invoices`, which no longer exists.
- NO-RATIONALE: `target/cache-layer.md` states a decision with no reason.
- COPY-DRIFT: `wiki-lint/SKILL.md` differs between `<skill-dir-A>` and `<skill-dir-B>`;
  the `<skill-dir-B>` copy is newer (`a1b2c3d`, YYYY-MM-DD).
- NO-CONTEXT-BLOCK: `AGENTS.md` has no `<!-- dev-wiki:start -->` block.
- SETTINGS-UNSET: `project.code-query-tool` is `~` in `wiki/dev-wiki.yml`.

### Drift
- `modules/billing.md` — verified at `a1b2c3d`; 4 commits have touched
  `backend/src/modules/billing` since: <shas>. Re-ingest.
- `guides/testing.md` — `verified-at: 9f3c1de` no longer resolves (history rewritten).
  Re-verify.

### Uningested
- `b2c3d4e` (YYYY-MM-DD, PR #NN) — no `Range:` in `log.md` covers it. Re-ingest.

### Budget
- Core total: NNk / <§3 ceiling>. Over-budget pages: `guides/frontend-howto.md` 4.1k.
- UNDECLARED-GROWTH: `[YYYY-MM-DD] ingest | PR #NN` grew the core, no `Core:` line.

### Query-redundant
- `modules/billing.md:40-58` — a "key files" table; a code query answers this.

### Provenance / Dead refs / Orphans / Pending / Contradictions / Stale targets / Past horizon

### Installation (skill copies / context block / settings)
- UNFILLED-PLACEHOLDER: `guides/testing.md:12` still shows a raw placeholder for the package manager.

### Summary
| Check | Count |
|---|---|
| Blocking | N |
| Drift | N |
| Uningested commits | N |
| Over-budget | N |
| Query-dup | N |
| Provenance | N |
| Dead refs | N |
| Orphans | N |
| Pending ingest | N |
| Unverified/stale targets | N |
| False rejections (`not-doing/`) | N |
| Past horizon (>40 commits, or `never`) | N |
| Partial markers | N |
| Reference stale (>180 days) | N |
| Drifted skill copies | N |
| Context files missing the block | N |
| Unset settings / unfilled placeholders | N |

**Next action:** …
```

## Rules

1. **Read-only on wiki pages.** The only write is one line at the **top** of `wiki/log.md`
   (directly below the `---` separator, newest-first): `## [<date>] lint | <N drift, N blocking,
   …>`. Get the date with `date +%F`; never hardcode it. Never a `Range:` line — lint covers
   nothing.

   **Write that line only when a human invoked you directly.** If you were dispatched by another
   skill — `/wiki-audit` runs you as its step 1, `/wiki-bootstrap` as its Phase G — **write
   nothing at all** and return the report to your caller, who owns the log entry for the
   combined pass. The same applies whenever the invocation says report-only, dry-run, or "do not
   write".

   This is not housekeeping. A dispatched run and its caller both append to the *same*
   top-of-file region, so the second writer lands inside the first one's entry — duplicating the
   pass, or corrupting the heading of the entry above. You cannot detect the collision from
   inside — the file you read may already be stale — so the rule is positional, not conditional
   on what you find there.
2. **`specs/` is never a source.** Do not flag a page for disagreeing with a spec.
3. **Cite everything** — file, line, and the commit that proves the drift. A finding the
   human has to re-investigate is not a finding.
4. **Drift and dead `covers:` paths lead the report.** Both fail silently in production use.
5. **You check freshness, budget and contract compliance — not code quality.** Opinions about
   the code belong to code review.
