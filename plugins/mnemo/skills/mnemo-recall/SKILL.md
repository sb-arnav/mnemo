---
name: mnemo-recall
description: Use to recall something from a PAST Claude Code session — when the user says "did we discuss", "what did I say about", "last time", "a while back", "you helped me with X before", "remember when", or references earlier work not in the current context. Searches every past session transcript (FTS5, zero-LLM) and returns the matching conversation with enough surrounding context to act on.
---

# mnemo-recall — search your past sessions

Claude Code keeps a full transcript of every session, but they're invisible to
the agent mid-conversation. mnemo-recall makes them searchable, so you can pull
back a decision, a config value, or a discussion from weeks ago instead of
asking the user to repeat themselves. This is the Hermes "it remembered a detail
from three weeks ago" capability, native to Claude Code.

**Reach for this BEFORE saying "I don't have that context" or asking the user to
re-explain prior work.** If the user references something that plausibly happened
in an earlier session, search first.

## How to use it

```bash
mnemo recall search "<keywords>"           # find sessions; returns snippets + session ids
mnemo recall scroll <session> <anchor>     # widen context around a hit (anchor = uuid or line no shown in search)
mnemo recall browse                        # most recent sessions, newest first
mnemo recall index                         # refresh the index (auto-runs on SessionEnd; safe to run anytime)
```

(If `mnemo` isn't on PATH: `python3 ${CLAUDE_PLUGIN_ROOT}/bin/mnemo-recall ...`.)

## Workflow

1. **Search** with the strongest distinctive keywords from the user's reference
   (project names, error strings, tool names, decisions). Results are ranked
   sessions, each with highlighted `⟦match⟧` snippets and a `session` id.
2. If a snippet looks right but you need more, **scroll** around its anchor to
   read the surrounding turns (`--window N` for a wider view).
3. Use what you find to answer directly — cite that it's from a past session and
   roughly when, so the user knows you recalled it rather than guessed.

## Notes

- Keyword/substring search (FTS5), not semantic — vary terms if the first query
  misses. Bare terms are OR'd, so extra keywords broaden rather than narrow.
- Indexes only human-readable conversation (user messages + assistant text), so
  results are signal, not tool spew.
- The index is local at `~/.mnemo/sessions.db` and refreshes incrementally; if a
  very recent session is missing, run `mnemo recall index`.
