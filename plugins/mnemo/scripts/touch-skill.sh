#!/bin/bash
# PostToolUse hook — usage telemetry for forged skills.
#
# When the Skill tool invokes a mnemo-forged skill, bump its uses/last-used
# frontmatter. That telemetry is what lets the curator tell a skill that earns
# its keep from one that's gone stale. Best-effort and silent: it must never
# slow down or interfere with the main session. mnemo-skill touch is a no-op for
# any skill that isn't forged-by:mnemo, so this is safe to fire on every Skill call.
set -uo pipefail

MNEMO_HOME="${MNEMO_HOME:-$HOME/.mnemo}"
[ -f "$MNEMO_HOME/OFF" ] && exit 0
[ -n "${MNEMO_REVIEWING:-}" ] && exit 0
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

INPUT="$(cat 2>/dev/null || true)"
NAME="$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if (d.get("tool_name") or "").lower() != "skill":
    sys.exit(0)
ti = d.get("tool_input") or {}
# the Skill tool names the skill in one of these fields depending on version
name = ti.get("skill") or ti.get("name") or ti.get("command") or ""
print(str(name).strip())
' 2>/dev/null || true)"

[ -z "${NAME:-}" ] && exit 0
# normalise plugin:skill → skill, strip leading slash
NAME="${NAME##*:}"; NAME="${NAME#/}"
MNEMO_HOME="$MNEMO_HOME" python3 "$PLUGIN_ROOT/bin/mnemo-skill" touch "$NAME" >/dev/null 2>&1 || true
exit 0
