# Security model

dorveille is a self-modifying loop: it writes to its own memory and forges
skills automatically, driven by `claude -p` worker agents that hooks spawn after
your sessions. This document states the trust boundaries plainly so you can
decide whether that fits your threat model.

## Trust boundary

- The workers are constrained **by prompt and by `--add-dir` scoping**, not by an
  OS-level sandbox. They run the real `claude` binary with `Bash` available
  (needed to call dorveille's own CLIs), so their *effective* capability is local
  command execution. In normal operation they only write `~/.dorveille/*` and
  skills they forged (`forged-by: dorveille`), and never touch hand-authored
  skills, `CLAUDE.md`, or settings — but that restraint is enforced by the
  worker's instructions, not by a hard jail.
- The review and curator workers can write (`acceptEdits` + `Write`/`Edit`,
  scoped to `~/.dorveille` and `~/.claude/skills`). The verifier and probe-replay
  workers are read-only.
- The curiosity worker has network access (`WebSearch`/`WebFetch`) and writes
  proposals only — it never applies a change to memory or skills.

## What protects you

- **Recursion guard:** every worker runs with `DORVEILLE_REVIEWING=1`, and every
  hook no-ops when that is set, so a worker's own turns can't re-trigger the loop.
- **Trust layer:** memory injected into the system prompt is a frozen snapshot;
  each entry is born with provenance + a trust score, an independent verifier
  quarantines suspicious lessons (env-artifacts, contradictions, web-poisoning),
  and low-trust lessons are held out of context. Web-sourced lessons start low.
- **Deterministic promptware scan** on memory at write- and inject-time blocks
  injection/exfiltration/invisible-unicode content from reaching the prompt.
- **Bounded + auditable:** memory is char-capped; everything is plain
  git-trackable files under `~/.dorveille/`; the curator archives (never deletes).
- **Kill switch:** `dorveille off` (or `touch ~/.dorveille/OFF`) halts the whole
  loop immediately; `dorveille quarantine` / `release` / `discard` give you a
  human review surface over what was learned.

## Reporting

This is an early-stage, single-maintainer project. If you find a security issue,
open an issue on the repository describing it. There is no formal disclosure SLA.
