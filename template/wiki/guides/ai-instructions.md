---
title: AI Instructions
class: curated
last-reviewed: never
---
# AI Instructions

> **Over the 3k page budget, deliberately.** This is the constitution: every agent gets it whole,
> in every prompt, whatever the task. Splitting it would mean deciding which rules some agents
> may skip, and there is no such subset.

This is the **common** rule document. Read it first, then read exactly one mode file (§1). It has
three parts, deliberately kept apart:

1. **The mode router** (§1) — which second rule file applies to you.
2. **Environment and tools** (§2) — facts about the machine and the repository. Facts only:
   nothing in that section tells you what to do.
3. **Universal rules** (§3) — the rules that are identical in both modes.

Rules that differ between modes are **not** here. Each mode file states its own version in full.

**No document in this wiki amends a rule stated in another document.** There is no layering, no
patch table, no "except under X". A document commits this defect when it says of a rule written
elsewhere that it carries any of the marks listed on the next line. Report such text rather than
trying to apply it.

> **Override vocabulary:** `cancel|waive|relax|tighten|loosen|stricter|overrid|supersed|retarget|unchanged`

Those are stems, so every inflection matches. That line is the single source of truth for what
the defect looks like: a compliance gate (if the project has one) should read these very words out
of it at runtime, so adding a mark there is all that is needed to make the gate enforce it. There
is deliberately no second copy of the list anywhere — a copy is the very failure the rule exists
to prevent.

## 1. Which mode you are in

| Mode | Also read |
|---|---|
| **Pair programming** — one human and one assistant on one machine, working together in real time | [`ai-rules-pair-programming.md`](./ai-rules-pair-programming.md) |
| **Orchestration** — an orchestrator dispatching several agents that work in parallel git worktrees against one shared dev stack and one shared database | [`ai-rules-orchestration.md`](./ai-rules-orchestration.md) |

Read this file and **exactly one** of those two. They are not layers stacked on each other: where
they cover the same subject they say different things on purpose, and reading both as if both
applied gives you a contradiction instead of a rule.

### Precedence for deciding

1. **An explicit declaration in your task prompt.** The orchestrator states that you are one of
   several agents, which worktree is yours, and whether you hold the dev-sandbox lease. **This is
   the only thing that selects orchestration mode.**
2. **The worktree indicator** (below) — corroborating evidence, never a selector.
3. **Default: pair programming.** Absent a declaration, you are pairing with a human.

Pair programming is the safe default **on the autonomy axis**: a human is present and you may
freely ask questions, so an assistant that lands here by mistake fails by asking — loud, cheap and
harmless — rather than by committing and pushing on its own.

That claim does not extend to the shared-resource axis. The dev stack and the database are shared
by every branch (§2.1), so an assistant in this mode can still start containers, read logs or open
a browser that belong to another branch's code, and report what it sees as though it were its own
work. `[PP-4]` exists for exactly this case; orchestration handles it with the lease instead.

### The worktree indicator

Works from any subdirectory (git 2.31+ for `--path-format`):

```sh
[ "$(git rev-parse --path-format=absolute --git-dir)" \
  != "$(git rev-parse --path-format=absolute --git-common-dir)" ] \
  && echo "linked worktree" || echo "main checkout"
```

In the main checkout both paths are the same `.git`. In a linked worktree the first is
`.git/worktrees/<name>` while the second stays `.git`. The reasoning: a human pairing with an
assistant works in the main folder, on `{{MAIN_BRANCH}}` or a feature branch there; orchestrated
agents always get their own worktree.

**Being in a linked worktree may only ADD restrictions. It never grants a permission.** Every
consequence you draw from it must be of the form "assume less", never "go ahead":

- Assume you do **not** hold the dev-sandbox lease: containers that are up are probably serving
  another directory's code.
- Assume gitignored files are **absent** — a fresh worktree has no `.env` and no `node_modules`
  until the sandbox script's `link-env` has run in it (§2.3).
- Assume other branches are live around you in the shared stack and database.

It does **not** authorise autonomous commit, push or PR; that comes only from an explicit
declaration. Without this asymmetry a human who opened an interactive session inside a worktree
would silently get an assistant that stopped asking and started pushing.

## 2. Environment and tools — facts, not rules

### 2.1 What is shared across every branch and agent

| Resource | Why it cannot be parallelised |
|---|---|
| The dev stack (`docker-compose.dev.yml`) | Fixed container names and fixed host ports. Only one checkout can run it. |
| The dev database / backend instance | One instance for all branches. Migrations and data are global. |
| The code-query index (if it is a long-lived service) | Bound to **one directory's working tree** as of the last poll — never a commit. See [`code-query-tool.md`](./code-query-tool.md). |

A command that "works" for one person can, when someone else holds the stack, silently report
**another branch's reality** — worse than failing, because the answer looks like an answer.

This is physics, not policy: it holds whoever you are and whichever mode you are in. The modes
only differ in how they cope. Orchestration gives the exclusivity a name — the **dev-sandbox
lease**, one holder at a time, handed out by the orchestrator. Pair programming has only one
worker, so what it has instead is the obligation to check whose code the running stack is serving
before believing anything it says.

### 2.2 The dev stack and the compile check

Backend, web and mobile dev servers run in Docker with hot reload: a saved file is rebuilt inside
the container with no manual step (details in [`docker-workflow.md`](./docker-workflow.md)).
`tsc --noEmit` in the workspace you touched is the compile check; if no package defines a
`typecheck` script, invoke it directly.

**Package filters match package NAMES, not directory names.** `pnpm --filter <name>` takes the
`name` from `package.json`; when the directory is `backend` and the package is `acme-backend`,
`--filter backend` matches nothing. A filter that matches nothing does not error: pnpm prints
`No projects matched the filters` and **exits 0**. So `pnpm --filter backend exec tsc --noEmit`
is a compile check that never ran and reported success — the worst failure mode for a gate, and
one you only catch by reading the output, not the exit code. `cd {{BACKEND_DIR}} && pnpm exec tsc
--noEmit` cannot fail this way.

Nothing enforces stack exclusivity for you. If the sandbox script keeps no ownership record, `up`
from a second location stops the stack where it was, then fails on name and port conflicts — Docker
refuses at the end, but by then the first directory's stack is already down.

### 2.3 Worktrees, env files and `node_modules`

A worktree is created from the main checkout:

```bash
git fetch origin
git worktree add -b 123-feature ../123-feature origin/{{MAIN_BRANCH}}
```

A fresh one contains **no gitignored files**: no `.env`, no `node_modules`. pnpm's layout is
symlink-based, so a workspace without its own `node_modules` cannot resolve workspace
dependencies, and `tsc --noEmit`, lint and test runners all fail outright. The sandbox script's
`link-env` subcommand puts them there (what it moves, and why the stack runs in one checkout at a
time: [`docker-workflow.md`](./docker-workflow.md)); the rule to run it before any gate is
`[OR-15]`.

Keep the orchestrator's own bookkeeping **outside every checkout** — a workspace root one level
above the main checkout, which is not itself a git repo. Otherwise the orchestrator's state shows
up as untracked noise in someone's `git status` and risks being swept into a commit. An
orchestrated agent is never given the main checkout; it gets its own `<nnn>-<slug>/` worktree.

Cleaning up: `git worktree remove ../123-feature`, then `git worktree prune` to drop registrations
whose directory was deleted by hand (those stay registered as `prunable` until pruned).

### 2.4 Which gates rewrite your working tree

`lint` is **read-only in every workspace**: it reports with `--max-warnings 0` and changes
nothing. Mutating variants are opt-in and explicitly named: `lint:fix` and `format`
(`prettier --write`). Formatting is the formatter's job alone, so check it with `format:check`,
not lint. The compile check (`tsc --noEmit`) is read-only everywhere. Contract details:
[`coding-standards.md`](./coding-standards.md).

### 2.5 Code-query index

If the project runs a persistent code index behind `{{CODE_QUERY_TOOL}}`, it describes a
**working tree, not a commit**, may lag a write by a poll interval, usually covers code only (docs,
specs and SQL are invisible to it), and answers for one directory. Facts and failure modes:
[`code-query-tool.md`](./code-query-tool.md).

## 3. Universal rules

These hold in both modes. Rule IDs are stable; cite them when reporting a violation.

1. **[U-1] English only.** Code, comments, identifiers, commit messages, PR descriptions and
   documentation are in English. This does **not** apply to user-facing strings (labels,
   notifications, UI copy), which may be in whatever language suits the audience. If the project
   keeps a drafts folder for working discussions in a native language, that folder is exempt; a
   draft is translated when it graduates into permanent documentation.

2. **[U-2] Always read before write.** Before modifying a file, read its current content.
   Someone may have changed it since you last looked.

3. **[U-3] Never edit files with `sed`, `awk` or shell redirects.** No `sed -i`, no `awk`, no
   `echo >`, no `cat <<EOF >`. Use the Edit/Write tools for every modification and Read/Grep/Glob
   for viewing and searching. Why: shell edits are opaque in the diff and bypass the harness's
   file-state tracking; the dedicated tools are reviewable and idempotent.

4. **[U-4] Never reset or drop shared data.** No `db reset`, no command that drops and recreates
   the schema or the data of an instance every branch shares. There is no undo. If pending
   migrations apply automatically when the backend restarts (and adding a file triggers that
   restart), you never need a reset to pick one up. *(Example — adapt to your backend.)*

5. **[U-5] Never kill a process by port.** No `lsof -ti:<port> | xargs kill`, with any signal —
   `-9` is in every example of the mistake, so the rule gets misread as "`-9` is the dangerous
   part"; it is not, killing **by port** is. On a Docker-published port the PID `lsof` returns is
   Docker Desktop's own forwarder, not the server in the container, and killing it takes down
   every container on the machine. Kill a process you started yourself, by command name
   (`pkill -f "<exact command line>"`).

6. **[U-6] Run lint after changing code, and never use a mutating command to *check*.** `lint`
   is read-only (§2.4) — run it and fix what it reports. `lint:fix` and `format` rewrite files and
   bury your diff; use `format:check` for formatting questions and `tsc --noEmit` for "does it
   compile". Format only the files you changed: a repo-wide `format` churns hundreds of unrelated
   files, and reverting that churn in bulk can clobber a human's uncommitted edits.

7. **[U-7] Report test counts from the runner.** The collected case count as the test runner
   reports it is the number. Never estimate it by grepping for test definitions.

8. **[U-8] Trust the code index only if your working directory is the one it covers.** If you are
   working somewhere else, its answers describe another tree — worse than no answer, because you
   would believe them. Being at the same commit does not help: the test is same directory, not
   same commit. When you must decline to use it, say why.

9. **[U-9] Decide which guide governs a change by what the change *does*, not by whether a
   document mentions its path.** A script under `tools/` that runs `docker compose` is governed
   by the Docker guide even though that guide never contains the string `tools/`. Concluding "no
   guide applies" from a failed grep would let a diff adding `lsof -ti:3000 | xargs kill` to a
   deploy script pass a compliance check clean. Where a change genuinely has no governing guide
   beyond these rules, say so — but only after checking what it does.

10. **[U-10] Keep the wiki current.** If you change the architecture, add a dependency, or add or
    change an API contract, update the corresponding page. The change-log entry is a separate
    rule and lives in your mode file, which says who writes it and when.

11. **[U-11] Use the automation browser, never the human's own browser.** For any browser work
    (verifying a screen, screenshots, clicking through a flow) use the isolated automation
    browser, `{{BROWSER_TOOL}}`, which runs its own profile. Tools that drive the browser the human
    is using steal focus, navigate their tabs, and can resize their window; do not use them
    without explicit permission, and never resize their window at all. The exception is a page
    that needs the human's own logged-in session: ask first, then use the fewest calls. Point
    screenshots at a gitignored folder (e.g. `.playwright-mcp/`, the Playwright MCP's usual
    output folder), or they land at the repo root and pollute `git status`.

12. **[U-12] Delegate mechanical work to cheaper models; keep judgement.** The orchestrating model
    plans, resolves ambiguity and talks to the human. Searching, reading files to extract a fact
    and "where is X defined" go to a small fast model; writing code from a clear spec goes to a
    mid-tier one. A delegation prompt carries exact file paths, the spec, and the context (types,
    interfaces, existing patterns) — the subagent knows only what the prompt says. Do not delegate
    a lookup whose target you already know, and run independent delegations in parallel.
