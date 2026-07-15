---
description: High-confidence CONCISE plan — a 3-round iterative fusion panel (Opus + GPT, blind) deepens an /agl-plan seed, then hands off to /agl-analyze → /agl-build. agl-native (no OMC).
argument-hint: "[--no-interview] <what to plan / decide>"
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` and
`${CLAUDE_PLUGIN_ROOT}/references/fusion.md` (once per session).

`/agl-fusion-plan` applies the fusion panel to **planning**. Instead of one
panel→judge pass it runs the panel as an **iterative loop** seeded by an agl plan,
and plugs into the agl lifecycle end to end: **`/agl-spec` → `/agl-plan` (seed) →
3-round panel deepening → write back to `plans/…/plan.md` → `/agl-analyze` →
`/agl-build`.** The panel replaces only the *plan-thinking* step; agl owns the
interview, plan format, consistency gate, and execution.

`${SCRIPTS}` is `${CLAUDE_PLUGIN_ROOT}/scripts/fusion`.

**Hard rule (same as fusion): Opus always judges and synthesizes. You are the
judge — stay separate from the panelists.** The Opus panelist is always a
*spawned subagent*, never you.

## Step 0 — Requirements (pick the mode FIRST)

**Decide interactive vs non-interactive before doing anything — it determines
whether you may interview.**

- **Non-interactive** when ANY is true: invoked with `--no-interview`; running
  autonomously inside a larger `/agl-build`; running inside a spawned sub-agent;
  or you otherwise cannot reach a human to answer. **This is the default during
  plan execution.**
  → **Do NOT interview. Do NOT call `AskUserQuestion`. Do NOT run `/agl-spec`.**
  Derive `SEED_PLAN` from context that already exists, in this order: (1) the
  spec (`docs/specs/…`), (2) the flagged section of the larger `plans/…/plan.md`,
  (3) the task args you were given. If that context is genuinely insufficient,
  do NOT guess — stop and return a short note listing exactly what's missing, so
  the human or orchestrator resolves it. Then go to Step 1.

- **Interactive** (a human typed `/agl-fusion-plan …` directly and can answer):
  gather requirements the agl way, then produce the seed plan:
  1. If no spec covers this, run `/agl-spec` on the request **verbatim** (its
     one-question-at-a-time interview → spec with measurable `AC-#`). Skip if a
     current spec already exists.
  2. Run `/agl-plan` on that spec to produce the initial `plans/<YYMMDD-HHMM>-<slug>/plan.md`.
     **Capture that path as `SEED_PLAN`** — it carries the gathered requirements;
     they must survive into the final plan. Do not let `/agl-build` auto-start.

## Step 1 — Preconditions

This skill targets the `opus-gpt` panel. Allocate one per-invocation dir
(`run_dir="$(mktemp -d "${TMPDIR:-/tmp}/agl-fusion-plan.XXXXXX")"`) so concurrent
runs never collide, then check codex:

```bash
command -v codex && codex --version
```

- `codex` installed → run the full Opus + GPT loop below.
- `codex` **missing** → tell the user, then fall back to two independent Opus
  panelists per round (`opus-opus`) rather than failing. Note the downgrade and
  how to enable GPT (`npm i -g @openai/codex` + `codex login`).

Honor `references/fusion.md`: every panelist gets the same input **verbatim**, no
assigned lenses or personas.

## Step 2 — The loop, SEEDED from the agl plan (round R = 1, 2, 3)

The panel does NOT draft blind — round 1 is already seeded by `SEED_PLAN`, so the
spec's requirements anchor everything.

### 2a. Build each panelist's prompt (identical for both, every round)

The original request **verbatim**, plus the current plan, plus:

> Here is the current plan (round 1: the requirements + initial plan from an agl
> spec/plan; later rounds: the synthesized plan from the previous round):
> ```
> <round 1: SEED_PLAN | round R>1: PLAN v(R-1)>
> ```
> You are one of several independent expert planners; you will not see the
> others' work. Research with web + bash as needed, then return an IMPROVED,
> COMPLETE plan. **Preserve every requirement and constraint already captured** —
> do not drop them. Fix wrong assumptions, fill gaps, add missing risks/edge
> cases, sharpen sequencing and decisions, and CUT padding — the plan must get
> tighter and denser, not longer. If you genuinely believe no material
> improvement is possible, say so explicitly on the first line
> (`NO_MATERIAL_CHANGE`) and return the plan unchanged.

If `.agl/CONSTITUTION.md` exists, append it so both planners respect project law —
planning is inherently project-scoped, so Step 2's injection **always** applies here
(unlike a plain fusion question, which may be off-project). Keep panelists **isolated** — never paste one
panelist's round-R output into the other's round-R prompt; the only shared input
across a round is the previous round's synthesized plan (or `SEED_PLAN` in round 1).

### 2b. Launch BOTH panelists in ONE turn (parallel, blind)

- **Opus panelist** → `Agent` tool, `subagent_type: general-purpose`,
  prompt = the panelist prompt above, **first line marked `[AGL-FUSION-PANELIST]`**.
  Spawn a **fresh** subagent each round.
- **GPT panelist** → write the prompt to a file under `$run_dir` and run codex
  at **high** effort:
  ```bash
  bash ${SCRIPTS}/run_codex.sh "$run_dir/codex_r${R}_prompt.md" "$run_dir/codex_r${R}_out.md" high
  ```
  Read the out file once it finishes. Exit 127 / missing-codex → apply the Step 1
  fallback.

Send the Agent call and the codex Bash call in the **same message** so they run
concurrently.

### 2c. Judge → synthesize Plan vR

When both panelists return, follow `references/fusion.md` **Track B + 3c**: build
the structured analysis over the two plans (**Consensus · Contradictions ·
Partial coverage · Unique insights · Blind spots**), then write **Plan vR**: the
single best plan grounded in it, and adversarially verify it preserves every
`SEED_PLAN` requirement. Do not average or smooth over conflict. A panelist that
failed or was dropped is treated as **absent**, never as silent agreement — if it
dropped a requirement, restore it.

### 2d. Early stop

If `R >= 2` and **both** panelists returned `NO_MATERIAL_CHANGE`, the plan has
converged: finalize and skip the remaining round(s). Record the convergence round.

## Step 3 — Write the CONCISE final plan back to `plans/…/plan.md`

The deliverable is **short but content-dense** — every line load-bearing, no
filler, no restating the task, no hedging. A round that only added length without
adding/correcting a decision did NOT improve the plan.

Write it back to the **same `SEED_PLAN` file** (`plans/<slug>/plan.md`) so there
is ONE agl artifact, in the standard `/agl-plan` format (see that command):
phased tasks (Setup → Foundational → slices → Polish) each with `acceptance:` /
`covers:` (AC-# IDs) / `files:` (real paths) / `depends:` / `[P]` / `risk:`; a
`## Verification` section (evidence rung); a `## Contracts` section for every wire
boundary; and a `## Constitution Check` if `.agl/CONSTITUTION.md` exists (every
principle honored or justified). Keep the status table. Add a pre-mortem only if
the task is genuinely high-risk (auth/security, migration, destructive, PII).

## Step 4 — Present, then hand off to the agl lifecycle

Present, in the owner's language, product-owner voice:

1. **Final Plan** — the dense plan inline (or a tight summary + the
   `plans/<slug>/plan.md` path if long).
2. **Convergence trail** — 1–2 lines per round: seed → v1 → v2 → v3, what each
   round changed (decisions added / removed / corrected). Evidence the iteration
   earned its tokens.
3. **Panel line** — panel slug (`opus-gpt`), rounds run, early-stop or not,
   any downgrade. Then `save_run.sh` + `save_brain.sh` on the run for provenance.

Then **offer** the handoff — do not auto-run execution:

```
1️⃣ /agl-analyze — consistency-gate the plan (spec ↔ plan ↔ tasks ↔ constitution) before building
2️⃣ /agl-build — start the first task (or `/agl-build auto` after analyze is clean)
3️⃣ Edit plan — tell me which decision to change
```

with one explicit recommendation (usually option 1 — analyze before build).

## Cost & latency note

One run is the interview + `/agl-plan` seed + ~6 panelist runs + 3 judge passes —
several× a single plan, as slow as the slowest panelist per round. That's the
deliberate trade for high-stakes planning where a wrong plan is expensive. For
trivial planning, run plain `/agl-plan` (or `/agl-fusion-gpt`) instead — don't
reach for the full chain when one would obviously do.

Task: $ARGUMENTS
