#!/bin/bash
# mnemo review worker — the retrospective half of the loop.
#
# Spawned detached by reflect.sh (every N turns) and session-end.sh (catch-all).
# Reads the just-finished transcript and decides what to persist: facts about
# the user, agent notes, and reusable skills. Writes them back to mnemo's
# bounded store and to ~/.claude/skills.
#
# Runs the REAL claude binary headless. Recursion is prevented by the
# MNEMO_REVIEWING env sentinel: every mnemo hook no-ops when it's set, so the
# worker's own turns can't re-trigger this loop. (We can't use --bare — it
# skips credential discovery and lands "Not logged in".)
set -uo pipefail

TRANSCRIPT="${1:-}"
SESSION="${2:-unknown}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MNEMO_HOME="${MNEMO_HOME:-$HOME/.mnemo}"
MODEL="${MNEMO_REVIEW_MODEL:-claude-sonnet-4-6}"
LOG="$MNEMO_HOME/logs/review.log"
mkdir -p "$MNEMO_HOME/logs"

[ -n "${MNEMO_REVIEWING:-}" ] && exit 0
[ -f "$MNEMO_HOME/OFF" ] && exit 0
[ -f "$TRANSCRIPT" ] || { echo "[$(date -u +%FT%TZ)] skip: no transcript $TRANSCRIPT" >>"$LOG"; exit 0; }

CLAUDE_BIN="$(command -v claude || echo "$HOME/.local/bin/claude")"
MEM="$PLUGIN_ROOT/bin/mnemo-mem"
LESSON="$PLUGIN_ROOT/bin/mnemo-lesson"
SYS="$(cat "$PLUGIN_ROOT/prompts/combined-review.md")"
SKILLS_DIR="${MNEMO_SKILLS_DIR:-$HOME/.claude/skills}"
mkdir -p "$SKILLS_DIR"
TODAY="$(date -u +%Y-%m-%d)"
# Web-influence detection: did this session pull in web content (poisoning surface)?
if grep -qiE '"(WebFetch|WebSearch)"|web_search|tavily|"name":"mcp__' "$TRANSCRIPT" 2>/dev/null; then WEB=1; else WEB=0; fi

USER_MSG="A Claude Code session just ended. Its full transcript (JSONL, one message per line) is at:
  $TRANSCRIPT

Read it — focus on the user's own messages, any corrections, preferences they revealed, and any non-trivial technique or fix that emerged. Then also skim recent correction hints at:
  $MNEMO_HOME/corrections.jsonl

Then update memory and skills per your instructions, using these tools:

MEMORY (bounded; the CLI enforces the §-format and char caps — always use it, never edit the .md files by hand):
  python3 $MEM add|replace|remove user|memory \"<text>\"
    • user   = who this user is: identity, preferences, communication style, habits
    • memory = your notes: environment facts, project conventions, lessons learned
  Inspect first with:  python3 $MEM show user   /   python3 $MEM show memory

SKILLS (live, native Claude Code skills at $SKILLS_DIR/<name>/SKILL.md):
  • You may CREATE a new skill, or EDIT a skill whose frontmatter contains 'forged-by: mnemo'.
  • You must NEVER edit any other skill (human-authored or plugin skills are off-limits).
  • Today's date is $TODAY — new skills MUST carry the full frontmatter shape from
    your instructions (name, description, forged-by: mnemo, forged: $TODAY, uses: 0,
    last-used: never, contradicted: false).

PROVENANCE — REQUIRED for every lesson you write (this is what makes mnemo trustworthy):
After writing a memory entry OR forging a skill, register it so it carries provenance + a trust score:
  python3 $LESSON register --type memory|skill --target <user|memory|skill-name> \\
    --key \"<short unique substring of the entry / the skill name>\" --session \"$SESSION\" \\
    --trigger <correction|technique|web-research> [--web] \\
    --probe-q \"<a yes/no question whose correct answer encodes this lesson>\" --probe-a yes|no
  • trigger=correction  → the user corrected you (highest trust)
  • trigger=technique   → a non-trivial fix/workflow you discovered
  • trigger=web-research → the lesson is sourced from web content (lowest trust; treat as unverified)
  • add --web if THIS session involved web research (this session's web-influence = $WEB).
Low-trust lessons (web-sourced / unverified) are automatically HELD from injection until trust is raised — that is the intended safety behaviour, not a bug. Register honestly.

When finished, print a single line summarising what you changed (e.g. 'updated USER.md (registered, trust 85); forged skill deploy-staq (registered)'), or exactly 'Nothing to save.'"

echo "[$(date -u +%FT%TZ)] review START session=$SESSION model=$MODEL transcript=$TRANSCRIPT" >>"$LOG"
timeout "${MNEMO_REVIEW_TIMEOUT:-300}" env \
  MNEMO_REVIEWING=1 MNEMO_HOME="$MNEMO_HOME" \
  "$CLAUDE_BIN" -p \
    --model "$MODEL" \
    --permission-mode acceptEdits \
    --allowed-tools "Read,Bash,Write,Edit,Glob,Grep" \
    --add-dir "$MNEMO_HOME" --add-dir "$SKILLS_DIR" \
    --append-system-prompt "$SYS" \
    "$USER_MSG" </dev/null >>"$LOG" 2>&1
rc=$?
echo "[$(date -u +%FT%TZ)] review DONE  session=$SESSION rc=$rc" >>"$LOG"

# Phase 2 — independent verification gate over the lessons just registered.
# Separate process + separate prompt so the writer can't verify its own drift.
bash "$PLUGIN_ROOT/scripts/verify.sh" "$SESSION" "$TRANSCRIPT" >/dev/null 2>&1 || true
exit 0
