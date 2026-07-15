---
description: Fan a hard question to a blind PANEL of models in parallel → Opus 4.8 judges + adversarially verifies → grounded answer. Auto-picks the richest panel this machine can run.
argument-hint: <your hard question or task>
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` and
`${CLAUDE_PLUGIN_ROOT}/references/fusion.md` (once per session).

Run the **fusion** pipeline on the task below, **auto-selecting the richest panel**
this machine supports (`detect_panel.sh` decides: 3-way if `codex` + `agy` are
installed, else it degrades gracefully). Follow `references/fusion.md` exactly:

1. **Step 0** — allocate ONE `run_dir` (`mktemp -d`) and write the question
   verbatim to `"$run_dir/question.txt"`; run `detect_panel.sh` for the SLUG.
2. **Step 1** — preflight (informational, never a gate).
3. **Step 2** — fan out **in parallel and blind**: each panelist gets the task
   **verbatim** (no lenses), plus `.agl/CONSTITUTION.md` if it exists. Opus 4.8
   panelist(s) via the `Agent` tool (first line marked `[AGL-FUSION-PANELIST]`);
   GPT via `run_codex.sh`; Gemini via `run_gemini.sh`. Launch all in one turn.
4. **Step 3** — classify the deliverable, then judge: **Track A** (code → run both
   candidates, merge, run the merged result until it passes) or **Track B**
   (research → the five sections). Then **3c: adversarially verify your own
   synthesis** before writing the final answer.
5. **Steps 4–7** — grounded final deliverable → `save_run.sh` (global provenance)
   → `save_brain.sh` (mirror into `.agl/` if a brain exists) → present, leading
   with the answer then the audit trail, and name the panel slug + participants.

Never assign lenses or personas — independence is the mechanism. If an external
CLI is missing or a panelist fails, degrade gracefully and note it; never abort
because one CLI failed. Opus 4.8 always judges and writes the final answer.

End with the standard numbered menu (one explicit recommendation), in the owner's
language.

Task: $ARGUMENTS
