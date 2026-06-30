# AGL Brain v2 — format spec

The brain lives in `.agl/` at the project root. Design goals, in priority order:
**O(1) recap cost** (reading the brain never grows with project age),
**mechanical staleness detection** (never trust a note over git),
**one fact per file** (the Claude Memory model — update, link, delete individually).

This avoids the single-monolith trap, where a growing `session.json`-style
file makes recap cost balloon (observed in practice: 255 KB / 105k tokens,
truncated on read) and stale handover notes cause wrong-state reports.

```
.agl/
├── CONSTITUTION.md # project principles — binding gates. Read by spec/plan/review. Optional but recommended.
├── STATE.md        # small, always read at recap. The ONLY source of "now".
├── BRAIN.md        # memory index — one line per memory file. Read at recap.
├── memory/         # one durable fact per file. Read individually, on demand.
│   └── <type>-<slug>.md
└── sessions/       # append-only daily history. Rarely read; never read whole.
    └── YYYY-MM-DD.md
```

## CONSTITUTION.md

The project's binding principles — the few rules every spec, plan, and review
must honor. Optional, but recommended once the project has a point of view (a
stack choice, a testing bar, a "never do X"). Unlike `core-behaviors.md`
(global AGL discipline, the same in every project), the constitution is THIS
project's law, ratified by the owner.

Hard size budget: **3–7 principles**. A constitution nobody can recite is
decoration. Each principle is a gate: `/agl-plan` writes a `## Constitution
Check` against it, `/agl-analyze` and `/agl-review` flag violations, and
`/agl-build` honors it during implementation.

```markdown
---
version: 1.0.0          # MAJOR.MINOR.PATCH — bump on every amendment
ratified: YYYY-MM-DD
amended: YYYY-MM-DD
---

# Constitution

## P1 — <short name>
<one or two lines: the rule as MUST / NEVER, and why it exists.>

## P2 — <short name>
...

## Amendment log
- 1.0.0 (YYYY-MM-DD) — ratified with P1–P4.
```

**Gate semantics.** A principle is overridden only with an explicit, recorded
justification — what principle, why needed, what simpler alternative was
rejected — written onto the plan's `## Constitution Check`. A silent violation
is a review/analyze finding, not a judgment call.

**Versioning.** MAJOR = a principle removed or redefined incompatibly;
MINOR = a principle added; PATCH = wording/clarification. Bump on every edit
and append to the amendment log. The constitution is the one brain file that
is deliberately stable — it should change rarely and visibly. To change a rule
mid-work, propose an amendment (with a version bump); don't quietly route
around it.

## STATE.md

Hard size budget: **150 lines**. If it grows past that, move detail into
`sessions/` or `memory/` — STATE.md holds pointers, not prose.

```markdown
---
project: <name>
updated: <ISO timestamp>
last_commit: <short SHA of HEAD when this file was last saved>
---

# State

## Now
<1–3 lines: the one thing in flight, or "Nothing in flight.">

## Next (backlog)
| ID | Task | Priority | Blocked on |
|----|------|----------|------------|
| BL-08 | Windows Optimizer live UAT — checklist docs/specs/... | P1 | Windows machine |

## Recently shipped (last 7 — older history lives in sessions/)
- 2026-06-11 `3bd74e5` BL-05 Password Tier 2 → sessions/2026-06-11.md

## Watchlist (dated obligations)
- 2026-07-02 — monthly `npm audit` recheck in functions/ (accepted-risk trigger)
```

**`last_commit` is the staleness anchor.** Recap runs
`git log --oneline <last_commit>..HEAD`. Empty output → STATE is current,
trust it. Non-empty → work happened after the last save: reconstruct from
those commits + today's session file, tell the user STATE was stale, and
refresh it. There is no handover.md in this system — STATE.md + the anchor
make handover files (and their staleness bugs) unnecessary.

## memory/ files

One durable fact per file. Filename: `<type>-<slug>.md`.

```markdown
---
name: gotcha-csp-tauri-build
description: <one line — recap matches tasks against this; write it as "when X, beware Y">
type: gotcha | decision | learning | reference | preference | runbook
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

<The fact. Keep it actionable: what, why, how to apply.>
<For accepted-risk decisions, a "Re-report trigger:" line is MANDATORY
 (a date, version, or severity condition) — a risk-accept without a trigger
 is silent debt.>

Links: [[other-memory-name]]
```

Types: `gotcha` (trap + workaround), `decision` (choice + why + trigger),
`learning` (transferable lesson), `reference` (URL/dashboard/ticket),
`preference` (how the owner wants things done), `runbook` (how to run/UAT/
deploy this project).

## BRAIN.md

The index — one line per memory file, nothing else. This is what recap reads;
individual files load only when their description matches the task at hand.

```markdown
# Brain index
- [when X, beware Y](memory/gotcha-csp-tauri-build.md) — gotcha
- [wallet mutations must use runTransaction](memory/decision-wallet-txn.md) — decision
```

## sessions/YYYY-MM-DD.md

Append-only. Each save appends one entry:

```markdown
## HH:MM — <one-line outcome>
- Commits: `abc1234` <subject>, ...
- Evidence: <test counts, build status, UAT performed>
- Memory: created/updated [[name]], [[name]]   ← links, never duplicated prose
- Next: <what was queued, if anything>
```

## Memory discipline (the Claude Memory rules)

1. **Update, don't duplicate.** Before writing a memory, scan BRAIN.md for an
   existing file covering the same fact — update that file and bump `updated`.
2. **Delete when wrong.** A memory proven incorrect is removed (file + index
   line), not annotated around.
3. **Don't store what the repo already records** — code structure, git
   history, CLAUDE.md content. Store only what you'd otherwise re-discover
   the hard way.
4. **Trust but verify.** A recalled memory reflects when it was written. If it
   names a file/flag/function, confirm it still exists before acting on it.
5. **One fact per file.** If an entry needs two descriptions, it is two files.
