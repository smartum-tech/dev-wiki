---
title: AI Rules — Orchestration
class: curated
last-reviewed: never
---
# AI Rules — Orchestration

**APPLIES WHEN** an orchestrator has declared in your task prompt that you are one of several
agents working in parallel git worktrees against one shared Docker stack and one shared database.
That declaration is the only thing that puts you here.

**DOES NOT APPLY WHEN** you are the single assistant working beside a human who is present and can
answer you. Read [`ai-rules-pair-programming.md`](./ai-rules-pair-programming.md) instead — not as
well. Being in a linked worktree on its own does not put you in this mode; it only tells you that
you probably do not hold the dev-sandbox lease. See the mode router in
[`ai-instructions.md`](./ai-instructions.md).

Read [`ai-instructions.md`](./ai-instructions.md) first: it carries the facts about the
environment — what is shared, how worktrees and `node_modules` work, which lint scripts rewrite
your files — and the rules that are the same in both modes. This file adds the rules specific to
working under an orchestrator. It states no fact of its own about the environment: where it needs
one it cites that document, so the two mode files cannot drift apart in how they describe the
machine.

The one thing to internalise before the list: you have no human in your loop. Nobody will answer
a question you stop to ask, so a blocked agent that waits produces nothing at all. Do every part of
the task that is not blocked, then state the blocker and what you assumed in your final report to
the orchestrator.

`{{SANDBOX_SCRIPT}}` below is the project's sandbox script (links env files into a worktree, moves
the stack between checkouts); its subcommands are described in
[`docker-workflow.md`](./docker-workflow.md).

## Rules

1. **[OR-1] Work only in your own linked worktree, never in the main checkout.** The worktree
   indicator is only sound if orchestrated agents are always in a worktree and humans are always
   in the main checkout. And the main checkout is normally the directory a long-lived code index
   or dev stack has mounted, so writing there perturbs state somebody else is querying.

2. **[OR-2] If your task produces changes, commit, push and open your own pull request.** You are
   expected to finish the job end to end without waiting for a human to press anything. Write the
   commit message in English (`[U-1]`) and describe what the change does rather than which agent
   produced it.

   **A read-only task is the exception, and it is not a small one.** Reviewers, auditors and
   analysts — anything dispatched to inspect a branch rather than to change it — commit nothing,
   push nothing and open nothing. Their output is the report they return to the orchestrator. A
   reviewer that commits has contaminated the very branch it was asked to judge, and the next
   reviewer cannot tell your findings from the author's work.

3. **[OR-3] Open your PR against the branch below yours in the stack, and stop there.** Sub-PRs
   are stacked: the base is the branch your work builds on, not `{{MAIN_BRANCH}}`, and getting this
   wrong makes the diff show every commit from the branches beneath you. Do not merge, do not
   rebase, and never force-push — yours or anybody else's branch. The human owns merging the chain.

4. **[OR-4] Never install dependencies.** `{{PACKAGE_MANAGER}} install`, `add` and `update` are
   forbidden in a worktree: `node_modules` is symlinked in from the main checkout, so an install
   writes through the symlink into everyone else's tree. Bring tooling in with
   `{{SANDBOX_SCRIPT}} link-env` instead. If a task genuinely needs a new dependency, say so in
   your report and let the orchestrator sequence it.

5. **[OR-5] Only the lease holder may run commands that address the shared stack.** That covers
   starting or stopping the stack, any `docker compose` invocation, `docker logs`,
   `docker restart`, the sandbox script's `up|down`, opening the app in a browser, driving
   Playwright against a running app, and checking hot-reload output to confirm a build. Without the
   lease every one of those either fails on a name and port conflict or answers you about another
   branch's code — and the second is worse, because the answer looks valid. If you were not told
   you hold the lease, you do not.

6. **[OR-6] Never stop, kill, remove or recreate a container.** No `docker kill`, `docker rm`,
   `docker compose down`, `docker system prune`. The containers belong to whichever branch
   currently holds the lease, and killing them takes out that agent's work in the middle of a test
   run. Moving the stack is done with the sandbox script, by the lease holder, and by nobody else.

7. **[OR-7] Let migrations apply themselves; a rollback needs the orchestrator's approval and the
   lease.** *(Example — adapt to your backend.)* Three tiers:

   - **Adding a migration file is ordinary work.** Commit it like any other change.
   - **Explicit "apply migrations" commands are not part of that work.** Your migration lands when
     your branch holds the sandbox and the backend restarts on your code (`[U-4]`). Until then it
     does not need to have landed — that is the expected state of an agent without the lease, not
     an obstacle to work around. The in-container variants would address another branch's stack
     anyway (`[OR-5]`).
   - **Rollbacks are destructive.** One database serves every branch and every agent, so a
     rollback changes the schema under everyone, including agents mid-test. They are never yours to
     decide.

   A migration-status command only reads — use it freely.

8. **[OR-8] Do not touch sibling repositories.** Your worktree is the whole of your working set.
   Changes that belong in another checkout on the machine go into your report as a recommendation,
   not into a commit.

9. **[OR-9] Never touch `change-log.md` from a sub-PR.** N agents appending to one file conflict on
   every merge. One entry is written per feature branch, at the end, by whoever closes the branch —
   not by you, and not per commit. If a review-compliance routing table has no row for the file,
   that omission is intentional and must not be "fixed".

10. **[OR-10] Compare a red gate against the merge base before you touch anything.** A repository
    can have real, long-standing failures, and demanding absolute green makes agents either stall
    or start "fixing" unrelated code until the change is buried under foreign diff. So: run the
    gates relevant to what you touched; if one is red, re-run it **at the merge base** and prove
    the result is identical, pasting real output from both runs. Only a proven-identical red is
    acceptable — a red that differs from the base is yours to fix. Never repair a pre-existing
    failure in unrelated code as a side effect.

11. **[OR-11] Take the lease for your whole stack-dependent block, then release it once.** If you
    were granted it, keep it through everything that needs the stack — integration tests, e2e, the
    reviewers' hypothesis checks — and hand it back when that block is finished. Never ping-pong:
    acquiring and releasing repeatedly costs a full stack move each time. If your task turns out to
    need the stack and you were not granted the lease, stop and report that, rather than starting
    the stack yourself.

12. **[OR-12] Batch your review feedback into one round.** Once the lease leaves a branch, that
    branch's review context is gone: the code index has followed the stack to another directory
    and the shared database has moved on. Re-review therefore costs a full lease round-trip, so
    send findings as one set instead of trickling them.

13. **[OR-13] Treat the lease as assigned at planning time, not competed for at runtime.** Only one
    worktree may run the dev stack; that right is the **lease**, and the orchestrator grants it.
    Every subtask is classified up front as stack-needing or stack-free, and at most one
    stack-needing task is ever in flight. Stack-free work — unit tests, `tsc --noEmit`,
    non-mutating lint, tooling, documentation, review gates — runs in parallel freely and needs
    nothing but `link-env`. If a decomposition ends up with two parallel stack-needing tasks, that
    is a decomposition smell: merge them or sequence them.

14. **[OR-14] Do not move the lease off a branch whose review is still running.** When two tasks
    want it, the one closer to completion wins, and review of the current holder outranks
    acquisition by a new implementer, because review is what unblocks the merge chain. Nothing
    enforces this in software — the discipline is the only interlock there is.

15. **[OR-15] Run `{{SANDBOX_SCRIPT}} link-env` in your worktree before any gate, and never route
    around a missing lease with a manual build.** A fresh worktree has no `.env` and no
    `node_modules`, so `tsc --noEmit`, lint and test runners all fail outright until `link-env` has
    run; it touches no container and needs no stack, so it is always available to you. Manual
    builds are not a workaround for not holding the lease: containers rebuild via hot reload, and
    `tsc --noEmit` in the workspace you touched answers "does this compile" with no stack at all.

16. **[OR-16] Brief sub-agents like peers.** When you dispatch your own helpers, the prompt is
    all they have: state the goal, what is already ruled out, the exact files, and the scope. Say
    explicitly whether they are read-only (`[OR-2]`). Hand them a question, not your hypothesis —
    an agent given a conclusion to check tends to return it confirmed. Keep mechanical search on
    cheap models and judgement on yours (`[U-12]`).
