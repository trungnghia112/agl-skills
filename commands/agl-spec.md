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
   question, as a numbered menu with a recommended option (never a wall of
   questions). Repeat until ~90% confident you could defend the spec to a
   skeptic. Cover: who is it for, what problem, what does "done" look like,
   what's explicitly OUT of scope, constraints (platform, budget, deps).

3. **Surface assumptions** you're still making, explicitly, before writing.

4. **Write the spec** to `docs/specs/<slug>.md`:
   - Problem & outcome (owner language: "user can X → we get Y")
   - Acceptance criteria — each one independently checkable
   - Out of scope — named, so /agl-build can refuse scope creep concretely
   - Risks & open questions — anything hitting a risk gate (payments, auth,
     irreversible ops) flagged here, not discovered mid-build
   - Verification plan — which evidence rung closes this (tests only?
     live UAT? wire-format probe?)

5. **No code in this command.** If you're tempted to prototype, that's
   /agl-build's job after /agl-plan.

6. Update `.agl/STATE.md` `## Now` (spec in progress → done). End with:

```
1️⃣ /agl-plan — break this spec into tasks
2️⃣ Edit spec — tell me what to change
3️⃣ /agl-build auto — plan + build in one pass
```
with one explicit recommendation.
