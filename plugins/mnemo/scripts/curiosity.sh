#!/bin/bash
# mnemo curiosity loop — runs periodically (via cron/routine, not per-session).
#
# Where the review worker is reactive (learn from what just happened), the
# curiosity loop is proactive: it looks at the accumulated memory + skill
# library, picks ONE under-developed or stale area, does real research, and
# writes a concrete improvement PROPOSAL. It deliberately does NOT auto-apply —
# proposals land in ~/.mnemo/curiosity/ for review, keeping self-modification
# auditable (the known failure mode of self-improving agents is silent drift).
set -uo pipefail

MNEMO_HOME="${MNEMO_HOME:-$HOME/.mnemo}"
[ -f "$MNEMO_HOME/OFF" ] && exit 0
[ -f "$MNEMO_HOME/CURIOSITY_OFF" ] && exit 0
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MODEL="${MNEMO_CURIOSITY_MODEL:-claude-sonnet-4-6}"
LOG="$MNEMO_HOME/logs/curiosity.log"
mkdir -p "$MNEMO_HOME/curiosity" "$MNEMO_HOME/logs"

CLAUDE_BIN="$(command -v claude || echo "$HOME/.local/bin/claude")"
OUT="$MNEMO_HOME/curiosity/$(date -u +%Y-%m-%d-%H%M).md"
SYS="$(cat "$PLUGIN_ROOT/prompts/curiosity.md")"

USER_MSG="Review the current state of this agent's long-term knowledge:
  - $MNEMO_HOME/MEMORY.md and $MNEMO_HOME/USER.md (run: python3 $PLUGIN_ROOT/bin/mnemo-mem show memory / show user)
  - the skill library at $HOME/.claude/skills (list dirs; read a few SKILL.md headers)

Pick exactly ONE area that is under-developed, stale, thin, or that the user
clearly cares about but the library handles weakly. Do real research (web
search/fetch is allowed) and write a CONCRETE, specific improvement proposal
to:
  $OUT

The proposal should be directly usable: an exact draft skill, or an exact
memory refinement, with sources. No generic advice, no slop. If nothing is
worth proposing right now, write a one-line note saying so and stop."

echo "[$(date -u +%FT%TZ)] curiosity START model=$MODEL out=$OUT" >>"$LOG"
timeout "${MNEMO_CURIOSITY_TIMEOUT:-600}" env \
  MNEMO_REVIEWING=1 MNEMO_HOME="$MNEMO_HOME" \
  "$CLAUDE_BIN" -p \
    --model "$MODEL" \
    --permission-mode acceptEdits \
    --allowed-tools "Read,Bash,Glob,Grep,WebSearch,WebFetch,Write" \
    --add-dir "$MNEMO_HOME" \
    --append-system-prompt "$SYS" \
    "$USER_MSG" </dev/null >>"$LOG" 2>&1
rc=$?
echo "[$(date -u +%FT%TZ)] curiosity DONE rc=$rc out=$OUT" >>"$LOG"
exit 0
