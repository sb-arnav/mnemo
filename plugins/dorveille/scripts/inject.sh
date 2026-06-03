#!/bin/bash
# SessionStart hook — inject dorveille's frozen memory snapshot into the session.
# Soul + user-model + agent-notes, all bounded. This is the "loads it
# automatically before execution begins" half of the loop.
set -uo pipefail

DORVEILLE_HOME="${DORVEILLE_HOME:-$HOME/.dorveille}"
[ -f "$DORVEILLE_HOME/OFF" ] && exit 0
[ -n "${DORVEILLE_REVIEWING:-}" ] && exit 0     # don't inject into a review/curiosity worker
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MEM="$PLUGIN_ROOT/bin/dorveille-mem"

# Drain stdin (hook protocol sends JSON we don't need here).
cat >/dev/null 2>&1 || true

TEXT="$(DORVEILLE_HOME="$DORVEILLE_HOME" python3 "$MEM" inject 2>/dev/null)"
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
