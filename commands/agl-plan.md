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
     `files:` (real paths), `depends:` (task IDs), and
     `risk:` tag where a risk gate applies (payment/auth/irreversible —
     these tasks require owner sign-off at build time, plan it in).
   - A `## Verification` section naming the evidence rung for the whole
     feature (suite + build at minimum; live UAT when UI/IPC is touched).
   - Status table (⬜/🟡/✅ per task) — /agl-build updates it as it goes.

4. **Sanity pass**: would a staff engineer say "why didn't you just..."?
   Collapse over-engineered task chains now, not during build.

5. Update `.agl/STATE.md` (`## Now` = plan ready; backlog item if this is a
   tracked feature). End with:

```
1️⃣ /agl-build — làm task đầu tiên (từng bước, chắc chắn)
2️⃣ /agl-build auto — duyệt 1 lần, chạy cả plan
3️⃣ Chỉnh plan — nói task cần sửa
```
with one explicit recommendation.
