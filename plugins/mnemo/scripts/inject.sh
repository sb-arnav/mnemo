#!/bin/bash
# SessionStart hook — inject mnemo's frozen memory snapshot into the session.
# Soul + user-model + agent-notes, all bounded. This is the "loads it
# automatically before execution begins" half of the loop.
set -uo pipefail

MNEMO_HOME="${MNEMO_HOME:-$HOME/.mnemo}"
[ -f "$MNEMO_HOME/OFF" ] && exit 0
[ -n "${MNEMO_REVIEWING:-}" ] && exit 0     # don't inject into a review/curiosity worker
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MEM="$PLUGIN_ROOT/bin/mnemo-mem"

# Drain stdin (hook protocol sends JSON we don't need here).
cat >/dev/null 2>&1 || true

TEXT="$(MNEMO_HOME="$MNEMO_HOME" python3 "$MEM" inject 2>/dev/null)"
[ -z "$TEXT" ] && exit 0

# Emit via the SessionStart additionalContext channel.
python3 - "$TEXT" <<'PY' 2>/dev/null || true
import json, sys
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": sys.argv[1],
    }
}))
PY
exit 0
