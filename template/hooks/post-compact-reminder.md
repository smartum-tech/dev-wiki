# POST-COMPACT: Re-read Critical Rules

Context was compacted. You MUST re-read these files NOW, before your next action:

## IMMEDIATELY READ:
1. `CLAUDE.md` - the project's critical rules (the most commonly violated ones)
2. `wiki/guides/ai-instructions.md` - the common rules, and §1 tells you
   which ONE mode file to read next (`ai-rules-pair-programming.md` if a human is
   working with you, `ai-rules-orchestration.md` if an orchestrator dispatched
   you). Compaction is exactly when the mode gets forgotten.
3. If working on a feature: its task list under `specs/`

## Quick Rules (read full docs for details):
{{PROJECT_QUICK_RULES}}
<!-- Replace the line above with 4-8 one-line rules this project's agents most often break
     after a compaction, each pointing at where the full rule lives. Keep it short: this
     file is printed into the context on every compaction. Shape:
- NO <the forbidden command> - <why, in five words> (CLAUDE.md §N)
- DO <the step that gets skipped> after <trigger> (wiki/guides/<page>.md)
-->

## If Unsure About Architecture:
Read: `wiki/architecture/overview.md`
