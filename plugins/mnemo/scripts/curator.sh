#!/bin/bash
# mnemo curator — background skill-library consolidation.
#
# Hermes ships a curator that periodically merges narrow agent-created skills
# into class-level umbrellas, archives stale ones (never deletes), and respects
# pins. mnemo forged skills but never consolidated them, so the library could
# only grow into a flat sprawl. This is that pass: a separate `claude -p` agent,
# scoped to `forged-by: mnemo` skills only, reasons over the deterministic
# lifecycle signals from `mnemo-skill candidates` and umbrella-ifies the library.
#
# Triggered on demand (`mnemo curator [run|dry-run]`) or on a schedule (cron).
# Like every mnemo worker it runs MNEMO_REVIEWING=1 so it can't recurse.
set -uo pipefail

MODE="${1:-run}"   # run | dry-run
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MNEMO_HOME="${MNEMO_HOME:-$HOME/.mnemo}"
MODEL="${MNEMO_CURATOR_MODEL:-${MNEMO_REVIEW_MODEL:-claude-sonnet-4-6}}"
LOG="$MNEMO_HOME/logs/curator.log"
SKILLS_DIR="${MNEMO_SKILLS_DIR:-$HOME/.claude/skills}"
SKILL="$PLUGIN_ROOT/bin/mnemo-skill"
mkdir -p "$MNEMO_HOME/logs" "$MNEMO_HOME/pruned"

[ -f "$MNEMO_HOME/OFF" ] && exit 0
[ -n "${MNEMO_REVIEWING:-}" ] && exit 0
CLAUDE_BIN="$(command -v claude || echo "$HOME/.local/bin/claude")"
TODAY="$(date -u +%Y-%m-%d)"

CANDIDATES="$(MNEMO_HOME="$MNEMO_HOME" MNEMO_SKILLS_DIR="$SKILLS_DIR" python3 "$SKILL" candidates 2>/dev/null)"
COUNT="$(printf '%s\n' "$CANDIDATES" | grep -c $'\t' || true)"
if [ "$COUNT" -lt 2 ]; then
  echo "[$(date -u +%FT%TZ)] curator: only $COUNT forged skill(s) — nothing to consolidate" >>"$LOG"
  [ "$MODE" = "dry-run" ] && echo "Only $COUNT mnemo-forged skill(s); consolidation needs ≥2. Nothing to do."
  exit 0
fi

DRY=""
[ "$MODE" = "dry-run" ] && DRY="

═══════════════════════════════════════════════
DRY-RUN — REPORT ONLY. Do NOT move, edit, or write any file. Describe what you
WOULD do, then print the structured yaml block.
═══════════════════════════════════════════════"

SYS="$(cat "$PLUGIN_ROOT/prompts/curator.md")"
USER_MSG="Consolidate the mnemo-forged skill library. Today is $TODAY.

The forged-by:mnemo skills live under:
  $SKILLS_DIR/<name>/SKILL.md
Archive target (never delete): $MNEMO_HOME/pruned/<name>/

Candidate skills (name, usage signals, description) — these are the ONLY skills
you may touch; anything not in this list is off-limits:

$CANDIDATES

Inspect any candidate with Read/Glob on its directory. Verify a skill is
forged-by:mnemo (grep its frontmatter) before moving or editing it. Consolidate
per your instructions, archiving absorbed siblings to $MNEMO_HOME/pruned/.$DRY

When done, print the human summary + the required yaml block."

echo "[$(date -u +%FT%TZ)] curator START mode=$MODE model=$MODEL candidates=$COUNT" >>"$LOG"
timeout "${MNEMO_CURATOR_TIMEOUT:-600}" env \
  MNEMO_REVIEWING=1 MNEMO_HOME="$MNEMO_HOME" MNEMO_SKILLS_DIR="$SKILLS_DIR" \
  "$CLAUDE_BIN" -p \
    --model "$MODEL" \
    --permission-mode acceptEdits \
    --allowed-tools "Read,Bash,Write,Edit,Glob,Grep" \
    --add-dir "$MNEMO_HOME" --add-dir "$SKILLS_DIR" \
    --append-system-prompt "$SYS" \
    "$USER_MSG" </dev/null | tee -a "$LOG"
echo "[$(date -u +%FT%TZ)] curator DONE  mode=$MODE rc=$?" >>"$LOG"
exit 0
