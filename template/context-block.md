<!-- dev-wiki:start — managed by dev-wiki (https://github.com/smartum-tech/dev-wiki); edit freely, keep the markers -->
## Before any task: read `wiki/README.md`

The project's knowledge tree is `wiki/`. Start with [`wiki/README.md`](wiki/README.md): it says
what the tree is for and, just as importantly, what not to load. [`wiki/index.md`](wiki/index.md)
is the catalogue. Every task also carries `wiki/guides/ai-instructions.md`, which routes you to
exactly one mode file.

- **Anything a query over the code can answer is not in the wiki.** Where a symbol lives, who
  calls what, what a module exports: ask the code. The wiki holds what a query cannot return:
  intent, invariants, and the gotcha that cost someone a day.
- **Where the code and `wiki/target/` disagree, follow `target/`.** The surrounding code is not a
  specification; some of it is a pattern we regret.
- Learned something the diff cannot hold (an incident, a root cause, a vendor surprise) → the
  `wiki-journal` skill. After a merge to the main branch → `wiki-ingest`. Periodically →
  `wiki-lint`. A proposed rule or refusal goes to `specs/drafts/`, never straight into
  `wiki/target/` or `wiki/not-doing/`.
- Setup not finished yet (`wiki/dev-wiki.yml` still has `~` values) → run the `wiki-bootstrap`
  skill; it resumes where it stopped.
<!-- dev-wiki:end -->
