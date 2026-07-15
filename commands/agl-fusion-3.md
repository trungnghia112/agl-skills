---
description: Full 3-family fusion panel — Opus + GPT + Gemini in parallel, judged + adversarially verified by Opus (opus-gpt-gemini)
argument-hint: <your hard question or task>
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` and
`${CLAUDE_PLUGIN_ROOT}/references/fusion.md` (once per session).

Run the **fusion** pipeline, forcing the richest panel
`opus-gpt-gemini`: Opus (`Agent` subagent), GPT (via
`run_codex.sh` → `codex exec`), and Gemini (via `run_gemini.sh` → `agy`,
pseudo-TTY) answer the SAME prompt **in parallel**, each independently with
web + bash and none seeing the others' work → Opus judges all three,
**adversarially verifies its own synthesis**, and writes the final answer
grounded in the analysis.

Follow `references/fusion.md` exactly (one `run_dir` → detect confirms the slug →
preflight → fan out in parallel and blind → judge on the fitting track →
adversarial verify → grounded final → `save_run.sh` → `save_brain.sh` → present).
Pass the task **verbatim** to all three; **no lenses**. Inject `.agl/CONSTITUTION.md`
into each panelist prompt **only if it exists and the question is about this project**
(Step 2 — skip it for general/off-project questions). Three families, one of each — do **not**
add a second Opus run.

This command targets the FULL panel but **degrades gracefully**: if `codex` or
`agy` is missing or a panelist fails/times out, drop it, note the degraded panel
in the output, and finish with what remains (`opus-gpt`, then ultimately
`opus-opus`) rather than aborting. Opus always judges and writes the final
answer.

For a research/analysis task present the five sections (Consensus /
Contradictions / Partial coverage / Unique insights / Blind spots); for a
code/artifact task run both candidates and merge them into one working result
with a merge rationale. End with the standard numbered menu (one explicit
recommendation), in the owner's language.

Task: $ARGUMENTS
