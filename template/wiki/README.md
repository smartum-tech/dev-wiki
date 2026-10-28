# wiki/ — what to trust here, and for what

This tree answers two questions: **how to write this repository correctly**, and **how to work
in it effectively.** A third serves both — **how the system is actually built**, in the parts a
query cannot show you.

**Maintaining this tree is a different job with different rules — those are in
[CONTRIBUTING.md](./CONTRIBUTING.md).** If you are reading to do work in the codebase, you do
not need it. Read this page, then [`index.md`](./index.md).

---

## 1. What is NOT here

**Anything you could get by querying the code.** Where a symbol lives, what a module exports,
who calls what, which files changed together — that is the job of `{{CODE_QUERY_TOOL}}` (a code
graph if one is installed, otherwise grep, glob and the language server), and it answers from
the code as it is right now. This tree deliberately holds no file inventories, no directory
trees, no endpoint catalogues. If you came looking for one, you are in the wrong tool and the
answer here would be stale anyway.

What is here is what a query cannot return: intent, invariants, constraints, the gotcha that
cost someone a day, and the reason a thing is the way it is.

`specs/` is a third place, and it is **not authoritative**: it holds what we intend to build,
including things that were never built or built differently.

---

## 2. Kinds of page, and which one wins

| | Holds | Answers |
|---|---|---|
| `guides/` | **actions** — how to do a thing here, and how not to | how do I add an endpoint, write a test, run the stack |
| `architecture/`, `modules/` | **states** — how the system is built | how the pieces fit; what a domain owns and guarantees |
| `target/` | **the contested set** | where the code will argue with you, and who is right |
| `not-doing/` | **the refused set** | what we could have built and decided against, and why |

`architecture/` and `modules/` differ only in scale — the whole system against one domain.

`target/` and `not-doing/` are both **injected core** — every agent gets them whole, on every
task (§6). They are the two places a decision beats the code, so arriving without them is how
an agent rebuilds something we already refused.

**`target/` is not "the ideal", and it is deliberately small.** A decision only lands there
because there is a conflict: the code violates it, or agents keep choosing the obvious-but-wrong
thing by default. When a rule is simply followed, it lives in `guides/` or `architecture/` and
nothing is written twice. An empty-looking `target/` is not a gap in curation.

### The precedence, which is the whole point

> **`target/` > the rest of this tree > the code.**

The surrounding code is not a specification. Some of it is a pattern we regret — written
earlier from an under-specified brief — and copying it because "that is how this project does
it" is how the mistake spreads. That is exactly what `target/` exists to stop, and why it wins
outright: everything in it is there *because* the code disagrees.

The second half matters as much and is easier to forget: **the ordinary pages outrank the code
too.** They are instructions for writing it, not a report on it. If following one conflicts
with the task, say so in your report rather than quietly picking the code's side.

---

## 3. What not to load

Reading the tree whole means everything below, and most of it is not knowledge you need. Each
has a reason and a moment when you *would* open it — that moment is rare.

| Skip | Why | Open it when |
|---|---|---|
| `reference/` | vendor, standards and legal artifacts, verbatim. A single machine-readable spec can be many times the size of the rest of the tree, so the folder total is not a number you can plan around | you need an exact vendor field, status or clause — **grep it, never read a file whole** |
| `journal/` | raw material for `/wiki-ingest`, not written to be read. What matters from it has already been compiled into the pages above | you are investigating a recurrence and want the earlier incidents |
| `log.md` | bookkeeping, and the append-only registry of which commit ranges an ingest has covered | you are debugging the wiki's own machinery, or checking whether a change ever reached this tree |
| `CONTRIBUTING.md`, `modules/CONTRIBUTING.md`, `journal/CONTRIBUTING.md`, every `TEMPLATE.md` | how to *maintain* the tree; a template is a skeleton and makes no claim | you are writing into it |

Everything else — `index.md`, `product-overview.md`, `architecture/`, `target/`, `not-doing/`,
`guides/`, and the `modules/` pages your task touches — is the part meant to be read.

---

## 4. What authorizes what

| If you need… | Read | Because it is authorized by |
|---|---|---|
| how to do the work here | `guides/` | a decision, checked against the code |
| how the system is built | `architecture/`, `modules/` | the code, at a known commit — each page names the paths it makes claims about |
| **where the code will disagree**, and who is right | `target/` | a human's decision. See §2 |
| whether we already refused an idea, and why | `not-doing/` | a human's decision. Injected whole, like `target/` |
| what a vendor or a standard actually says | `reference/` | the external source, transcribed verbatim |
| what happened, and when | `journal/` | someone who was there. Dated, append-only |
| what we intend to build | `specs/` — **not authoritative** | nobody; it is intention |

---

## 5. Two reading rules that are not obvious

**A date on a page is not a confidence score.** `last-verified` says when a page was last
checked against the code; it exists so `/wiki-lint` and `/wiki-ingest` know what to re-check.
It is not an instruction to trust an old page less, and an out-of-date page does not lose to the
code by default — §2 settles that, not the date. `last-verified: never` means only that nobody
has checked the page yet.

**Disagreement resolves differently by kind of page.** A page describing how the system is built
is *about* the code, so when the two differ, the code is what is true and the page has fallen
behind — note it in your report. A page saying how to write the code is not about the code at
all, so the same difference is a **violation to report, never a page to correct**. Editing a
rule to match drifted code is how a rule dies quietly.

A claim marked `(unverified)` is a third thing: inherited and never confirmed. Treat it as a
lead, not as a fact.

---

## 6. How this gets to you

Telling an agent to *go read* something fails reliably. So the orchestrator **inlines page
content into the sub-agent's prompt**. If you are a sub-agent, what you needed should already
be in front of you; if something is obviously missing, say so rather than guessing.

Four things go into **every** prompt, because they are what must not be violated whatever the
task is:

- `guides/ai-instructions.md` — the constitution and the mode router
- `guides/coding-standards.md`
- all of `target/` (its `TEMPLATE.md` excepted)
- all of `not-doing/` (its `TEMPLATE.md` excepted) — a task that rebuilds something we refused
  is wasted before it starts, and nothing later in the pipeline catches it

Plus exactly one mode file — `guides/ai-rules-pair-programming.md` or
`guides/ai-rules-orchestration.md` — **declared by the caller, never guessed by the agent.**

Choosing what else to inline is the orchestrator's judgement, and it makes that judgement from
**the readable part of the tree as §3 defines it** — this file, `index.md`,
`product-overview.md`, all of `architecture/`, `target/`, `not-doing/` and `guides/`, and
**every** `modules/` page. Everything §3 lists under *Skip* stays skipped: at plan time nothing
has yet asked for a vendor clause or a past incident.

**A planner's read is not the core ceiling**, and the two are routinely confused. The ceiling in
`CONTRIBUTING.md` §3 bounds only what every prompt carries; a planner additionally reads every
module page, and `modules/` tends to be the faster-growing half. That is also the one place a
planner reads more than a sub-agent — a sub-agent is given the pages its task touches, while the
orchestrator reads them all precisely because it does not yet know which domains the task will
reach. Both figures rot within a week, so derive rather than quote:

```bash
cat wiki/README.md wiki/index.md wiki/product-overview.md \
  $(ls wiki/{architecture,guides,target,not-doing,modules}/*.md | grep -v '/TEMPLATE.md$') | wc -c
```

divided by four, less any page claiming the lookup-table exception (`CONTRIBUTING.md` §3) —
drop `modules` from the glob for the core alone. `reference/` is in neither, because one
verbatim artifact can outweigh everything else put together.

For the few cases where the required reading is not obvious from either end — a page that
governs a directory it never mentions — see the *not obvious from either end* table in
[`index.md`](./index.md).

---

## 7. Layout

```
wiki/
├── index.md             catalogue of every page — start here
├── product-overview.md  what we build and for whom
├── guides/              how to work here: house rules and cross-cutting how-to
├── architecture/        how the system is built, at system scale
├── modules/             how it is built, one page per domain — not per directory
├── target/              where the code will disagree with us, and who is right
├── not-doing/           what we decided against, and why — injected whole, like target/
├── journal/             dated incidents and findings
├── reference/           vendor and legal artifacts, verbatim — grep, do not read whole
├── CONTRIBUTING.md      how to maintain all of the above
└── log.md               ingest/lint/audit operations log
```

`modules/` pages are cut by **domain**, not one per source directory. Which page covers which
directories is [`modules/index.md`](./modules/index.md) — that catalogue lives beside the pages
it lists, because `modules/` is outside the core and only a planner reads it.

A file named `TEMPLATE.md` is a skeleton for a writer, not a page: it makes no claim, is not
injected, and is outside every count.

Some files live outside this tree on purpose:

- `change-log.md` at the repository root — released changes (`CONTRIBUTING.md` §6);
- the maintainer's own backlog, if the project keeps one (for example `specs/backlog.md`) — a
  person's scratch list, where an intention is a line until it needs more than a line and
  becomes its own document under `specs/drafts/`;
- a per-variable environment reference, if the project keeps one. It is addressed to an
  operator rather than an agent and stays **out of the tree on purpose** — do not move it in and
  do not mirror it here; the deployment guide holds the decision layer (which variables you
  actually have to decide, and why) instead.

**An agent files into `specs/drafts/`, one file per finding — never into a shared backlog.**
That file is a person's notepad, and a shared file at the repository root conflicts on every
merge when several branches append to it at once; a directory of one-file findings does not.
