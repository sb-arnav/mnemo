#!/bin/bash
# dorveille curiosity loop — runs periodically (via cron/routine, not per-session).
#
# Where the review worker is reactive (learn from what just happened), the
# curiosity loop is proactive: it looks at the accumulated memory + skill
# library, picks ONE under-developed or stale area, does real research, and
# writes a concrete improvement PROPOSAL. It deliberately does NOT auto-apply —
# proposals land in ~/.dorveille/curiosity/ for review, keeping self-modification
# auditable (the known failure mode of self-improving agents is silent drift).
set -uo pipefail

DORVEILLE_HOME="${DORVEILLE_HOME:-$HOME/.dorveille}"
[ -f "$DORVEILLE_HOME/OFF" ] && exit 0
[ -f "$DORVEILLE_HOME/CURIOSITY_OFF" ] && exit 0
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MODEL="${DORVEILLE_CURIOSITY_MODEL:-claude-sonnet-4-6}"
LOG="$DORVEILLE_HOME/logs/curiosity.log"
mkdir -p "$DORVEILLE_HOME/curiosity" "$DORVEILLE_HOME/logs"

CLAUDE_BIN="$(command -v claude || echo "$HOME/.local/bin/claude")"
OUT="$DORVEILLE_HOME/curiosity/$(date -u +%Y-%m-%d-%H%M).md"
SYS="$(cat "$PLUGIN_ROOT/prompts/curiosity.md")"

USER_MSG="Review the current state of this agent's long-term knowledge:
  - $DORVEILLE_HOME/MEMORY.md and $DORVEILLE_HOME/USER.md (run: python3 $PLUGIN_ROOT/bin/dorveille-mem show memory / show user)
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
timeout "${DORVEILLE_CURIOSITY_TIMEOUT:-600}" env \
  DORVEILLE_REVIEWING=1 DORVEILLE_HOME="$DORVEILLE_HOME" \
  "$CLAUDE_BIN" -p \
    --model "$MODEL" \
    --permission-mode acceptEdits \
    --allowed-tools "Read,Bash,Glob,Grep,WebSearch,WebFetch,Write" \
    --add-dir "$DORVEILLE_HOME" \
    --append-system-prompt "$SYS" \
    "$USER_MSG" </dev/null >>"$LOG" 2>&1
rc=$?
echo "[$(date -u +%FT%TZ)] curiosity DONE rc=$rc out=$OUT" >>"$LOG"
exit 0
