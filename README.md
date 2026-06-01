# mnemo

**The Hermes self-improving loop, native to Claude Code.**

People keep leaving Claude Code for [Hermes Agent](https://github.com/NousResearch/hermes-agent) — not because the model is better (it isn't), but because Hermes *compounds*: it curates its own memory, builds a model of you, and writes its own skills, all automatically. "Day thirty doesn't feel like day one." Claude Code already has every storage primitive Hermes has — skills, memory files, subagents — it was just missing the **involuntary loop** that feeds them. And Anthropic [cut subscription tokens out of third-party agents like Hermes](https://github.com/NousResearch/hermes-agent), so getting that experience there now costs API-rate money.

mnemo is that loop, rebuilt as Claude Code plugin hooks — so it runs **inside** Claude Code on your own subscription, no token bridge, nothing to get banned.

## What it does

Three loops on autopilot:

| Loop | Trigger | Effect |
|------|---------|--------|
| **Memory curation** | `Stop` every N turns + `SessionEnd` | A background `claude -p --bare` worker reads the finished transcript and writes what mattered to a bounded store. Injected back next session. |
| **Skill forging** | same worker | Corrections and non-trivial techniques become real Claude Code skills (`~/.claude/skills`), or patches to ones it forged before. |
| **Curiosity** | scheduled | Periodically researches one weak/stale area and writes an improvement *proposal* (never auto-applied). |

The memory model is ported from Hermes (MIT): two bounded, `§`-delimited stores —
`USER.md` (who you are, 1375 chars) and `MEMORY.md` (agent notes, 2200 chars).
**Bounded on purpose** — the cap forces prioritisation, which is why the memory
stays sharp instead of becoming a dump.

## Better than a blind loop: mnemo *measures itself*

Hermes (and every prior-art Claude Code memory plugin) writes memory and forges
skills **without ever checking whether any of it helped.** mnemo closes that loop:

- **Skill effectiveness** — every forged skill tracks `uses` / `last-used` /
  `contradicted`. The review worker bumps usage when a skill actually fired, and
  when a new correction contradicts a forged skill it **flags and fixes it**
  instead of silently keeping wrong knowledge.
- **Garbage collection** — `mnemo skill gc` prunes skills that never fire or got
  contradicted, to a revertable graveyard. The library stays sharp at scale.
- **A falsifiable compounding signal** — `mnemo status` reports how often recent
  corrections repeat an older topic. Trending down = the loop is genuinely
  sticking. Hermes asks you to take "it compounds" on faith; mnemo shows the number.
- **Curiosity that acts** — proposals ship with a one-command `apply` block, so a
  finding becomes a fix (`mnemo apply <proposal>`), dry-run by default.

```
$ mnemo status
🧠 mnemo — compounding status
memory
  user-model  [████····················]  16%  231/1375
  agent-notes [██████··················]  26%  591/2200
forged skills (effectiveness)
  deploy-staq     2  2026-06-08  2026-06-01
compounding signal (corrections)
  last 7d  1/3 recent corrections repeat an older topic  ✅ compounding
```

## Why it's safe (and not just "a self-modifying agent")

Self-improving agents drift. mnemo is built so it can't drift far:

- It **only writes its own store and skills it forged itself** (`forged-by: mnemo`). It never edits your hand-authored skills, `CLAUDE.md`, or settings.
- The review worker runs `--bare` (no hooks) with `MNEMO_REVIEWING=1`, so it **can't recurse** into itself.
- Memory is **bounded**; curiosity is **advisory** (proposes, doesn't apply).
- Everything is plain markdown in git-trackable dirs — **fully auditable and revertable**.

## Install

```bash
# from a local checkout (dev):
claude --plugin-dir ~/mnemo/plugins/mnemo

# or via the marketplace:
claude plugin marketplace add ~/mnemo
claude plugin install mnemo@mnemo
```

First run creates `~/.mnemo/`. Optionally seed `~/.mnemo/SOUL.md` with how you
want the agent to show up. To schedule curiosity, add a cron line:

```cron
0 4 * * *  CLAUDE_PLUGIN_ROOT=$HOME/mnemo/plugins/mnemo bash $HOME/mnemo/plugins/mnemo/scripts/curiosity.sh
```

## Controls

- Pause all: `touch ~/.mnemo/OFF` · pause curiosity only: `touch ~/.mnemo/CURIOSITY_OFF`
- Inspect: `python3 ~/mnemo/plugins/mnemo/bin/mnemo-mem show user`
- Tune: `MNEMO_NUDGE_INTERVAL` (default 8), `MNEMO_MIN_TURNS` (3), `MNEMO_REVIEW_MODEL` (claude-sonnet-4-6)

See the bundled `mnemo` skill for the full control surface.

## Credit

The loop's design and judgment prompts are adapted from **Hermes Agent** by
Nous Research (MIT) — see `NOTICE`. mnemo shares no source code with it; it's an
independent re-implementation of the *idea* as Claude Code hooks.

MIT licensed.
