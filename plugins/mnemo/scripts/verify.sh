#!/bin/bash
# Phase 2 — the independent verification gate.
#
# Runs AFTER the review worker, as a SEPARATE `claude -p` pass. The writer that
# created the lessons can't be trusted to catch its own drift, so a fresh,
# skeptical agent challenges each unverified lesson on four axes (durable vs
# env-artifact, contradiction, web-poisoning, regression) and quarantines any
# that fail — physically pulling them from the live store. This is the property
# Hermes never had.
set -uo pipefail

SESSION="${1:-unknown}"
TRANSCRIPT="${2:-}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MNEMO_HOME="${MNEMO_HOME:-$HOME/.mnemo}"
MODEL="${MNEMO_VERIFY_MODEL:-${MNEMO_REVIEW_MODEL:-claude-sonnet-4-6}}"
LOG="$MNEMO_HOME/logs/verify.log"
mkdir -p "$MNEMO_HOME/logs"

[ -f "$MNEMO_HOME/OFF" ] && exit 0
LESSON="$PLUGIN_ROOT/bin/mnemo-lesson"
MEM="$PLUGIN_ROOT/bin/mnemo-mem"
SKILLS_DIR="${MNEMO_SKILLS_DIR:-$HOME/.claude/skills}"
CLAUDE_BIN="$(command -v claude || echo "$HOME/.local/bin/claude")"

UNV="$(MNEMO_HOME="$MNEMO_HOME" python3 "$LESSON" unverified 2>/dev/null)"
if [ -z "$UNV" ] || [ "$UNV" = "(none)" ]; then
  echo "[$(date -u +%FT%TZ)] verify: nothing unverified session=$SESSION" >>"$LOG"
  exit 0
fi

SYS="$(cat "$PLUGIN_ROOT/prompts/verify.md")"
USER_MSG="Independent verification pass. The review agent just wrote these lessons; they are UNVERIFIED:

$UNV

The source-session transcript (to check poisoning — where a 'fact' actually came from) is at:
  $TRANSCRIPT

Inspect existing trusted knowledge:
  python3 $MEM show user
  python3 $MEM show memory
  skill library under: $SKILLS_DIR

Rule on EACH lesson by id:
  python3 $LESSON verify <id> [--trust N]                    # survives all four axes
  python3 $LESSON quarantine <id> --reason \"<axis + why>\"    # fails an axis (removes from live store)

When done, print one line: how many passed, how many quarantined."

echo "[$(date -u +%FT%TZ)] verify START session=$SESSION model=$MODEL" >>"$LOG"
timeout "${MNEMO_VERIFY_TIMEOUT:-240}" env \
  MNEMO_REVIEWING=1 MNEMO_HOME="$MNEMO_HOME" MNEMO_SKILLS_DIR="$SKILLS_DIR" \
  "$CLAUDE_BIN" -p \
    --model "$MODEL" \
    --permission-mode acceptEdits \
    --allowed-tools "Read,Bash,Grep,Glob" \
    --add-dir "$MNEMO_HOME" --add-dir "$SKILLS_DIR" \
    --append-system-prompt "$SYS" \
    "$USER_MSG" </dev/null >>"$LOG" 2>&1
echo "[$(date -u +%FT%TZ)] verify DONE  session=$SESSION rc=$?" >>"$LOG"
exit 0
