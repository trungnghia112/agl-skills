---
description: Cross-artifact consistency check (spec ↔ plan ↔ tasks ↔ constitution) before build — read-only, every finding adversarially verified
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` (once per session).

This command is **read-only**: it reports inconsistencies, it never edits the
spec, plan, or code. Run it after `/agl-plan`, before `/agl-build` — catching a
coverage gap here costs minutes; catching it mid-build costs a rewrite. It
checks artifacts against EACH OTHER, not against the actual code — for that,
see `/agl-converge`.

## Inputs

Locate, in order: the spec (`$ARGUMENTS`, else the newest in `docs/specs/`),
its plan (`plans/.../plan.md`), and `.agl/CONSTITUTION.md` if present. Missing
a plan → say so and offer `/agl-plan`. Do not invent the missing artifact, and
do not analyze imagined requirements.

## Checks (each finding cites file:line on BOTH sides of the mismatch)

1. **Coverage (by ID)** — every spec `AC-#` is named in some task's `covers:`,
   and every `covers:` points at a real `AC-#`. An `AC-#` claimed by no task is
   a **CRITICAL** gap; a task covering nothing is scope creep to flag; a
   `covers:` referencing a non-existent `AC-#` is drift. Report the ratio
   (e.g. "14/14 AC covered"). If the spec predates IDs, match by wording and
   recommend re-running `/agl-spec` to add them.
2. **Requirements quality** ("unit tests for the spec's English," not for the
   code — this is about the writing, not the implementation) — any
   `[NEEDS CLARIFICATION]` marker still in the spec is a **CRITICAL** gap on
   its own. Beyond that, for each `AC-#`:
   - **Clarity** — a vague qualifier with no number ("fast", "secure",
     "scalable", "prominent") makes the AC unmeasurable, hence unbuildable.
   - **Completeness** — an obviously-needed case left unstated (an error
     path, an empty state, an auth boundary) for that AC.
   - **Consistency** — two ACs (or an AC and a plan decision) describing the
     same behavior differently.
   - **Scenario coverage** — for the feature's core flow, are Primary /
     Alternate / Exception / Recovery paths each represented, or silently
     assumed? (Distinct from check 1's AC↔task coverage — this is coverage
     *within* the spec's scenarios, not across artifacts.)
   This is still an interview job, not a rewrite job: a real gap routes back
   to `/agl-spec` — `/agl-analyze` reports the gap, it never invents the
   missing requirement itself.
3. **Constitution** — any plan or spec decision that violates a
   `.agl/CONSTITUTION.md` principle WITHOUT a recorded justification on the
   plan's `## Constitution Check` = **CRITICAL**.
4. **Duplication & conflict** — two requirements that overlap or contradict
   (e.g. spec says SQLite, plan says Postgres). Flag the weaker/older phrasing.
5. **Terminology drift** — the same concept named differently across spec /
   plan / tasks; both `/agl-recap` and `/agl-build` trip on this.
6. **Plan realism** — tasks whose `files:` point at paths that don't exist and
   aren't created by an earlier task; `depends:` cycles or dangling task IDs.
7. **Phase integrity** — a slice task that `depends:` on a later slice (breaks
   independent delivery), or on nothing in Foundational when it clearly needs
   shared setup; a slice whose checkpoint increment isn't actually shippable on
   its own. Foundational that quietly contains one slice's private work.
8. **Contract coverage** — every wire boundary the spec's verification plan
   marks "contract required" has a matching entry in the plan's `## Contracts`;
   every task touching that boundary references its contract; no contract field
   contradicts the spec's acceptance criteria or data shape. A "contract
   required" boundary with no contract = **HIGH** (wire-format bug surface).

## Discipline

**Adversarially verify before reporting** (as in `/agl-review`): for each
candidate finding, try to refute it — is the "uncovered" requirement actually
handled by a task under a different name? Is the "conflict" resolved in a note
you skimmed past? Findings that survive go in the report. Do not manufacture
findings to look thorough — "consistent, full coverage, no gaps" is a valid and
good result, report it plainly.

## Output

A severity-ordered report (**CRITICAL / HIGH / MEDIUM / LOW**), each finding
with both locations and a one-line fix, followed by a coverage summary line
(e.g. "14/14 criteria mapped · 0 unmapped tasks · 0 markers left"). Write
nothing to disk. End with a numbered menu:

```
1️⃣ Fix the gaps — route CRITICAL/HIGH back to /agl-spec or /agl-plan
2️⃣ /agl-build — proceed (only if no CRITICAL remains)
3️⃣ Accept a finding with a note — record why it's tolerable, then proceed
```

with one explicit recommendation. While any **CRITICAL** coverage gap,
unresolved `[NEEDS CLARIFICATION]`, or unjustified constitution violation
remains, option 2 is NOT the recommendation — name the blocker.
