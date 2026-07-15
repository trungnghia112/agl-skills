---
description: Fusion panel of two independent Opus runs, judged + adversarially verified by Opus (opus-opus) — zero external CLI, works everywhere
argument-hint: <your hard question or task>
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` and
`${CLAUDE_PLUGIN_ROOT}/references/fusion.md` (once per session).

Run the **fusion** pipeline, forcing the `opus-opus` panel: run the same prompt
**twice** as TWO independent Opus panelists (`Agent` subagents, in parallel,
neither seeing the other's work) → Opus judges both, **adversarially verifies
its own synthesis**, and writes the final answer grounded in the analysis. This
panel needs **no external CLI** and works everywhere — two cold runs of the same
model, synthesized, beat running it once.

Follow `references/fusion.md` exactly (one `run_dir` → preflight → fan out in
parallel and blind → judge on the fitting track → adversarial verify → grounded
final → `save_run.sh` → `save_brain.sh` → present). Do **NOT** add a GPT or
Gemini panelist, even if `codex`/`agy` are installed — this command is pinned to
the pure-Opus panel. Pass the task **verbatim** to both runs; **no lenses**.
Inject `.agl/CONSTITUTION.md` into each panelist prompt **only if it exists and the
question is about this project** (Step 2 — skip it for general/off-project questions). Both
panelists are spawned subagents (not you) so your synthesis reads both answers
fresh; mark each Agent prompt's first line `[AGL-FUSION-PANELIST]`.

For a research/analysis task present the five sections (Consensus /
Contradictions / Partial coverage / Unique insights / Blind spots); for a
code/artifact task run both candidates and merge them into one working result
with a merge rationale. End with the standard numbered menu (one explicit
recommendation), in the owner's language.

Task: $ARGUMENTS
