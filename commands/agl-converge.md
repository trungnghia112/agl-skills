---
description: Reconcile the plan against the actual code — append gap-tasks for drift, never rewrite existing ones; idempotent when nothing has drifted
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` (once per session).

Where `/agl-analyze` checks artifacts against EACH OTHER (spec ↔ plan ↔ tasks ↔
constitution, read-only), `/agl-converge` checks the plan against the ACTUAL
CODE — the question `/agl-analyze` cannot answer: did what got built actually
satisfy what was planned, even when the plan's own ✅ status table says so?
Run it whenever drift is plausible: a hand edit landed outside `/agl-build`, a
plan reopened weeks later, or before `/agl-ship` on a plan you didn't build
end-to-end yourself.

## Inputs

Locate the plan (`$ARGUMENTS`, else the newest in `plans/`), its spec
(`docs/specs/...`), and `.agl/CONSTITUTION.md` if present. No plan → say so,
offer `/agl-plan`. Scope is exactly the spec's `AC-#`s and the plan's tasks —
do not go looking for unrelated issues.

## Steps

1. **Build the intent inventory** — every spec `AC-#`, every plan task's
   `acceptance:` / `covers:` / `files:`, every constitution principle. This is
   what "done" means for this pass; nothing else is in scope.

2. **Assess the code, not the status table.** For each inventory item, open
   the `files:` the task named (plus a keyword search for the behavior it
   describes) and check whether it's actually there — a task marked ✅ that
   turns out empty, reverted, or half-done is exactly the drift this command
   exists to catch. Classify each gap:
   - **missing** — the work isn't in the code at all.
   - **partial** — it's there but doesn't fully satisfy the `acceptance:` line.
   - **contradicts** — the code conflicts with the spec, a plan decision, or a
     constitution principle.
   - **unrequested** — code exists that no task or `AC-#` called for (surfaced
     for awareness only — converge never deletes code, it appends a task to
     review/justify or remove it).

3. **Assign severity**: CRITICAL = constitution violation, or a
   missing/contradicts gap blocking a P1 slice's checkpoint. HIGH =
   missing/partial on a core `AC-#`. MEDIUM = partial on a secondary
   requirement, or unrequested work with unclear justification. LOW = minor
   polish-level gaps.

4. **Report before writing anything** — a table (gap type / severity / source
   `AC-#` or principle / evidence / remaining work), plus counts (`AC-#`s
   checked, principles checked, findings by type and severity).

5. **Append, never rewrite.** If there are findings: append a new
   `## Convergence — <date>` section to the END of `plan.md`, one task per
   finding in the same task format as the rest of the plan
   (`acceptance:`/`covers:`/`files:`/`risk:`, plus a `gap:` tag),
   CRITICAL/HIGH first. Do not touch a single existing task line, the status
   table, or any prior `## Convergence` section — a repeat run adds a new
   dated section below, it never edits an old one. If there are zero
   findings, leave `plan.md` byte-for-byte unchanged and report **"✅
   Converged — code satisfies spec, plan, and tasks."**

## Discipline

Same adversarial-verify bar as `/agl-analyze`: before reporting a finding, try
to refute it — is the "missing" work actually done under a file/name you
didn't check? Don't invent drift to look thorough; a clean converge run is a
valid, good result.

## Output

Update `.agl/STATE.md` `## Now` with the outcome, then end with:

```
1️⃣ /agl-build — implement the appended Convergence tasks
2️⃣ Accept a finding with a note — record why it's tolerable, then proceed
3️⃣ /agl-ship — only if converged (or all findings accepted)
```

with one explicit recommendation; while a CRITICAL finding remains, option 3
is NOT it.
