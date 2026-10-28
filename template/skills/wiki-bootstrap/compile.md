# Bootstrap stages `plan` and `run`: compiling what exists

This file is part of the `wiki-bootstrap` skill and is read when [`SKILL.md`](./SKILL.md) routes
to stage 1 (`plan`) or stage 2 (`run`). Recon (stage 0) has already run. The settings in
`wiki/dev-wiki.yml` are filled, and so are the placeholders in the wiki pages. Below:

- `<main-branch>` is `project.main-branch`;
- `<code-query-tool>` is `project.code-query-tool`;
- `<source>` is `project.legacy-docs`, the documentation folder to compile. It may be `none`.
  With no source, the plan has only `adopt` rows and the domain map, and Phases B and E are
  skipped;
- `<spec-folder>` is `specs/wiki-bootstrap/`.

You compile the project's existing documentation and its code into the `wiki/` tree defined by
`wiki/README.md` and `wiki/CONTRIBUTING.md`. That contract is **binding and already written**:
you fill it, you do not redesign it. Read `wiki/README.md`, `wiki/CONTRIBUTING.md` and
`wiki/modules/CONTRIBUTING.md` before anything else.

Existing instruction files count as source too. A `CLAUDE.md`, an `AGENTS.md`, `.cursor/rules/`
or `GEMINI.md` that predates the install is a curated house-rules file, so rule 1 below applies
to it. Leave the `<!-- dev-wiki:start -->` block out: it is ours.

**`plan` and `run` are one bootstrap in two sittings.** The plan carries the decisions a machine
must not make alone — the domain map, the destination of every file, what is curated — and the
human's edit of it is the approval. `run` never follows `plan` in the same invocation.

**`run` is designed to proceed without asking.** Nobody may be watching, and nobody will notice a
destructive mistake until the report is read. §1 is therefore not advice.

## The tree is not empty when you start

The boilerplate ships a working tree: `README.md`, `CONTRIBUTING.md`, `index.md`, `log.md`, a
`product-overview.md` scaffold, generic `guides/` pages, and the empty curated folders. Every
shipped content page carries `covers: []`, `last-verified: never` and `verified-by: boilerplate`
— honest markers for text nobody has yet checked against this codebase.

So this run is a **merge, not a copy.** Project knowledge goes *into* the shipped pages where they
already cover the subject, and every shipped page — including those no source file maps to —
leaves this run either verified against the code with its `covers:` filled, or still marked
`never` with the reason in the report. Overwriting a shipped page with a compiled source file
loses the generic rules it carries; leaving it untouched leaves a page that looks adopted and was
never read against the project. §2b defines the merge.

## What you are producing, and what you are not

The tree holds three kinds of page, and knowing which one a sub-agent is writing changes what
it writes:

| Kind | Where | Written as |
|---|---|---|
| **actions** — how to do a thing here | `guides/` | instructions. Imperative, checkable, opinionated |
| **states** — how the system is built | `architecture/`, `modules/` | description. Present tense, current state, at system and domain scale |
| **the contested and refused sets** | `target/`, `not-doing/` | **not by you.** See below |

**You never write `wiki/target/` or `wiki/not-doing/`.** A page lands there only where a human has
decided something the code violates, something agents keep getting wrong by default, or
something we refused to build. All are judgements about intent that a machine reading a
repository cannot make: everything you can see is how the code *is*, and a target inferred from
that is a summary of the present dressed as an intention.

So both folders are normally empty when your run finishes, and **that is the correct outcome** —
not an unfinished phase. What you noticed goes to a candidate list under `specs/drafts/`, where
a human prioritises it like any other unscheduled work. Say plainly in that file's own opening
that nothing in it has been decided; a candidate list that reads like a rule list is worse than
no list at all.

---

## 1. Guardrails — check before the first dispatch, restate in every sub-agent prompt

**Writes are permitted only under `wiki/`, `<spec-folder>` and `specs/drafts/`.** Everything else
is read-only for this entire run:

- **never** modify, move or delete anything under `<source>` — it is the live authority that
  other agents are reading right now, on other branches, until the cutover;
- **never** modify source code, tests, configs, migrations, or root files — including the code
  comments and instruction files that point at `<source>`; repointing them is the cutover's job;
- **never** `git push`, open a PR, merge, rebase, or switch branches;
- **never** start the stack, run tests, lint or migrations — this run needs no running system;
- **never** use `sed`, `awk` or shell redirects to edit or read files — Edit, Write and Read
  only;
- **never** build or rebuild a code index — query `<code-query-tool>` if it is available,
  otherwise Read/Grep;
- sub-agents must not spawn their own sub-agents. Where your agent has no sub-agent tool, run
  each fan-out below sequentially yourself, one destination page at a time, with a fresh read of
  its inputs per page.

PRECONDITION — prove all of these before dispatching anything, and abort with a written reason
into the report if any fails:

```bash
git rev-parse --abbrev-ref HEAD
# a dedicated bootstrap branch — NEVER <main-branch>
git status --porcelain -- . ':(exclude)wiki' ':(exclude)<spec-folder>' ':(exclude)specs/drafts'
# must be EMPTY, and stay empty for the whole run (recon's install files are committed by now)
test -f wiki/README.md && test -f wiki/CONTRIBUTING.md && { [ "<source>" = none ] || test -d <source>; }
# the contract exists, and so does the source if there is one
grep -rnE '\{\{[A-Z_]+\}\}' wiki/README.md wiki/CONTRIBUTING.md wiki/*/CONTRIBUTING.md
# must be EMPTY: recon fills the contract before any plan
git rev-parse --short HEAD
# the baseline SHA — record it in the plan; `run` compiles against exactly this commit
```

The placeholder check matters more than it looks. An unfilled contract is a contract nobody
decided. A settings file still carrying `~` for the main branch makes every git command run
against a ref that does not exist, and every drift check then fails, which reads as "everything
drifted". If either check fails, go back to recon; do not guess.

**Check what the code-query tool describes.** If `<code-query-tool>` answers from an index built
elsewhere — another checkout, a container — confirm that index describes the baseline commit. If
it does not, or you cannot tell, forbid it for the run, say so in the report, and fall back to
Read/Grep. An index of someone else's code answers confidently and with no error.

In `run`, commit to the bootstrap branch after **every** phase, so a crash costs one phase and not
the whole run.

---

## 2. Phases

`plan`: Phase A, then stop. `run`: B and E concurrently, then C and D concurrently, then F and G.

**Scaffolding lives in `<spec-folder>`, never inside `wiki/`.** The plan, the mined gotchas and
the report are artifacts of the run: they get deleted once a human has curated the tree, and
anything still inside `wiki/` at that point has to be swept out by hand — while pages' `sources:`
frontmatter goes on citing scaffolding paths that no longer exist.

### Phase A — mapping (you, no sub-agent; the whole of `plan`)

Emit `<spec-folder>/bootstrap-plan.md` with four parts. Done when every file under `<source>` has
exactly one row, every content page already in `wiki/` has exactly one row, and every choice the
rules below did not settle is listed under *For the human*.

**1. One row per file under `<source>`** (`git ls-files <source>`): its destination page,
provenance class, and action —

- `compile` — rewrite to the contract, into a new page;
- `merge-into <page>` — fold into a page that already exists, shipped or produced by this run
  (§2b);
- `verbatim` — copy unchanged, frontmatter added;
- `defer-to-cutover` — not copied; `git mv` in the cutover PR;
- `keep-outside` — stays out of the tree on purpose; the cutover moves it beside what it serves;
- `drop` — with the reason.

**2. One row per shipped page with no source** — action `adopt`: verify its generic claims
against this codebase, fill its placeholders and `covers:`, stamp or leave it `never` (§2b).

**3. The domain map** — the `modules/` pages you propose and the directories each `covers:`.
That map is a judgement about this codebase, and the whole point of `modules/` is that it is not
1:1 with directories: propose it, and the human's edit is the decision. Where `wiki/modules/`
already has pages, their `covers:` *is* the map and you propose nothing. A project with no
domain-shaped code may have no `modules/` pages at all; say so rather than inventing domains.

**4. For the human** — every destination choice that was yours rather than a rule's, every rule
harvested from a dropped file (rule 9), and every file the tooling reads by path (rule 8).

General rules, in priority order:

1. **Curated stays verbatim.** House rules a human wrote — the agent constitution, the mode
   files, the product overview — are copied unchanged with frontmatter added, or merged under
   §2b's curated rule. Do not recompile and do not "improve": a machine rewriting a human's
   decision is the one failure the provenance classes exist to prevent.
2. **Vendor and legal artifacts stay verbatim**, into `reference/`. Never translate, summarise,
   reconcile with the code, or fix a typo. A non-markdown artifact (a JSON or YAML contract)
   gets no frontmatter; its `origin`, `source-url` and `fetched` go in its row of
   `wiki/reference/README.md`.
3. **Everything else about how the system works gets compiled** to the contract's shape and
   budget — which mostly means deleting what a code query can answer.
4. **Never copy a file over ~1 MB.** Duplicating it doubles it in the repository's history for
   ever. Mark it `defer-to-cutover` and `git mv` it in the cutover PR.
5. **A release journal is mined, not moved.** Its durable gotchas go into module and guide pages
   and the rules it suggests into the candidate list; the file itself is deferred to the cutover
   (`CONTRIBUTING.md` §6 puts the change-log at the repository root).
6. **Intentions are not wiki content.** A backlog, a screen inventory, a roadmap — all belong
   with the specs.
7. **A file addressed to a different audience stays outside.** A guide written for another team,
   an operator's reference, a document kept in another language on purpose for its readers —
   `keep-outside`. Its readers are not agents, and compiling it to the contract would rewrite it
   out of their reach.
8. **A file the tooling reads by path is `defer-to-cutover`.** Find them with
   `git grep -n '<source>/' -- . ':(exclude)<source>' ':(exclude)wiki'` — scripts, CI, configs.
   Copying it leaves two copies the tooling and the wiki will each update separately; moving it
   is one `git mv` plus repointing the readers, in one PR.
9. **The source's own index is dropped, its rules are not.** `wiki/README.md` and `index.md`
   supersede a `README.md` that lists the folder, but such a file often carries the only copy of
   a house rule ("never add a dependency without updating the architecture page"). Harvest each
   one into *For the human* with a proposed home; a human decides where it lands.
10. **A non-English source compiled into a compiled page is translated as part of compiling.** A
    curated or reference file is never translated by a machine — reference keeps its language
    (`CONTRIBUTING.md` §3); a curated one goes to *For the human*.

An illustrative plan for a typical docs folder (`memory-bank/`, `docs/`) — the shape, not this
project's answer:

| Source | Destination | Action |
|---|---|---|
| `README.md` | — | `drop` — superseded by `wiki/README.md` + `index.md`; its rules harvested (rule 9) |
| `guides/ai-instructions.md` | `wiki/guides/ai-instructions.md` (shipped) | `merge-into` — curated: §2b verbatim section |
| `product-overview.md` | `wiki/product-overview.md` (shipped scaffold) | `verbatim` — curated, replaces the scaffold body |
| `architecture.md` | `wiki/architecture/overview.md` | `compile` — the stack and the data flow, minus the inventory |
| `guides/<how-to>.md` on a subject a shipped guide covers | that shipped guide | `merge-into` |
| `guides/<how-to>.md` on a new subject | `wiki/guides/<same name>.md` | `compile` |
| a guide that states how the data path *is* | `wiki/architecture/<topic>.md` | `compile` — it is a state, not a how-to |
| `references/<vendor>/` | `wiki/reference/<vendor>/` | `verbatim`, or `defer-to-cutover` if tooling reads its path |
| `change-log.md` | repository root, at cutover | `defer-to-cutover`; **mined** in Phase E |
| `backlog.md` | `specs/`, at cutover | `defer-to-cutover` — intentions are not wiki content |
| a guide written for another team, in their language | stays where it is | `keep-outside` |
| a screen inventory | `specs/` | `verbatim` into specs — an intention; sending it into `wiki/` means moving it out again |
| (none) | each shipped guide no row above reaches | `adopt` |

Anything the rules do not settle: choose, and list the choice under *For the human*. Do not
silently invent new top-level folders.

**Then stop.** Report the plan's path and the *For the human* items. Commit nothing; the plan
stays in the working tree for the human it is addressed to.

### Phase B — `reference/` (one sub-agent)

Copy the reference artifacts verbatim. Add only the frontmatter block (`title`,
`class: reference`, `origin`, and — for anything from a published source — `source-url` and
`fetched`), or for a non-markdown artifact the same fields in its README row. **No translation,
no summarising, no reformatting, no fixing typos** — the value of these files is that they are
exactly what the third party wrote. Write or extend `wiki/reference/README.md`: each artifact,
what it is authoritative for, and which ones must be grepped rather than read. A README the
source folder already had for an artifact is the vendor-facing half of that row — keep its
content, do not paraphrase it away.

### Phase E — mining the release journal (two or three sub-agents, split by date range)

`<source>/change-log.md` (or whatever the plan names as the release journal) can be thousands of
lines of release history. It stops being a knowledge source at the cutover, so this is the one
pass that harvests it. Split it on entry boundaries — `grep -n '^## ' <file>` gives the line
number of every entry; hand each agent a line range to `Read` with `offset`/`limit`. Each agent
extracts **only durable knowledge**, discarding everything that is merely "what shipped":

- **gotchas** — non-obvious behaviour, root causes, ordering requirements, vendor quirks, races,
  things that bit someone. Tag each with its page from the approved domain map, or with the
  `guides/` page it belongs to.
- **decisions with a reason** — especially a rejected alternative, and especially where the
  reason is not visible in the code that resulted. A rejected alternative is the raw material of
  a `not-doing/` entry — a candidate, never an entry.
- **candidate rules** — statements about the shape of the system that read like a rule. These go
  to the candidate list, never to `target/`.

Output goes to `<spec-folder>/mined-gotchas.md` and `<spec-folder>/mined-decisions.md`. Cite the
change-log line for every item, so a human can check it without re-reading the whole file.

Discard aggressively. A gotcha a code query would answer is not a gotcha. Ten real ones beat
two hundred restated commit messages.

### Phase C — `guides/` and `architecture/` (fan-out, one sub-agent per destination page)

Each agent owns exactly one destination page — a `compile`, `merge-into` or `adopt` row. Its
contract:

1. Read the source file(s) from `<source>`, and the destination page whole if it exists.
2. Query `<code-query-tool>` for the mechanics the source currently spells out.
3. Read the current code for anything either text asserts.
4. Write to the contract: English, ≤ 2–3k tokens, frontmatter per `wiki/CONTRIBUTING.md` §4,
   every code-query-derivable fact removed. An existing page is merged into under §2b, never
   rewritten whole.
5. Report back: dropped content and why; claims it could not confirm against code; contradictions
   between the shipped text and the project; placeholders it could not fill; candidate rules.

**Tell each agent which kind of page it is writing.** A `guides/` page is instructions and may be
imperative; an `architecture/` page describes how the system is built and is written in the
present tense about the current state. The same source paragraph becomes different prose
depending on which it feeds, and an agent that is not told will default to whichever the source
already was.

**Deleting derivable content is the point of this phase, not a side effect.** File inventories,
directory trees, "key files" tables, endpoint catalogs and import lists all go. A fact stays only
if it is intent, an invariant, a constraint, a gotcha, or a procedure — or a record of what the
running system actually does where the code claims otherwise (`CONTRIBUTING.md` §2).

Curated rows (`verbatim`, and `merge-into` a curated page) do not get an agent; you do them
yourself, under §2b.

### Phase D — `modules/` (fan-out, one sub-agent per domain page)

One agent per page of the approved domain map. Each receives its directory list, the matching
slice of the mined gotchas, and the page template from `wiki/modules/CONTRIBUTING.md`. Its
contract:

1. Query `<code-query-tool>` for the domain's shape — that is *orientation*, and it does
   **not** go on the page.
2. Read the code that defines the domain's states, boundaries and invariants.
3. Read whatever `<source>` says about it, plus its mined gotchas.
4. Write the page to the template: responsibility, invariants, states, boundaries, gotchas.
5. Report back: candidate rules, unverifiable claims, and whether the domain→directory map still
   fits the code.

If the map does not fit, **say so, do not re-cut it.** A domain boundary is a human decision —
the human already made it when they approved the plan.

### Phase F — assembly (you)

- `wiki/index.md` — every page, per the format in that file. Replace the shipped rows' summaries
  where the page changed.
- Validate that every page `index.md` names now exists, and that every page on disk is named by
  `index.md` or its folder's catalogue. A page nothing points at will never reach a prompt; an
  index row pointing at nothing reads as coverage. Both are blocking findings, not notes.
- Sweep for unfilled placeholders: `grep -rnE '\{\{[A-Z_]+\}\}' wiki/`. Each hit is either
  filled from the code now or listed in the report under *Needs human curation*.
- `specs/drafts/target-candidates.md` — the union of candidate rules from C, D and E,
  deduplicated, each with its reason and a citation; rejected alternatives that read like
  `not-doing/` entries in a section of their own. Note where several agents proposed the same
  rule independently: rediscovery is the strongest signal that something is foundational rather
  than incidental.
- `wiki/log.md` — one bootstrap entry, newest-first, directly below the `---` separator; delete
  the shipped example comment block. The entry carries a machine-read baseline line:

  ```markdown
  ## [<date>] bootstrap | <source> → wiki/ — N pages compiled, M merged, K adopted

  Baseline: <baseline short SHA>
  - Stamped: N pages at <baseline>. Left `never`: K pages (see the report).
  ```

  `Baseline:` is the lower bound `/wiki-lint` §1d and `/wiki-ingest` Step 0 count from. It is not
  a `Range:` line, deliberately: the bootstrap compiled the state at one commit, it did not ingest
  the history before it. Commits that land on `<main-branch>` while this branch is open will
  show as UNINGESTED on the first lint after the merge; that is true, and an ordinary ingest
  closes it.
- The report — see §3.

**Every path you write, you run.** A `covers:` entry or a check expression that matches nothing
reads as coverage rather than as a gap, and it makes an unfalsifiable claim look verified. A glob
written from habit — `migrations/**` where migrations live elsewhere, `**/*.test.ts*` where the
tests are `*.spec.tsx` — is syntactically fine, plausible, and matches zero files; written into
the two places built to catch drift, it guarantees the check never fires.
`git ls-files -- '<path>' | head -1` is the test, run once at the moment of writing.

### Phase G — acceptance

Run the `wiki-lint` skill **report-only** — tell it not to write its `log.md` line; the bootstrap
entry is this pass's (lint's rule 1). Attach its report. Do not fix what it finds unless the fix
is mechanical and inside `wiki/`; the point of the pass is to hand the human an honest picture of
what was built.

Then commit to the bootstrap branch, update `<spec-folder>/state.md` (`run: done`, the report's
path), and tell the user the run is finished, where the report is, and that the interview is next
(SKILL.md stage 3). Do not start the interview in the same breath as an unattended run: the human
reads the report first.

---

## 2b. Merging into a page that already exists

Shipped pages and pages an earlier phase produced are merged into, never overwritten.

1. **Read the existing page whole first.** Its section structure stays. Project knowledge goes
   into the section it belongs to; a new section only when no existing one fits. `Edit`, not
   `Write`.
2. **The shipped text is a default, not this project's decision.** On a compiled page, where the
   project's documentation states a different practice and the code confirms it, the project's
   practice replaces the default, and the replacement is listed under *Contradictions*.
3. **Silence is not contradiction.** Where the project says nothing, check the default against
   the code: if it holds, keep it. If it plainly does not apply here — it names a surface, a tool
   or a layer this project does not have — leave it, list it under *Needs human curation*, and do
   not stamp the page. Deleting a default is a decision about the project, and leaving a false
   sentence under a fresh stamp is worse than either.
4. **Recon filled the placeholders; a page that still has one gets it filled now** if the source
   or the code answers it, running each path you write, and the value goes into `placeholders:`
   in `wiki/dev-wiki.yml` too. One that neither answers stays, and is listed.
5. **Curated pages are not merged by a machine.** Where the shipped page is an unfilled scaffold
   (a template awaiting content, like `product-overview.md`) and the project has a curated file
   for it, the project's file replaces the scaffold body verbatim and the frontmatter stays.
   Where the shipped page carries rules of its own (`guides/ai-*.md`), keep it unchanged and copy
   the project's file verbatim into a delimited section at its end —
   `## Project house rules — verbatim from <source path>` — then list every overlap and
   contradiction between the two under *Needs human curation*. Two rule sets on one page is a
   known-temporary state a human resolves — the interview (stage 3) is where they resolve it;
   a machine reconciling them is the failure the classes exist to prevent.
6. **Frontmatter.** `covers:` lists what could make the page wrong (`CONTRIBUTING.md` §4) — fill
   it, or leave `covers: []` deliberately on a page that states rules rather than describing
   code. Add the source file(s) to `sources:`. Stamp per §4 rule 6.

---

## 3. The report — the deliverable that gets read first

`<spec-folder>/bootstrap-report.md`. The tree is worthless if it cannot be audited in an hour. The
report must carry:

1. **Provenance table** — every produced or merged page, its sources, its action, and its token
   size (`wc -c / 4`).
2. **Budget** — always-read core total against the ceiling in `CONTRIBUTING.md` §3; every page
   over 3k, named.
3. **Dropped content** — what was removed as code-query-derivable, grouped, with a sample. This
   is the section that proves the boundary was actually applied.
4. **Unverifiable claims** — everything inherited that no agent could confirm against code. Mark
   each `(unverified)` **on its own page as well**; the report is a copy, and the report gets
   deleted.
5. **Contradictions** — where two sources disagreed, or the shipped default and the project
   disagreed, and what was chosen.
6. **Needs human curation** — the candidate rules, the domain-map disagreements, the curated
   overlaps from §2b, the unfilled placeholders, the defaults that may not apply, and the plan
   choices that were yours rather than a rule's.
7. **Cutover checklist** — what the cutover PR must do, none of which this run may: `git mv` each
   `defer-to-cutover` file; move each `keep-outside` file; delete `<source>`; and repoint every
   reader of `<source>` paths outside it —
   `git grep -n '<source>/' -- . ':(exclude)<source>' ':(exclude)wiki'` — root instruction files,
   other skills, scripts, code comments. A pointer left at the old folder sends the next agent to
   a directory that no longer exists, or worse, to one that still does and has stopped being
   maintained.
8. **What was not done**, and why.

**The report is scaffolding and is meant to be deleted.** Once a human has curated the tree,
whatever is still open in it moves to the backlog or the specs, and the file goes — along with
the plan and the mined files. A tree whose index tells readers to consult a bootstrap report
before trusting a page is carrying a permanent apology it should have outgrown. Write it so that
each item can be *moved* rather than summarised.

---

## 4. Rules

1. **Additive only.** `<source>` is live until the cutover. Not one byte of it changes.
2. **Never fabricate.** A claim that cannot be traced to code, `<source>` or the release journal
   is either dropped or marked `(unverified)` and listed in the report. A confident invention in
   a knowledge base compounds silently — it is the single worst outcome of this run, worse than a
   missing page.
3. **The contract is fixed.** `wiki/README.md`, `wiki/CONTRIBUTING.md` and
   `wiki/modules/CONTRIBUTING.md` are inputs. If one is wrong, record the disagreement in the
   report and follow it anyway.
4. **Curated stays curated.** You write nothing into `wiki/target/`, `wiki/not-doing/` or the
   `ai-*` house rules beyond frontmatter, verbatim copying, and §2b's delimited section.
5. **Budget is a constraint, not a goal.** A page that will not fit is split, and the split is
   reported — it is never quietly left at 8k tokens. The shipped pages that declare a budget
   exception in their own opening lines keep it; a merge does not earn one.
6. **Stamp what you checked.** A compiled page whose every claim — the shipped default text
   included — was confirmed against the baseline gets `last-verified` (`date +%F`),
   `verified-at` (the baseline short SHA) and `verified-by: bootstrap`. A page with anything left
   unconfirmed keeps `last-verified: never` and names what is left in the report. The marker is a
   position in a re-check queue, and inventing one forges the record it exists to keep.
7. **Report honestly.** A phase that half-worked is reported as half-worked. The review depends on
   this file being true.

---

## 5. What must be settled before `plan`, and what to check

**Travels with dev-wiki, unchanged:** the phase order, the guardrails, the provenance classes,
the kinds of page, the page budget discipline, the fan-out shape, and the general rules in
Phase A. Those are the design.

**Settled in recon, with the human confirming each value, and the precondition refuses to run
without them:**

- **the contract's placeholders** — every `{{…}}` in `wiki/README.md`, `wiki/CONTRIBUTING.md`
  and the folder CONTRIBUTING files. This stage *fills* a contract; it does not author one, and
  a machine-authored contract is a summary of whatever the docs already said rather than a
  decision about what the tree is for;
- **the settings** — `project.main-branch`, `project.code-query-tool` and `project.domain-dirs`
  in `wiki/dev-wiki.yml` (the last is what `wiki-lint`'s UNCOVERED check walks);
- **the branch** this runs on.

**Decided by a human in the plan:** the domain map, the destination table, and every *For the
human* item.

**Check before running:** whether the project actually has a code-query tool that serves the
baseline commit. Without one, every "is this derivable from the code?" decision falls back to
Read/Grep, which works but costs far more and tempts the run into keeping inventory it should
delete. Say so in the report rather than discovering it in review.

**Two things learned on the first run of this skill that are worth carrying.**

The run's own report is where its value concentrates. That run found inherited pages describing
code that never existed — a guard, a table, a whole API surface — and those pages had been
injected into sub-agent prompts as house rules. It also raised an authorization gap that turned
out to be real. Budget for reading the report properly, and treat "the tree exists" as the
smaller half of the outcome.

And the thing a bootstrap is structurally worst at is exactly the thing it will be tempted to
produce most of: **rules**. Everything it can see is how the code *is*, so every rule it derives
is the present tense with an imperative mood bolted on. Of the candidates that run produced, most
were correct descriptions of current behaviour and belonged on a module page; a handful were
real. Propose freely, promote nothing.
