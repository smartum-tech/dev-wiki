---
name: wiki-bootstrap
description: >
  Adopt the dev-wiki tree in this repository, interactively and resumably: recon reads the code
  and fills the settings and the product overview, plan/run compile the existing docs and code
  into wiki/, and the interview walks the team through the guides one at a time so the shipped
  defaults become their own decisions. Run it again to continue where it stopped.
argument-hint: "[status | recon | plan | run | interview [<guide>] | finish]"
disable-model-invocation: true
---

# Wiki Bootstrap

dev-wiki's installer copied a working `wiki/` tree into this repository. Every content page
carries `last-verified: never` and `verified-by: boilerplate`: it is generic text that nobody
has checked against this codebase or agreed to as this team's rule. This skill turns it into
this project's wiki, in five stages. Each stage ends in a state a human can stop at.

| # | Stage | Who drives | What happens | Detail |
|---|---|---|---|---|
| 0 | `recon` | agent asks, human confirms | detect the stack, settle settings and placeholders, write the product overview, prune guides that cannot apply | [recon.md](./recon.md) |
| 1 | `plan` | agent, then the human edits the plan | map every existing doc and every shipped page to an action | [compile.md](./compile.md) §2 Phase A |
| 2 | `run` | agent, unattended | compile docs and code into the pages, stamp what was verified, report | [compile.md](./compile.md) Phases B–G |
| 3 | `interview` | human decides, agent scribes | guide by guide: show what the code does, ask only the decisions, write the answers | [interview.md](./interview.md) |
| 4 | `finish` | agent proposes, human approves | cutover checklist, post-compaction rules, final lint, delete the scaffolding | §4 below |

**Facts come from the code. Only decisions are asked.** Every stage holds to that line. A
question whose answer the repository already contains wastes the human's attention, and the
interview is long enough without it.

## 1. Every invocation starts here

1. Read `wiki/dev-wiki.yml`. If it is missing, dev-wiki is not installed: tell the user to run
   the installer (see the dev-wiki README) and stop.
2. Read `specs/wiki-bootstrap/state.md`. If it is missing, this is the first run: create it from
   the shape in §3, and the next stage is `recon`.
3. **Pick the stage.**
   - An argument names a stage: do that one. If its predecessors are not done, say which are
     missing and ask before skipping ahead. `interview` is the exception: it may run before
     `plan`/`run` if the human insists, at the cost of asking things the compile would have
     answered.
   - `status`: print the state summary and stop.
   - No argument: tell the user in two lines where things stand and what is next, then go
     ahead. When the next stage is `run`, start it only once the human says the plan is
     reviewed.
4. **Speak `project.interview-language`** to the human, falling back to the language they write
   in. Everything written into `wiki/` stays English (`wiki/CONTRIBUTING.md` §3). When a human's
   answer becomes a rule, show them the English wording before it lands.

**One file, many agents.** Tool names below (Read, Edit, Write, Grep, Glob, Bash, Agent) are
Claude Code's; use your harness's equivalents. Where you have no sub-agent tool, do each fan-out
yourself, one page at a time. Where you have a structured question tool (Claude Code's
AskUserQuestion), use it for multiple-choice decisions. Otherwise ask in plain chat, one decision
per message, with numbered options.

## 2. Guardrails for every stage

- **Writes go only to** `wiki/`, `specs/wiki-bootstrap/`, `specs/drafts/`, and the files recon
  §6 names: the `<!-- dev-wiki:start -->` blocks, the post-compaction reminder, and the
  harness settings the installer left as `todo:`. Code, tests, configs and the existing docs
  folder are read-only. Compile §1 restates this for `run`, which is stricter still.
- **Never commit, push or switch branches without the human's go-ahead in this session.**
  Recon proposes a branch and a commit, and the human says yes. `run` commits per phase on the
  branch the human approved.
- **`wiki/target/` and `wiki/not-doing/` are written only from a human's explicit answer**,
  never from what the code looks like (`wiki/CONTRIBUTING.md` §1). The interview may write them
  because there a human is deciding out loud. Compile never does.
- **Every skill copy stays identical.** When anything changes a file under one directory in
  `skill-dirs`, copy it to the others in the same step. Lint reports a drifted copy as blocking.
- **Update `state.md` at the end of every step that changed anything.** It is what lets the next
  session, in any agent, resume without asking what happened.

## 3. `specs/wiki-bootstrap/state.md`

The state file is a scaffolding file and gets deleted in `finish`. Keep this shape, so any agent
can read it:

```markdown
# wiki-bootstrap state
<!-- Resume point for /wiki-bootstrap. Edit by hand if you must; keep the headings. -->

## Stages
- recon: done 2026-01-05 — branch `wiki-bootstrap`, commit abc1234
- plan: done — specs/wiki-bootstrap/bootstrap-plan.md (human reviewed: yes)
- run: done — specs/wiki-bootstrap/bootstrap-report.md
- interview: in progress — 9 of 27 guides
- finish: pending

## Pruned guides
- guides/native-push.md — no push notifications (recon, human confirmed)

## Interview
| Guide | Status | Changed | Notes |
|---|---|---|---|
| guides/ai-instructions.md | done | 3 rules edited, 1 dropped | |
| guides/e2e-writing.md | deferred | | selector strategy — ask the QA lead |
| guides/testing.md | pending | | |

## Open
- (questions any stage left for a human, one line each, with where the answer lands)
```

## 4. Stage `finish`

Run it when the interview has no `pending` rows. A guide may stay `deferred`, and its open
question then moves to `specs/drafts/`.

1. **Cutover.** If `project.legacy-docs` is not `none`, show the cutover checklist from the
   bootstrap report: the files to `git mv`, the old folder to retire, and every pointer to repoint
   (`git grep -n '<legacy-docs>/' -- . ':(exclude)<legacy-docs>' ':(exclude)wiki'`). Offer to do
   it as a separate commit or PR, and do it only on a yes. Instruction files that told agents to
   read the old folder first get that line replaced by the dev-wiki block's pointer, never left
   beside it: two "read this first" lines are worse than one.
2. **Post-compaction rules.** If `.claude/prompts/post-compact-reminder.md` exists and still has
   `{{PROJECT_QUICK_RULES}}`, propose 4–8 one-line rules. Take them from what the interview
   showed agents most often get wrong. The human edits; you write.
3. **Index and log.** `wiki/index.md` must list exactly the pages on disk. Fill its
   `{{BOOTSTRAP_*}}`, `{{LEGACY_DOCS_DIR}}` and `{{CORE_*}}` values. Measure the core with
   `wc -c` over the always-read set divided by 4, and set `{{CORE_MEASURED}}` to today's date.
   Add one `wiki/log.md` entry, newest first:
   `## [<date>] interview | N guides reviewed — R rules edited, D dropped, P pruned`. Keep the
   `Baseline:` line from `run` where it is.
4. **Lint.** Run the `wiki-lint` skill once, report-only. Hand over its blocking findings. Do not
   fix them here unless the fix is mechanical and inside `wiki/`.
5. **Clean up, on a yes.** Move every still-open item to `specs/drafts/`, one file per item.
   Then delete `specs/wiki-bootstrap/`: the plan, the report, the mined files and `state.md`.
   Scaffolding that outlives its run turns into a second, unmaintained wiki.
6. **Hand over.** Tell the user in a few lines what now keeps the tree true: `wiki-journal` when
   something is learned, `wiki-ingest` after each merge to `<main-branch>`, `wiki-lint` weekly or
   in CI, and `wiki-audit` when lint's findings pile up. Use the invocation syntax of the agents
   in `agents:`.
