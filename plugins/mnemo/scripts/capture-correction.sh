#!/bin/bash
# UserPromptSubmit hook — capture correction-shaped prompts the moment they
# happen (before the fix), into mnemo's own corrections feed. A user
# correction is one of Hermes' first-class skill-creation triggers; the
# review worker reads this feed to know what to encode.
#
# This is a HINT feed, not a judgement — the heuristic is deliberately loose
# and anchored to reduce false positives; the review worker is the real judge.
# Captures only; injects nothing; never blocks.
set -uo pipefail

MNEMO_HOME="${MNEMO_HOME:-$HOME/.mnemo}"
[ -f "$MNEMO_HOME/OFF" ] && exit 0
[ -n "${MNEMO_REVIEWING:-}" ] && exit 0     # don't capture the worker's own prompt

INPUT="$(cat 2>/dev/null || true)"
PROMPT="$(python3 -c '
import json, sys
try: print(json.load(sys.stdin).get("prompt", ""))
except Exception: pass
' <<<"$INPUT" 2>/dev/null)"
[ -z "${PROMPT:-}" ] && exit 0

# Correction signals: anchored short words at the start, plus strong phrases.
if printf '%s' "$PROMPT" | grep -qiE \
  "^(no\b|nope|stop\b|wrong\b|don'?t\b|actually\b|ugh|that'?s not|thats not|that'?s wrong)|i told you|you keep|stop doing|don'?t do that|why did you|not what i|too verbose|i hate when|you always"; then
  MNEMO_HOME="$MNEMO_HOME" python3 - "$PROMPT" <<'PY' 2>/dev/null || true
import json, os, sys
from datetime import datetime, timezone
home = os.environ.get("MNEMO_HOME", os.path.expanduser("~/.mnemo"))
os.makedirs(home, exist_ok=True)
rec = {
    "ts": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "type": "correction",
    "text": sys.argv[1][:500],
}
with open(os.path.join(home, "corrections.jsonl"), "a", encoding="utf-8") as f:
    f.write(json.dumps(rec, ensure_ascii=False) + "\n")
PY
fi
exit 0
