---
title: <The decision as a statement — e.g. "Recurring work is declared in code">
class: curated                # decision pages are curated; a descriptive page is compiled and
                              # follows the guides shape instead (frontmatter as in CONTRIBUTING §4)
covers:                       # paths where a commit could start or stop following the decision
  - <path>
last-reviewed: YYYY-MM-DD     # the decision itself, confirmed by a human
last-verified: never          # the code checked against it
verified-at:
verified-by:
sources: []
---

# <Same as title>

<!-- For a system-scale DECISION: one that shapes many directories and that the code follows
     (if the code mostly disagrees, it belongs in target/ instead). A descriptive page about
     how a part of the system works is compiled, not curated, and needs no template: title,
     prose, gotchas. Budget ≤ 2–3k tokens — this folder is core. Delete every comment before
     committing. -->

<!-- THE DECISION. Two or three sentences, the operative one in bold, including what is
     forbidden ("no X, no Y"). -->

## Why

<!-- The property being bought, and what goes wrong without it. If an incident proved it,
     state the mechanism, not the story — the story is a journal entry; link it. -->

## Where it stands

<!-- Whether the code follows the decision at the last check, and how that was checked. Where
     a known exception exists, name it and say why it is not a violation. -->

## What it does not promise

<!-- OPTIONAL. The misreading this decision attracts — the part that gets misremembered. Often
     the most valuable section. -->

## See also

<!-- The guides that carry the how-to, the modules it governs, the not-doing entry that refuses
     the obvious alternative. -->
