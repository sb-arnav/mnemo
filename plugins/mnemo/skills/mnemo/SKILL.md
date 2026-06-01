---
name: mnemo
description: Use when the user asks what mnemo is, what the agent has learned/remembered about them, where memory lives, or wants to inspect, edit, pause, or tune the self-improving loop (memory, user model, forged skills, curiosity proposals).
---

# mnemo — the compounding memory loop

mnemo gives Claude Code the thing people leave for Hermes Agent: a closed
learning loop that runs on autopilot, so the agent **compounds** instead of
forgetting you between sessions. It's three loops wired into hooks:

1. **Memory curation** (Stop / SessionEnd hook → background review worker):
   after a session, a `claude -p --bare` worker reads the transcript and writes
   what mattered to a bounded store. Injected back at the next SessionStart.
2. **Skill forging** (same worker): when a correction or a non-trivial technique
   appears, the worker writes/patches a real Claude Code skill.
3. **Curiosity** (scheduled): periodically researches one weak/stale area and
   writes an improvement *proposal* (never auto-applied).

## Where things live

- `~/.mnemo/USER.md` — who the user is (cap 1375 chars). The user model.
- `~/.mnemo/MEMORY.md` — agent notes: environment, conventions, lessons (cap 2200).
- `~/.mnemo/SOUL.md` — stable operating personality, injected every session.
- `~/.mnemo/corrections.jsonl` — correction hints captured live.
- `~/.mnemo/curiosity/` — dated improvement proposals awaiting review.
- `~/.mnemo/logs/` — review.log, curiosity.log.
- Forged skills → `~/.claude/skills/<name>/` with `forged-by: mnemo` frontmatter.

## Inspecting and editing memory

Always use the CLI (it enforces the §-format and char caps — never hand-edit
the `.md` files):

```bash
MEM=~/mnemo/plugins/mnemo/bin/mnemo-mem    # or ${CLAUDE_PLUGIN_ROOT}/bin/mnemo-mem
python3 $MEM show user
python3 $MEM show memory
python3 $MEM add user "Prefers brutal honesty, no sugarcoating."
python3 $MEM replace memory "old substring" "updated entry"
python3 $MEM remove user "substring to drop"
```

`SOUL.md` is free-form prose — edit it directly (kept under ~1600 chars).

## Controls

- **Pause everything:** `touch ~/.mnemo/OFF` (remove to resume).
- **Pause only curiosity:** `touch ~/.mnemo/CURIOSITY_OFF`.
- **Force a review now:** `bash ~/mnemo/plugins/mnemo/scripts/review.sh "<transcript.jsonl>" manual`
- **Run curiosity now:** `bash ~/mnemo/plugins/mnemo/scripts/curiosity.sh`
- **Tune cadence:** env `MNEMO_NUDGE_INTERVAL` (turns between reviews in long
  sessions, default 8), `MNEMO_MIN_TURNS` (min turns for an end-of-session
  review, default 3), `MNEMO_REVIEW_MODEL` (default claude-sonnet-4-6).

## Safety invariants

- mnemo only ever writes its own store and skills it forged itself; it never
  edits human-authored skills, CLAUDE.md, or settings.
- The review worker runs `--bare` (no hooks) and sets `MNEMO_REVIEWING=1`, so it
  can't recurse into itself.
- Memory is bounded by design — the cap is what keeps it sharp.
- Everything is plain markdown under git-trackable dirs: fully auditable and
  revertable.
