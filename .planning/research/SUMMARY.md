# Research Summary — grounding for mnemo (the trust layer)

This replaces generic domain research: it's a code-grounded study of the actual
competitor, NousResearch/hermes-agent (cloned at /tmp/hermes-agent, ~976k LOC),
read across five subsystems. It defines what NOT to build (already solved) and
where the real opportunity is.

## Anti-reinvent list — Hermes already ships these (do NOT rebuild)

- **Memory loop**: turn-based memory nudge (interval 10) + iteration-based skill
  nudge, forked background review agent inheriting the parent's cached system
  prompt for prefix-cache reuse (~26% cost cut), frozen-snapshot injection,
  prompt-injection threat scanning with `[BLOCKED]` placeholders, external-drift
  detection with `.bak` + refuse-write. (`tools/memory_tool.py`, `agent/background_review.py`)
- **Skill effectiveness telemetry**: `.usage.json` use/view/patch counts +
  timestamps. (`tools/skill_usage.py`)
- **Skill GC + lifecycle + consolidation**: active→stale(30d)→archived(90d),
  recoverable archive, umbrella consolidation of overlapping skills, pin,
  dry-run, machine-readable run reports. (`agent/curator.py`)
- **User modeling**: Honcho dialectic + 8 external memory providers.
- **Recall**: SQLite + FTS5 (+ trigram for CJK), BM25 ranked cross-session search.
- **Breadth**: 20+ platform gateway, cron, Kanban multi-agent swarm, 6 terminal
  backends, ACP/MCP bridges, provider fallback + cost routing.

**Implication:** mnemo v0.2's "effectiveness tracking + GC" duplicated Hermes'
curator and should be deprecated. Memory/skill *mechanics* are a solved, crowded
space. Do not compete there.

## The validated gap — what Hermes has NOT solved (the wedge)

1. **No verification/trust of self-modification.** The headline feature
   (self-improvement) has no verification gate. Skills self-modify on pure LLM
   judgment; a skill that subtly drifts wrong, or is poisoned by web content
   pulled in during the session that created it, just keeps auto-loading. No
   eval-on-skill, no regression check, no provenance-trust score. The curator
   even refuses to trust its own usage counters (`curator.py:378`).
2. **No eval rigor on the loop itself.** No reproducible "did learning help?"
   benchmark. 1300+ tests, all plumbing; none measure outcome improvement.
3. **Single-machine / single-user / not codebase-native.** Memory + learned
   user-model are local; no team/repo sharing. Hermes lives in messaging+cron,
   not the repo.

## Why mnemo wins here

mnemo is already Claude-Code-native (in the repo, on the subscription, git-backed
= auditable/revertable). That's the structural edge Hermes lacks (its identity is
"lives in Telegram, not your laptop"). Building **verification + eval + provenance**
on top of an already-native, already-git-backed substrate is something Hermes
can't easily follow — and it's what makes self-improvement *trustworthy*, which
is the actual blocker to every dev adopting a self-modifying agent.

## Pitfalls to avoid (from the study)

- Don't let the verifier be the same agent that wrote the lesson (self-judging
  can't catch its own drift) — use an independent `claude -p` pass.
- `--bare` skips credential discovery → "Not logged in". The worker must run
  non-bare; recursion is prevented by the `MNEMO_REVIEWING` env sentinel.
- Keep memory bounded (the char cap is *why* it stays sharp).
- Don't silently drop failed lessons — quarantine with a reason (auditable).
- Avoid capturing environment-dependent failures / negative tool claims as
  durable lessons (they harden into self-imposed constraints).
