---
title: AI Rules — Pair Programming
class: curated
last-reviewed: never
---
# AI Rules — Pair Programming

**APPLIES WHEN** you are the single assistant working with a human who is present: they can see
your output, answer a question within seconds, and review your diff before it goes anywhere. This
is the default mode — if nobody told you otherwise, you are here.

**DOES NOT APPLY WHEN** an orchestrator has declared in your task prompt that you are one of
several agents working in parallel worktrees against the shared stack. Read
[`ai-rules-orchestration.md`](./ai-rules-orchestration.md) instead — not as well.

Read [`ai-instructions.md`](./ai-instructions.md) first: it carries the mode router, the facts
about the environment, and the rules that are the same in both modes. This file adds the rules
specific to working beside a human, and repeats nothing from there.

## Rules

1. **[PP-1] No automatic git operations.** Do not commit and do not push without an explicit
   request. The human reviews the diff first, then either commits it themselves or asks you to.
   Staging files, `git add -p`, amending or rewriting history all count as committing for this
   purpose. Reading git state — `status`, `diff`, `log`, `show` — is always fine.

2. **[PP-2] Ask when you are uncertain.** A human is in the loop and answering is cheap for them.
   When the request is ambiguous in a way that changes what you would build, when two readings of
   a requirement lead to materially different work, or when you are about to do something hard to
   reverse, ask before acting rather than picking a branch and hoping. Routine judgement calls you
   can defend are still yours to make — asking about every trivial choice wastes the same
   attention. When the human says "let's discuss, then build", settle every interface choice
   before writing code, and prefer a configurable design over betting on one variant.

3. **[PP-3] Let migrations apply themselves; ask before rolling one back.** *(Example — adapt to
   your backend.)* Three tiers, and they are not the same thing:

   - **Adding a migration file is ordinary work** and needs nobody's permission. If the backend
     runs in watch mode inside Docker, the new file restarts it and the pending migrations run on
     that restart (`[U-4]`). That is the mechanism — not a fallback for it.
   - **The explicit "apply migrations" commands are not part of that work.** The restart has
     already applied your file. Reaching for one during ordinary work means you are working around
     the mechanism; say so to the human and find out why the restart did not do its job — do not
     force the apply through.
   - **Rollback commands are destructive.** One database serves every branch, so a rollback is
     never scoped to your work: it changes the schema under everyone. Ask, and wait for the
     answer, before running any of them.

   A migration-status command only reads — use it freely.

4. **[PP-4] Establish whose code the stack is serving before you trust it, or start it.** Only
   one directory on the machine can run the dev stack at a time, and nothing enforces that — the
   containers belong to whichever directory last brought them up (`ai-instructions.md` §2.1). So
   before you read a log, open the app, or conclude anything from either, know which checkout is
   behind them.

   The cheapest check is to ask: the human started it and is sitting right there. Mechanically,
   `docker compose ls` lists each running project with the compose file it was started from —
   compare that path with your own working directory. `docker ps` tells you only that something is
   running, not whose; use it to confirm services are not already up before you start them.

   This matters most when your working directory is a linked worktree, which is where a stack
   belonging to somebody else is most likely. If the stack is not yours, **say so and let the human
   decide** — do not quietly take it over, and do not report what you saw as though it came from
   your branch. Either of you may start the project when nothing else is using it; it makes no
   practical difference who does, since every component runs in a container.

5. **[PP-5] Debug through the shared container logs.** Services run in Docker precisely so that
   you and the human read the same logs at the same time. Never start a service on the host to get
   your own copy of the output — it conflicts with the container and splits the picture you are
   both looking at.

6. **[PP-6] Close the feedback loop after you write files.** Hot reload triggers by itself once a
   file lands on disk. Check the corresponding logs afterwards and confirm that the part of the
   project you touched at least builds — a syntax or import error that static reading missed shows
   up there immediately. Hot reload only rebuilds the directory the containers were started from,
   so if `[PP-4]` says the stack is not yours, a clean log proves nothing about your edit.

7. **[PP-7] Read logs with the project's own commands** (`{{PACKAGE_MANAGER}} logs`,
   `logs:<service>`, or `docker logs -t -f <container> --tail 100`). Use them to catch build
   failures, HMR errors and runtime exceptions. These commands address whatever containers are
   currently up, so `[PP-4]` comes first: a log read from somebody else's stack looks exactly like
   a log read from yours.

8. **[PP-8] Open the app in a browser when you change the frontend.** Drive it with the automation
   browser (`{{BROWSER_TOOL}}`) against the running stack (never the human's own browser, `[U-11]`). It lets the human
   see the result and lets you inspect the DOM and take screenshots instead of reasoning about
   rendered output blind. Subject to `[PP-4]` for the same reason as the logs — and here the
   failure is worse, because a screenshot of another branch's UI is persuasive evidence of
   something that is not true.

9. **[PP-9] Record the change in `change-log.md`.** One entry per feature branch, written at the
   end of that branch's work — not one entry per commit. (Alternative: an entry after every change;
   it is simpler to remember but multiplies merge conflicts on a shared file, which is why the
   per-branch form is the default here.)
