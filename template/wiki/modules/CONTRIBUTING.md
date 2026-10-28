# modules/ — domain pages

One page per **domain**, not per source directory (`{{BACKEND_DIR}}/<module>` or wherever the
project's domain code lives). Directories and domains rarely line up one to one: several small
directories collapse into one domain page, and one large directory can carry several pages. A
domain that outgrows a single page is split **by topic**, keeping the same `covers:` on both
halves — which is why a drift finding on such a directory fires on every page that shares it,
and that is intended. Splitting by size is the exception the budget forces; splitting by
directory is still wrong. The directory-level truth — which file holds what, who calls whom —
is `{{CODE_QUERY_TOOL}}`'s job and must not be restated here (`../CONTRIBUTING.md` §2).

A domain page answers: what this part of the system is responsible for, the invariants it
maintains, the states and transitions that matter, the non-obvious constraints, and the
gotchas that cost someone a day.

## Where the domain → directory map lives

**In each page's own `covers:` frontmatter, and nowhere else.** That is the copy the drift
check reads and the orchestrator routes on, so it is the one that has to be right.
[`index.md`](./index.md) in this folder renders it as a catalogue. Do not keep a third copy
anywhere — a map maintained in three places is maintained in none, and a hand-kept one is
stale within a day.

Changing the map means editing a page's `covers:`. `/wiki-ingest` must not re-cut domain
boundaries on its own: if the code stops fitting the current split, say so in the run report
and let a human decide.

**By default, client-side code (`{{FRONTEND_DIR}}`, `{{MOBILE_DIR}}`, shared UI libraries) and
`{{E2E_DIR}}` have no module pages**; they are covered by `../guides/`. A project whose domain
logic lives in shared libraries or on the client — pricing, rules engines, offline sync —
should give that logic module pages too. Decide it once and record the decision here,
replacing this paragraph.

## Page template

```markdown
---
title: <Domain name>
class: compiled
covers:
  - backend/src/modules/<dir>
  - backend/src/modules/<dir>/<file-the-page-asserts-about>.ts
last-verified: never           # a date once every claim was checked; never back-date
verified-at:                   # the {{MAIN_BRANCH}} commit it was checked against
verified-by:                   # human | ingest | audit | bootstrap
sources:
  - <the file it was compiled from, e.g. memory-bank/<file>.md>
---

# <Domain name>

## Responsibility
What this domain owns, in two or three sentences, and — just as important — what it
deliberately does NOT own.

## Invariants
The things that must always be true. These are the highest-value lines on the page; an
agent that breaks one has broken the domain regardless of whether tests pass.

## States and transitions
Only where the domain has a real state machine (an order, a payout, a review application).
Legal transitions and who may trigger them. Skip the section otherwise.

## Boundaries
How other domains are allowed to reach this one (events, a facade service, HTTP), and what
is forbidden. Link the `../architecture/` and `../target/` pages that govern it.

## Gotchas
Non-obvious behaviour that has bitten someone: an ordering requirement, a vendor quirk, a
race, a rate limit, a migration that cannot be re-run. Each with the reason it exists.

## See also
Links to `../guides/`, `../target/`, `../reference/`, and journal entries.
```

## What must NOT appear on a module page

- file listings, directory trees, "key files" tables, exported-symbol inventories;
- call graphs, import maps, dependency lists;
- API endpoint catalogs that merely restate the controllers or the API contract;
- code blocks copied from the source.

All of the above are code queries. A page that contains them is over budget and will be
flagged by `/wiki-lint`.
