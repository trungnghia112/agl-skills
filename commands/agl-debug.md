---
description: Reproduce → localize → fix → guard. No fix without a reproduction; no close without a regression test
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` (once per session).
`$ARGUMENTS` describes the problem. Check BRAIN.md first — gotcha memories
exist precisely for this moment (but verify a matched gotcha still applies
to current code before assuming it's the cause).

## Steps

1. **Reproduce.** Get the failure to happen on demand (failing test, exact
   command, live probe). If you cannot reproduce it, say so and gather more
   signal (logs, narrower probes) — do NOT "fix" what you haven't seen fail.
   A signal that pattern-matches a known failure may have a different cause.

2. **Localize.** Bisect the path: which layer (UI / state / IPC / backend /
   external)? Use real probes (log the actual payload, not the typed
   interface — wire-format lies are a recurring class). State your current
   hypothesis explicitly; when evidence kills it, say so and form the next
   one. Don't shotgun changes.

3. **Fix.** Minimum change that addresses the CAUSE (not the symptom).
   If the true fix is large, say so and present options — a band-aid chosen
   knowingly by the owner beats one applied silently.

4. **Guard.** Add the regression test that would have caught this. If
   untestable (env-dependent), add the next-best guard (assertion, CI check,
   runbook note) and name the gap.

5. **Record.** Non-obvious root cause → gotcha memory (deduped). If the
   investigation disproved an existing memory, fix or delete that memory.

6. Run suite + build, report with evidence, update STATE.md `## Now`,
   numbered menu with one recommendation.
