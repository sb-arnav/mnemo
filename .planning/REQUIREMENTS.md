# mnemo — v1 Requirements (the trust layer)

Core value: a self-improving Claude Code agent you can **trust** — every lesson
is verified before it sticks, carries provenance + a trust score, and is
re-evaluated against a falsifiable probe.

A "lesson" = a memory entry (USER.md / MEMORY.md) or a forged skill.

## v1 Requirements

### Verification (the gate)
- [ ] **VERIFY-01**: Before any lesson is committed to the live store, an *independent* verifier (a separate `claude -p` pass, not the writer) challenges it on four axes — durable-rule vs environment-artifact, contradicts-existing memory/skills, poisoned/injected by web content in the source session, would-cause-regression — and returns pass | quarantine with a reason.
- [ ] **VERIFY-02**: A lesson that fails verification is moved to `~/.mnemo/quarantine/` with its failing reason recorded — never silently dropped — and is reviewable.
- [ ] **VERIFY-03**: The verifier runs on the user's subscription via the real `claude` binary (non-bare `-p`), recursion-guarded by `MNEMO_REVIEWING`, with a bounded timeout.
- [ ] **VERIFY-04**: A human can release (`mnemo quarantine release <id>`) or discard a quarantined lesson; the action is auditable.

### Provenance + trust
- [ ] **PROV-01**: Every lesson carries provenance at creation: source session id, trigger type (correction | technique | web-research), and a web-influence flag (true if WebFetch/WebSearch appeared in the source session).
- [ ] **PROV-02**: Every lesson carries a trust score (0–100) derived from provenance + verification verdict + probe history, stored with the lesson.
- [ ] **PROV-03**: Lessons below a trust threshold are excluded from SessionStart auto-injection until raised (flagged, not silently used).

### Eval harness (did learning help?)
- [ ] **EVAL-01**: When a lesson is forged, a tiny falsifiable probe is captured at creation (a yes/no check whose expected answer encodes the lesson) and stored with it.
- [ ] **EVAL-02**: A periodic replay runs probes against current state; a now-failing probe flags its lesson (trust drop / quarantine).
- [ ] **EVAL-03**: `mnemo status` surfaces a reproducible "did learning help?" signal — probe pass-rate over time + repeat-correction trend.

### Native + auditable surface
- [ ] **NATIVE-01**: Quarantine, provenance, trust scores, and probes are plain files in git-trackable dirs — auditable and revertable.
- [ ] **NATIVE-02**: The `mnemo` CLI exposes the trust surface: `mnemo quarantine [list|release|discard]`, `mnemo trust [list]`, `mnemo eval [run]`, alongside existing `status`.

## v2 / Deferred

- [ ] **PORT-01**: export/import learned lessons across repos / a team (`mnemo export` / `import`).
- [ ] **PROV-04**: trust-score auto-decay over time for stale, unre-verified lessons.

## Out of Scope

- Multi-platform gateway, cron swarm, terminal backends, semantic/embedding recall — Hermes owns these; not our wedge.
- v0.2 skill effectiveness-tracking + GC + consolidation — deprecated (reinvented Hermes' curator). Strip or minimize during this milestone.

## Traceability

(Filled by the roadmapper — every v1 REQ maps to exactly one phase.)
