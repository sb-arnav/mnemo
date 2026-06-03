#!/bin/bash
# Stop hook — the turn-based memory/skill nudge.
#
# Copied from Hermes Agent's in-loop trigger (NousResearch/hermes-agent,
# agent/conversation_loop.py, MIT): fire the background review MID-SESSION,
# every N user turns, right after the response is delivered — never waiting for
# SessionEnd (which on short or WSL-killed sessions may never fire). Because the
# review runs as soon as turn N completes, the learning is captured before any
# later crash/kill.
#
# Like Hermes (their issue #22357), the turn count is HYDRATED FROM THE
# TRANSCRIPT rather than an in-memory counter: the hook runs in a fresh process
# each turn, so a per-invocation counter would be unreliable. We recompute the
# real user-turn count from the session file every time — robust and stateless.
# (We count genuine user prompts only, NOT tool-result lines, which also carry
# type=user and would otherwise inflate the count by 10–100x in Claude Code.)
set -uo pipefail

DORVEILLE_HOME="${DORVEILLE_HOME:-$HOME/.dorveille}"
[ -f "$DORVEILLE_HOME/OFF" ] && exit 0
[ -n "${DORVEILLE_REVIEWING:-}" ] && exit 0     # never reflect from inside a review worker
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
INTERVAL="${DORVEILLE_NUDGE_INTERVAL:-6}"

INPUT="$(cat 2>/dev/null || true)"
# Parse the hook payload AND count real user turns in the transcript in one pass.
read -r TRANSCRIPT SESSION TURNS < <(python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("", "unknown", 0); sys.exit(0)
tp = d.get("transcript_path", "")
sid = d.get("session_id", "unknown")
turns = 0
try:
    with open(tp, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                m = json.loads(line)
            except Exception:
                continue
            # a real user turn: type==user with a plain string content
            # (tool results are type==user but content is a list of blocks)
            if m.get("type") == "user" and isinstance((m.get("message") or {}).get("content"), str):
                turns += 1
except Exception:
    pass
print(tp, sid, turns)
' <<<"$INPUT" 2>/dev/null)

[ -z "${TRANSCRIPT:-}" ] && exit 0
[ -f "$TRANSCRIPT" ] || exit 0
TURNS="${TURNS:-0}"

mkdir -p "$DORVEILLE_HOME/state"
STATE="$DORVEILLE_HOME/state/$SESSION"
echo "$TURNS" > "$STATE.turns"             # session-end.sh reads this for its catch-all
last=$(cat "$STATE.reviewed" 2>/dev/null || echo 0)

# Fire once per crossing of an N-turn multiple, mid-session, detached.
if [ "$TURNS" -ge "$INTERVAL" ] && [ $((TURNS - last)) -ge "$INTERVAL" ]; then
  echo "$TURNS" > "$STATE.reviewed"
  nohup bash "$PLUGIN_ROOT/scripts/review.sh" "$TRANSCRIPT" "$SESSION" \
    >/dev/null 2>&1 &
fi
exit 0
