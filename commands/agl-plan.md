---
description: Decompose a spec into small verifiable tasks with acceptance criteria and risk tags
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` (once per session).

## Steps

1. **Locate the spec**: `$ARGUMENTS`, or the newest file in `docs/specs/`,
   or — if none — say so and offer `/agl-spec`. Do not invent requirements.

2. **Read before planning**: the actual source files the work will touch
   (verify file paths exist — plans referencing imagined files are the #1
   source of plan drift), relevant BRAIN.md memories (gotchas! runbook),
   and the repo's conventions.

3. **Write the plan** to `plans/<YYMMDD-HHMM>-<slug>/plan.md`:
   - Tasks of ≤ ~1 hour each, every task with:
     `acceptance:` (how we'll know it's done — concrete, checkable),
     `covers:` (the spec `AC-#` IDs this task satisfies — every `AC-#` must be
     covered by at least one task; this is what /agl-analyze verifies),
     `files:` (real paths), `depends:` (task IDs),
     a `[P]` marker when the task shares no `files:` and no `depends:` with its
     siblings (safe to run in parallel), and
     `risk:` tag where a risk gate applies (payment/auth/irreversible —
     these tasks require owner sign-off at build time, plan it in).
   - **Phase the tasks** — this is the spine of the plan:
     - **Setup** — scaffolding/tooling the whole feature needs.
     - **Foundational** — shared work every slice builds on. This phase
       **blocks all slices**: no slice task starts until Foundational is green.
       Keep it minimal — only what ≥2 slices genuinely share; don't smuggle a
       single slice's own work in here.
     - **One group per P-slice** (when the spec sliced them), each ending in a
       **slice checkpoint**: a line naming the independently-verifiable
       increment reached ("P1 done → CSV backup works = shippable MVP").
       Stopping at any checkpoint must leave something that works on its own —
       a slice may never `depends:` on a later slice.
     - **Polish** — cross-cutting cleanup, done last.
     A non-sliceable feature is just Setup → Foundational → one build group;
     don't manufacture phases where there's one slice.
   - A `## Verification` section naming the evidence rung for the whole
     feature (suite + build at minimum; live UAT when UI/IPC is touched).
   - A `## Constitution Check` section if `.agl/CONSTITUTION.md` exists:
     confirm the plan honors each principle. Any violation needs an explicit
     justification line (which principle, why needed, what simpler alternative
     was rejected) — an unjustified violation blocks the plan, it is not a
     judgment call.
   - Status table (⬜/🟡/✅ per task) — /agl-build updates it as it goes.

4. **Sanity pass**: would a staff engineer say "why didn't you just..."?
   Collapse over-engineered task chains now, not during build.

5. Update `.agl/STATE.md` (`## Now` = plan ready; backlog item if this is a
   tracked feature). End with:

```
1️⃣ /agl-build — do the first task (step by step, carefully)
2️⃣ /agl-build auto — approve once, run the whole plan
3️⃣ Edit plan — tell me which task to change
```
with one explicit recommendation.
