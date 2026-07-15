# AGL Fusion — panel → judge, agl-native

Read once per session, on the first `/agl-fusion*` invocation (alongside
`core-behaviors.md`). This is the doctrine every `/agl-fusion*` command follows.

Fusion turns one prompt into a **panel**. The question goes to several models
**at the same time**, each answering independently — with web search and bash,
and with no knowledge of the others. Then Opus (this session — the
orchestrator) reads every answer, extracts the structure of the panel's
reasoning (what they agree on, where they conflict, what only one saw, what they
all missed), **adversarially verifies its own synthesis**, and writes a final
answer grounded in that analysis.

The whole mechanism is **independence, then synthesis**. The diversity that
makes a panel beat a single model is *harvested, not manufactured*: running the
same prompt independently yields different reasoning paths, tool calls, and
sources — even two cold runs of the same model diverge enough that synthesizing
them beats running it once. So there are **no assigned "lenses" or personas** —
every panelist gets the user's task **verbatim** and answers it straight.

**One hard rule: Opus always judges and writes the final answer — the
pipeline can't be reversed.** The panelist models can't call back out to spawn
Opus, so Opus is always the driver. The slug reads driver-first for that reason.

Throughout, `${SCRIPTS}` is `${CLAUDE_PLUGIN_ROOT}/scripts/fusion`.

---

## What makes the agl version better than upstream fusion-fable

Five deliberate upgrades sit on top of the proven panel→judge core (the runner
scripts are byte-identical to fusion-fable — that engineering is not re-derived):

1. **Brain provenance.** Every run is mirrored into the project's own `.agl/`
   brain (not only the global `~/.claude/fusion-runs/`), so a fusion answer
   travels with the project and surfaces in `/agl-recap`. (Step 6.)
2. **Constitution-aware panelists.** For a **project-scoped** question, every
   panelist prompt carries `.agl/CONSTITUTION.md`'s binding principles, so answers
   respect project law instead of proposing things it forbids. Skipped for general
   / off-project questions, where it would be noise. (Step 2.)
3. **Adversarial judge.** After synthesis, the judge runs a *refute pass* on its
   own final answer — the same skepticism `/agl-review` and `/agl-analyze` apply
   to every finding — before presenting. This kills confidently-wrong synthesis,
   which the upstream judge has no guard against. (Step 3c.)
4. **Workflow orchestration for heavy panels.** For high-stakes questions the
   fan-out, per-finding adversarial verification, and loop-until-dry can run as a
   deterministic `Workflow` instead of hand-spawned agents. (Step 2, optional.)
5. **Multi-session concurrency safety.** *Every* temp file lives under one
   per-invocation `run_dir` (`mktemp -d`), so N Claude Code sessions can run
   fusion at once without ever reading each other's prompts or answers. (Step 0.)

Everything else — the mechanism, the tracks, graceful degradation — matches
fusion-fable exactly.

---

## Step 0 — One run dir, then pick the panel

**Allocate a single per-invocation directory and put EVERY temp file for this run
under it** — this is what makes concurrent runs across sessions safe:

```bash
run_dir="$(mktemp -d "${TMPDIR:-/tmp}/agl-fusion.XXXXXX")"
```

Write the user's question **verbatim** to `"$run_dir/question.txt"` (several
steps reuse it). Never use fixed paths like `/tmp/fusion_question.txt` — a fixed
name lets a second session's run clobber or read this one's.

Then detect the richest panel this machine supports:

```bash
bash ${SCRIPTS}/detect_panel.sh
```

It prints a `SLUG=` line:

| Slug | Panel | Requires |
| --- | --- | --- |
| `opus-opus` | the same prompt run twice as 2 independent Opus panelists | nothing — always available |
| `opus-gpt` | Opus + GPT in parallel | `codex` CLI |
| `opus-gemini` | Opus + Gemini in parallel | `agy` CLI |
| `opus-gpt-gemini` | Opus + GPT + Gemini in parallel | `codex` + `agy` CLIs |

If the user named a slug (or used a pinned `/agl-fusion-*` command), honor it —
but if a required CLI is missing, say so, drop that panelist, and fall back to
the next-richest panel rather than failing. Otherwise use the detector's pick.

**Which model each panelist runs — the client's terminal config, never a hardcode.**
Fusion **never pins, picks, or prefers a model or tier**. Each panelist runs on
whatever its CLI is configured to use:
- **Opus panelist(s) + the judge** → the **session model** (whatever Claude Code is
  set to). "Opus" throughout these docs is a *nominal* label for the driver — the
  actual model is your session's (Sonnet, Fable, a newer Opus, …).
- **GPT panelist** → **codex's account default** (`run_codex.sh` passes no `--model`).
- **Gemini panelist** → **agy's configured default** (`run_gemini.sh` passes no
  `--model`). Choose the tier you want in agy itself (a Pro vs a Flash tier is your
  `agy` setting, not fusion's).

The slugs name the *family* (`opus-gpt-gemini`), never a version, for the same
reason. Optional per-run override for Gemini only: `AGY_MODEL="<exact model from
agy models>"` pins one for that run. That is the *only* model knob, and it is off
by default — so upgrading any CLI's default silently upgrades fusion, with nothing
to change here.

## Step 1 — Preflight (informational, never a gate)

```bash
bash ${SCRIPTS}/preflight.sh <SLUG> "$run_dir/question.txt"
```

Show its output (rough token/call estimate + Codex cap reminder), then proceed.
It never blocks. Each panelist is bounded by `FUSION_TIMEOUT` (default 600s);
raise it for heavy deep-research questions (`FUSION_TIMEOUT=900 bash ${SCRIPTS}/...`).

## Step 2 — Fan out, in parallel and blind

Build each panelist's prompt as the user's task **verbatim** plus the short
instruction: *research with web search and bash, then return a complete,
self-contained answer; you are one of several independent experts and will not
see the others' work.* Do **not** assign lenses; do **not** pre-digest the task.
Answer in the user's question language.

**Constitution injection (agl upgrade #2) — ONLY for project-scoped questions.**
Inject `.agl/CONSTITUTION.md` **only when both** hold: (a) it exists, **and**
(b) the question is about *this project* — its code, architecture, a decision or
plan within it, "our X", a review/refactor of this repo. For a **general or
off-project question** — a research / strategy / technical question not tied to
this codebase (e.g. "is `ALTER TABLE … ADD COLUMN` safe on a big table",
"what should a solo dev do in 2026") — **do NOT inject it**: the project's law is
irrelevant noise there and only distracts the panelists. When genuinely unsure,
lean toward **not** injecting (a missing-but-irrelevant constraint costs nothing;
an injected-but-irrelevant one adds noise to every panelist and the judge).

When it *does* apply, append its content to every panelist prompt under a header like:

> This project is governed by the following binding principles — your answer
> must respect them (or explicitly flag if the task requires violating one):
> ```
> <contents of .agl/CONSTITUTION.md>
> ```

This is the *only* framing added — it constrains the answer to project law; it
does **not** assign a lens or nudge the conclusion.

Launch **all panelists in a single turn** so they run concurrently:

- **Opus panelist(s)** → the `Agent` tool, `subagent_type: general-purpose`
  (web + bash built in). For `opus-opus`, spawn **two** independent Opus
  subagents with the *same* prompt — two cold runs. For every other slug, spawn
  **exactly one** Opus panelist alongside the external panelist(s). Send them in
  the same message. When each returns, write its answer to `"$run_dir/opusA.md"`
  (and `"$run_dir/opusB.md"` for the second Opus run) for provenance.
  Prefix the Agent prompt's first line with the literal marker
  `[AGL-FUSION-PANELIST]` so any spawn hook can recognise and skip fusion's own
  panelist spawns.
- **GPT panelist** (if slug includes it) → write its prompt to a file under
  `$run_dir`, then:
  ```bash
  bash ${SCRIPTS}/run_codex.sh "$run_dir/codex_prompt.md" "$run_dir/codex_out.md" xhigh
  ```
  The runner copies the current repo/workdir to a throwaway directory, then runs
  `codex exec` with full local access against that copy — the live checkout is
  untouched while GPT gets the same local tools/keychain as a trusted Codex
  run. Exit 124 = timed out; any other non-zero = drop GPT, note downgrade.
- **Gemini panelist** (if slug includes it) →
  ```bash
  bash ${SCRIPTS}/run_gemini.sh "$run_dir/gemini_prompt.md" "$run_dir/gemini_out.md"
  ```
  Calls `agy` under a pseudo-TTY (working around agy bug #76 — empty stdout with
  no TTY) with a transcript-JSONL fallback and a hard anti-empty guard, so it
  never returns a silently empty answer. Exit 127 = `agy` not installed; exit 1 =
  empty after both paths; exit 124 = timed out. On any non-zero, drop Gemini and
  note the downgrade.

Keep panelists isolated: never paste one panelist's output into another's
prompt. The orchestrator (you) is the judge and must stay separate from the
panelists — for `opus-opus`, both panelists are spawned subagents, not you, so
your synthesis reads all answers fresh.

**Optional — Workflow orchestration (agl upgrade #4).** For a high-stakes
question (a wrong answer is expensive, or the user asks to "be exhaustive"),
drive the fan-out with the `Workflow` tool instead of hand-spawned agents: a
pipeline that (a) fans the verbatim prompt to the panelists, (b) builds the
structured analysis, (c) spawns independent skeptics to adversarially verify
each load-bearing claim, and (d) loops until a round surfaces nothing new. Use it
when the extra rigor earns its tokens; for ordinary questions the inline fan-out
above is enough.

**Graceful degradation.** If an external panelist exits non-zero, remove it,
record a one-line degradation note (e.g. `gemini dropped: agy empty →
opus-gpt`), and continue. Fallback order:
`opus-gpt-gemini` → `opus-gpt` → `opus-opus` (two independent
Opus runs, zero external CLI). For `opus-gemini`, dropping Gemini falls
back to `opus-opus` (spawn a second Opus panelist) so the judge still sees two
blind answers. A degraded run still completes — never abort because one CLI failed.

## Step 3 — Judge (pick the track that fits the task)

Once every panelist has returned, **classify the deliverable first**, because
code and prose merge completely differently. Read every panelist response in full
and attribute by panelist (e.g. "Opus run A", "GPT") so the user can trace
every decision. **Mixed task** (e.g. "design AND implement X") → the
implementation is the deliverable: use **Track A** for the code and fold the
reasoning in as brief rationale — don't emit a prose report where a working
artifact was asked for.

### 3a. Track A — artifact task (code, script, config, schema, command)

The user wants a buildable thing. → **Run both, then merge.** You are integrating
two *implementations* into one working program, not writing a report:

1. **Understand each candidate** — its approach, what it gets right, where it
   looks buggy or fragile; note the concrete differences (APIs, data structures,
   algorithms, edge-case handling).
2. **Run each candidate with bash** — build them, run them, run tests, feed
   representative inputs. Observed behavior is ground truth and outranks any
   reasoning about which "looks" better. (If it genuinely can't be executed here
   — needs the live game or an unavailable toolchain — fall back to seam-reasoning
   and mark it **unverified**.)
3. **Resolve disagreements by what actually ran** — prefer the version that
   demonstrably worked. Never average two answers or keep both "to be safe."
4. **Pick a foundation, graft the parts that worked — don't blend.** One coherent
   design, consistent style; never a Frankenstein of two whole programs.
5. **Run the merged artifact and fix until it passes.** The seam between grafted
   pieces (mismatched signatures, imports, types, units, indices) is exactly where
   a merge silently breaks — running is what catches it. This is agl "evidence or
   it didn't happen": a merged artifact is not done until it is *verified to run*.

The panel's value for code is that two independent attempts expose each other's
bugs — the merge should end up **more correct than either input**.

### 3b. Track B — research / analysis task

The user wants understanding or a recommendation. → **Structured synthesis**,
written to `"$run_dir/analysis.md"`:

- **Consensus** — points where panelists independently agree. Independent
  agreement (across families, or two cold runs of one model) is your
  highest-confidence signal; note how many converged and whether by different
  routes.
- **Contradictions** — direct disagreements on fact or recommendation. State the
  competing positions, who holds them, and adjudicate where you can (who ran the
  code / read the primary source?). If unresolved, say so and name what would
  settle it. Never bury a real conflict to look tidy.
- **Partial coverage** — important sub-questions only some panelists engaged.
- **Unique insights** — non-obvious, valuable points raised by exactly one
  panelist. Often the highest-leverage payoff of fanning out — preserve them.
- **Blind spots** — what the panel as a whole missed, including shared
  assumptions none questioned. As judge you may add one none of them named.

Either track: weight a panelist that actually ran the code or read a primary
source over one reasoning from memory. A panelist that failed or was dropped is
treated as **absent** — never as silent agreement.

### 3c. Adversarial verify the synthesis (agl upgrade #3)

Before writing the final answer, **try to refute your own synthesis** — the same
discipline `/agl-review` applies per-finding. For each load-bearing claim in the
final answer, ask: did a panelist actually establish this, or did I smooth two
weaker answers into a confident one? Is a "consensus" really independent
agreement, or did both panelists share the same wrong assumption? A claim that
survives the refutation stands; one that doesn't gets softened to its true
confidence or cut. Plausible-but-unverified is the failure mode this step exists
to kill. For a high-stakes question, spawn one or more independent skeptic
subagents to attempt the refutation with fresh context.

## Step 4 — Final deliverable

- **Track A (code/artifact):** emit the complete, merged artifact — every file,
  ready to run as-is, not a diff or "take A's X and B's Y." You got here by
  running both candidates and running the merged result until it passed. Follow
  with a tight merge rationale: what each candidate did when run, what you took
  from each, what you verified.
- **Track B (research):** write the answer grounded in the structured analysis
  (and hardened by 3c) — lead with high-confidence consensus, fold in unique
  insights, flag what stays uncertain. It must follow *from* the synthesis, not
  be one panelist's answer lightly edited. Write it to `"$run_dir/final.md"`.

## Step 5 — Save global provenance

```bash
FUSION_PANEL_NOTE="<degradation note, or empty>" \
FUSION_ESTIMATE="<the preflight one-liner, optional>" \
bash ${SCRIPTS}/save_run.sh <SLUG> "$run_dir/question.txt" "$run_dir/analysis.md" "$run_dir/final.md" \
  "opus-A=$run_dir/opusA.md" "opus-B=$run_dir/opusB.md" "gpt=$run_dir/codex_out.md" "gemini=$run_dir/gemini_out.md"
```

Pass one `LABEL=path` per panelist that ran; **include `opus-B` for the
`opus-opus` panel** so the second blind Opus answer is recorded, and drop the
label for any panelist not in the slug. `save_run.sh` substitutes a placeholder
for any answer file that is missing or empty, so a degraded panel still produces
a complete record. It prints the path
of the global provenance `.md` it wrote under `~/.claude/fusion-runs/`.

## Step 6 — Mirror into the project brain (agl upgrade #1)

Pass the path save_run.sh printed to the brain mirror:

```bash
bash ${SCRIPTS}/save_brain.sh "<path save_run.sh printed>" <SLUG>
```

If this project has a `.agl/` brain, it copies the record into
`.agl/fusion-runs/` and appends a one-line pointer to today's session log; if
there's no brain, it's a silent no-op. Then, per agl brain upkeep, if the run
resolved something that changes project state (a decision, a chosen approach,
a gotcha), update `.agl/STATE.md` `## Now` in-place (2 lines) — STATE is curated,
so that edit stays a deliberate Claude action, not a script append.

## Step 7 — Present

Lead with the **final deliverable** — the merged working artifact (Track A) or
the grounded answer (Track B) — then the audit trail beneath it: for code, what
each candidate did when run + the merge rationale + what you verified; for
research, the five-section analysis. Name the panel slug you ran and which
panelists participated. If the panel downgraded because a CLI was missing, say so
and how to enable the fuller panel. Keep the agl product-owner voice: outcome
first, evidence second, mechanics last. **End with a numbered menu** (2–4 options,
exactly one explicit recommendation) — never an open question. A natural menu:

```
1️⃣ Act on the answer — <the concrete next step the answer implies>
2️⃣ Re-run richer/deeper — bump the panel or FUSION_TIMEOUT and run again
3️⃣ Save to brain — record the decision into .agl/ (memory + STATE)
```

## Cost & latency note

A panel costs roughly N× a single answer in tokens and runs as slow as its
slowest panelist. That's the deliberate trade: spend more to stop being
confidently wrong where that's expensive. For quick or low-stakes questions, a
single direct answer is the right call — don't reach for fusion when one model
would obviously do.
