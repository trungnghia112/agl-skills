---
description: Fusion panel of Opus 4.8 + Gemini in parallel, judged + adversarially verified by Opus 4.8 (opus-gemini)
argument-hint: <your hard question or task>
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` and
`${CLAUDE_PLUGIN_ROOT}/references/fusion.md` (once per session).

Run the **fusion** pipeline, forcing the `opus-gemini` panel: Opus 4.8
(`Agent` subagent) and Gemini (via `run_gemini.sh` → `agy`, pseudo-TTY)
answer the SAME prompt **in parallel**, each independently with web + bash and
neither seeing the other's work → Opus 4.8 judges both, **adversarially verifies
its own synthesis**, and writes the final answer grounded in the analysis.

Follow `references/fusion.md` exactly (one `run_dir` → preflight → fan out in
parallel and blind → judge on the fitting track → adversarial verify → grounded
final → `save_run.sh` → `save_brain.sh` → present). Use **exactly one** Opus 4.8
panelist and **one** Gemini panelist — do **not** add a GPT panelist
or a second Opus run. Pass the task **verbatim** to both; **no lenses**. Inject
`.agl/CONSTITUTION.md` into each panelist prompt **only if it exists and the question
is about this project** (Step 2 — skip it for general/off-project questions).

If the `agy` CLI is missing or the Gemini panelist fails/times out, drop it,
record a one-line degradation note, and fall back to `opus-opus` (spawn a
second independent Opus panelist) so the judge still sees two blind answers —
never abort because one CLI failed. Opus 4.8 always judges and writes the final
answer.

For a research/analysis task present the five sections (Consensus /
Contradictions / Partial coverage / Unique insights / Blind spots); for a
code/artifact task run both candidates and merge them into one working result
with a merge rationale. End with the standard numbered menu (one explicit
recommendation), in the owner's language.

Task: $ARGUMENTS
