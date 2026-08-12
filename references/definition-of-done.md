# Definition of Done

The standing bar every change clears before it counts as done. Read by
/agl-plan (when writing acceptance criteria), /agl-build (per task) and
/agl-ship (per release).

**Not the same thing as acceptance criteria.** Acceptance criteria are
written per task and answer *"did we build the right thing?"* — they change
every time. The Definition of Done is fixed for the whole project and answers
*"is it finished to our standard?"*. A task is done when **its** acceptance
criteria are met **and** this bar is cleared. Either one alone leaves work
that looks finished and isn't.

Tailor this list to the project once (in `.agl/CONSTITUTION.md` if the
project has one), then reuse it unchanged. A bar renegotiated per feature is
not a bar.

## The standing checklist

### Correctness — every task
- [ ] The task's acceptance criteria are met
- [ ] Behavior verified at the rung the change demands (see core-behaviors #6
      — UI and wire-format changes REQUIRE the live rung)
- [ ] New behavior covered by a test that fails without the change
- [ ] Full suite green; no regressions
- [ ] Error paths and edge cases handled, not just the happy path

### Quality — every task
- [ ] Naming and structure carry the intent; no comment needed to explain *what*
- [ ] No duplicated business logic, dead code, debug output, or commented blocks
- [ ] Diff scoped to the task — no drive-by refactors riding along
- [ ] Lint and format pass

### Integration — every feature
- [ ] Works with the rest of the system, not only in isolation
- [ ] Migrations, config changes, and feature flags accounted for
- [ ] Backward compatibility considered for any public interface or wire format

### Documentation — every feature
- [ ] Public interfaces and user-facing behavior documented
- [ ] Decisions worth preserving written to the brain as `decision-*` memories
- [ ] Docs describe the current state in timeless language, not the change history

### Ship-readiness — every release
- [ ] Security reviewed wherever untrusted input, auth, or user data is touched
- [ ] Critical new paths observable (logs/metrics) when the app has that surface
- [ ] Rollback path named before anything risky is deployed
- [ ] Owner has approved — risk-gated changes require explicit sign-off

## Red flags

- *"It's done, I just haven't run it yet"* — unverified work is not done.
- *"Tests pass"* used as a synonym for done while docs, regressions, or the
  live rung are skipped.
- A different bar applied under deadline pressure.
- Acceptance criteria treated as the whole bar, with no standing floor beneath.
- "Done" declared before owner review on a change that needed it.
