---
name: setup
description: >
  Install dev-wiki into the current repository: the wiki/ knowledge tree, its maintenance skills
  wired into every coding agent the repo uses, then start the interactive bootstrap.
argument-hint: "[--agents claude,codex,cursor,gemini,pi]"
disable-model-invocation: true
---

# dev-wiki setup

You install dev-wiki into the repository the user is working in, then hand over to the
bootstrap in this same session.

1. **Confirm the target.** Run `git rev-parse --show-toplevel`. If it fails, or the user is
   plainly in the wrong repository, stop and say so. If `wiki/dev-wiki.yml` already exists, the
   install is done. Skip to step 4.
2. **Say what will be written before writing it.** List these, then ask for a go-ahead:
   - `wiki/`;
   - the skill folders: `.claude/skills/wiki-*`, plus `.agents/skills/wiki-*` when Codex,
     Cursor, Gemini or pi are used;
   - a marked block in `CLAUDE.md`, `AGENTS.md` and `GEMINI.md`, for the agents in use;
   - a post-compaction hook.

   Nothing is committed, and no existing file is overwritten.
3. **Run the installer** from the repository root. Pass the user's `--agents` list if they gave
   one. Otherwise let it detect, and include `claude`:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/install.sh" --from "${CLAUDE_PLUGIN_ROOT}" --no-launch --yes
   ```

   Show the user its output. If it refuses, report why and stop. It refuses before writing
   anything.
4. **Start the bootstrap here.** Read `.claude/skills/wiki-bootstrap/SKILL.md` and follow it from
   its beginning, as if the user had typed `/wiki-bootstrap`. Skills copied in during this
   session may not be listed until the next session, but the file can be read now. From the next
   session on, the user types `/wiki-bootstrap` to resume.
