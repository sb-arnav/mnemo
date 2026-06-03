# Roadmap: dorveille — the trust layer for AI agent self-improvement

## Overview

dorveille already curates cross-session memory and forges skills (the working v0.2
substrate). This milestone makes that learning **trustworthy**: every lesson
gains provenance + a trust score on the write path, is challenged by an
*independent* adversarial verifier before it can reach the live store,
carries a falsifiable probe that is replayed to catch silent drift, and is fully
auditable/revertable through a git-native `dorveille` CLI surface. The journey is a
layered build — metadata first, then the gate that consumes it, then the
eval/replay loop on top, then the human-facing trust surface that ties it
together — while deprecating the v0.2 effectiveness-tracking + GC that
reinvented Hermes' curator.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Provenance & Trust on the Write Path** - Every lesson is born with provenance + a trust score, low-trust lessons stop auto-loading, and the v0.2 curator-clone is deprecated.
- [ ] **Phase 2: The Verification Gate** - An independent adversarial verifier challenges every lesson and routes failures to a reviewable quarantine instead of the live store.
- [ ] **Phase 3: Falsifiable Probes & Replay** - Each lesson carries a probe captured at creation; periodic replay flags drifted lessons and produces a "did learning help?" signal.
- [ ] **Phase 4: Native Trust Surface** - The `dorveille` CLI exposes quarantine, trust, and eval over git-native files — auditable, revertable, human-operable.

## Phase Details

### Phase 1: Provenance & Trust on the Write Path
**Goal**: Every lesson (memory fact or forged skill) is created with provenance metadata and a trust score, low-trust lessons are excluded from auto-injection, and the deprecated v0.2 effectiveness/GC machinery is stripped so the trust layer is the substrate's new spine.
**Depends on**: Nothing (first phase — evolves the existing v0.2 write path)
**Requirements**: PROV-01, PROV-02, PROV-03
**Success Criteria** (what must be TRUE):
  1. A newly captured lesson records its source session id, trigger type (correction | technique | web-research), and a web-influence flag that is `true` exactly when WebFetch/WebSearch appeared in the source session.
  2. Each lesson stores a trust score (0–100) derived from its provenance (the verification verdict and probe history feed in once those phases land).
  3. A lesson whose trust score is below threshold is NOT injected at SessionStart — it is visibly flagged/held, not silently used.
  4. The v0.2 effectiveness-tracking + GC + consolidation paths are removed or inert, leaving no parallel curator competing with the trust layer.
**Plans**: TBD

Plans:
- [ ] 01-01: TBD

### Phase 2: The Verification Gate
**Goal**: No lesson reaches the live store unchallenged — an independent `claude -p` verifier judges each candidate on the four axes and routes failures to a reviewable, reasoned quarantine.
**Depends on**: Phase 1 (the verifier reads and updates provenance + trust; its verdict feeds the trust score)
**Requirements**: VERIFY-01, VERIFY-02, VERIFY-03
**Success Criteria** (what must be TRUE):
  1. Before commit, a separate verifier pass (not the writer) judges each lesson on all four axes — durable-rule vs environment-artifact, contradicts-existing memory/skills, web-poisoned/injected, would-cause-regression — and returns pass | quarantine with a reason.
  2. A web-poisoned or injected lesson lands in `~/.dorveille/quarantine/` with its failing reason recorded — never silently dropped — while a clean durable lesson passes through to the live store.
  3. The verifier runs on the user's subscription via the real (non-`--bare`) `claude` binary, is recursion-guarded by `DORVEILLE_REVIEWING`, and exits cleanly under a bounded timeout instead of hanging the session.
**Plans**: TBD

Plans:
- [ ] 02-01: TBD

### Phase 3: Falsifiable Probes & Replay
**Goal**: Trust is continuously re-earned — each forged lesson captures a tiny falsifiable probe at creation, a periodic replay catches lessons that have drifted or gone stale, and `dorveille status` exposes a reproducible "did learning help?" signal.
**Depends on**: Phase 2 (probes attach to lessons that have already passed the gate and carry provenance/trust; replay failures feed the trust score and quarantine)
**Requirements**: EVAL-01, EVAL-02, EVAL-03
**Success Criteria** (what must be TRUE):
  1. When a lesson is forged, a tiny falsifiable probe (a yes/no check whose expected answer encodes the lesson) is captured and stored alongside it.
  2. A periodic replay runs probes against current state; a now-failing probe flags its lesson — dropping its trust score and/or quarantining it.
  3. `dorveille status` surfaces a reproducible learning-health signal: probe pass-rate over time plus a repeat-correction trend.
**Plans**: TBD

### Phase 4: Native Trust Surface
**Goal**: A human can audit, operate, and revert the entire trust layer from the `dorveille` CLI over plain git-tracked files — releasing or discarding quarantined lessons, inspecting trust, and running evals on demand.
**Depends on**: Phase 3 (the CLI surfaces quarantine from Phase 2, trust from Phase 1, and eval/probes from Phase 3)
**Requirements**: VERIFY-04, NATIVE-01, NATIVE-02
**Success Criteria** (what must be TRUE):
  1. `dorveille quarantine list` shows held lessons with reasons; `dorveille quarantine release <id>` promotes one to the live store and `discard` removes it — each action recorded auditably.
  2. `dorveille trust [list]` shows lessons and their scores, and `dorveille eval [run]` triggers a probe replay on demand, alongside the existing `dorveille status`.
  3. Quarantine, provenance, trust scores, and probes are plain files in git-trackable directories — every trust decision is diffable and revertable with standard git.
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Provenance & Trust on the Write Path | 0/TBD | Not started | - |
| 2. The Verification Gate | 0/TBD | Not started | - |
| 3. Falsifiable Probes & Replay | 0/TBD | Not started | - |
| 4. Native Trust Surface | 0/TBD | Not started | - |
