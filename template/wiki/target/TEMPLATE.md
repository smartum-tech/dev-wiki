---
title: <The decision as a statement — e.g. "Status values are a TypeScript enum, not a database CHECK">
class: curated
covers:                       # paths where a commit could start or stop violating the rule
  - <path>
last-reviewed: YYYY-MM-DD     # when a human last confirmed the decision itself
last-verified: never          # when the code was last checked against it (drift clock)
verified-at:                  # the {{MAIN_BRANCH}} commit of that check
verified-by:                  # human | ingest | audit
sources: []                   # journal entries, PRs, the session it was decided in
---

# <Same as title>

<!-- A starting point, not a form: a target page is small and free-form, because decisions are
     not all the same shape. Two things are mandatory — the decision and why. Everything else
     is optional. No numbering: the filename is the identifier. Delete every comment before
     committing. See ../CONTRIBUTING.md §5. -->

<!-- THE DECISION (mandatory). State it so someone can tell whether a piece of code follows it.
     Bold the operative sentence: "**Do not write X.**" Say what to do instead, and give the
     worked example if one exists in the tree. -->

## Why

<!-- MANDATORY. The real reason. A wrong reason is worse than none: it can be refuted, and the
     rule goes down with it. If you do not know why, ask — do not invent a plausible mechanism.
     Say what the rule gives up, too, so nobody mistakes the trade for an oversight. -->

## Where the code disagrees

<!-- OPTIONAL, and the part that turns a declaration into an instruction: "you will meet Y in
     this codebase; do X instead". Say whether the existing violations are accepted debt (do
     not copy them, and do not fix them as a side quest) or scheduled work (link the spec).
     Broad is fine: "the project is not built this way at all". When the divergence closes,
     delete this section and keep the page. If the rule is followed today and only enforcement
     is missing, say that instead. -->

<!-- OPTIONAL: a check someone can run, e.g.

**Check:**

```bash
grep -rE '<pattern>' <path>
```

Run it once when you write it, and say what it over- or under-counts (a comment quoting the
rule matches the pattern too). Count files a violation is actually in, not lines a string
appears on. -->
