# mnemo — the trust layer for AI agent self-improvement

## What This Is

mnemo is a Claude Code plugin that makes the agent **compound** — it curates
cross-session memory and forges its own skills automatically — but unlike every
existing self-improving agent (Hermes, OpenClaw, and the prior-art CC plugins),
mnemo **verifies and evaluates what it learns before trusting it.**

It runs natively inside Claude Code, in your repo, on your own subscription
(driving the real `claude` binary via hooks — no API-key bridge, nothing that
gets a third-party agent banned).

## Core Value (the ONE thing that must work)

**You can trust the agent got smarter without fearing it learned something
wrong.** Every lesson (a memory fact or a forged skill) is challenged by an
independent verifier before it sticks, carries provenance + a trust score, and
is continuously re-evaluated against a falsifiable probe. Unverified or
contradicted lessons are quarantined, never silently auto-loaded.

## Why this is the right wedge (grounded in reading Hermes' actual code)

A deep study of NousResearch/hermes-agent (~976k LOC, cloned and read) showed
Hermes already ships the *mechanics* of self-improvement — and does them well:
- Skill usage telemetry (`tools/skill_usage.py`), GC + archival + umbrella
  **consolidation** (`agent/curator.py`), dialectic user-modeling (Honcho),
  FTS5 cross-session recall, a prefix-cache-safe background review fork.

What Hermes (and everyone) has **NOT** solved — validated across five
independent code readings:
1. **No verification of self-modification.** Skills self-modify on pure LLM
   judgment; a skill that drifts wrong or is poisoned by web content during its
   creating session keeps auto-loading. Hermes' own curator distrusts its usage
   counters (`curator.py:378`).
2. **No eval rigor on the loop itself** — no reproducible "did learning help?"
   signal. 1300+ tests, all plumbing; none measure whether learning improves
   outcomes.
3. **Single-machine / not codebase-native.** Memory + user-model are local,
   single-user; Hermes lives in Telegram/cron, not your repo.

mnemo is *already* Claude-Code-native — the one thing Hermes structurally is
not. So we build the thing Hermes can't: the **trust + eval layer**.

## Requirements

### Validated

(None yet — ship to validate. The v0.2 substrate exists and works: bounded
memory store `bin/mnemo-mem`, the `claude -p` review worker, the four hooks
(SessionStart/Stop/SessionEnd/UserPromptSubmit), the `MNEMO_REVIEWING`
recursion sentinel — these are reused, not re-proven.)

### Active

- [ ] VERIFY: an independent adversarial verifier gates every lesson before it persists
- [ ] VERIFY: failed lessons are quarantined with a reason (not silently dropped)
- [ ] PROV: every lesson carries provenance (session, trigger, web-influence) + a trust score
- [ ] PROV: low-trust lessons are quarantined/flagged, not auto-loaded
- [ ] EVAL: each forged lesson gets a tiny falsifiable probe captured at creation
- [ ] EVAL: a periodic replay confirms learned knowledge still holds; failures flag the lesson
- [ ] EVAL: a reproducible "did learning help?" signal in `mnemo status`
- [ ] NATIVE: quarantine, provenance, trust + probes are all git-native, auditable, revertable, visible via the `mnemo` CLI

### Out of Scope

- Multi-platform gateway (Telegram/Discord/etc.) — Hermes owns this; not our wedge.
- Cron multi-agent swarm, 6 terminal backends — Hermes territory.
- Embedding/semantic recall — Hermes has FTS5; recall isn't our differentiator.
- The v0.2 skill effectiveness-tracking + GC + consolidation — **deprecated**: it
  reinvented Hermes' curator, which is deeper. Strip or minimize it.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Build the trust+eval layer, not more memory/skills mechanics | Hermes already solved the mechanics; verification/eval is the real unsolved gap | — Pending |
| Deprecate v0.2 effectiveness-tracking + GC | It reinvented Hermes' curator (skill_usage.py + curator.py), which is deeper | — Pending |
| Verifier = independent adversarial agent (separate `claude -p` pass) | A self-judging writer can't catch its own drift; independence is the point | — Pending |
| Reuse the working v0.2 substrate | mnemo-mem store, review worker, hooks, sentinel all tested and working | — Pending |
| Stay Claude-Code-native + git-native | It's our structural edge over Hermes and makes everything auditable/revertable | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-06-01 after initialization*
