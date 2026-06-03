---
name: dorveille
description: Use when the user asks what dorveille is, what the agent has learned/remembered about them, why a lesson was quarantined or held, how much to trust what it learned, or wants to inspect, release, pause, or tune the self-improving trust loop (memory, provenance, verification, probes, curiosity).
---

# dorveille — the trust layer for agent self-improvement

dorveille makes Claude Code **compound** (cross-session memory + self-forged skills),
but unlike Hermes and every other self-improving agent it **verifies and
evaluates what it learns** so you can trust it didn't learn something wrong. It
runs natively in your repo, on your own subscription, via the real `claude`
binary in hooks. Every lesson (a memory entry or a forged skill) flows through:

1. **Write + provenance** (Stop / SessionEnd → review worker): a `claude -p`
   worker reads the finished transcript, writes lessons, and registers each with
   provenance (session, trigger, web-influence) + a base **trust score**.
2. **Independent verification** (chained `verify.sh`): a *separate* agent
   challenges each lesson — durable vs env-artifact, contradiction,
   web-poisoning, regression — and **quarantines** failures (pulling them from
   the live store). The writer can't verify its own drift; this agent can.
3. **Trust-gated injection** (SessionStart): only lessons at/above the trust
   threshold are injected. Low-trust / quarantined lessons are held back.
4. **Probe replay** (`eval.sh`, scheduled/on-demand): each lesson carries a tiny
   yes/no probe; replay re-checks it still holds, dropping trust on drift.
5. **Curiosity** (scheduled): researches one weak area, proposes an improvement
   (often with a one-command `apply` block).

Alongside the trust loop, dorveille has full parity with the Hermes *mechanics*:

- **Episodic recall** — FTS5 search over every past session transcript
  (`dorveille recall`), so the agent can pull back a decision or config from weeks
  ago instead of asking you to repeat yourself. See the `dorveille-recall` skill.
- **The curator** — a background pass that consolidates forged skills into
  class-level umbrellas and archives stale ones (never deletes), so the skill
  library stays sharp instead of sprawling (`dorveille curator`).
- **Skill usage telemetry + pinning** — forged skills track `uses`/`last-used`;
  `dorveille skill pin <name>` protects one from the curator.

## The `dorveille` CLI

```bash
dorveille status                      # dashboard: memory, recall, skills, trust, probes, compounding
dorveille trust                       # every lesson with provenance + trust score
dorveille quarantine list             # lessons the verifier held back, with reasons
dorveille quarantine release <id>     # vouch for one → restore it to the live store
dorveille quarantine discard <id>     # permanently drop one
dorveille eval                        # replay probes now (did learning still hold?)
dorveille mem show user|memory        # inspect the bounded stores
dorveille recall search "<query>"     # search past sessions · scroll/browse/index
dorveille skill list                  # forged skills with usage/age · pin/unpin/stale
dorveille sweep                       # review idle, unreviewed sessions (reliable trigger)
dorveille backfill [N]                # one-time: learn from the N most-recent past sessions
dorveille curator [dry-run]           # consolidate the forged-skill library
dorveille curiosity                   # run the curiosity loop now
dorveille on | off                    # resume / pause the whole loop
```

(If `dorveille` isn't on PATH: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/dorveille ...`.)
Schedule the proactive loops with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/install-cron.sh`.

## Where things live (all git-trackable, auditable, revertable)

- `~/.dorveille/USER.md` (1375 chars) · `MEMORY.md` (2200) · `SOUL.md` — the stores.
- `~/.dorveille/lessons.json` — the trust registry (provenance, trust, verification, probe).
- `~/.dorveille/quarantine/` — held lessons + stashed copies (release-able).
- `~/.dorveille/eval-history.jsonl` — probe pass-rate over time.
- `~/.dorveille/sessions.db` — FTS5 episodic-recall index over past transcripts.
- `~/.dorveille/pruned/` — skills the curator archived (recoverable; never deleted).
- `~/.dorveille/corrections.jsonl` · `curiosity/` · `logs/` (review/verify/eval/curiosity/curator).
- Forged skills → `~/.claude/skills/<name>/` with `forged-by: dorveille`.

## Trust scoring

Base from provenance: correction 85, technique 65, web-research 45 (−20 if the
session used the web). The verifier may raise it (clear correction) or quarantine
(poisoning / contradiction). A failed probe drops it 25. Below
`DORVEILLE_TRUST_THRESHOLD` (default 50) → held from injection.

## Safety invariants

- dorveille only writes its own store + skills it forged; never edits human skills,
  CLAUDE.md, or settings. The curator only ever touches `forged-by: dorveille` skills
  and archives (never deletes).
- Verification is **independent** (separate `claude -p`, `DORVEILLE_REVIEWING`-guarded
  so it can't recurse). The writer never signs off its own work.
- The memory store is hardened: a deterministic injection/exfil/invisible-unicode
  scan blocks promptware at write- and inject-time, an fcntl lock makes concurrent
  sessions safe, and a drift guard backs up rather than clobbers out-of-band edits.
- Memory is bounded; quarantine + release keep self-modification reversible.
- Pause: `touch ~/.dorveille/OFF` (or `dorveille off`). Tune: `DORVEILLE_TRUST_THRESHOLD`,
  `DORVEILLE_NUDGE_INTERVAL`, `DORVEILLE_REVIEW_MODEL`, `DORVEILLE_VERIFY_MODEL`, `DORVEILLE_EVAL_MODEL`.
