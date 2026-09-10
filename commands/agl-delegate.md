---
description: Delegate implementation to the codex lane — you stay the architect: write the spec, pick the effort, verify the diff, get an advisor verdict
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` and
`${CLAUDE_PLUGIN_ROOT}/references/delegation.md` (once per session).

`$ARGUMENTS`: the task to delegate. Empty = take the next pending task from
the plan (`plans/.../plan.md`); if there is no plan, ask what to delegate
rather than guessing.

You are the **architect** for this command. You do not type implementation
code — you decide, specify, route, and judge. A code block longer than an
interface signature means the spec isn't written yet.

## The loop

1. **Load real context.** Open the files the task names. Check `.agl/BRAIN.md`
   for a gotcha or runbook covering them, and verify any recalled memory
   against the current code before relying on it (core-behaviors #7).

2. **Decide, then surface assumptions.** Non-trivial decisions get stated
   before delegation: "ASSUMPTIONS: 1) … 2) … — correct me now or I proceed."
   An ambiguity you hand to a lane comes back as a wrong diff.

3. **Write the six-part spec** — objective, files, interfaces, constraints,
   verification, `REASONING: <rung>`. Pick the **lowest rung that is adequate**;
   effort is cost and wall-clock, not a quality dial. A spec you cannot finish
   writing is a decision you have not made — make it, don't delegate it.

4. **Consult `agl-advisor` first** when this task crosses a commitment
   boundary: an architecture choice, a migration, an API shape, a refactor
   strategy, or a problem that already failed twice. Act on the verdict or
   surface the disagreement.

5. **Invoke the `agl-codex-lane` agent** with the spec. Independent specs — no
   shared files, no ordering dependency — launch in parallel in a single
   message. Sequential chains and single-file surgery stay serial.

6. **Verify the report — it is a claim, not evidence.** Read the diff yourself,
   re-run the verification command yourself, and compare the lane's final
   message against what the diff actually does. `STATUS: refused` (exit 0,
   empty tree) is a refusal — treat it as one and send a corrected spec.
   `STATUS: unavailable` means codex is missing or unauthenticated: say so out
   loud and decide whether to keep the task with the session. Never absorb that
   substitution silently.

7. **Advisor final review** before you report done: pass the diff and the
   stated goal for a ship / fix-first / rethink verdict.

8. **Commit, surgically scoped.** Stage only this task's files. Never
   `git add -A`. The lane never commits — the commit boundary is yours. Then
   mark the task ✅ (both its `acceptance:` and
   `${CLAUDE_PLUGIN_ROOT}/references/definition-of-done.md`) and update
   `.agl/STATE.md` `## Now`.

## Hard rules

- **Never patch the lane's output by hand.** A wrong diff gets a corrected
  spec, not your fingers. Hand-fixing is how the cost saving quietly
  evaporates — and how the cross-vendor check turns back into self-review.
- **Never let the lane substitute itself.** No codex means no lane; it does not
  mean a Claude model quietly typing the code under a lane's banner.
- **Delegated work clears the same bar as hand-written work.** Delegation
  changes who types, never what "done" means.
- **Risk gates still apply** (core-behaviors): payments, auth, destructive data
  operations, secrets, anything not undoable with `git revert` → stop for
  owner sign-off before delegating, not after.

End with a numbered menu — delegate the next task / review / test / ship —
and exactly one explicit recommendation.
