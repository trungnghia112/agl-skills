---
description: Five-axis review of current changes, with adversarial verification of each finding before it reaches the report
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` (once per session).
Scope: `$ARGUMENTS`, else the current diff (staged + recent branch commits).

## Steps

1. **Review across five axes**, reading the surrounding code, not just the
   diff: correctness (edge cases, races, error paths), readability,
   architecture (does it fit the codebase's existing patterns?), security
   (input validation, secrets, injection, least privilege), performance
   (only what's measurable — no speculative micro-optimizing).

2. **Adversarial verify before reporting.** For each candidate finding, try
   to REFUTE it: re-read the code assuming the author was right; check
   whether the "bug" is actually handled upstream, intended, or covered by a
   test. Findings that survive go in the report with file:line and concrete
   consequence. Plausible-but-unverified findings are the failure mode this
   step exists to kill. (Per-finding skepticism beats one generic
   double-check pass.)

3. **Simplification pass, separate section**: fewer-lines/reuse/altitude
   suggestions are NOT bugs — never mix them into the correctness list.

4. **Report**: confirmed findings (severity-ordered, each with evidence),
   then simplifications, then what was checked and found clean. If
   everything is clean, say exactly that — do not manufacture findings to
   look thorough.

5. End with a numbered menu: fix all confirmed / fix selected / proceed to
   /agl-ship — one explicit recommendation. If fixes are applied, each gets
   the /agl-build per-task loop (test proving the fix, scoped commit).
