---
name: mnemo
description: Use when the user asks what mnemo is, what the agent has learned/remembered about them, why a lesson was quarantined or held, how much to trust what it learned, or wants to inspect, release, pause, or tune the self-improving trust loop (memory, provenance, verification, probes, curiosity).
---

# mnemo — the trust layer for agent self-improvement

mnemo makes Claude Code **compound** (cross-session memory + self-forged skills),
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

Alongside the trust loop, mnemo has full parity with the Hermes *mechanics*:

- **Episodic recall** — FTS5 search over every past session transcript
  (`mnemo recall`), so the agent can pull back a decision or config from weeks
  ago instead of asking you to repeat yourself. See the `mnemo-recall` skill.
- **The curator** — a background pass that consolidates forged skills into
  class-level umbrellas and archives stale ones (never deletes), so the skill
  library stays sharp instead of sprawling (`mnemo curator`).
- **Skill usage telemetry + pinning** — forged skills track `uses`/`last-used`;
  `mnemo skill pin <name>` protects one from the curator.

## The `mnemo` CLI

```bash
mnemo status                      # dashboard: memory, recall, skills, trust, probes, compounding
mnemo trust                       # every lesson with provenance + trust score
mnemo quarantine list             # lessons the verifier held back, with reasons
mnemo quarantine release <id>     # vouch for one → restore it to the live store
mnemo quarantine discard <id>     # permanently drop one
mnemo eval                        # replay probes now (did learning still hold?)
mnemo mem show user|memory        # inspect the bounded stores
mnemo recall search "<query>"     # search past sessions · scroll/browse/index
mnemo skill list                  # forged skills with usage/age · pin/unpin/stale
mnemo curator [dry-run]           # consolidate the forged-skill library
mnemo curiosity                   # run the curiosity loop now
mnemo on | off                    # resume / pause the whole loop
```

(If `mnemo` isn't on PATH: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/mnemo ...`.)
Schedule the proactive loops with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/install-cron.sh`.

## Where things live (all git-trackable, auditable, revertable)

- `~/.mnemo/USER.md` (1375 chars) · `MEMORY.md` (2200) · `SOUL.md` — the stores.
- `~/.mnemo/lessons.json` — the trust registry (provenance, trust, verification, probe).
- `~/.mnemo/quarantine/` — held lessons + stashed copies (release-able).
- `~/.mnemo/eval-history.jsonl` — probe pass-rate over time.
- `~/.mnemo/sessions.db` — FTS5 episodic-recall index over past transcripts.
- `~/.mnemo/pruned/` — skills the curator archived (recoverable; never deleted).
- `~/.mnemo/corrections.jsonl` · `curiosity/` · `logs/` (review/verify/eval/curiosity/curator).
- Forged skills → `~/.claude/skills/<name>/` with `forged-by: mnemo`.

## Trust scoring

Base from provenance: correction 85, technique 65, web-research 45 (−20 if the
session used the web). The verifier may raise it (clear correction) or quarantine
(poisoning / contradiction). A failed probe drops it 25. Below
`MNEMO_TRUST_THRESHOLD` (default 50) → held from injection.

## Safety invariants

- mnemo only writes its own store + skills it forged; never edits human skills,
  CLAUDE.md, or settings. The curator only ever touches `forged-by: mnemo` skills
  and archives (never deletes).
- Verification is **independent** (separate `claude -p`, `MNEMO_REVIEWING`-guarded
  so it can't recurse). The writer never signs off its own work.
- The memory store is hardened: a deterministic injection/exfil/invisible-unicode
  scan blocks promptware at write- and inject-time, an fcntl lock makes concurrent
  sessions safe, and a drift guard backs up rather than clobbers out-of-band edits.
- Memory is bounded; quarantine + release keep self-modification reversible.
- Pause: `touch ~/.mnemo/OFF` (or `mnemo off`). Tune: `MNEMO_TRUST_THRESHOLD`,
  `MNEMO_NUDGE_INTERVAL`, `MNEMO_REVIEW_MODEL`, `MNEMO_VERIFY_MODEL`, `MNEMO_EVAL_MODEL`.
