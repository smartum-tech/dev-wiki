# Maintaining `wiki/`

Rules for writing into this tree — for `/wiki-bootstrap`, `/wiki-ingest`, `/wiki-journal`,
`/wiki-lint`, `/wiki-audit`, and for a human editing by hand. **Reading the wiki to do work in
the codebase needs none of this**; that is [README.md](./README.md).

Two more contributor documents sit next to this one:
[`modules/CONTRIBUTING.md`](./modules/CONTRIBUTING.md) (the module page template) and
[`journal/CONTRIBUTING.md`](./journal/CONTRIBUTING.md) (what belongs in the raw layer). Both
are contributor-only — neither has a reader half, which is why neither is split the way this
file is split from `README.md`. The naming carries that: a `README.md` in this tree is for
someone reading, a `CONTRIBUTING.md` for someone writing.

**Two `README.md` files below the root are deliberate and must not be renamed for
consistency.** `reference/README.md` tells a reader which artifact answers which question and
which ones to grep rather than open — that is reading guidance, and it is the reason the folder
is navigable at all. `not-doing/README.md` is injected with the entries, because it says how a
reader matches a proposal against them.

**`TEMPLATE.md` files are skeletons, not pages.** One sits in `journal/`, `target/`,
`not-doing/` and `architecture/`. A template carries no claim, so it has no real frontmatter
values, is never injected, is outside the core count, and is exempt from drift and budget
checks. `index.md` lists each one once, under *Maintaining*, which is what keeps lint from
reporting it as an orphan.

---

## 1. What authorizes a page

The organising axis is not the folder layout, and not which agent's hands are on the keyboard —
a machine writes nearly everything here. It is **what authorizes the content**.

| Class | Where | Authorized by |
|---|---|---|
| **raw** | `journal/` | having been there — a human, or the agent that worked the problem with them |
| **compiled** | `modules/`, most of `guides/`, `architecture/overview.md`, `index.md` | the code, at a known commit |
| **curated** | `target/`, `not-doing/`, the decision pages in `architecture/`, `product-overview.md`, `guides/ai-*.md` | a human's decision |
| **reference** | `reference/` | the external source, as published |

### curated — typed by a machine, authorized by a human

The normal way one gets written is an architecture session: a human and an agent argue a
decision through, the human settles it, then asks the agent to record what was decided. The
agent is the scribe; the decision is the human's.

What must never happen is a machine **originating** a curated claim — inferring a target from
how the code currently looks, promoting its own proposal, or settling an open question because
it had to write something. Concretely:

- write here **only when asked**, and only what was decided;
- unattended automation (`/wiki-ingest` on merge) touches `target/` for exactly one thing:
  deleting a *where the code disagrees* paragraph when the diff proves the divergence closed;
- **a machine that wants a new curated page proposes it in `specs/drafts/`**, where it is
  prioritised like any other unscheduled work — never by writing into `target/` or
  `not-doing/`. A staging file inside `target/` does not work: it has no owner and no closing
  condition, so it reads as outstanding work forever.

Two things are worth proposing. One is a conflict you can see coming — a decision the code is
about to violate, or a default agents keep getting wrong. The other is the opposite: **a good
pattern applied locally that deserves to be general.** Neither is yours to promote.

### reference — transcribed, never composed

Every page here was transcribed from a published source. The rule is not "do not write", it is
**do not write from your own head**: never translate, summarise, reconcile with our code, fix a
typo, or fill a gap by inference. The page's value is that it reproduces what the source says,
so that when our behaviour and the vendor's contract disagree, this file settles it.

**A stale copy is corrected by re-fetching the whole page, not by editing it.** A diff touching
a few sentences means someone "improved" it, and the page has stopped being a copy. A re-fetch
rewrites the body and bumps `fetched:` together.

This matters more than it looks wherever a vendor contract is validated by nothing except
production — the vendor's sandbox checks little, and a mock is ours, so it agrees with our
understanding by construction. Then `reference/` is the only external description of the
contract we hold, which makes its freshness a safety property.

---

## 2. The code-query boundary

> **If a fact can be recovered by querying the code at read time, it does not belong here.**

The query is `{{CODE_QUERY_TOOL}}` — a code graph if one is installed, otherwise grep, glob and
the language server. The principle does not depend on which. Binding on every skill that writes:

- never write file inventories, function lists, directory trees, import maps, "key files"
  tables, or endpoint catalogues;
- lint **flags** such content in existing pages so it can be deleted;
- a page may name a file **only** as an anchor for a non-derivable claim — *the retry budget
  lives in `payments-http.client.ts` and is deliberately below the vendor's rate limit* — never
  as documentation of where things are.

This boundary is what keeps the page budget achievable. Inherited documentation is usually
mostly inventory, and taking it out is most of what a bootstrap does.

**"Derivable from the code" means the code actually answers it.** Where the code *claims*
something the running system does not honour, a record of the real state is knowledge, not
inventory — and it is some of the most valuable knowledge here, because nothing else holds it.

An illustration of the trap: a migration that runs `REVOKE ALL … FROM PUBLIC` reads as if the
function is now locked down, but explicit per-role grants are separate ACL entries and survive
it. A registry of the grants *actually in force* looks like it restates the migrations; it is
the opposite — the migrations are wrong about themselves, and the registry is the only place the
discrepancy is visible. Deleting it as "derivable" would delete the one true record.

Before cutting something as derivable, ask what a query would actually return. Live database
grants, deployed configuration, what a vendor's API does versus what its docs say — none of
these are in the repository.

---

## 3. Page budget and language

- **A `modules/`, `guides/` or `architecture/` page must fit in a sub-agent's prompt:
  ≤ 2–3k tokens.** A page that cannot be pasted whole cannot be pushed, and a page that cannot
  be pushed will not be read. The per-page budget is the pressure to watch first.
- **Always-read core** (`README.md` + `index.md` + `product-overview.md` + `guides/` +
  `architecture/` + `target/` + `not-doing/`, every `TEMPLATE.md` excepted): **≤ 100k tokens by
  default.** A project may set its own ceiling — here, once; every other mention points at this
  paragraph rather than repeating the number. `modules/`, `reference/` and pages claiming the
  lookup-table exception below sit outside it. `README.md` counts: it is read once at the top of
  a task exactly as `index.md` is, so it is charged exactly as `index.md` is. `not-doing/` grows
  one entry at a time, which is why an entry is capped at 40 lines (§5b) rather than trimmed
  once the total bites.
- **Over the ceiling → an audit, not a raise.** When the core presses the ceiling, `/wiki-audit`
  runs before anyone raises it: an audit asks which pages earn their place, a raise asks
  nothing. Cuts by page size rather than page value are the failure mode either way — read a
  core measurement as a prompt to audit, never as a quota to trim under. A ceiling raised
  without an audit is a ceiling that will be raised again.
- **An ingest that adds net tokens to the core must name what it cut** — in its `log.md` entry,
  as a line reading `Core: +N/-M (net ±K)` followed by what the `-M` was, or by why nothing could
  be cut. Saying "nothing" is a legitimate answer; saying nothing at all is not.

  The reason is arithmetic. A core grows by accretion: many ingests, each individually
  reasonable, each adding a few hundred tokens. The per-page budget is the only other brake, and
  it has two holes: it fires *after* a page is already over, and an ingest that adds 200 tokens
  to each of eight pages trips nothing at all. Without this rule the cost of growth lands on
  whoever next runs an audit, which is the wrong person and always too late. This rule moves it
  to where the growth happens.

  It is a disclosure rule, not a quota — an ingest is never blocked for growing the core, and an
  ingest **must not** drop a real claim to balance its own arithmetic. That would trade knowledge
  for a number. What it must not do is grow the core silently.
- **The lookup-table exception.** A page may exceed the per-page budget **only** if it is a
  lookup table rather than a narrative — something a reader greps for one row instead of reading
  (a registry, a census) — and only if it **says so in its own opening lines**. Such a page does
  not count against the core either: the exception exists *because nobody inlines it*, so
  charging it as though everybody did would put the two rules in contradiction. Trimming a
  lookup table to fit would delete exactly the rows nobody happened to need this week.
  **The exception is not a way out of the core budget, and this is the test:** every section of
  such a page must be scoped to a row in its table. The moment it carries something an agent
  needs *without* looking a row up, that part is ordinary guidance, belongs on a narrative page,
  and is charged normally.
- Over the per-page budget → split by topic, or remove derivable content (§2). Never "kept
  because it is all useful".
- **compiled and curated are English-only.** `journal/` is English when machine-written, free
  when human-written. `reference/` keeps the source's language.

---

## 4. Frontmatter

`modules/`, `guides/`, and `architecture/`:

```yaml
---
title: Payments integration
class: compiled              # raw | compiled | curated | reference
covers:                      # code paths whose change could make this page wrong (drives drift lint)
  - backend/src/modules/payments
  - backend/src/modules/payments-queue/payments.processor.ts
last-verified: YYYY-MM-DD    # for a human to read; `never` until first checked
verified-at: <sha>           # the {{MAIN_BRANCH}} commit it was checked against — for the machine
verified-by: ingest          # human | ingest | audit | bootstrap | boilerplate (shipped, never checked here)
sources:
  - memory-bank/payments.md
  - journal/YYYY-MM-DD-<slug>.md
---
```

**A page that states a rule carries two dates, and they mean different things.** `last-reviewed`
is when a human last confirmed the decision itself; `last-verified` is when the code was last
checked to still follow it. The decision does not go stale because the code moved — that is the
whole point of it — so only the second date participates in drift detection.

`product-overview.md`, `not-doing/` entries and `guides/ai-*.md` carry `title`, `class`,
`last-reviewed` only: nothing in them is a claim about code.

`reference/` pages carry `title`, `class: reference`, `origin` (a sentence on what the artifact
is), plus — for anything from a published source — `source-url:` and `fetched:` (the date this
copy was taken). They carry no `last-verified`: the question is not whether they match our code
but whether they still match their **source**, and `fetched` is what makes that answerable. An
artifact with no live URL — a legal instrument we issued, a printed standard — carries an
edition date instead and does not participate in the staleness check.

### Two clocks, and neither of them is a confidence score

A marker is a **position in the re-check queue**: it tells `/wiki-lint` and `/wiki-ingest`
which pages to look at, and it tells a reader nothing about whether to believe the page. See
[README §5](./README.md).

The two questions run on different clocks, so they are measured differently.

- **"Has the code moved under this page?" is measured in commits, not days.** `verified-at`
  records the `{{MAIN_BRANCH}}` commit the page was checked against, and the check is exact: did
  any commit between it and `HEAD` touch a path in `covers:`. A repository nobody worked on
  produces no drift, which a calendar cannot express — a quiet month would otherwise declare the
  whole tree stale for nothing.
- **"Does a human still believe this decision?" is measured in days.** That is `last-reviewed`,
  and it erodes with calendar time and turnover whether or not the code ever moved.

`last-verified` stays as the human-readable half of the first pair. When `verified-at` is
absent the machine falls back to comparing dates, which is coarser but works — so pages can
gain the field as they are touched, and a hand edit that sets only a date is still valid.

- **a content page with no marker at all is invisible to drift detection**, which is worse
  than a stale page because it looks maintained. A page that has genuinely never been checked
  carries `last-verified: never` — it sorts to the front of the queue and lies to no one.
  **Never back-date instead**: a date means "checked then", and inventing one forges the very
  record the field exists to keep.
- `verified-by` distinguishes a machine's re-check from a human's; a bare date cannot;
- **the marker moves only when every claim was confirmed.** A partial check leaves the old one
  and files the discrepancy — advancing on partial evidence manufactures confidence.
- **`partial:` is where a partial check is filed, and it is a field, not a comment.** A machine
  reads `last-verified:`; it does not read the sentence beside it. So a page that is partial and
  wears a fresh date lies to every consumer, whatever the comment says. The field takes one
  folded scalar: what could not be walked, why it cannot be walked *here* (live catalog state, a
  running container, a host the agent cannot reach), and what was checked instead. Its presence
  means `last-verified` covers only the rest of the page, and it blocks a full stamp until the
  named measurement is taken somewhere that can take it. A page carrying it is not a defect.
  **Count them with `grep -rl '^partial:' wiki/`, never from a number written here** — a
  written count is wrong by the next ingest.
- **a `verified-at` that no longer resolves means re-verify, not error.** History gets
  rewritten; a squashed or rebased commit makes `git log <sha>..HEAD` fail outright rather
  than return nothing. That failure is the correct signal and must be treated as "check this
  page", never as a broken lint.

**Run every path you write, once, when you write it.** A `covers:` entry or a check expression
that matches nothing reads as coverage rather than as a gap. The usual way it goes wrong is an
assumed shape: a glob for SQL migrations in a repository whose migrations are TypeScript, or
`**/*.test.ts` where the suite is `*.spec.tsx`.

### `covers:` lists what could make the page **wrong**

Not what the page is *about*, and not what a task touching the page would edit. Those are three
different sets, and mixing them is what makes a drift check useless.

The test is one question: **if a commit lands here, could this page become false?** For example:

- a `target/` page forbidding `CHECK` constraints on status columns covers the whole migrations
  folder, correctly — a new migration can add the constraint the page forbids;
- a guide about running migrations must **not** cover that folder, though it is entirely about
  migrations: a new migration says nothing about how the runner behaves. It covers the runner,
  and any one migration it cites by name;
- `guides/coding-standards.md` covers **nothing at all**. "Use `{{PACKAGE_MANAGER}}`",
  "kebab-case", "no `window.alert`" are conventions the code must follow; a commit can violate
  one, but cannot make the page wrong. Covering every source root would make it drift on nearly
  every commit — a signal that always fires is the same as one that never fires.

**An empty `covers:` is a legitimate answer** for a page that states rules rather than describing
code, and lint must not read it as a missing field. Such pages ride the freshness horizon
instead, and their violations are found by a compliance review of the diff, not by drift.

Directory-wide entries (`frontend/src`, the whole migrations folder) are almost always the wrong
shape. Prefer the specific files and subdirectories the page actually asserts things about.

---

## 5. `target/` — the contested set

Read [README §2](./README.md) first for what this folder is *for*; the rest is shape.
[`target/TEMPLATE.md`](./target/TEMPLATE.md) is a starting point, not a form.

A page here is **small and free-form**, because the decisions are not all the same shape — one
is "no `CHECK` constraints on status columns", another is "we will use Redis as a cache, and
deciding what belongs in it is a judgement call". A template that fits the first mangles the
second.

**Two things are mandatory.**

- **The decision**, stated so that someone can tell whether code follows it.
- **Why.** The letter alone can be lawyered around; the letter plus the reason cannot. And a
  *wrong* reason is worse than none — it can be refuted, and the rule goes down with it. If you
  do not know why, ask; do not invent a mechanism that sounds plausible.

Everything else is optional and takes whatever shape the decision needs: **where the code
currently disagrees**, a check someone can run, a link to the journal entry or PR behind it.

The divergence paragraph is the part that turns a declaration into an instruction — *you will
meet Y in this codebase; do X instead*. It is worth writing even when it is broad: "the project
is not built this way at all" tells an agent not to look for an example and not to read the
absence as an argument. Where it cannot be written, leave it out.

**No numbering.** The filename is the identifier, and it carries meaning that `T-007` does not.

**A page does not leave `target/` when the divergence closes.** The rule outlives the debt: "no
`CHECK` constraints" is still needed once every old migration is rewritten, or the next one
arrives. Delete the divergence paragraph; keep the page.

**Hard boundary:** `target/` constrains the shape of the system. Never the design of an unbuilt
feature; that is `specs/`, however ideal. Violating this turns `target/` into a second
`specs/drafts/` and it loses all authority.

There is no `decisions/` folder. The "why" is in the page; the "how we got here" is `journal/`,
which does it better — dated, written by whoever was there, accumulating a thread across
recurrences. What that costs: a page is edited in place, so a reversed position leaves no trace.
Where it matters, say so — *this previously required X; code before &lt;date&gt; may still
follow it*.

---

## 5b. `not-doing/` — the refused set

Same provenance as `target/`: a human decides, an agent takes dictation, unattended automation
never writes here. Same injection too — the directory is core, pushed whole into every prompt.
The shape of an entry, the admission test that keeps deferrals and code-shape rules out, and how
a match is surfaced are in [`not-doing/README.md`](./not-doing/README.md), not repeated here.

Three rules belong to maintenance rather than to writing, which is why they live on this side:

- **An entry is capped at 40 lines, and 15–25 is the working range.** Being core means every
  entry is paid for on every task, and the directory only grows. The cap is a routing check as
  much as a budget: an entry that cannot fit is usually a `target/` rule or a deferral.
- **An entry is not drift-checked against code.** It records a decision, not a state, so it
  carries `last-reviewed` and no `covers:`. What *is* a finding is an entry naming something
  that now exists in the code — that means either the decision was reversed and the entry is a
  false rejection, or something shipped against a standing decision. Either way a human has to
  look.
- **The reason lives here, once.** Where a `modules/` or `guides/` page previously carried a
  rejection, it now carries a pointer and the entry carries the reason. Do not restore the
  paragraph: two copies of a rejection diverge the first time somebody reconsiders one of them.

---

## 6. The change-log at the repository root

`change-log.md` records **released changes**, one entry per feature branch, at the end of that
branch's work:

```markdown
## YYYY-MM-DD — 042 rate limiter on the payments client
Sliding-window limiter in the payments HTTP client, below the vendor's limit; 429 maps to
RATE_LIMITED instead of a generic failure.
PR #NN. Journal: `wiki/journal/YYYY-MM-DD-payments-rate-limiter.md`.
```

Three to five lines: what shipped and why, the PR, and — **when the branch produced a journal
entry** — a pointer to it.

**The pointer is optional, and most branches have nothing to point at.** `journal/` takes only
what the diff cannot contain, which is a high bar most work does not clear (see
[`journal/CONTRIBUTING.md`](./journal/CONTRIBUTING.md)); a routine feature that shipped exactly
what its diff says produces no entry, and saying so is the correct outcome. `/wiki-ingest`
compiles from the realized diff and the current code, so it runs on a branch with no entry
exactly as it runs on one with an entry — a missing pointer holds up nothing. Write
`Journal: —` or omit the line; do not manufacture an entry to fill the slot.

Findings, gotchas and rejected approaches do not belong in the change-log. When a branch
produces any, they go into a journal entry, because that is what the wiki compiles from and the
change-log is not.

---

## 7. Workflow

```
an existing docs folder, once, at adoption
  └─▶ /wiki-bootstrap → the whole tree compiled from it; every page
                        stamped, or `last-verified: never`              [compiled]
        └─▶ ONE PR; the human's merge IS the confirmation

feature merges to {{MAIN_BRANCH}}
  └─▶ /wiki-ingest    → compiled from the diff, the current code and its comments;
                        surgical edits to modules/, guides/, architecture/, index.md,
                        log.md                                          [compiled]
        └─▶ ONE PR; the human's merge IS the confirmation

something is learned that the diff does not contain (an incident, a root cause)
  └─▶ /wiki-journal   → wiki/journal/<date>-<slug>.md                   [raw]
        └─▶ picked up by the next /wiki-ingest

periodically, and before trusting the tree
  └─▶ /wiki-lint      → drift, dead covers: paths, orphans, budget overruns,
                        query-derivable content, stale references       (read-only)

lint's findings have piled up, or the core presses the §3 ceiling
  └─▶ /wiki-audit     → full-tree read in one context → per-page plan for the
                        human → approved plan applied page by page: claims
                        re-verified, duplicates collapsed, UNINGESTED commits
                        dispositioned                                   [compiled]
```

**Bootstrap is the first step, and it runs once.** `/wiki-bootstrap` compiles this tree from
whatever documentation the project already keeps — a `memory-bank/`, a `docs/` folder, a pile of
READMEs — checking each claim against the code as it goes, stripping inventory (§2), and
routing every statement to the page kind that owns it. A claim it cannot confirm is carried
marked `(unverified)`, never silently dropped and never silently promoted. Curated pages
(`target/`, `not-doing/`, decision pages) are compiled only from what the old docs record as a
human's decision; the bootstrap does not infer new ones. Once its PR merges, `/wiki-ingest` takes
over, and the old folder is retired — deleted when the tree no longer needs it, kept in history.
Until it is deleted, it is a source, not a second authority: an agent reads the tree.

**A page that states a rule is never edited to match drifted code.** When the freshness horizon
fires on a descriptive page and the code has moved, fix the page — it was describing the code
and it fell behind. When it fires on a rule and the code has moved, the code is in violation:
say so, and escalate. An ingest that "updates" rules to match whatever the code now does is a
machine that quietly erases the tree's reason for existing.

Ingest does **not** require a journal entry and does not write one. Most merges produce none:
what a feature did is in the diff, what shipped is in the change-log, and `journal/` carries
only what neither can hold.

**Edits are surgical.** Prefer `Edit` over rewriting a page: the tree's value is stability and
accuracy, not churn, and a wholesale rewrite loses accumulated knowledge under the appearance
of an update.

The `sources:` frontmatter on bootstrapped pages names files in the retired docs folder, and
keeps naming them after it is deleted. That is deliberate and must not be "fixed": it records
what a page was compiled **from**, which was true at the time and is how you find the original
in git history. Provenance is a historical claim, not a link.
