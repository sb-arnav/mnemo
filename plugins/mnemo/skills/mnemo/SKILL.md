---
name: mnemo
description: Use when the user asks what mnemo is, what the agent has learned/remembered about them, how well it's compounding, or wants to inspect, edit, pause, prune, or tune the self-improving loop (memory, user model, forged skills, effectiveness, curiosity proposals).
---

# mnemo — the measured compounding loop

mnemo gives Claude Code what people leave for Hermes Agent: a closed learning
loop that runs on autopilot so the agent **compounds** instead of forgetting you
— but unlike Hermes, mnemo *measures* whether its learning actually helps and
prunes what doesn't. Three loops:

1. **Memory curation** (Stop / SessionEnd → background review worker): after a
   session, a `claude -p` worker reads the transcript and writes what mattered
   to a bounded store, injected back at the next SessionStart.
2. **Skill forging + effectiveness** (same worker): corrections and techniques
   become real Claude Code skills. Each forged skill tracks `uses` / `last-used`
   / `contradicted`; the worker bumps usage when a skill fired and flags (then
   fixes) any skill a new correction contradicts.
3. **Curiosity** (scheduled, 04:30 daily): researches one weak/stale area and
   writes an improvement *proposal* — often with a one-command `apply` block.

## The `mnemo` CLI (front door)

```bash
mnemo status                # dashboard: memory pressure, skill hit-rates, compounding signal
mnemo mem show user         # inspect the user model / agent notes
mnemo mem add user "..."    # add/replace/remove (enforces §-format + char caps)
mnemo skill list            # forged skills + usage/contradiction flags
mnemo skill gc [--apply]    # prune dead (unused N days) + contradicted skills → ~/.mnemo/pruned/
mnemo apply <proposal.md>   # apply a curiosity proposal's change block (dry-run; add --yes to execute)
mnemo curiosity             # run the curiosity loop now
mnemo off | on              # pause / resume the whole loop
```

(If `mnemo` isn't on PATH: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/mnemo ...`, or
`~/mnemo/plugins/mnemo/bin/mnemo ...`.)

## Where things live

- `~/.mnemo/USER.md` — the user model (cap 1375 chars).
- `~/.mnemo/MEMORY.md` — agent notes: environment, conventions, lessons (cap 2200).
- `~/.mnemo/SOUL.md` — stable operating personality, injected every session.
- `~/.mnemo/corrections.jsonl` — live-captured corrections (feeds the compounding metric).
- `~/.mnemo/curiosity/` — dated proposals; `~/.mnemo/pruned/` — graveyard of GC'd skills.
- `~/.mnemo/logs/` — review.log, curiosity.log, skill-flags.log.
- Forged skills → `~/.claude/skills/<name>/` with `forged-by: mnemo` frontmatter.

## What makes it *measured* (the edge over Hermes)

- Forged skills carry effectiveness metadata; ones that never fire or get
  contradicted are surfaced by `mnemo skill gc` and pruned (revertably).
- `mnemo status` shows a **falsifiable compounding signal**: how often recent
  corrections repeat an older topic. Trending down = the loop is sticking.

## Safety invariants

- mnemo only writes its own store and skills it forged (`forged-by: mnemo`); it
  never edits human-authored skills, CLAUDE.md, or settings.
- The review worker sets `MNEMO_REVIEWING=1`, so every mnemo hook no-ops inside
  it — no recursion.
- Memory is bounded by design; curiosity is advisory (`apply` is opt-in, dry-run
  by default). Everything is plain markdown in git-trackable dirs — auditable and
  revertable.
- Tune: `MNEMO_NUDGE_INTERVAL` (8), `MNEMO_MIN_TURNS` (3), `MNEMO_GC_DAYS` (21),
  `MNEMO_REVIEW_MODEL` (claude-sonnet-4-6).
