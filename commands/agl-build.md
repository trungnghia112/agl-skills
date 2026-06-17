---
description: Implement plan tasks with TDD — one task and stop, or "auto" for the whole plan after a single approval
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` (once per session).
`$ARGUMENTS`: empty = one task; `auto` (or `all`) = whole plan, single
checkpoint. Check BRAIN.md for gotchas/runbook relevant to the files touched
— and verify any recalled memory against current code before relying on it.

## Per-task loop (both modes — this never gets skipped or shortened)

1. Read the task's acceptance criteria + load real context (open the files).
2. Non-trivial decisions → state ASSUMPTIONS first.
3. **RED**: write the failing test that encodes the acceptance criterion.
   (Where a test is genuinely impossible — e.g. UAC prompt UX — say so and
   name the manual verification that replaces it. Silence is not an option.)
4. **GREEN**: minimum code to pass. Boring solution preferred.
5. Full suite + build. Regressions are YOUR problem now, not later.
6. **Commit, surgically scoped**: stage only this task's files (+ its plan
   status update). Never `git add -A`. One task = one commit = one clean
   revert point.
7. Mark the task ✅ in plan.md, update `.agl/STATE.md` `## Now` (2 lines).
8. Default mode: stop and report. Auto mode: next task.

## Auto mode (`/agl-build auto`)

1. Require a plan (`plans/.../plan.md`); generate via /agl-plan logic if
   only a spec exists; refuse if neither (→ /agl-spec).
2. Require a clean baseline: uncommitted changes unrelated to the plan →
   stop, ask the owner to commit/stash. Per-task commits must not absorb
   strangers' diffs or the clean-revert guarantee breaks.
3. **Single checkpoint**: present the full plan, wait for an unambiguous yes
   ("approve"/"go"/"do it"). Hedged answers are not approval.
4. Execute every task in dependency order through the per-task loop.
5. **Hard stops mid-run** (report and wait — do not push through):
   - a `risk:`-tagged task is next (payments/auth/irreversible/secrets)
   - a test won't go green or the build breaks without an obvious fix
     (→ switch to /agl-debug methodology)
   - the spec is ambiguous on a decision the plan didn't settle
   On resume, `/agl-build auto` continues from the next pending task.
6. End-of-run summary: tasks done, tests added, commits made, anything
   skipped or flagged.

## Verification rung

The plan's `## Verification` section is binding. UI or IPC/wire-format
touched → the live rung (run the app, probe the real payload/render) is
REQUIRED before declaring the feature done; suite-green alone is
insufficient — type checkers and unit tests cannot see those bugs.

End (both modes) with a numbered menu: continue / review / test / ship —
one explicit recommendation.
