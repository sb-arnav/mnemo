#!/bin/bash
# sweep.sh — lifecycle-independent review trigger (the reliable path).
#
# The Stop (every N turns) and SessionEnd hooks only fire the review worker for
# long sessions or cleanly-ended ones. Short sessions never reach the turn
# threshold, and on WSL/closed terminals SessionEnd often never completes — so
# the worker can silently never run (empty memory despite heavy use). This sweep
# fixes that: it finds IDLE, substantive, not-yet-reviewed session transcripts
# and runs the review worker on them, independent of how the session ended.
#
#   sweep.sh                 review up to MNEMO_SWEEP_MAX idle unreviewed sessions (cron)
#   sweep.sh --backfill [N]  one-time catch-up: review the N most-recent unreviewed
#                            substantive sessions, ignoring the idle filter (default 10)
#
# Dedup: a per-session marker records the transcript's mtime+size at review time,
# so a session is re-reviewed only if it grew since (new content), never twice
# for the same state.
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MNEMO_HOME="${MNEMO_HOME:-$HOME/.mnemo}"
PROJECTS="${MNEMO_PROJECTS_DIR:-$HOME/.claude/projects}"
LOG="$MNEMO_HOME/logs/sweep.log"
MARKERS="$MNEMO_HOME/reviewed"
mkdir -p "$MNEMO_HOME/logs" "$MARKERS"

[ -f "$MNEMO_HOME/OFF" ] && exit 0
[ -n "${MNEMO_REVIEWING:-}" ] && exit 0

MIN_TURNS="${MNEMO_SWEEP_MIN_TURNS:-4}"     # skip trivial sessions
IDLE_MIN="${MNEMO_SWEEP_IDLE_MIN:-15}"      # don't touch sessions edited in last N min (likely active)
MAX="${MNEMO_SWEEP_MAX:-3}"                 # cap reviews per run (each is a claude -p call)

if [ "${1:-}" = "--backfill" ]; then
  MAX="${2:-10}"
  IDLE_MIN=0
  echo "[$(date -u +%FT%TZ)] sweep BACKFILL start max=$MAX" >>"$LOG"
fi

mapfile -t files < <(ls -t "$PROJECTS"/*/*.jsonl 2>/dev/null)
done=0
for f in "${files[@]}"; do
  [ "$done" -ge "$MAX" ] && break
  [ -f "$f" ] || continue
  sid="$(basename "$f" .jsonl)"

  # skip sessions still being written (likely active) unless backfilling
  if [ "$IDLE_MIN" -gt 0 ] && [ -n "$(find "$f" -mmin -"$IDLE_MIN" 2>/dev/null)" ]; then
    continue
  fi

  fp="$(stat -c '%Y-%s' "$f" 2>/dev/null || echo "?")"
  marker="$MARKERS/$sid"
  [ -f "$marker" ] && [ "$(cat "$marker" 2>/dev/null)" = "$fp" ] && continue

  turns="$(grep -c '"type":"user"' "$f" 2>/dev/null || echo 0)"
  if [ "$turns" -lt "$MIN_TURNS" ]; then
    echo "$fp" > "$marker"          # remember we judged it (too small) so we don't recount it
    continue
  fi

  echo "[$(date -u +%FT%TZ)] sweep reviewing $sid ($turns turns)" >>"$LOG"
  bash "$PLUGIN_ROOT/scripts/review.sh" "$f" "$sid" || true
  echo "$fp" > "$marker"
  done=$((done + 1))
done

echo "[$(date -u +%FT%TZ)] sweep DONE reviewed=$done" >>"$LOG"
[ -t 1 ] && echo "sweep: reviewed $done session(s) (markers in $MARKERS/)"
exit 0
