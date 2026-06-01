#!/bin/bash
# Stop hook — the periodic "nudge". Fires after every assistant turn; counts
# turns per session and, every N turns, spawns the background review worker
# (detached, non-blocking). Mirrors Hermes' turn-based memory/skill nudge.
set -uo pipefail

MNEMO_HOME="${MNEMO_HOME:-$HOME/.mnemo}"
[ -f "$MNEMO_HOME/OFF" ] && exit 0
[ -n "${MNEMO_REVIEWING:-}" ] && exit 0     # never reflect from inside a review worker
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
INTERVAL="${MNEMO_NUDGE_INTERVAL:-8}"

INPUT="$(cat 2>/dev/null || true)"
read -r TRANSCRIPT SESSION < <(python3 -c '
import json, sys
try: d = json.load(sys.stdin)
except Exception: d = {}
print(d.get("transcript_path", ""), d.get("session_id", "unknown"))
' <<<"$INPUT" 2>/dev/null)

[ -z "${TRANSCRIPT:-}" ] && exit 0
[ -f "$TRANSCRIPT" ] || exit 0

mkdir -p "$MNEMO_HOME/state"
STATE="$MNEMO_HOME/state/$SESSION"
turns=$(( $(cat "$STATE.turns" 2>/dev/null || echo 0) + 1 ))
echo "$turns" > "$STATE.turns"
last=$(cat "$STATE.reviewed" 2>/dev/null || echo 0)

if [ "$turns" -ge "$INTERVAL" ] && [ $((turns - last)) -ge "$INTERVAL" ]; then
  echo "$turns" > "$STATE.reviewed"
  nohup bash "$PLUGIN_ROOT/scripts/review.sh" "$TRANSCRIPT" "$SESSION" \
    >/dev/null 2>&1 &
fi
exit 0
