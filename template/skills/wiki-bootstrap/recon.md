# Stage 0: recon

This file belongs to the `wiki-bootstrap` skill and is read when [`SKILL.md`](./SKILL.md)
routes to stage 0.

Recon is the general-information pass. It needs about ten minutes of the human's time. It settles
everything the later stages assume:

- which branch to work on;
- the settings file;
- every placeholder in the wiki;
- the product overview;
- which shipped guides apply at all.

Recon does not write content pages. Its only outputs are confirmed values and one curated page,
`product-overview.md`.

**Gather first, then ask once.** Steps 2 and 3 run without questions. Step 4 shows everything
they found in one table, so the human can confirm it in one pass. Asking each value as you find
it would cost twenty interruptions for answers that are mostly "yes".

## 1. Branch and starting point

Run:

```bash
git rev-parse --abbrev-ref HEAD
git status --porcelain
```

The installer's files are uncommitted. If the current branch is the main branch, or looks like
one (`main`, `master`, `develop`, `trunk`), propose `git switch -c wiki-bootstrap`. The
uncommitted install moves with you. Any other branch: ask whether to work here or on a new one.
Do not switch until the human says yes.

## 2. Detect: settings and placeholders

Fill a working table: key, value found, evidence. Find each value in the order given, and stop at
the first hit. Every path you record, test with `git ls-files -- '<path>' | head -1` or
`test -e`. An empty result is "not found", never a guess.

| Key | Where to look |
|---|---|
| `project.name` | `name` in the root manifest (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod` module); the README's H1; the directory name |
| `project.main-branch` | `git symbolic-ref --short refs/remotes/origin/HEAD` (strip `origin/`); else whichever of `main`/`master` exists in `git branch -a`; else ask |
| `project.package-manager` | the lockfile: `pnpm-lock.yaml`, `yarn.lock`, `package-lock.json`, `bun.lock*`, `uv.lock`, `poetry.lock`, `Cargo.lock`, `go.sum`, `Gemfile.lock`; `packageManager` in `package.json` |
| `project.code-query-tool` | MCP servers in `.mcp.json`, `.cursor/mcp.json`, `.codex/config.toml`, `.gemini/settings.json` (a code graph or index server: graphify, serena, sourcegraph, …); none means `grep/Glob/LSP` |
| `project.legacy-docs` | `memory-bank/`, `docs/`, `doc/`, `documentation/`, `adr/` or `docs/adr/`, `.cursor/rules/`; several hits are listed, and the human picks; none means `none` |
| `project.domain-dirs` | backend directories whose children are domain modules (`src/modules/`, `apps/api/src/modules/`, `internal/`, `app/domains/`); none means `[]` |
| `{{PROJECT_NAME}}` | = `project.name` |
| `{{MAIN_BRANCH}}`, `{{PACKAGE_MANAGER}}`, `{{CODE_QUERY_TOOL}}`, `{{DOMAIN_DIRS}}` | = the matching settings |
| `{{FRONTEND_DIR}}` | `web/`, `frontend/`, `client/`, `apps/web/`, `app/`; a directory with a `vite.config.*`, `next.config.*` or `angular.json` |
| `{{MOBILE_DIR}}` | `mobile/`, `apps/mobile/`; a directory with `capacitor.config.*`, `app.json` with `expo`, `pubspec.yaml`, or `ios/` + `android/` |
| `{{BACKEND_DIR}}` | `backend/`, `server/`, `api/`, `apps/api/`, `supabase/`; a directory with a server framework in its manifest |
| `{{E2E_DIR}}` | the `testDir` of `playwright.config.*`; `cypress/`; `e2e/`, `tests/e2e/` |
| `{{MOCK_SERVER_DIR}}` | `mock-server/`, `mocks/`; a package depending on `msw`, `json-server`, `prism` or `express` that serves fixtures |
| `{{API_CONTRACT_FILE}}` | `git ls-files '*openapi*.y*ml' '*openapi*.json' '*swagger*' '*.graphql' '*.proto'` |
| `{{TYPES_DIR}}` | a shared types package: `libs/types`, `packages/types`, `shared/` |
| `{{UI_LIB_DIR}}`, `{{UI_LIB_IMPORT}}` | the shared design-system package and its import name (`libs/ui` / `@libs/ui`, `packages/ui` / `@acme/ui`) |
| `{{DEV_URL}}`, `{{DEV_PORT}}` | `server.port` in the frontend's dev-server config; `ports:` in a compose file; `.env.example` |
| `{{BROWSER_TOOL}}` | a browser-automation MCP server in the configs above (Playwright MCP, …); none means "a Playwright script run headless" |
| `{{REGISTRY_HOST}}` | `image:` lines in compose files and CI; a `docker login` in scripts |
| `{{SANDBOX_SCRIPT}}` | a script that prepares a git worktree (`scripts/*worktree*`, `tools/*sandbox*`); none means "none" |

Then sweep for any placeholder not in this table, since a shipped page may carry its own:

```bash
grep -rhoE '\{\{[A-Z_]+\}\}' wiki/ | sort | uniq -c
```

Leave `{{BOOTSTRAP_*}}`, `{{LEGACY_DOCS_DIR}}`, `{{CORE_*}}` and `{{PROJECT_QUICK_RULES}}` for
`finish`.

## 3. Detect: what applies

The banks under [`questionnaire/`](./questionnaire/) carry one section per shipped guide. You do
not need them whole here; pull just the gates:

```bash
grep -nE '^## |^\*\*(Applies when|Otherwise|Depends on)|prune together' <this skill's dir>/questionnaire/*.md
```

Read a section in full only where its gate line is not self-contained. For each shipped guide,
evaluate its **Applies when** check against the repository. Sort the guides into three lists:

- **applies**: the check passed;
- **prune**: the check failed, and the bank says `prune`;
- **unsure**: the check failed, the bank says `keep-as-reference`, or the evidence is mixed.
  Examples: a `ios/` folder and no Capacitor config, or a backend that lives in another
  repository.

Honour every **Depends on** / **prune together** note, both ways. A pruned page's dependants are
pruned too. A kept page keeps the pages it depends on.

## 4. Confirm, once

Show the human one message:

1. the settings and placeholders table: key, value, evidence in a few words. Mark each `?` row
   that is not found or ambiguous;
2. the three guide lists, with the reason for each pruned and unsure entry;
3. the legacy docs found, and which one is proposed as the `plan` source;
4. one question: the interview language. Default: the language the human writes in.

Tell them they can correct any row in free text. Apply the corrections and show only the
changed rows back. Repeat until they confirm.

Then write:

- `wiki/dev-wiki.yml`: the `project:` keys, and every filled placeholder under
  `placeholders:` as `NAME: value`. That record is what later stages and the questionnaire
  banks read;
- every `{{NAME}}` in `wiki/` that has a value: replace it with Edit, one occurrence at a time.
  Grep first and work through the list. A placeholder that stands for something the project
  does not have (`{{MOBILE_DIR}}` with no mobile app) is normally on a page being pruned. If it
  is not, write `(none)` and add the page to `## Open` in `state.md`;
- pruning: delete each pruned page. Remove its row from `wiki/index.md`. Then repair the links
  into it: `grep -rn '<page>.md' wiki/` (`<page>` is the pruned file's name), and turn each hit
  into plain text or delete the sentence if it only pointed there. A dead link reads as coverage.
  Record each pruned page in `state.md` with its reason. **Unsure pages are kept**: the
  interview asks about them first.

## 5. Product overview

`wiki/product-overview.md` is curated: a human authorizes every sentence. It is the "general
information about the project" every agent reads first.

1. Draft it from what is already written: the README, the manifests' descriptions, the legacy
   docs' overview, and any landing page copy in the repository. Follow the shipped page's
   sections and comments. Mark every sentence you inferred rather than found with `(?)`.
2. Show the draft. Ask only what the draft could not answer, and at most six questions in one
   message:
   - What is it, for whom, and what problem does it solve, in two sentences?
   - Which surfaces exist: web, mobile, admin, API for third parties? Which one matters most?
   - The domain words a newcomer gets wrong, as a few glossary terms.
   - What stage is it at: prototype, beta, production with real users or money? This changes
     how careful every later rule is.
   - Who works on it: team size, who reviews, how agents are used (pair or orchestrated)?
   - What it deliberately is not, or will not do?

   An answer to the last question is the raw material for `not-doing/`. Ask whether each item
   should become an entry: if yes, write it from `wiki/not-doing/TEMPLATE.md` with the human's
   reason. If not, leave it on the overview as a sentence.
3. Write the page, show it, and apply corrections. Remove every `(?)` that was confirmed and
   every sentence that was not. Set `last-reviewed:` to today.

## 6. Harness to-dos

`todo:` in `wiki/dev-wiki.yml` lists what the installer would not do itself:

- `merge-claude-hook`: `.claude/settings.json` already existed. Add the `SessionStart` hook with
  matcher `compact` that prints `.claude/prompts/post-compact-reminder.md` into the existing
  `hooks` object. The shape is in the dev-wiki repository's `template/hooks/claude-settings.json`,
  and the same JSON is shown in its README. Keep every existing key. Show the diff and get a yes
  before saving.
- `merge-post-compact-reminder`: a reminder file already existed. Add a line that points at
  `wiki/README.md` and `wiki/guides/ai-instructions.md` to it, rather than replacing it.

Remove each item from `todo:` when done. Also check that each file in `context-files` has its
`<!-- dev-wiki:start -->` block. Where an older "read X first" instruction above the block
points at the legacy docs, leave it for now. `finish` replaces it in the cutover, once the wiki
actually holds that content.

## 7. Close recon

Propose a commit of the install and recon: `wiki: install dev-wiki, recon`. Make it only on a
yes. `plan` and `run` require a clean tree outside `wiki/` (compile §1). Mark recon `done` in
`state.md` with the branch and the commit.

Then say what is next:

- `plan`, if there is a legacy docs folder or any `modules/` worth proposing;
- otherwise straight to `plan`, which still has work to do with no source: an `adopt` row for
  every surviving shipped page, plus the domain map.
