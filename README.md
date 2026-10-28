# dev-wiki

A knowledge tree for AI-assisted development, plus the skills that keep it true. One command
installs it into your repository and wires it into the coding agents your team uses: Claude Code,
Codex, Cursor, Gemini CLI and pi. A guided bootstrap then turns it into *your* project's wiki.

`wiki/` holds what agents cannot get by reading the code: intent, invariants, house rules, and the
gotcha that cost someone a day. Anything a query over the code can answer stays out. That one
rule keeps the tree small enough to read at the start of every task. Five skills maintain it:
`wiki-bootstrap` once, then `wiki-ingest` after each merge, `wiki-journal` when something is
learned, `wiki-lint` as a health check, and `wiki-audit` when the lint findings pile up.

The tree ships with 46 guides: testing, e2e, CI/CD, Docker, native builds, API contracts,
frontend patterns, security checklists, and the rules for how agents work. They were extracted
from production monorepos (React web, Capacitor mobile, contract-first API, Postgres backend) and
stripped of everything project-specific. Each is a set of **defaults with reasons**. The bootstrap
asks your team which of them to keep.

## Install

**From a terminal**, at the root of your repository:

```bash
curl -fsSL https://raw.githubusercontent.com/smartum-tech/dev-wiki/master/install.sh | bash
```

**From inside any coding agent:** paste this.

> Set up dev-wiki in this repository: follow
> https://raw.githubusercontent.com/smartum-tech/dev-wiki/master/INSTALL.md

**As a Claude Code plugin:**

```
/plugin marketplace add smartum-tech/dev-wiki
/plugin install dev-wiki@smartum-tech
/dev-wiki:setup
```

All three run the same [`install.sh`](./install.sh). It detects which agents the repository uses,
asks you to confirm, and writes the files listed below. It never commits, never overwrites an
existing file, and refuses to run twice. The terminal route then offers to start the bootstrap in
Claude Code or Codex. The other two routes start it in the same session.

Options: `--agents claude,codex,cursor,gemini,pi`, `--ref <tag>`, `--yes`, `--no-launch`,
`--from <local checkout>`. See `install.sh --help`.

## What gets written

| Path | What |
|---|---|
| `wiki/` | the tree, and `wiki/dev-wiki.yml`, the settings every skill reads first |
| `.claude/skills/wiki-*` | the five skills, for Claude Code |
| `.agents/skills/wiki-*` | the same five, byte-identical, for Codex, Cursor, Gemini CLI and pi |
| `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` | a short block between `<!-- dev-wiki:start -->` markers that points agents at the wiki, inserted under the file's title |
| `.claude/prompts/post-compact-reminder.md`, `.claude/settings.json` | Claude Code only: a hook that re-reads the critical rules after a context compaction. The settings file is created only if absent; otherwise the bootstrap merges the hook in with your approval |

## The bootstrap

Run `/wiki-bootstrap` (`$wiki-bootstrap` in Codex, `/skill:wiki-bootstrap` in pi). It is
resumable: stop at any point, and the next run, in any agent, continues from
`specs/wiki-bootstrap/state.md`.

| Stage | You | The agent |
|---|---|---|
| **0 · recon** | confirm one table, answer up to six questions about the product | detects the stack, the main branch, the directories, an existing docs folder; fills every placeholder; drafts `product-overview.md`; proposes pruning guides that cannot apply (no mobile app → no native guides) |
| **1 · plan** | review and edit the plan | maps every file of your existing docs (`memory-bank/`, `docs/`, old `CLAUDE.md` rules) and every shipped page to an action, and proposes the domain map |
| **2 · run** | read the report | compiles docs and code into the pages, unattended; merges into the shipped defaults rather than overwriting them; stamps what it verified; lists what it could not |
| **3 · interview** | decide | guide by guide, shows what your code already does ("role selectors in 41 of 44 specs"), the shipped default and its reason, and asks only the decisions. Answers become your rules: kept, edited, dropped, or deferred. Explicit refusals can become `not-doing/` entries |
| **4 · finish** | approve | cutover from the old docs folder, post-compaction rules, final lint, scaffolding removed |

The rule behind every stage: **facts come from the code, and only decisions are asked.** The
interview does not lead with generic "best practices". On request it searches for known problems
in the versions you actually use. It shows each finding with its link, and nothing lands
unless you accept it.

## Agent support

| Agent | Skills from | Context file | Invoke | Notes |
|---|---|---|---|---|
| Claude Code | `.claude/skills/` | `CLAUDE.md` | `/wiki-lint` | post-compaction hook installed |
| Codex | `.agents/skills/` | `AGENTS.md` | `$wiki-lint` | |
| Cursor | `.agents/skills/` | `AGENTS.md` | `/wiki-lint` | also reads `.claude/skills/`, so with Claude Code wired too it lists each skill twice; harmless |
| Gemini CLI | `.agents/skills/` | `GEMINI.md` | ask: "run the wiki-lint skill" | skills may need `/skills enable` |
| pi | `.agents/skills/` | `AGENTS.md` | `/skill:wiki-lint` | needs `"enableSkillCommands": true` |

The skills are plain `SKILL.md` folders with no per-project edits, so the copies stay identical.
`wiki-lint` reports a copy that drifts.

## Repository layout

```
install.sh                 the installer
INSTALL.md                 the same, as instructions for an agent
.claude-plugin/            Claude Code plugin + marketplace manifests
skills/setup/              the plugin's /dev-wiki:setup skill
template/
  wiki/                    the tree as shipped
  skills/                  wiki-bootstrap (+ recon, compile, interview, questionnaire/),
                           wiki-ingest, wiki-journal, wiki-lint, wiki-audit, AUTHORING.md
  context-block.md         the block inserted into CLAUDE.md / AGENTS.md / GEMINI.md
  dev-wiki.project.yml     the project half of wiki/dev-wiki.yml
  hooks/                   Claude Code post-compaction hook and reminder
```

## Known limits

- **No upgrade command yet.** The installed `wiki/dev-wiki.yml` records the dev-wiki commit it
  came from, so a later version can be diffed against `template/` by hand.
- The post-compaction hook is wired for Claude Code only.
- The always-read core is about 100k tokens with every guide in. Pruning in recon normally brings
  it well under. A few pages exceed the ~3k-token page budget: `ai-instructions.md`,
  `deployment.md` and `security-database-checklist.md`.
- Backend pages (migrations, database security, scheduled jobs) assume Postgres and are marked
  *(example)*. Recon prunes them when the repository has no such backend.

## License

MIT
