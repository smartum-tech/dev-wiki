# Questionnaire: AI rules and conventions

Covers: `guides/ai-instructions.md`, `guides/ai-rules-pair-programming.md`,
`guides/ai-rules-orchestration.md`, `guides/coding-standards.md`, `guides/code-query-tool.md`,
`guides/browser-automation.md`. The three `ai-*` pages are one rule set: ask them in that order.

## guides/ai-instructions.md — AI Instructions (common rules, mode router, environment facts)

**Applies when:** always. Every agent reads it whole.
**Otherwise:** keep-as-reference — it is the constitution; only the facts in §2 and the
[U-*] rules are tuned.

**Detect, don't ask** (facts the agent gathers and shows as "your code does X in N of M"):
- Main branch and package manager — `git symbolic-ref --short refs/remotes/origin/HEAD`; the
  `packageManager` field in the root `package.json`.
- Shared dev stack: which compose files exist and whether container names / host ports are fixed
  — `git ls-files '*docker-compose*' '*compose*.y*ml'`, then `git grep -n "container_name\|ports:"
  -- <those files>`.
- Whether a compile check script exists — `typecheck` in each `package.json`
  (`git grep -n '"typecheck"' -- '**/package.json'`); otherwise `tsc --noEmit` is invoked directly.
- Lint / format script names and whether `lint` is read-only — `git grep -n '"lint\|"format'
  -- '**/package.json'`; look for `--fix` / `--write` in plain `lint`.
- Sandbox script that links env files into worktrees — `git ls-files | grep -i "sandbox\|link-env"`.
- Worktree usage today — `git worktree list`; naming of branches — `git branch -r`.
- Migrations or a shared database — `{{BACKEND_DIR}}` for `migrations/`, `prisma/`, `alembic/`,
  `db/`; compose services named `db`, `postgres`, `mysql`.
- Drafts folder in a native language — `git ls-files | grep -i "draft\|specs/"`.
- Compliance gate that reads the override vocabulary — `git grep -il "override vocabulary"`.

**Decide** (ask only these; one at a time):
1. **Which language rules apply to code, commit messages, docs and drafts?** — [U-1] decides what
   reviewers and agents may write in.
   - Ours: English everywhere except user-facing strings; a drafts folder may stay in a native
     language and is translated when it graduates — one language keeps grep, review and agents
     consistent.
   - Also common: English code, team's language for PR descriptions; fully native-language docs
     (small single-language team).
   - Evidence: language of the last 20 commit subjects (`git log -20 --format=%s`), drafts folder.
   - Lands in: §3 [U-1].
2. **Which shell edits are banned for agents?** — [U-3] trades convenience for reviewability.
   - Ours: no `sed`, `awk` or shell redirects for editing; Edit/Write/Read/Grep/Glob only — shell
     edits are opaque in the diff and bypass file-state tracking.
   - Also common: ban only in-place edits (`sed -i`) but allow read-only pipes; no ban, agent
     harness has no dedicated edit tools.
   - Evidence: whether the agent harness offers Edit/Write tools (detected from the agent list in
     `wiki/dev-wiki.yml`).
   - Lands in: §3 [U-3].
3. **Which destructive operations are forbidden outright on shared state?** — [U-4]/[U-5] have
   no undo.
   - Ours: no database reset or schema drop on an instance every branch shares; never kill a
     process by port; kill your own process by command name.
   - Also common: reset allowed on a per-developer local DB (name the command and the
     environment); port-kill allowed when no container runtime is used.
   - Evidence: the migrations/shared-database detect item; whether services publish ports from
     containers.
   - Lands in: §3 [U-4], [U-5] — drop the example in [U-4] if there is no shared database.
4. **What counts as a wiki-update trigger for agents?** — [U-10] defines when an agent must edit
   docs, not just code.
   - Ours: architecture change, new dependency, new or changed API contract.
   - Also common: also on new env var / config key; also on new user-facing feature; only on
     contract change.
   - Evidence: how many of the last 20 commits touching `package.json`/contract also touched docs.
   - Lands in: §3 [U-10].
5. **Do agents delegate mechanical work to cheaper models?** — [U-12] only helps where the harness
   lets the orchestrator pick a model.
   - Ours: lookups and file-reading go to a small fast model, spec-driven code to a mid-tier one,
     judgement stays on the orchestrator — cost and latency.
   - Also common: single model for everything; delegation only for reviews.
   - Evidence: model-tier settings in agent config (`.claude/settings*.json`, agent definitions).
   - Lands in: §3 [U-12] — delete it when no model choice exists.
6. **Does the team run orchestrated parallel agents at all?** — decides whether the router and
   §2.3 stay.
   - Ours: two modes, pair programming by default, orchestration only by explicit declaration in
     the task prompt.
   - Also common: pair programming only (prune `ai-rules-orchestration.md`, collapse the router
     to one row, drop lease text in §2.1); orchestration only (CI-driven agents).
   - Evidence: `git worktree list` shows more than one linked worktree; orchestration notes in
     agent config.
   - Lands in: §1 router and §2.1 / §2.3; prunes `ai-rules-orchestration.md` together with the
     lease rules in `docker-workflow.md`.

**Web, on request:** version-specific known issues for the detected package manager's filter
semantics (does a filter that matches nothing exit 0?); the agent harness's current guidance on
worktrees and file-edit tools.

## guides/ai-rules-pair-programming.md — AI Rules: Pair Programming

**Applies when:** a human works interactively beside the assistant (the default). Check: any
interactive agent in `wiki/dev-wiki.yml` `agents`.
**Otherwise:** prune — only if the team runs agents exclusively unattended (then
`ai-instructions.md` §1 loses its default row).

**Detect, don't ask** (facts the agent gathers and shows as "your code does X in N of M"):
- Commit and PR habit — `git log -30 --format='%an %s'` (are there agent trailers, are commits
  per branch or per task).
- Change-log file and shape — `test -f change-log.md`, `git ls-files | grep -i "change-log\|changelog"`;
  its entries per branch or per commit — read the last 10 entries.
- Logs / stack commands — `git grep -n '"logs' -- '**/package.json'`; `docker compose ls` if
  Docker is up.
- Whether a frontend exists to verify in a browser — `{{FRONTEND_DIR}}` present with a dev
  server script.
- Migration tooling — `{{BACKEND_DIR}}` for migration directories and a watch-mode dev command.

**Decide** (ask only these; one at a time):
1. **May the assistant commit and push on its own?** — [PP-1] is the line between "suggests" and
   "ships".
   - Ours: no commit and no push without an explicit request; staging, `git add -p`, amend and
     history rewrites count as committing; reading git state is always fine — the human reviews
     the diff first.
   - Also common: commit freely on a feature branch, never push; commit and push on a feature
     branch, never on `{{MAIN_BRANCH}}`; full autonomy up to a PR (then this is orchestration
     territory).
   - Evidence: the commit-and-PR-habit detect item.
   - Lands in: Rules [PP-1].
2. **What may the assistant decide alone, and what must it ask?** — [PP-2] sets the question
   budget.
   - Ours: ask when a request is ambiguous in a way that changes what is built, when two
     readings lead to materially different work, or before anything hard to reverse; routine
     defensible choices are the assistant's; "discuss, then build" means settle every interface
     choice first and prefer a configurable design.
   - Also common: ask before touching files outside the named scope; ask before any new
     dependency; ask only on irreversible actions.
   - Evidence: none in code — ask directly, and list the team's concrete "always ask first"
     actions (dependency add, schema change, deleting files, touching CI).
   - Lands in: Rules [PP-2] (add the team's explicit ask-first list).
3. **Who starts the dev stack, and may the assistant take it over?** — [PP-4] guards against
   reading another checkout's stack.
   - Ours: check whose code the stack serves (`docker compose ls`, or just ask); if it is not
     yours, say so and let the human decide; either side may start it when nothing else uses it.
   - Also common: only the human starts and stops containers; the assistant may start it freely
     (single checkout, no shared stack).
   - Evidence: compose files and fixed container names / ports from `ai-instructions.md`
     detect.
   - Lands in: Rules [PP-4], [PP-5], [PP-7]; drop all three if there is no containerised
     stack.
4. **May the assistant run services on the host to get its own output?** — [PP-5].
   - Ours: no; debug through the shared container logs so both read the same picture.
   - Also common: yes for a unit-level process that publishes no shared port; yes when no
     containers are used.
   - Evidence: whether dev servers run in compose or on the host (`pnpm dev` style scripts vs
     compose services).
   - Lands in: Rules [PP-5].
5. **Must the assistant open the app in a browser after frontend changes, and may it run the full
   test suite?** — [PP-8] and the missing rule on suites.
   - Ours: open the app with the automation browser after every frontend change; (no default
     shipped for running the full suite).
   - Also common: browser check only for visual changes or when asked; full unit suite before
     handing off; full e2e only when asked or by the lease holder.
   - Evidence: the unit/e2e script names and typical runtime (`git grep -n '"test' --
     '**/package.json'`).
   - Lands in: Rules [PP-8]; add a rule for suites if the team wants one.
6. **When is the change-log written?** — [PP-9] vs merge conflicts on a shared file.
   - Ours: one entry per feature branch, written at the end of that branch's work — not per
     commit, to avoid merge conflicts on a shared file.
   - Also common: an entry after every change (simpler, more conflicts); entries generated from
     PR titles at release; no change-log at all (drop the rule and the file).
   - Evidence: the change-log detect item (how entries are actually grouped today).
   - Lands in: Rules [PP-9]; also [OR-9] in `ai-rules-orchestration.md` (keep them consistent).
7. **Migration policy (only if the backend has migrations)** — [PP-3].
   - Ours: adding a migration file is ordinary work and applies on the watch-mode restart;
     explicit apply commands are a smell; rollbacks need the human's approval; status commands
     are free.
   - Also common: agents run apply commands explicitly (no watch-mode auto-apply); agents never
     touch migrations; a per-developer database makes rollback safe.
   - Evidence: migration-tooling detect item; whether the dev command applies migrations on start.
   - Lands in: Rules [PP-3] (and [OR-7]); drop with [U-4]'s example when there are no migrations.

**Web, on request:** current agent-harness guidance on permission modes and auto-commit
behaviour; the tool's own flags for read-only vs edit access.

## guides/ai-rules-orchestration.md — AI Rules: Orchestration

**Applies when:** an orchestrator dispatches several agents in parallel worktrees. Check:
`git worktree list` shows linked worktrees, or the team confirms parallel-agent use.
**Otherwise:** prune — together with the router row in `ai-instructions.md` §1, the worktree
notes in §2.3, and the lease sections of `docker-workflow.md`.

**Detect, don't ask** (facts the agent gathers and shows as "your code does X in N of M"):
- Sandbox script and its subcommands — `git ls-files | grep -i "sandbox"`; read the script for
  `link-env`, `up`, `down`.
- Whether `node_modules` / `.env` are shared across worktrees — `git worktree list` then `ls -la`
  in a linked worktree.
- Shared database or fixed compose names — same as the `ai-instructions.md` detect list.
- PR stacking in history — `git log --merges -20 --format=%s`; open PR bases via `gh pr list
  --json baseRefName,headRefName` if `gh` is available.
- Branch naming — `git branch -r`.

**Decide** (ask only these; one at a time):
1. **How do parallel agents share a dev stack?** — [OR-5], [OR-6], [OR-11], [OR-13], [OR-14]
   are all consequences of one choice.
   - Ours: one shared stack, exclusive "lease" assigned by the orchestrator at planning time; at
     most one stack-needing task in flight; stack-free work (types, lint, unit tests) runs freely;
     agents never stop, kill or recreate containers.
   - Also common: a stack per worktree with offset ports and a separate database (no lease, so
     drop these rules); no stack at all (agents test only unit-level); a CI-side stack that
     agents never touch.
   - Evidence: fixed container names and host ports (detect), database count.
   - Lands in: Rules [OR-5], [OR-6], [OR-11]–[OR-15]; with per-worktree stacks most of them are
     deleted.
2. **How far may an agent take git work?** — [OR-2], [OR-3].
   - Ours: commit, push and open its own PR against the branch below it in the stack, then stop;
     never merge, rebase or force-push; read-only roles (reviewers, auditors) commit nothing.
   - Also common: commit and push but no PR (orchestrator opens it); PRs against `{{MAIN_BRANCH}}`
     (no stacking); the orchestrator commits everything.
   - Evidence: PR stacking in history.
   - Lands in: Rules [OR-2], [OR-3].
3. **May agents install or update dependencies?** — [OR-4] depends on whether `node_modules` is
   symlinked.
   - Ours: never; the sandbox script links tooling in; a needed dependency goes in the report.
   - Also common: allowed in a worktree with its own `node_modules`; allowed only for the lease
     holder; allowed with the orchestrator's pre-approval.
   - Evidence: whether linked worktrees share `node_modules` by symlink.
   - Lands in: Rules [OR-4], [OR-15].
4. **Who writes the change-log in an orchestrated run?** — [OR-9].
   - Ours: no sub-PR touches it; one entry per feature branch is written by whoever closes the
     branch, to avoid N-way merge conflicts.
   - Also common: each agent appends its own entry (accept conflicts or use a fragments
     directory); entries generated at merge time.
   - Evidence: change-log detect item in `ai-rules-pair-programming.md`; keep both answers
     consistent.
   - Lands in: Rules [OR-9].
5. **What must a green gate look like before an agent hands off?** — [OR-10].
   - Ours: run the gates relevant to the change; a red gate must be proven identical at the merge
     base with pasted output from both runs; never repair unrelated failures as a side effect.
   - Also common: absolute green required (fine in a clean repo); only the touched package must
     be green.
   - Evidence: run the gate commands on `{{MAIN_BRANCH}}` and count failures.
   - Lands in: Rules [OR-10].
6. **Where do worktrees and orchestrator state live, and may agents touch sibling repos?** —
   [OR-1], [OR-8].
   - Ours: each agent in its own `<nnn>-<slug>/` linked worktree, never the main checkout;
     orchestrator bookkeeping outside every checkout; sibling repositories are report-only.
   - Also common: a fixed `.worktrees/` folder inside the repo (gitignored); agents may edit a
     named sibling repo (monorepo split across checkouts).
   - Evidence: `git worktree list`; other checkouts next to the repo.
   - Lands in: Rules [OR-1], [OR-8]; `ai-instructions.md` §2.3.

**Web, on request:** the agent harness's current worktree and background-agent features; known
`git worktree` issues for the git version in use (`git --version`).

## guides/coding-standards.md — Coding Standards, Formatting & the Lint Contract

**Applies when:** always; individual sections prune by stack. No frontend → drop "No system
dialogs". No API contract file → drop "Contract-first". Single package → drop the shared-package
paragraph.
**Otherwise:** keep-as-reference.

**Detect, don't ask** (facts the agent gathers and shows as "your code does X in N of M"):
- Package manager and pinning — `packageManager` in the root `package.json`;
  `git ls-files | grep -E "pnpm-lock|package-lock|yarn.lock|bun.lock"` (more than one lockfile
  is a finding); workspace file `pnpm-workspace.yaml` or `workspaces` in `package.json`.
- Formatter config — `git ls-files | grep -iE "prettierrc|prettier.config|\.editorconfig|biome"`;
  per-workspace overrides: more than one prettier config.
- Linter config and shape — `git ls-files | grep -E "eslint.config|\.eslintrc"`; whether each
  extends `eslint-config-prettier` — `git grep -n "eslint-config-prettier"`.
- Gate scripts — `git grep -n '"lint\|"format\|--max-warnings' -- '**/package.json'`; whether plain
  `lint` has `--fix`, whether `format:check` exists, whether root scripts are `&&` chains over
  packages (and which package comes first).
- Gate reach — lint glob and `tsconfig` `include` per workspace, against `git ls-files` directories
  such as `tools/`, `scripts/` that sit outside them.
- TypeScript strictness — `git grep -n '"strict"' -- '**/tsconfig*.json'`.
- File naming in practice — `git ls-files '*.ts' '*.tsx' | grep -E "/[A-Z]|[a-z][A-Z][^/]*$"`
  (count of non-kebab names) against the total.
- System dialogs in use — `git grep -nE "window\.(alert|confirm|prompt)|[^.]\b(alert|confirm)\(" --
  '*.ts' '*.tsx'`; and whether a styled confirm dialog component exists.
- Commit message shape — `git log -50 --format=%s`; share starting with `feat|fix|refactor|docs|
  chore|test|style|perf` followed by `:`.
- API contract file — `git ls-files | grep -iE "openapi|swagger|schema.graphql|\.proto$"`.
- Shared packages — `{{TYPES_DIR}}` and any UI package; imports of them — `git grep -c "from '@"`
  for the workspace scope.
- Architectural fences — `git grep -n "no-restricted-imports\|noInlineConfig"` in lint configs.
- `prettier-ignore` use — `git grep -c "prettier-ignore"`.
- Counts or line numbers inside comments — `git grep -nE "(//|#|\*).*(\w+\.\w+:[0-9]+|all (two|three|four|five|six|seven|eight|nine|ten) )"`.

**Decide** (ask only these; one at a time):
1. **File-naming convention** — the page's rule is convention, not lint; it only holds if
   everyone agrees.
   - Ours: lowercase first letter, kebab-case for multi-word names, dot notation for role
     (`users.service.ts`, `home-page.tsx`); generated entry points keep the tool's naming.
   - Also common: PascalCase for React components and camelCase for utilities (fits teams on
     Next.js defaults); snake_case (Python-heavy repos); enforced by `eslint-plugin-check-file`
     or `unicorn/filename-case` instead of convention.
   - Evidence: file-naming-in-practice detect item.
   - Lands in: "File naming".
2. **Commit-message format** — drives changelogs and release tooling.
   - Ours: `type: short description`, English, with `type` in `feat | fix | refactor | docs |
     chore | test | style | perf`.
   - Also common: Conventional Commits with scope (`feat(api): ...`) and breaking-change footers
     (fits automated releases); ticket-id prefix (`PROJ-123: ...`); free form.
   - Evidence: commit-message-shape detect item.
   - Lands in: "Commit messages".
3. **Which gates block a merge, and are warnings allowed?** — the lint contract.
   - Ours: `format:check`, `lint` with `--max-warnings 0`, and `tsc --noEmit`; plain `lint` never
     writes, only `lint:fix` does; format only the files you changed.
   - Also common: warnings allowed with a tracked baseline (legacy repos); formatting enforced in
     a pre-commit hook; checks only in CI.
   - Evidence: gate-scripts and gate-reach detect items (and whether the root chain runs).
   - Lands in: "The gate commands and the read-only contract"; "Formatting".
4. **Are system dialogs forbidden?** (frontend only) — blocking browser/OS chrome.
   - Ours: `alert`, `confirm`, `prompt` are forbidden; use inline banners, toasts and the
     project's styled confirm dialog.
   - Also common: allowed in internal admin tools; allowed only `confirm` for destructive actions
     until a dialog component exists.
   - Evidence: system-dialogs detect item (count of existing uses).
   - Lands in: "No system dialogs". Prune the section when there is no frontend.
5. **Comment policy** — what a comment may say.
   - Ours: no comments by default; only a non-obvious why; never a count or a line number.
   - Also common: doc comments on every public API (typedoc/godoc/javadoc); comments required on
     complex functions; `TODO(owner)` allowed with a ticket.
   - Evidence: share of exported symbols with doc comments (sample `{{FRONTEND_DIR}}` and
     `{{BACKEND_DIR}}`); the counts-in-comments detect item.
   - Lands in: "Comments".
6. **Contract-first order (only if an API contract file exists)** — where the source of truth
   sits.
   - Ours: contract file first, then shared types, then handler, then client; all in one PR.
   - Also common: code-first with a generated spec (the contract is an output, so reverse the
     order); a separate contract repo with versioned releases.
   - Evidence: the API-contract detect item; `{{API_CONTRACT_FILE}}` presence and whether types
     are generated from it.
   - Lands in: "Contract-first API changes".
7. **Shared types and design-system location rules** — one place for each.
   - Ours: shared types in one package imported everywhere; visual primitives and tokens in one
     shared UI package; decision test is "repeats across designs, carries no business logic".
   - Also common: types co-located with the owning module, shared only on second use; a design
     system maintained as a separate versioned package.
   - Evidence: shared-packages detect item.
   - Lands in: "Shared types and design system live in one place" (set the real package names);
     prune for a single-package repo.
8. **Which architectural boundaries are enforced by lint?** — a fence only exists if it is in
   config.
   - Ours: (none shipped beyond the worked example) — the page shows a `no-restricted-imports`
     fence with `noInlineConfig` as the pattern.
   - Also common: `eslint-plugin-boundaries` or `dependency-cruiser` layer rules; Nx module
     boundary tags; none (review only).
   - Evidence: architectural-fences detect item.
   - Lands in: "Lint rules as architectural fences" — list the real fences or prune the example.

**Web, on request:** current ESLint flat-config / `eslint-config-prettier` interplay for the
detected versions; the detected package manager's workspace-filter exit-code behaviour; Prettier
or Biome notes if the formatter is not Prettier.

## guides/code-query-tool.md — Code-query tool

**Applies when:** the repo wires a code graph, index or semantic search tool. Check:
`git ls-files | grep -iE "\.mcp\.json|mcp.*\.json"` then `git grep -il "graphify\|codegraph\|serena\|sourcegraph\|ctags\|lsp"`
in agent config; compose services named like an indexer.
**Otherwise:** keep-as-reference — shrink to the last section ("What the tool is for, in
practice") reworded for grep/Glob/LSP; drop "What an index describes" and both failure-mode
sections, and set `project.code-query-tool` to `grep/Glob/LSP` in `wiki/dev-wiki.yml`.

**Detect, don't ask** (facts the agent gathers and shows as "your code does X in N of M"):
- MCP servers declared — read `.mcp.json`, `.cursor/mcp.json`, `.claude/settings*.json`
  (`mcpServers`); list those that look like code query.
- Indexer as a service — `git grep -n "graph\|index" -- '*compose*.y*ml'`; a bind mount on `./`
  and a `user:` line show which failure modes apply.
- Index output folder ignored in git — `git check-ignore -v <output-dir>`; what its ignore file
  excludes (docs, specs, SQL).
- Hooks that gate on "graph file present" — `git grep -n "graph" -- '.claude/hooks' '.claude/settings*.json'`.
- LSP availability — language-server entries in agent config; `tsconfig.json` present.
- Where it runs — whether the config uses a hostname other than `localhost`
  (`git grep -nE "https?://[a-z0-9.-]+" -- .mcp.json`).

**Decide** (ask only these; one at a time):
1. **Which code-query tool do agents use?** — fills `{{CODE_QUERY_TOOL}}` and the settings file.
   - Ours: a code-knowledge-graph MCP server if installed, otherwise grep/Glob/LSP; the graph is
     never required.
   - Also common: grep/Glob/LSP only (shrinks the page); a hosted code-search service; an
     editor-integrated index.
   - Evidence: MCP-servers-declared detect item.
   - Lands in: title, intro, `project.code-query-tool` in `wiki/dev-wiki.yml`.
2. **How is the index served?** — decides which failure modes stay.
   - Ours: a long-lived dev container with a file watcher (lags by one poll, covers one
     directory), or a graph built from the pushed commit and served over stdio on an unattended
     runner (no watcher, no lag).
   - Also common: built per session on the host; built in CI and downloaded; hosted by a vendor
     (then the working-tree rules do not apply).
   - Evidence: indexer-as-a-service and where-it-runs detect items.
   - Lands in: "What an index describes", "Failure modes of a containerised indexer" (keep only
     if containerised with a bind mount).
3. **How strictly do agents trust the index?** — [U-8] in `ai-instructions.md`.
   - Ours: trust it only when the working directory is the covered one; same commit is not
     enough; say why when declining it.
   - Also common: trust within a short staleness window after writes; always cross-check with
     Grep before stating a structural claim.
   - Evidence: whether the index is bound to one directory (compose bind mount).
   - Lands in: "What an index describes" (One directory); `ai-instructions.md` [U-8].
4. **May agents build or run the indexer?** — runaway builds and permission failures.
   - Ours: no; the harness wires the MCP server before the session starts.
   - Also common: agents may trigger a rebuild command when the index is stale; a make target
     that anyone may run.
   - Evidence: any `rebuild`/`index` script in `package.json` or a Makefile.
   - Lands in: "How it is served" paragraph.

**Web, on request:** version-specific known issues of the detected indexer (bind-mount ownership,
incremental rebuild gaps, MCP transport changes); how the agent harness loads deferred MCP tools.

## guides/browser-automation.md — Browser Automation for Agents

**Applies when:** the repo has a frontend or e2e suite, or agents are expected to verify UI. Check:
`test -d {{FRONTEND_DIR}}` or `git ls-files | grep -iE "playwright|cypress|e2e"`.
**Otherwise:** prune — and with it the browser rules [U-11] / [PP-8] and the pages that cite it
(`e2e-testing.md`, `e2e-writing.md` if present).

**Detect, don't ask** (facts the agent gathers and shows as "your code does X in N of M"):
- Browser MCP / tool configured — read `.mcp.json`, `.claude/settings*.json`, agent config
  for `playwright`, `puppeteer`, `chrome`, `browser`; extension-based tools (anything that drives
  the user's own Chrome) listed separately.
- Screenshot output location — `git check-ignore -v .playwright-mcp`; `git grep -n
  "screenshot" -- '.claude' 'AGENTS.md' 'CLAUDE.md'`; stray images at the repo root
  (`git ls-files '*.png' | grep -v "/"`).
- Whether agents drive a local or remote browser — non-`localhost` URLs in the browser tool's
  config; CORS allow-list in the backend config — `git grep -niE "cors|allowed.?origins"`.
- Test ids available for selectors — `git grep -c 'data-testid'`.
- Credentials in tool config — `git grep -nEi "authorization|bearer|token" -- .mcp.json
  .claude/settings*.json`.
- Other browser tool families visible to the session — tools whose names contain `browser`,
  `chrome` or `playwright` in the agent's tool list.

**Decide** (ask only these; one at a time):
1. **Which isolated browser tool do agents use?** — fills `{{BROWSER_TOOL}}`; everything else on
   the page names it.
   - Ours: a Playwright-based MCP server that launches its own browser instance and touches
     nobody's session.
   - Also common: Playwright scripts run through the CLI (no MCP); a Puppeteer MCP; a remote
     browser gateway (then §4 applies in full); the agent harness's built-in browser pane; none
     (prune the page).
   - Evidence: browser-tool-configured detect item.
   - Lands in: §1 and the `{{BROWSER_TOOL}}` placeholder in `ai-instructions.md` [U-11] and
     `ai-rules-pair-programming.md` [PP-8].
2. **Is the user's own browser ever allowed?** — [U-11] and §1.
   - Ours: never without explicit permission; only for a page that needs the user's own
     logged-in session; ask first, minimal calls; never resize their window.
   - Also common: never, with no exception (use API-fabricated state instead); allowed on a
     dedicated profile on the user's machine; allowed freely on a CI/remote box.
   - Evidence: other-browser-families detect item (is an extension tool even installed?).
   - Lands in: §1, `ai-instructions.md` [U-11].
3. **Where do screenshots go?** — keeps `git status` clean and decides whether they can be reused.
   - Ours: a gitignored folder with an explicit filename prefix (e.g. `.playwright-mcp/<name>.png`);
     never the repo root.
   - Also common: the agent's scratchpad / a temp folder outside the repo; a committed
     `docs/screenshots/` for evidence in PRs; attached to the PR, not stored.
   - Evidence: screenshot-output-location detect item (stray images at the root mean the
     rule is not followed today).
   - Lands in: §1 last paragraph; `ai-instructions.md` [U-11].
4. **Does the browser run on a different machine than the repo?** — decides whether §4 stays.
   - Ours: shipped as a caveat: a remote or containerised browser resolves `localhost` to its own
     host; CORS allow-lists are exact-match; plain-HTTP non-localhost origins are insecure
     contexts.
   - Also common: always local (prune §4); always remote on a mesh VPN (move the working origin
     and CORS list into this page).
   - Evidence: where-it-runs detect item.
   - Lands in: §4 (prune or fill the real origin and where its config lives).
5. **How are credentials in tool config handled?** — §8.
   - Ours: a token committed in MCP config for a private, network-restricted gateway may be
     deliberate; say so on the page and in the config so reviewers do not "fix" it.
   - Also common: tokens only in untracked local config or env-var references; a secrets manager
     injected at launch; no credentials (local browser).
   - Evidence: credentials-in-tool-config detect item.
   - Lands in: §8 (state the repo's actual policy, or prune).

**Web, on request:** the detected browser MCP server's current options for screenshot output
folder and filename, snapshot attributes (test-id exposure) and locator generation; version-specific
bugs for the detected Playwright release; how the agent harness defers MCP tool schemas.
