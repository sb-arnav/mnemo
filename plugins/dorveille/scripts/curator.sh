#!/bin/bash
# dorveille curator — background skill-library consolidation.
#
# Hermes ships a curator that periodically merges narrow agent-created skills
# into class-level umbrellas, archives stale ones (never deletes), and respects
# pins. dorveille forged skills but never consolidated them, so the library could
# only grow into a flat sprawl. This is that pass: a separate `claude -p` agent,
# scoped to `forged-by: dorveille` skills only, reasons over the deterministic
# lifecycle signals from `dorveille-skill candidates` and umbrella-ifies the library.
#
# Triggered on demand (`dorveille curator [run|dry-run]`) or on a schedule (cron).
# Like every dorveille worker it runs DORVEILLE_REVIEWING=1 so it can't recurse.
set -uo pipefail

MODE="${1:-run}"   # run | dry-run
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DORVEILLE_HOME="${DORVEILLE_HOME:-$HOME/.dorveille}"
MODEL="${DORVEILLE_CURATOR_MODEL:-${DORVEILLE_REVIEW_MODEL:-claude-sonnet-4-6}}"
LOG="$DORVEILLE_HOME/logs/curator.log"
SKILLS_DIR="${DORVEILLE_SKILLS_DIR:-$HOME/.claude/skills}"
SKILL="$PLUGIN_ROOT/bin/dorveille-skill"
mkdir -p "$DORVEILLE_HOME/logs" "$DORVEILLE_HOME/pruned"

[ -f "$DORVEILLE_HOME/OFF" ] && exit 0
[ -n "${DORVEILLE_REVIEWING:-}" ] && exit 0
CLAUDE_BIN="$(command -v claude || echo "$HOME/.local/bin/claude")"
TODAY="$(date -u +%Y-%m-%d)"

CANDIDATES="$(DORVEILLE_HOME="$DORVEILLE_HOME" DORVEILLE_SKILLS_DIR="$SKILLS_DIR" python3 "$SKILL" candidates 2>/dev/null)"
COUNT="$(printf '%s\n' "$CANDIDATES" | grep -c $'\t' || true)"
if [ "$COUNT" -lt 2 ]; then
  echo "[$(date -u +%FT%TZ)] curator: only $COUNT forged skill(s) — nothing to consolidate" >>"$LOG"
  [ "$MODE" = "dry-run" ] && echo "Only $COUNT dorveille-forged skill(s); consolidation needs ≥2. Nothing to do."
  exit 0
fi

DRY=""
[ "$MODE" = "dry-run" ] && DRY="

═══════════════════════════════════════════════
DRY-RUN — REPORT ONLY. Do NOT move, edit, or write any file. Describe what you
WOULD do, then print the structured yaml block.
═══════════════════════════════════════════════"

SYS="$(cat "$PLUGIN_ROOT/prompts/curator.md")"
USER_MSG="Consolidate the dorveille-forged skill library. Today is $TODAY.

The forged-by:dorveille skills live under:
  $SKILLS_DIR/<name>/SKILL.md
Archive target (never delete): $DORVEILLE_HOME/pruned/<name>/

Candidate skills (name, usage signals, description) — these are the ONLY skills
you may touch; anything not in this list is off-limits:

$CANDIDATES

Inspect any candidate with Read/Glob on its directory. Verify a skill is
forged-by:dorveille (grep its frontmatter) before moving or editing it. Consolidate
per your instructions, archiving absorbed siblings to $DORVEILLE_HOME/pruned/.$DRY

When done, print the human summary + the required yaml block."

echo "[$(date -u +%FT%TZ)] curator START mode=$MODE model=$MODEL candidates=$COUNT" >>"$LOG"
timeout "${DORVEILLE_CURATOR_TIMEOUT:-600}" env \
  DORVEILLE_REVIEWING=1 DORVEILLE_HOME="$DORVEILLE_HOME" DORVEILLE_SKILLS_DIR="$SKILLS_DIR" \
  "$CLAUDE_BIN" -p \
    --model "$MODEL" \
    --permission-mode acceptEdits \
    --allowed-tools "Read,Bash,Write,Edit,Glob,Grep" \
    --add-dir "$DORVEILLE_HOME" --add-dir "$SKILLS_DIR" \
    --append-system-prompt "$SYS" \
    "$USER_MSG" </dev/null | tee -a "$LOG"
echo "[$(date -u +%FT%TZ)] curator DONE  mode=$MODE rc=$?" >>"$LOG"
exit 0
