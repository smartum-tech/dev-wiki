---
title: "Code-query tool — how agents use {{CODE_QUERY_TOOL}}"
class: compiled
covers: []                 # fill when adopting — e.g. .mcp.json, the indexer's compose service
last-verified: never
verified-by: boilerplate
sources: []
---

# Code-query tool

The wiki's boundary principle: *if a query over the code can answer it, it does not belong in the
wiki.* `{{CODE_QUERY_TOOL}}` is how agents run that query: a code-knowledge-graph MCP server
(graphify or similar) if the project installed one, otherwise grep/Glob/LSP. Do not require the
graph — the principle holds without it — but when one exists, know what it is and what it is not.

## What an index describes

- **A working tree, not a commit.** A file you save and never commit is in the index seconds later;
  a commit, branch switch or stash is not an event a file-watcher can even observe. The index agrees
  with a commit only by coincidence. So a provenance marker cannot be a commit SHA — record the
  path plus a rebuild timestamp or tree hash.
- **One directory.** A container bind-mounted on `./` describes the checkout compose was started in.
  Another worktree on the same host still reaches the same port and gets confident answers about a
  different tree — a wrong answer, not an error. Hence `ai-instructions.md` U-8: trust it only when
  your working directory is the covered one, and say so when you decline to.
- **Code only, usually.** Ignore files typically drop markdown, yaml, html, images, `docs/`,
  `wiki/`, `specs/` and SQL so extraction needs no LLM key. The graph can say nothing about
  documentation or specs, and a docs-only branch is **invisible** to it — a graph that shows no
  difference is not evidence that such a branch changed nothing.
- **A lagging view.** One poll interval plus an incremental rebuild: a query fired right after a
  write can still be answered from the previous state.

How it is *served* is a per-host fact (a long-lived dev container, or a graph built from the pushed
commit and served over stdio on an unattended runner, which has no watcher and no lag); the
*interface* (an MCP server wired by the harness before the session starts) is not. Agents never
build or run the indexer themselves.

## Where a tool runs is not where it is available

Establish which machine you are on before diagnosing a missing tool — `hostname` answers it —
because the same symptom has different correct responses on a dev box, an unattended runner and a
laptop. An address that resolves from one does not from another; use a mesh-VPN hostname rather than
a LAN IP for anything shared. A service deliberately bound to loopback is available nowhere else, and
"re-point the config at the other host" is not the missing one-liner — there is no endpoint to
point at. **One dead server is not "MCP is unavailable here"**: an agent that generalises from a
failed index will skip a tool it has.

Instruction copies (CLAUDE.md, AGENTS.md, skill files, and PreToolUse hooks) that carry the same
remedy are hand-kept, and a correction lands in all of them or it half-lands. Hooks fire first, then
prompt files, then skills; hooks are the ones sweeps miss. **Do not trust a written count of the
copies — count them at the point of use** (`grep -rl <the address> .`).

## Failure modes of a containerised indexer

*Applies when the indexer runs in a container with a bind-mounted output directory; skip it for an
indexer that runs on the host or per session.*

- **Fresh checkout, unwritable output dir.** The output folder is gitignored, so a fresh worktree
  lacks it and the indexer creates it itself. Write permission is tested **once per checkout**, on
  the first start — which is why a long-lived main checkout never sees it and the bug reads as
  intermittent when it is deterministic. On Linux the bind mount passes the host's real uid through,
  so an image user with a different uid gets `EACCES` and the container never starts.
- **macOS cannot reproduce it.** Docker Desktop's VirtioFS `fakeowner` makes every parent look owned
  and writable. "Works on my Mac" is worth nothing for bind-mount ownership; test on the container's
  own filesystem. Fix by running the service as the host's uid via env (digits in the untracked
  `.env`, never `$(id -u)` — compose does not execute it).
- **A partial index is worse than a crash.** An extractor that swallows per-file cache-write
  failures into warnings writes a silently incomplete graph and exits 0; queries
  return results that are simply missing things, and hooks gating on "graph file present" point
  agents at it with full confidence. After changing the uid, **check ownership, not output**:
  `find <out-dir> ! -uid $(id -u)` must return nothing; a green full extraction proves only that
  nothing has yet needed a file the old uid owns.
- **`rm -rf` of a tree the container's uid owns cannot complete without root** — deleting needs
  write permission on the *containing* directory. It gets part-way and stops, reporting success per
  file: the only outcome that looks done. Move the stale tree aside (`mv`, which needs only the
  parent) and remove it later under `sudo`.
- **Fixes on the wrong side of the ownership boundary don't work**: `mkdir -p` in the entrypoint
  (same uid, same wall), `try/except` around the mkdir (edits a vendored package and trades a loud
  failure for a quiet one), tracking the output dir with a placeholder (git carries no ownership), a
  named volume (the hooks need the file on the host). The uid the container runs as is the only
  lever on the host's side.

## What the tool is for, in practice

Use it to answer structural questions (who calls this, what imports that, where is this defined)
before reading whole files, and to *verify* a wiki claim rather than to store it. Where a symbol
resolves, cite the symbol in docs instead of a line number. If the query returns nothing, fall back
to Grep/Glob, and if the index doesn't cover your tree, say so and fall back — never answer from a
tree you cannot confirm is yours.
