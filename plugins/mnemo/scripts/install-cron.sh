#!/bin/bash
# install-cron.sh — turnkey scheduling for mnemo's proactive loops.
#
# Hermes' "Crons" pillar = scheduled background work (briefings, maintenance).
# mnemo's scheduled loops are: keep the recall index fresh, replay probes
# (did learning still hold?), run curiosity (propose improvements), and run the
# curator (consolidate the skill library). This installs them as user crontab
# entries inside an idempotent marker block. Re-running replaces the block.
#
#   install-cron.sh            install/refresh the mnemo cron block
#   install-cron.sh --print    print the block, install nothing
#   install-cron.sh --remove   remove the mnemo cron block
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MARK_BEGIN="# >>> mnemo cron >>>"
MARK_END="# <<< mnemo cron <<<"
ENVLINE="CLAUDE_PLUGIN_ROOT=$PLUGIN_ROOT"

read -r -d '' BLOCK <<EOF || true
$MARK_BEGIN
# mnemo scheduled loops — edit times freely; keep the markers.
0 */6 * * *   $ENVLINE python3 $PLUGIN_ROOT/bin/mnemo-recall index >/dev/null 2>&1
30 3 * * *    $ENVLINE bash $PLUGIN_ROOT/scripts/eval.sh >/dev/null 2>&1
0 4 * * *     $ENVLINE bash $PLUGIN_ROOT/scripts/curiosity.sh >/dev/null 2>&1
30 4 * * 0    $ENVLINE bash $PLUGIN_ROOT/scripts/curator.sh run >/dev/null 2>&1
$MARK_END
EOF

if [ "${1:-}" = "--print" ]; then
  printf '%s\n' "$BLOCK"
  exit 0
fi

# strip any existing mnemo block, then optionally append the fresh one
current="$(crontab -l 2>/dev/null || true)"
cleaned="$(printf '%s\n' "$current" | awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
  $0==b {skip=1} skip && $0==e {skip=0; next} !skip')"

if [ "${1:-}" = "--remove" ]; then
  printf '%s\n' "$cleaned" | crontab -
  echo "mnemo cron block removed."
  exit 0
fi

{ printf '%s\n' "$cleaned" | sed '/^$/d'; printf '%s\n' "$BLOCK"; } | crontab -
echo "mnemo cron installed (recall index 6h · eval 03:30 · curiosity 04:00 · curator Sun 04:30)."
echo "Inspect: crontab -l   ·   remove: $0 --remove"
