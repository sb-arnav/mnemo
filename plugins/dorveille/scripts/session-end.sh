#!/bin/bash
# SessionEnd hook — catch-all retrospective. Most Claude Code sessions are
# shorter than the turn-based nudge interval, so without this they'd never
# get reviewed. Runs the worker once at the end if the session had real
# activity and hasn't been reviewed since its last trigger, then clears state.
set -uo pipefail

DORVEILLE_HOME="${DORVEILLE_HOME:-$HOME/.dorveille}"
[ -f "$DORVEILLE_HOME/OFF" ] && exit 0
[ -n "${DORVEILLE_REVIEWING:-}" ] && exit 0
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MIN_TURNS="${DORVEILLE_MIN_TURNS:-3}"

INPUT="$(cat 2>/dev/null || true)"
read -r TRANSCRIPT SESSION < <(python3 -c '
import json, sys
try: d = json.load(sys.stdin)
except Exception: d = {}
print(d.get("transcript_path", ""), d.get("session_id", "unknown"))
' <<<"$INPUT" 2>/dev/null)

[ -z "${TRANSCRIPT:-}" ] && exit 0
[ -f "$TRANSCRIPT" ] || exit 0

STATE="$DORVEILLE_HOME/state/$SESSION"
turns=$(cat "$STATE.turns" 2>/dev/null || echo 0)
last=$(cat "$STATE.reviewed" 2>/dev/null || echo 0)

if [ "$turns" -ge "$MIN_TURNS" ] && [ "$turns" -gt "$last" ]; then
  nohup bash "$PLUGIN_ROOT/scripts/review.sh" "$TRANSCRIPT" "$SESSION" \
    >/dev/null 2>&1 &
fi

# Keep the episodic-recall index fresh. Incremental (only changed sessions
# re-index), detached + silent so it never blocks session teardown.
nohup python3 "$PLUGIN_ROOT/bin/dorveille-recall" index >/dev/null 2>&1 &

rm -f "$STATE.turns" "$STATE.reviewed"
exit 0
