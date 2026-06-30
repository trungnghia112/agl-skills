---
description: Turn an idea into a spec with acceptance criteria — interview when vague, never code
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` (once per session).
`$ARGUMENTS` is the idea/feature. If `.agl/` exists, check BRAIN.md for
relevant memories (prior decisions, preferences) before asking anything.

## Steps

1. **Gauge clarity.** If the ask is already concrete (clear user, problem,
   and success condition), skip to step 3. If vague, interview.

2. **Interview — one question at a time.** Ask the single highest-leverage
   question as a numbered menu with a recommended option (never a wall of
   questions). Drive the questions by a coverage taxonomy — walk these axes and
   stop only when each is answered or consciously deferred:
   who/for-whom · the problem · what "done" looks like · OUT of scope ·
   data shape · interaction/UX flow · non-functional bars (perf, security,
   limits) · integrations & dependencies · edge cases & failure handling ·
   constraints (platform, budget, deps).
   Pick the next question by (impact × uncertainty), not by list order. Repeat
   until ~90% confident you could defend the spec to a skeptic.

3. **Surface assumptions** you're still making, explicitly, before writing.

4. **Write the spec** to `docs/specs/<slug>.md`:
   - Problem & outcome (owner language: "user can X → we get Y")
   - Acceptance criteria — each gets a stable ID (`AC-1`, `AC-2`, …),
     independently checkable AND measurable (a number or a yes/no test, never
     "fast" / "nice" / "secure"). The IDs are the traceability anchor:
     /agl-plan tags each task with the `AC-#` it satisfies and /agl-analyze
     checks every `AC-#` is covered.
   - Priority slices (only when the feature is sliceable): group the criteria
     into P1/P2/P3, each an independently shippable increment — P1 alone must
     be a viable MVP, not half a feature. A non-sliceable feature stays one
     slice; don't invent ceremony.
   - Out of scope — named, so /agl-build can refuse scope creep concretely
   - Risks & open questions — anything hitting a risk gate (payments, auth,
     irreversible ops) flagged here, not discovered mid-build
   - Verification plan — which evidence rung closes this (tests only?
     live UAT? wire-format probe?)
   - Mark any genuine residual ambiguity inline with
     `[NEEDS CLARIFICATION: <the exact question>]` — but **no more than 3** in
     a spec. More than that means you stopped interviewing too early; ask
     another question instead of parking it. These markers are gates:
     `/agl-analyze` blocks build while any remain, and `/agl-plan` refuses to
     plan around one.

5. **Spec self-check (the spec's own acceptance test).** Before finishing,
   confirm: ≤3 `[NEEDS CLARIFICATION]` markers and each is truly the owner's
   call (not laziness); every acceptance criterion is independently checkable
   and measurable; no implementation detail leaked in (the spec says WHAT/WHY,
   not HOW — no stack, no APIs, no file layout); out-of-scope is named. Fix
   what fails before writing STATE.

6. **No code in this command.** If you're tempted to prototype, that's
   /agl-build's job after /agl-plan.

7. Update `.agl/STATE.md` `## Now` (spec in progress → done). End with:

```
1️⃣ /agl-plan — break this spec into tasks
2️⃣ Edit spec — tell me what to change
3️⃣ /agl-build auto — plan + build in one pass
```
with one explicit recommendation.
