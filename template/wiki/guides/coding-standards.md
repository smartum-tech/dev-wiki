---
title: Coding Standards, Formatting & the Lint Contract
class: compiled
covers: []   # deliberate: nothing here is a claim about code a commit could falsify. These are
             # conventions the code must follow, so a violation is a compliance finding, not drift.
             # Add the formatter/linter config paths when adopting, if you want drift on those.
last-verified: never
verified-by: boilerplate
sources: []
---

# Coding Standards, Formatting & the Lint Contract

Conventions the code must follow. A violation is a compliance finding, not wiki drift.

## Package manager: {{PACKAGE_MANAGER}} only

Pin it in the root `package.json` (`packageManager`) and define workspaces in the workspace file.
Never run another manager's `install`/`add`: a stray lockfile diverges from the real one and
breaks reproducible installs for everyone. Beware built-in aliases that look like project scripts (with pnpm, bare `pnpm up` is
`pnpm update` and rewrites the lockfile) — see [`docker-workflow.md`](./docker-workflow.md).

## File naming

- **Lowercase first letter**: `group.ts`, not `Group.ts`.
- **Kebab-case for multi-word names**: `user-profile.service.ts`, not `userProfile.service.ts`.
- **Dot notation for file role**: `users.service.ts`, `home-page.tsx`, `orders.routes.ts`.

This is convention, not a lint rule. Tool-generated entry points that keep the tool's own naming
are the only exception.

## Contract-first API changes

If the project has an API contract file (OpenAPI), it is the single source of truth, and a change
goes in this order — all steps in one commit/PR, never code running ahead of the contract:

1. Edit the contract.
2. Edit the shared types to match.
3. Edit the handler (mock or real backend).
4. Edit the client code that consumes it.

When a real backend replaces a mock, it must match the same contract file.

## Shared types and design system live in one place

- A type reused across packages (client and server/mock) lives in the shared types package and is
  imported from it; do not redeclare it per package. A type needed by one package stays local.
- Reusable visual primitives (button, card, tag, list row, icon) live in the shared UI package,
  not in an app's `components/` folder; so do CSS tokens and base classes. Colors, radii and
  shadows come from tokens, never hard-coded. Web-only tuning of a shared class goes in a
  web-scoped layer of the shared package, never by editing the shared file. When in doubt, put it
  in the shared package. Decision test: does the pattern repeat across designs, and does the
  component carry business logic (router, data fetching, domain types)? Logic means it stays in
  the app.

## No system dialogs (frontend & mobile)

`window.alert()`, `window.confirm()` and `window.prompt()` are **forbidden**: they block the main
thread, render as raw browser/OS chrome (unstylable, inconsistent, and they look like a crash in a
mobile shell), break assistive tech, and cannot be dismissed or timed out programmatically.

| Need | Use |
|---|---|
| Validation / API error | Inline error banner next to the action |
| Action success | Toast or inline success banner |
| Destructive confirmation | The project's styled confirm dialog |
| Data input | A form field or a modal with an input |

## No duplicate inline string literals

Before adding a literal that *names* something (a status, an error message, a queue or event name,
a query key), search for existing uses. Already used elsewhere → extract a named constant in a
shared location and update every call site. New but likely to recur → define the constant from the
start. The failure this prevents: the same logical value spelled slightly differently across files,
which turns a rename from a compiler-checked edit into a grep-and-hope.

## Comments: why, never what — and never a count or a line number

Don't write comments by default. One is warranted only when the **why** is not obvious: a hidden
invariant, a workaround for a specific bug, a non-obvious link to an external system. Never
describe what the code plainly does, and never write "used in X" or "added for Y flow" — that
belongs in the PR description and goes stale in code.

**Never write a count into a comment.** "All six call sites", "the twenty specs that mock this
module" is a fact with no compiler behind it, and it is wrong the moment someone adds the next
one. **Correcting the number is the wrong fix**: it re-arms the trap for the next author. Delete
the count and state the property instead — *every other spec mocks this module*, *each of these
statuses*.

**A line number in a comment is the same defect, and it rots faster.** `auth.tsx:26-28` is a count
by another name: nothing checks it, and any edit above moves it. A rotted count is merely wrong; a
rotted range still resolves, to other code that has nothing to do with the claim, so it reads as
corroboration. Delete the range, keep the file — and if you need more precision, name a symbol,
which survives the edits a line number does not. The same applies to prose and to wiki pages:
cite a filename, a symbol, a commit SHA, a PR number, or a quoted line the reader can grep.

## Commit messages

`type: short description`, in English, where `type` is one of `feat | fix | refactor | docs |
chore | test | style | perf`. Good: `feat: add cancel-order endpoint to the mock server`. Bad:
`update files`, `wip`.

## Formatting: the formatter owns style, the linter owns code quality

One shared **Prettier** config at the repo root governs style everywhere (no per-workspace
override); each workspace's **ESLint** config is scoped to code-quality rules and extends
`eslint-config-prettier`, which switches off the rules that would fight the formatter over the
same line. Formatting arguments get resolved once, in the formatter config, never re-litigated
rule-by-rule in the linter. A workspace whose lint config has no stylistic rules to silence need
not extend it — adding the dependency buys nothing.

- Don't hand-format. Don't fight the formatter with `// prettier-ignore` — it is an escape hatch
  for rare generated or aligned code, not a way to keep a preferred style.
- Formatting is not a code-review topic: if `format:check` and `lint` are green, the style of the
  diff is not up for discussion. Enable format-on-save in the editor.
- **Format only the files you changed.** A repo-wide `format` on a tree that was not clean churns
  hundreds of unrelated files, and reverting that in bulk can clobber uncommitted edits. Run the
  formatter per workspace or on a file list; reserve the root `format` for a deliberate,
  standalone formatting commit.

## The gate commands and the read-only contract

```bash
{{PACKAGE_MANAGER}} format         # write: every workspace
{{PACKAGE_MANAGER}} format:check   # same set, check-only — this is what gates a merge
{{PACKAGE_MANAGER}} lint           # read-only, --max-warnings 0 (a warning fails the run)
{{PACKAGE_MANAGER}} lint:fix       # same scope, with --fix — a separate, explicit opt-in
```

Plain `lint` never rewrites files; **only `lint:fix` may mutate code**, and it must be invoked on
purpose. Don't reach for `--fix` just to turn a red run green without reading what it flagged — it
defeats a strict, non-mutating check gating the merge. Run a script from inside a workspace to scope
it to that package.

Traps in how gates are wired:

- **Root scripts are `&&` chains over packages, so the first red package hides every package
  after it.** A package's *position* in the chain is therefore a decision: a package whose check is
  red for pre-existing reasons should not sit ahead of one that is green. A check and its `--fix`
  companion must visit the same packages, so all the chains move together.
- **A `lint` script in a package is not evidence the gate has ever run.** A package can carry one
  from its first commit that exits 2 with "couldn't find a configuration file" because no config
  exists in its ancestry, and nothing at the root invokes it, so nobody notices. When in doubt about
  a workspace's gate, run it rather than reading its scripts.
- **Directories outside a gate's glob are unchecked, and nothing about the path says so.** A lint
  glob of `{src,test}/**` and a `tsconfig` `include` of `src` skip an adjacent `tools/` folder —
  exactly where operational CLIs live, the worst place for a gate to be missing. Know what each gate
  reaches; keep logic that needs checking inside the checked tree; decide deliberately (and record
  it as a decision) whether to extend a gate or accept the gap.
- **A package filter that matches nothing exits 0** — see `ai-instructions.md` §2.2. Use a `cd`
  into the workspace for gates that must not silently skip.

## Lint rules as architectural fences

A lint rule is the only mechanism that can make an architectural boundary fail a build, so a
boundary worth keeping tends to end up there rather than in a review comment — e.g. a
`no-restricted-imports` scoped to a path glob, forbidding a UI folder from importing the module
that re-derives state the component is handed as a prop. Ban the whole module, not the one
function, because the resolvers re-derive the same thing under another name. If the block sets
`noInlineConfig: true`, `// eslint-disable-next-line` silently does nothing inside it — the fix is
to consume the prop, not to suppress the rule. Document the fence's reasoning next to the thing it
protects.
