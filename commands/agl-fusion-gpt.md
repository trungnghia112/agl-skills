---
description: Fusion panel of Opus + GPT in parallel, judged + adversarially verified by Opus (opus-gpt)
argument-hint: <your hard question or task>
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` and
`${CLAUDE_PLUGIN_ROOT}/references/fusion.md` (once per session).

Run the **fusion** pipeline, forcing the `opus-gpt` panel: Opus
(`Agent` subagent) and GPT (via `run_codex.sh` → `codex exec`) answer the
SAME prompt **in parallel**, each independently with web + bash and neither
seeing the other's work → Opus judges both, **adversarially verifies its own
synthesis**, and writes the final answer grounded in the analysis.

Follow `references/fusion.md` exactly (one `run_dir` → preflight → fan out in
parallel and blind → judge on the fitting track → adversarial verify → grounded
final → `save_run.sh` → `save_brain.sh` → present). Use **exactly one** Opus
panelist and **one** GPT panelist — do not add a Gemini panelist or a second
Opus run. Pass the task **verbatim** to both; **no lenses**. Inject
`.agl/CONSTITUTION.md` into each panelist prompt **only if it exists and the question
is about this project** (Step 2 — skip it for general/off-project questions). Likewise
inject the **freshness guard** (Step 2) **only if the question is time-sensitive**
(latest version/price/release-status/law) — skip it for timeless questions.

If the `codex` CLI is not installed, **stop and say so** (with how to enable it:
`npm i -g @openai/codex` + `codex login`) rather than silently downgrading to the
`opus-opus` panel — this command is pinned to include GPT.

For a research/analysis task present the five sections (Consensus /
Contradictions / Partial coverage / Unique insights / Blind spots); for a
code/artifact task run both candidates and merge them into one working result
with a merge rationale. End with the standard numbered menu (one explicit
recommendation), in the owner's language.

Task: $ARGUMENTS
