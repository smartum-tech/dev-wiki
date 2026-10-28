#!/usr/bin/env bash
# dev-wiki installer — puts the wiki/ knowledge tree and its maintenance skills into the
# current git repository and wires them into the coding agents it uses.
#
#   curl -fsSL https://raw.githubusercontent.com/smartum-tech/dev-wiki/master/install.sh | bash
#
# Options:
#   --agents LIST   comma-separated: claude,codex,cursor,gemini,pi (default: detected)
#   --ref REF       branch or tag of dev-wiki to install (default: master)
#   --from DIR      install from a local checkout of dev-wiki instead of downloading
#   --target DIR    repository to install into (default: the git root of the current dir)
#   --yes           do not ask; accept the detected agents
#   --no-launch     do not offer to start the bootstrap afterwards (use from inside an agent)
#
# What it writes, and nothing else:
#   wiki/                                the tree, plus wiki/dev-wiki.yml (settings)
#   .claude/skills/wiki-*                if claude   — Claude Code
#   .agents/skills/wiki-*                if codex, cursor, gemini or pi
#   CLAUDE.md / AGENTS.md / GEMINI.md    a <!-- dev-wiki:start --> block, inserted once
#   .claude/prompts/post-compact-reminder.md, and .claude/settings.json only if it is absent
#
# It never commits, never overwrites an existing file, and refuses to run twice.

set -euo pipefail

REPO="smartum-tech/dev-wiki"
REF="master"
FROM=""
TARGET=""
AGENTS=""
ASSUME_YES=0
LAUNCH=1
ALL_AGENTS="claude codex cursor gemini pi"

say()  { printf '%s\n' "$*"; }
info() { printf '\033[34m›\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

# Interactive only when a terminal is reachable: under `curl | bash` stdin is the script.
has_tty() { [ -r /dev/tty ] && [ -w /dev/tty ] && { : < /dev/tty; } 2>/dev/null; }
ask() { # ask "question" default → echoes the answer
  local reply=""
  if [ "$ASSUME_YES" -eq 0 ] && has_tty; then
    printf '%s ' "$1" > /dev/tty
    IFS= read -r reply < /dev/tty || reply=""
  fi
  printf '%s' "${reply:-$2}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --agents)    AGENTS="${2:-}"; shift 2 ;;
    --ref)       REF="${2:-}"; shift 2 ;;
    --from)      FROM="${2:-}"; shift 2 ;;
    --target)    TARGET="${2:-}"; shift 2 ;;
    --yes|-y)    ASSUME_YES=1; shift ;;
    --no-launch) LAUNCH=0; shift ;;
    -h|--help)   grep '^#' "$0" | tail -n +2 | cut -c3-; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
done

# ── 1. Where to install ───────────────────────────────────────────────────────────────────

command -v git >/dev/null 2>&1 || die "git is required."
if [ -z "$TARGET" ]; then
  TARGET="$(git rev-parse --show-toplevel 2>/dev/null)" \
    || die "not inside a git repository — cd into the repo you want the wiki in, or pass --target."
fi
[ -d "$TARGET/.git" ] || [ -f "$TARGET/.git" ] || die "$TARGET is not the root of a git repository."
cd "$TARGET"

[ -f wiki/dev-wiki.yml ] && die "dev-wiki is already installed here (wiki/dev-wiki.yml exists). Run /wiki-bootstrap to continue it."
[ -e wiki ] && die "a wiki/ already exists and is not dev-wiki's. Move it aside first — the bootstrap can compile it as legacy docs."

# ── 2. Get the template ───────────────────────────────────────────────────────────────────

CLEANUP=""
trap '[ -n "$CLEANUP" ] && rm -rf "$CLEANUP"' EXIT

if [ -n "$FROM" ]; then
  SRC="$(cd "$FROM" && pwd)"
  COMMIT="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo unknown)"
else
  command -v curl >/dev/null 2>&1 || die "curl is required (or pass --from <local checkout>)."
  command -v tar  >/dev/null 2>&1 || die "tar is required (or pass --from <local checkout>)."
  CLEANUP="$(mktemp -d)"
  info "Downloading $REPO@$REF"
  curl -fsSL "https://codeload.github.com/$REPO/tar.gz/$REF" | tar -xz -C "$CLEANUP" \
    || die "download failed — check the ref ($REF) and your network."
  SRC="$(find "$CLEANUP" -mindepth 1 -maxdepth 1 -type d | head -1)"
  COMMIT="$(git ls-remote "https://github.com/$REPO" "$REF" 2>/dev/null | cut -c1-7)"
  COMMIT="${COMMIT:-unknown}"
fi
[ -d "$SRC/template/wiki" ] && [ -d "$SRC/template/skills" ] || die "$SRC does not look like dev-wiki (no template/)."

# ── 3. Which agents ───────────────────────────────────────────────────────────────────────

detect() {
  local found=""
  { [ -d .claude ] || [ -f CLAUDE.md ] || command -v claude >/dev/null 2>&1; } && found="$found claude"
  { [ -d .codex ] || command -v codex >/dev/null 2>&1; } && found="$found codex"
  { [ -d .cursor ] || [ -f .cursorrules ] || command -v cursor-agent >/dev/null 2>&1; } && found="$found cursor"
  { [ -d .gemini ] || [ -f GEMINI.md ] || command -v gemini >/dev/null 2>&1; } && found="$found gemini"
  { [ -d .pi ] || command -v pi >/dev/null 2>&1; } && found="$found pi"
  # AGENTS.md alone says "some AGENTS.md agent"; Codex is the most common reader.
  [ -z "$found" ] && [ -f AGENTS.md ] && found=" codex"
  [ -z "$found" ] && found=" claude codex"
  printf '%s' "${found# }"
}

if [ -z "$AGENTS" ]; then
  AGENTS="$(detect)"
  say ""
  say "Agents to wire: $AGENTS"
  say "  (all supported: $ALL_AGENTS)"
  AGENTS="$(ask "Press Enter to accept, or type your own list (space or comma separated):" "$AGENTS")"
fi
AGENTS=" $(printf '%s' "$AGENTS" | tr ',' ' ') "
for a in $AGENTS; do
  case " $ALL_AGENTS " in *" $a "*) ;; *) die "unknown agent: $a (supported: $ALL_AGENTS)" ;; esac
done
want() { case "$AGENTS" in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

SKILL_DIRS=""
want claude && SKILL_DIRS="$SKILL_DIRS .claude/skills"
{ want codex || want cursor || want gemini || want pi; } && SKILL_DIRS="$SKILL_DIRS .agents/skills"
CONTEXT_FILES=""
want claude && CONTEXT_FILES="$CONTEXT_FILES CLAUDE.md"
{ want codex || want cursor || want pi; } && CONTEXT_FILES="$CONTEXT_FILES AGENTS.md"
want gemini && CONTEXT_FILES="$CONTEXT_FILES GEMINI.md"

# Refuse before writing anything, so a half-install never happens.
for d in $SKILL_DIRS; do
  for s in "$SRC"/template/skills/wiki-*/; do
    n="$(basename "$s")"
    [ -e "$d/$n" ] && die "$d/$n already exists — remove it or install with a different --agents list."
  done
done

# ── 4. Write ──────────────────────────────────────────────────────────────────────────────

cp -R "$SRC/template/wiki" wiki
ok "wiki/"

for d in $SKILL_DIRS; do
  mkdir -p "$d"
  for s in "$SRC"/template/skills/wiki-*/; do cp -R "${s%/}" "$d/"; done
  [ -e "$d/AUTHORING.md" ] || cp "$SRC/template/skills/AUTHORING.md" "$d/AUTHORING.md"
  ok "$d/wiki-{bootstrap,ingest,journal,lint,audit}"
done

# The block goes right under the file's H1 title if it has one, else at the very top: it
# says "read this first", and the bottom of a long instruction file is where nobody reads.
BLOCK="$SRC/template/context-block.md"
insert_block() {
  local f="$1" tmp first
  if [ -f "$f" ] && grep -q '<!-- dev-wiki:start -->' "$f"; then
    ok "$f (block already present)"; return
  fi
  if [ ! -f "$f" ]; then
    cp "$BLOCK" "$f"; ok "$f (created)"; return
  fi
  tmp="$(mktemp)"
  IFS= read -r first < "$f" || first=""
  case "$first" in
    "# "*) { printf '%s\n\n' "$first"; cat "$BLOCK"; printf '\n'; tail -n +2 "$f"; } > "$tmp" ;;
    *)     { cat "$BLOCK"; printf '\n'; cat "$f"; } > "$tmp" ;;
  esac
  cat "$tmp" > "$f"; rm -f "$tmp"
  ok "$f (block inserted)"
}
for f in $CONTEXT_FILES; do insert_block "$f"; done

TODO=""
if want claude; then
  mkdir -p .claude/prompts
  if [ -e .claude/prompts/post-compact-reminder.md ]; then
    TODO="$TODO merge-post-compact-reminder"
    warn ".claude/prompts/post-compact-reminder.md exists — left alone; the bootstrap merges ours into it."
  else
    cp "$SRC/template/hooks/post-compact-reminder.md" .claude/prompts/post-compact-reminder.md
    ok ".claude/prompts/post-compact-reminder.md"
  fi
  if [ -e .claude/settings.json ]; then
    if grep -q 'post-compact-reminder' .claude/settings.json; then
      ok ".claude/settings.json (hook already wired)"
    else
      TODO="$TODO merge-claude-hook"
      warn ".claude/settings.json exists — not edited; the bootstrap adds the post-compact hook to it."
    fi
  else
    cp "$SRC/template/hooks/claude-settings.json" .claude/settings.json
    ok ".claude/settings.json (post-compact hook)"
  fi
fi

yaml_list() { local out="" x; for x in $1; do out="$out${out:+, }$x"; done; printf '[%s]' "$out"; }
{
  printf '# dev-wiki settings. Written by the installer and /wiki-bootstrap; edit by hand freely.\n'
  printf '# Every wiki skill reads this file first.\n'
  printf 'version: 1\n'
  printf 'installed: { source: https://github.com/%s, ref: %s, commit: %s, date: %s }\n' \
    "$REPO" "$REF" "$COMMIT" "$(date +%F)"
  printf 'agents: %s\n' "$(yaml_list "$AGENTS")"
  printf '# every copy of the wiki skills; they are kept byte-identical (wiki-lint checks)\n'
  printf 'skill-dirs: %s\n' "$(yaml_list "$SKILL_DIRS")"
  printf '# files carrying the <!-- dev-wiki:start --> block\n'
  printf 'context-files: %s\n' "$(yaml_list "$CONTEXT_FILES")"
  printf '# setup steps the installer left to /wiki-bootstrap recon\n'
  printf 'todo: %s\n' "$(yaml_list "$TODO")"
  cat "$SRC/template/dev-wiki.project.yml"
} > wiki/dev-wiki.yml
ok "wiki/dev-wiki.yml"

# ── 5. Next step ──────────────────────────────────────────────────────────────────────────

say ""
say "Installed. Nothing is committed — review with: git status"
say ""
say "Next: run the bootstrap in your agent. It reads the code, fills what it can, and then"
say "walks you through the guides one at a time. You can stop and resume it any time."
want claude && say "  Claude Code   /wiki-bootstrap"
want codex  && say "  Codex         \$wiki-bootstrap"
want cursor && say "  Cursor        /wiki-bootstrap"
want gemini && say "  Gemini CLI    ask: \"run the wiki-bootstrap skill\" (skills may need /skills enable)"
want pi     && say "  pi            /skill:wiki-bootstrap   (needs \"enableSkillCommands\": true)"
say ""

if [ "$LAUNCH" -eq 1 ] && [ "$ASSUME_YES" -eq 0 ] && has_tty; then
  if want claude && command -v claude >/dev/null 2>&1; then
    case "$(ask "Start the bootstrap in Claude Code now? [Y/n]" y)" in
      [Yy]*) exec claude "/wiki-bootstrap" < /dev/tty ;;
    esac
  elif want codex && command -v codex >/dev/null 2>&1; then
    case "$(ask "Start the bootstrap in Codex now? [Y/n]" y)" in
      [Yy]*) exec codex "\$wiki-bootstrap" < /dev/tty ;;
    esac
  fi
fi
