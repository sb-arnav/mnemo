#!/bin/bash
# Phase 3 — falsifiable probe replay (the "did learning still hold?" signal).
#
# Each lesson carries a tiny yes/no probe captured at creation. This periodic
# pass re-checks every active probe against the CURRENT memory/skills: a probe
# that now fails means the lesson drifted (removed, overwritten, contradicted)
# and loses trust — auto-held from injection if it drops below threshold. The
# run's pass-rate is the reproducible compounding signal nobody else has.
#
# Run on a schedule (cron) or on demand via `dorveille eval`.
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DORVEILLE_HOME="${DORVEILLE_HOME:-$HOME/.dorveille}"
MODEL="${DORVEILLE_EVAL_MODEL:-${DORVEILLE_REVIEW_MODEL:-claude-sonnet-4-6}}"
LOG="$DORVEILLE_HOME/logs/eval.log"
mkdir -p "$DORVEILLE_HOME/logs"

[ -f "$DORVEILLE_HOME/OFF" ] && exit 0
LESSON="$PLUGIN_ROOT/bin/dorveille-lesson"
MEM="$PLUGIN_ROOT/bin/dorveille-mem"
SKILLS_DIR="${DORVEILLE_SKILLS_DIR:-$HOME/.claude/skills}"
CLAUDE_BIN="$(command -v claude || echo "$HOME/.local/bin/claude")"

PROBES="$(DORVEILLE_HOME="$DORVEILLE_HOME" python3 "$LESSON" probes 2>/dev/null)"
if [ -z "$PROBES" ] || [ "$PROBES" = "(none)" ]; then
  echo "[$(date -u +%FT%TZ)] eval: no probes to replay" >>"$LOG"
  exit 0
fi

SYS="$(cat "$PLUGIN_ROOT/prompts/eval.md")"
USER_MSG="Replay these probes against CURRENT state. Each line is: <id>\t<expected yes|no>\t<question>

$PROBES

First read the current memory:
  python3 $MEM show user
  python3 $MEM show memory
(and consult the skill library under $SKILLS_DIR if a probe concerns a skill).

For each probe, record:
  python3 $LESSON probe-result <id> pass    # current state reflects the lesson
  python3 $LESSON probe-result <id> fail    # it no longer does (drift)

Then record the run and print the summary:
  python3 $LESSON eval-record --total <N> --passed <M>"

echo "[$(date -u +%FT%TZ)] eval START model=$MODEL" >>"$LOG"
timeout "${DORVEILLE_EVAL_TIMEOUT:-240}" env \
  DORVEILLE_REVIEWING=1 DORVEILLE_HOME="$DORVEILLE_HOME" DORVEILLE_SKILLS_DIR="$SKILLS_DIR" \
  "$CLAUDE_BIN" -p \
    --model "$MODEL" \
    --permission-mode acceptEdits \
    --allowed-tools "Read,Bash,Grep,Glob" \
    --add-dir "$DORVEILLE_HOME" --add-dir "$SKILLS_DIR" \
    --append-system-prompt "$SYS" \
    "$USER_MSG" </dev/null >>"$LOG" 2>&1
echo "[$(date -u +%FT%TZ)] eval DONE rc=$?" >>"$LOG"
exit 0
