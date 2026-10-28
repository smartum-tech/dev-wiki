# Installing dev-wiki: instructions for a coding agent

You are a coding agent (Claude Code, Codex, Cursor, Gemini CLI, pi, or similar). The user has
asked you to set up dev-wiki in the repository you are working in. Follow these steps in order.

1. **Confirm the target.** Run `git rev-parse --show-toplevel`. That directory is where the wiki
   goes. If it is not a git repository, or `wiki/dev-wiki.yml` already exists there, tell the
   user and stop. In the second case, offer to resume with step 5 instead.

2. **Say what will be written, and get a yes:**
   - `wiki/`: the knowledge tree, with its settings file `wiki/dev-wiki.yml`;
   - the maintenance skills (`wiki-bootstrap`, `wiki-ingest`, `wiki-journal`, `wiki-lint`,
     `wiki-audit`):
     - `.claude/skills/` for Claude Code;
     - `.agents/skills/` for Codex, Cursor, Gemini CLI and pi;
   - a short block between `<!-- dev-wiki:start -->` and `<!-- dev-wiki:end -->` markers. It
     goes into `CLAUDE.md`, `AGENTS.md` and/or `GEMINI.md`, depending on the agents, and points
     agents at the wiki;
   - for Claude Code, a post-compaction hook. It is created in `.claude/settings.json` only if
     that file does not exist yet.

   The installer never commits and never overwrites an existing file. Ask which agents the team
   uses. Always include yourself.

3. **Fetch the installer and read it before running it.** A script from the internet is run only
   after it has been read:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/smartum-tech/dev-wiki/master/install.sh -o /tmp/dev-wiki-install.sh
   ```

   Read `/tmp/dev-wiki-install.sh`. Then run it from the repository root, with the agents agreed
   in step 2:

   ```bash
   bash /tmp/dev-wiki-install.sh --agents <list> --yes --no-launch
   ```

   `<list>` is comma-separated, taken from `claude,codex,cursor,gemini,pi`.

4. **Show the user the installer's output.** If it refused, report its reason and stop. It
   refuses before writing anything, so there is nothing to clean up.

5. **Start the bootstrap in this session.** Read the bootstrap skill's own file:
   `.agents/skills/wiki-bootstrap/SKILL.md`, or `.claude/skills/wiki-bootstrap/SKILL.md` in
   Claude Code. Follow it from the beginning, as if the user had invoked it. Skills added during
   a session are often not registered until the next one, but reading the file works now. Tell
   the user how to resume it in later sessions:

   | Agent | Command |
   |---|---|
   | Claude Code, Cursor | `/wiki-bootstrap` |
   | Codex | `$wiki-bootstrap` |
   | pi | `/skill:wiki-bootstrap` (needs `"enableSkillCommands": true`) |
   | Gemini CLI | ask "run the wiki-bootstrap skill", and approve the activation |
