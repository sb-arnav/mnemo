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

## The `mnemo` CLI

```bash
mnemo status                      # dashboard: memory, trust registry, probe replay, compounding
mnemo trust                       # every lesson with provenance + trust score
mnemo quarantine list             # lessons the verifier held back, with reasons
mnemo quarantine release <id>     # vouch for one → restore it to the live store
mnemo quarantine discard <id>     # permanently drop one
mnemo eval                        # replay probes now (did learning still hold?)
mnemo mem show user|memory        # inspect the bounded stores
mnemo curiosity                   # run the curiosity loop now
mnemo on | off                    # resume / pause the whole loop
```

(If `mnemo` isn't on PATH: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/mnemo ...`.)

## Where things live (all git-trackable, auditable, revertable)

- `~/.mnemo/USER.md` (1375 chars) · `MEMORY.md` (2200) · `SOUL.md` — the stores.
- `~/.mnemo/lessons.json` — the trust registry (provenance, trust, verification, probe).
- `~/.mnemo/quarantine/` — held lessons + stashed copies (release-able).
- `~/.mnemo/eval-history.jsonl` — probe pass-rate over time.
- `~/.mnemo/corrections.jsonl` · `curiosity/` · `logs/` (review/verify/eval/curiosity).
- Forged skills → `~/.claude/skills/<name>/` with `forged-by: mnemo`.

## Trust scoring

Base from provenance: correction 85, technique 65, web-research 45 (−20 if the
session used the web). The verifier may raise it (clear correction) or quarantine
(poisoning / contradiction). A failed probe drops it 25. Below
`MNEMO_TRUST_THRESHOLD` (default 50) → held from injection.

## Safety invariants

- mnemo only writes its own store + skills it forged; never edits human skills,
  CLAUDE.md, or settings.
- Verification is **independent** (separate `claude -p`, `MNEMO_REVIEWING`-guarded
  so it can't recurse). The writer never signs off its own work.
- Memory is bounded; quarantine + release keep self-modification reversible.
- Pause: `touch ~/.mnemo/OFF` (or `mnemo off`). Tune: `MNEMO_TRUST_THRESHOLD`,
  `MNEMO_NUDGE_INTERVAL`, `MNEMO_REVIEW_MODEL`, `MNEMO_VERIFY_MODEL`, `MNEMO_EVAL_MODEL`.
