# Modules — which page covers which directories

The catalogue for `modules/` only. It lives here rather than in [`../index.md`](../index.md)
because `modules/` is **outside the always-read core** (`../CONTRIBUTING.md` §3): a table in
the root index would be charged to every prompt while only a planner uses it — and a planner
reads every module page anyway.

## How a page maps to directories

Pages are cut by **domain**, not one per source directory. Several directories may collapse
into one page, and one directory may carry several pages split by topic
([`CONTRIBUTING.md`](./CONTRIBUTING.md)). The authoritative map is each page's own `covers:`
frontmatter; this table renders it. When a page's `covers:` changes, its row here changes in the
same edit — the row follows the frontmatter, never the other way round.

The `Covers` cell names the directories (short form, relative to the domain-code root) plus one
hook — the thing a reader would not guess from the directory name. It routes, it does not
abstract. Open the page.

**If a task touches a directory you do not see here, or the page it needs is not obvious from
the directory name, the *Not obvious from either end* table in [`../index.md`](../index.md) is
the other half of this — and that one stays in the core, because it is the case this table
cannot serve.**

| Page | Covers |
| ---- | ------ |

<!-- One row per page, e.g.
| [payments.md](./payments.md) | `payments`, `payments-queue` — the transport and the vendor contract, and the one retry it must never do |
-->

## Splits considered and not taken

<!-- When an audit names a split and decides against it, record it here in one line each —
     page, the two halves it could become, why not — so the next audit does not rediscover it.
     Delete this comment once there is a first entry; leave the heading. -->

How to write one of these pages is [`CONTRIBUTING.md`](./CONTRIBUTING.md) in this directory.
