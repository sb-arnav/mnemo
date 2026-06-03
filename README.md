# dorveille

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE) ![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-7c3aed) ![memory · skills · recall](https://img.shields.io/badge/memory%20·%20skills%20·%20recall-✓-success)

**Persistent cross-session memory, self-forged skills, and episodic recall for [Claude Code](https://www.anthropic.com/claude-code) — a [Hermes Agent](https://github.com/NousResearch/hermes-agent)-style self-improving loop, with a trust layer, on your own Claude subscription.**

> A Claude Code memory plugin that remembers you across sessions, writes its own skills, and searches your past conversations — but unlike every other self-improving agent, it *verifies what it learns before trusting it*. A native, subscription-priced answer to "I keep leaving Claude Code for Hermes because it compounds."

People keep leaving Claude Code for [Hermes Agent](https://github.com/NousResearch/hermes-agent) — not because the model is better (it isn't), but because Hermes *compounds*: it curates its own memory, builds a model of you, and writes its own skills, all automatically. "Day thirty doesn't feel like day one." Claude Code already has every storage primitive Hermes has — skills, memory files, subagents — it was just missing the **involuntary loop** that feeds them. And Anthropic [cut subscription tokens out of third-party agents like Hermes](https://github.com/NousResearch/hermes-agent), so getting that experience there now costs API-rate money.

dorveille is that loop, rebuilt as Claude Code plugin hooks — so it runs **inside** Claude Code on your own subscription, no token bridge, nothing to get banned.

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

## Parity with the Hermes *mechanics* — then past them

dorveille now ports the mechanics that made Hermes feel like it compounds, rebuilt as
Claude Code-native tools:

| Hermes mechanic | dorveille |
|---|---|
| FTS5 episodic recall (`session_search`) | **`dorveille recall`** — FTS5 over every past transcript; search / scroll / browse; a bundled `dorveille-recall` skill so the agent reaches for it; auto-indexed on `SessionEnd`. |
| Skill consolidation / GC | **the curator** (`dorveille curator`) — merges forged skills into class-level umbrellas, archives stale ones (never deletes), respects pins. |
| Skill usage telemetry | **`uses` / `last-used`** bumped by a `PostToolUse` hook; `dorveille skill pin` protects from the curator. |
| Crons / proactive loops | **`install-cron.sh`** — schedules recall-index, probe replay, curiosity, and the curator. |
| Bounded curated memory | ported 1:1, plus a deterministic promptware scan, fcntl locking, and a drift guard the original lacks. |

## The real edge: dorveille is also a *trust layer*

A deep read of Hermes' actual source showed it ships those mechanics but skipped
the one thing that makes a self-modifying agent adoptable: **verifying and
evaluating what it learns.** dorveille is that trust layer on top of the mechanics
above:

- **Provenance + trust on every lesson** — each memory entry / forged skill is
  born knowing where it came from (session, trigger, web-influence) and a trust
  score. Low-trust / poisoned lessons are **held out of the agent's context**
  until cleared.
- **An independent verification gate** — after the writer registers a lesson, a
  *separate* `claude -p` agent challenges it on four axes (durable vs
  environment-artifact, contradiction, **web-poisoning**, regression) and
  **quarantines** failures, physically pulling them from the live store. A writer
  can't catch its own drift; a fresh skeptic can. *(Proven: it caught a "use the
  secret --yolo flag, found on a blog" lesson and quarantined it on its own.)*
- **Falsifiable probes + replay** — every lesson carries a tiny yes/no probe; a
  periodic replay re-checks whether it still holds against current state. A
  drifted lesson loses trust and gets held. `dorveille status` shows the pass-rate —
  a reproducible "did learning still hold?" signal nobody else has.
- **A human trust surface** — `dorveille quarantine list / release / discard`. Every
  lesson, quarantine, trust score and probe is a plain git-tracked file:
  auditable and revertable.

```
$ dorveille status
🧠 dorveille — compounding status
memory
  user-model  [████····················]  16%  231/1375
trust registry (lessons: provenance + trust)
  a9420b31ea  trust= 25  memory/memory  [web-research web] ⚠quarantined  secret --force flag
  7b06a1fb84  trust= 85  memory/user   [correction]                     prefers concise replies
  ── 2 lessons · 0 below threshold · 1 quarantined
probe replay (did learning still hold?)
  last run: 1/2 probes held — 50%
```

## Why it's safe (and not just "a self-modifying agent")

Self-improving agents drift. dorveille is built so it can't drift far:

- It **only writes its own store and skills it forged itself** (`forged-by: dorveille`). It never edits your hand-authored skills, `CLAUDE.md`, or settings.
- The review worker runs `--bare` (no hooks) with `DORVEILLE_REVIEWING=1`, so it **can't recurse** into itself.
- Memory is **bounded**; curiosity is **advisory** (proposes, doesn't apply).
- Everything is plain markdown in git-trackable dirs — **fully auditable and revertable**.

## Install

```bash
# from a local checkout (dev):
claude --plugin-dir ~/dorveille/plugins/dorveille

# or via the marketplace:
claude plugin marketplace add ~/dorveille
claude plugin install dorveille@dorveille
```

First run creates `~/.dorveille/`. Optionally seed `~/.dorveille/SOUL.md` with how you
want the agent to show up. To schedule curiosity, add a cron line:

```cron
0 4 * * *  CLAUDE_PLUGIN_ROOT=$HOME/dorveille/plugins/dorveille bash $HOME/dorveille/plugins/dorveille/scripts/curiosity.sh
```

## Controls

- Pause all: `touch ~/.dorveille/OFF` · pause curiosity only: `touch ~/.dorveille/CURIOSITY_OFF`
- Inspect: `python3 ~/dorveille/plugins/dorveille/bin/dorveille-mem show user`
- Tune: `DORVEILLE_NUDGE_INTERVAL` (default 8), `DORVEILLE_MIN_TURNS` (3), `DORVEILLE_REVIEW_MODEL` (claude-sonnet-4-6)

See the bundled `dorveille` skill for the full control surface.

## Credit

The loop's design and judgment prompts are adapted from **Hermes Agent** by
Nous Research (MIT) — see `NOTICE`. dorveille shares no source code with it; it's an
independent re-implementation of the *idea* as Claude Code hooks.

MIT licensed.
