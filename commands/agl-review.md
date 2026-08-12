---
description: Five-axis review of current changes, with adversarial verification of each finding before it reaches the report
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` (once per session).
Scope: `$ARGUMENTS`, else the current diff (staged + recent branch commits).

## Steps

1. **Review across five axes**, reading the surrounding code, not just the
   diff: correctness (edge cases, races, error paths), readability,
   architecture (below), security (input validation, secrets, injection,
   least privilege), performance (only what's measurable — no speculative
   micro-optimizing).

   **Architecture — the lenses that catch real damage.** Does it fit the
   codebase's existing patterns, and — if `.agl/CONSTITUTION.md` exists —
   honor each principle, or carry a recorded justification for the violation?
   Then, specifically:
   - Is a new conditional bolted onto an unrelated flow? A design smell, not
     a nit — the logic wants its own helper, state, or policy.
   - Do repeated conditionals on the same shape appear? That's a missing
     model or dispatcher. A "temporary" branch is usually permanent.
   - **Does this refactor reduce complexity or just relocate it?** Count the
     concepts a reader must hold. If the "cleaner" version leaves that count
     unchanged, it isn't cleaner. Prefer deleting an abstraction to polishing
     one, and restructuring that makes whole branches or layers disappear
     over restructuring that re-centralizes the same logic.
   - Is feature-specific logic leaking into a shared module? Or a bespoke
     near-duplicate of an existing canonical helper?
   - Are type boundaries explicit? Gratuitous `any`/casts/optionals and
     silent fallbacks usually paper over an unclear invariant — naming the
     invariant often makes the surrounding branching disappear.
   - **Watch total file size, not just diff size.** A small diff can still
     push a file past a healthy boundary (~1000 total lines is an inspection
     signal, not a cap). When a change materially grows an already-large
     file, ask whether to decompose *first*, then add.

   **Propose the move, not just the problem.** A finding that only says
   "this is complex" leaves the author guessing. Name the remedy: replace a
   conditional chain with a typed model or dispatcher; collapse duplicate
   branches; separate orchestration from business logic; move feature logic
   back to the package that owns it; reuse the canonical helper; make a type
   boundary explicit; delete a pass-through wrapper; extract a helper or
   split the file. Prefer the remedy that removes moving pieces.

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

   **Order by leverage and let the big thing be the review.** Correctness and
   security first, then structural regressions, then everything else. One
   structural problem plus ten nits is a review about the structural problem;
   a few high-conviction findings beat a long list.

   **Presumptive blockers** — surface these *with the simpler design attached*,
   and escalate to blocking only when the change actively makes structure
   worse: a refactor that relocates complexity instead of reducing it; a file
   pushed past its size boundary with no decomposition; feature logic added to
   a shared module; a near-duplicate of a canonical helper; a silent fallback
   hiding an unclear invariant.

5. End with a numbered menu: fix all confirmed / fix selected / proceed to
   /agl-ship — one explicit recommendation. If fixes are applied, each gets
   the /agl-build per-task loop (test proving the fix, scoped commit).
