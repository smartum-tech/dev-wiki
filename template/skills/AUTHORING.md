# Authoring a skill in this repository

The standard for anything under any directory listed in `skill-dirs` in `wiki/dev-wiki.yml`
(e.g. `.claude/skills/`, `.agents/skills/`). Distilled from
[mattpocock/skills](https://github.com/mattpocock/skills) `@8b36d4f` —
`skills/productivity/writing-for-agents/SKILL.md` and its `SKILL-MECHANICS.md`.

Not in `wiki/`: this governs how we write agent instructions, not how the codebase is built, and
the wiki's always-injected core has no room to spare (`wiki/CONTRIBUTING.md` §3).

## 1. Every step ends on a completion criterion

> "Every step ends on a **completion criterion** — the condition that tells the agent the work is
> done." — `writing-for-agents/SKILL.md:47`

Two independent properties make it a lever. **Checkable** — can the agent tell done from not-done?
A vague bound ("understanding reached") invites **premature completion**: the step ends before it
is genuinely done, because attention has slipped to *being done*. Sharpen the bound first; that is
local and cheap. And **demanding** — how much it requires:

> "'Every modified model accounted for' forces thorough work where 'produce a change list' does
> not." — `SKILL.md:50`

The demand does the digging — the legwork is latent in the wording rather than written as its own
step — and it is not step-bound: "every rule applied" binds a body of flat reference exactly as
"every step done" binds a sequence, which is how an all-reference document still carries a bar.

> "The strongest criteria are both checkable and exhaustive." — `SKILL.md:52`

The worked example is a debugging skill's reproduction phase: not "you have a good repro" but
*name one command you have already run, paste its invocation and output, show it is red-capable
and deterministic*. In the wiki skills: `/wiki-bootstrap`'s Phase A is done when every source
file and every shipped page has exactly one row; `/wiki-audit`'s lost-commits step is done when
every uncovered commit is dispositioned by SHA.

## 2. The no-op test

Hunt no-ops sentence by sentence. An instruction the model already obeys by default pays load to
say nothing.

> "The test — does it change behaviour versus the default? — is model-relative, not
> reader-relative: two people disagreeing about a no-op disagree about the default, and settle it
> by running the document, not by debate. When a sentence fails, delete the whole sentence rather
> than trim words from it." — `SKILL.md:81`

It grades leading words too: a word too weak to beat the default (*be thorough*, when the agent is
already thorough-ish) is a no-op, and the fix is a stronger word, not a different technique.

## 3. A leading word instead of a definition

A leading word is a compact concept already in the model's pretraining that the agent thinks with
while running the document. Repeated as a token, never as a sentence, it anchors a region of
behaviour in the fewest tokens by recruiting priors the model already holds.

> "'fast, deterministic, low-overhead' → _tight_ (a _tight_ loop)." — `SKILL.md:69`

The wiki skills already run on several. **Drift** carries "commits touching a page's `covers:`
paths since the commit it was verified against"; **covers** carries "what could make this page
wrong, not what it is about"; **curated** carries "typed by a machine, authorized by a human".
Each is one token where a paragraph used to be. Assume your document carries restatements a
leading word retires — find them.

## 4. Prompt the positive

Steering by prohibition drags the forbidden behaviour into context and makes it *more* available.

> "A prohibition earns its place only as a hard guardrail you cannot phrase positively." —
> `SKILL.md:74`

Even then, pair it with the positive target so attention lands on what to do. "Never edit files
with `sed`" is a legitimate guardrail, and it still names the Edit tool.

## 5. One meaning, one source

Keep each meaning in one authoritative place, so changing the behaviour is a one-place edit. We
state this harder than upstream does: a second copy of a list is the very failure the rule exists
to prevent, because the two copies diverge the first time one of them is edited. That is why the
wiki skills read the core set and its ceiling from `wiki/CONTRIBUTING.md` §3 rather than quoting
them, and why the domain map lives only in each page's `covers:`.

## 6. The `description:` is a trigger, not a summary

> "The pointer's _wording_, not its target, decides when the agent reaches the material — and how
> reliably." — `SKILL.md:12`

A must-have skill behind a weakly worded description is a variance bug. Four rules:

- **Front-load the leading word** — the description is where it does its triggering work.
- **One trigger per branch.** Synonyms renaming one branch are one branch written twice.
- **Cut identity the body already carries.** The description loads every turn; the body does not.
- **Every trigger must fire on something that exists here.** A trigger naming a command this
  installation does not have is a branch that can never be taken, and it reads as coverage.

## 7. Invocation modes

> "Pick model-invocation only when the agent must reach the skill on its own, or another skill
> must." — `SKILL-MECHANICS.md:12`

- **Model-invocable** (`disable-model-invocation: false`) — the description sits in context every
  turn, so the agent and other skills can fire it. Permanent load bought with discoverability.
- **Human-only** (`disable-model-invocation: true`) — no context load, and only a human typing the
  name reaches it. The description becomes "a one-line summary, trigger lists stripped"
  (`SKILL-MECHANICS.md:10`), and the cost moves to the human, who is now the index.

**State the mode explicitly in every skill**, model-invocable ones included. Omitting the key
behaves identically but records no decision, and the next author cannot tell an unmade choice from
a made one. The worked example is `wiki-bootstrap`: a one-shot compiler whose source folder a
human must name and whose plan a human must approve, so no agent can usefully reach for it on its
own — human-only. `wiki-lint` is the opposite case: `wiki-audit` must be able to fire it, so it is
model-invocable and pays for its description on every turn.

`disable-model-invocation` is the Claude Code spelling of the choice. Agents that spell it
differently (Codex keeps it in a skill's `agents/openai.yaml`) ignore the key and apply their own
default, so the decision recorded here stays the intent, and the description still has to work
without it.

## 8. Running in other agents

The same skill folder is copied byte-identical into every directory in `skill-dirs`, and each of
Claude Code, Codex, Cursor, Gemini CLI and pi loads it. Write for all of them.

- **Tool names are Claude Code's.** Read, Edit, Write, Grep, Glob, Bash and Agent in a skill name
  a capability; use your harness's equivalent (a file-edit tool, a content-search tool, a shell).
- **No sub-agent tool, no fan-out.** Where a skill says to dispatch a sub-agent per page, do it
  sequentially yourself, one page at a time, with a fresh read of the page each time — never a
  batch summarised from memory.
- **Invoking a skill.** Claude Code and Cursor: `/wiki-lint`. Codex: `$wiki-lint`. pi:
  `/skill:wiki-lint` (needs `enableSkillCommands`). Gemini CLI has no slash form: ask ("run the
  wiki-lint skill") and approve the activation prompt.
- **Writes stay inside the contract.** The only file a skill may write outside `wiki/` is the one
  its procedure names (`wiki-audit`'s plan file, for instance). Nothing else, in any harness.

Authoring rules that keep a skill portable:

- **Frontmatter is `name` (equal to the folder name), `description`, `argument-hint` when the
  skill takes arguments, and `disable-model-invocation`.** No `allowed-tools`: some harnesses treat
  it as a restriction, and Claude Code tool names would break it there.
- **No project values in the file, and no placeholders.** A skill is never edited per project. It
  says "the main branch (`project.main-branch` in `wiki/dev-wiki.yml`)" and starts by reading that
  file; a key still `~` means stop and send the user to `/wiki-bootstrap`, never a guess.
- **Never hard-code a skill directory.** A skill that greps, reads or edits other skills does it
  across every directory in `skill-dirs`; a copy it forgot is a copy that drifts (`/wiki-lint`
  checks for that).
