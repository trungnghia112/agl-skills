# Delegation — the architect's routing doctrine

Read once per session, on the first `/agl-delegate` or `/agl-build delegate`
invocation (alongside `core-behaviors.md`).

Delegation turns the session into an **architect**: it owns requirements,
decomposition, interfaces, specs, routing, and verification — and hands the
typing to a lane running on a different model family, via the `codex` CLI.
The premium is spent where it changes the outcome (the architecture and the
judgement of the diff), not on emitting boilerplate.

Two things make this worth the extra moving parts:

- **Cost.** Most of a build's tokens are mechanics. Mechanics are the cheapest
  thing to move off the session.
- **Vendor diversity.** The lane's code comes from a non-Anthropic family, so
  the session's verification is a genuine cross-vendor check rather than
  same-family self-review. Models from one lineage share blind spots.

Delegation is **opt-in and explicit** (constitution P1). `/agl-build` still
runs the session's own TDD loop by default; nothing routes to a lane unless
the owner asked for it.

---

## Cost discipline — the prime directive

**Emit judgment, not volume.** The architect's output is decomposition, specs,
routing decisions, verdicts on diffs, and short reports. A code block longer
than an interface signature is a spec that hasn't been delegated yet — stop and
delegate it. Hand-patching a lane's bug is the same failure wearing a disguise:
send a corrected spec back instead.

**Keep the context lean.** Everything in the architect's context is re-read on
every turn. Delegate broad codebase exploration to a cheap read-only agent and
keep only the conclusions. Read files yourself when the decision genuinely
depends on the exact code — not to feel thorough.

**Reason once, then hand off.** Do the hard thinking — architecture, interface
design, the debugging hypothesis — in one pass, capture it in the spec, and let
the lane carry it. Re-deriving a decision across turns pays for it twice.

What stays with the architect regardless of cost: decomposition, interface
design, hypothesis selection when debugging, spec writing, effort routing, and
judging verification evidence. Everything else is a delegation candidate.

---

## The lane

| Lane | Producer | Invoke | Route here when |
|---|---|---|---|
| Implementation | GPT, via `codex exec` | `agl-codex-lane` agent | The spec fully determines the outcome, or the effort rung covers the judgement it doesn't |
| Advice | Session model, clean context | `agl-advisor` agent | A commitment boundary, or the end-of-deliverable review. Never implements. |

**One lane, tiered by reasoning effort — not by model slug.** Fusion's rule
holds here too: a slug names a family, never a version, and the lane runs on
whatever `codex` is configured to use. Escalation is a rung on the effort
ladder, not a different hardcoded model. A spec MAY name `MODEL: <slug>` when
the owner has a specific tier in mind; absent that line, the lane never picks
one, and an upgrade to the CLI's default silently upgrades us.

If `codex` is missing or unauthenticated the lane returns `STATUS: unavailable`
and stops. It **never** falls back to implementing the task itself — a
cross-vendor lane that quietly becomes a same-vendor lane is worse than a loud
failure, because the caller chose the lane precisely for the diversity. On
`unavailable`, say so in the report and decide out loud: keep the task with the
session, or stop. Never absorb the substitution silently.

---

## Choosing the reasoning effort

Nothing is pinned. The architect names one rung per task; the lane passes it
through unchanged and **refuses rather than rounds** an unsupported rung. Pick
the lowest rung that is adequate — effort is cost and wall-clock, not a quality
dial to leave at maximum.

| Rung | Use for |
|---|---|
| `low` / `medium` | Mechanical edits, renames, wiring, config, tests mirroring an existing pattern |
| `high` | Ordinary features with a couple of decisions left to the lane |
| `xhigh` | Tricky logic, multi-file changes with interactions, the retry after a spec correction |
| `max` | The hardest single-lane work: concurrency, security-sensitive paths, gnarly debugging |
| `ultra` | Wide-blast-radius refactors and problems that resisted two attempts. Slowest; not every model has it — the lane reports `unavailable` rather than silently dropping to `max` |

Omitting the rung is acceptable for trivial work only: the lane then runs at the
owner's own configured default and flags it in `GAPS`. Never omit it on an
escalation.

A task that fails its spec once gets a **corrected spec**, not a shrug. Twice is
evidence it was misclassified: raise the rung, or take it back to the session.

---

## The spec contract

The lane shares none of the session's conversation. Every delegation carries
all six parts — this is what makes context-free delegation safe:

1. **Objective** — what to build or change, one paragraph
2. **Files** — exact paths to create or modify
3. **Interfaces** — signatures, types, or wire shapes the code must match
4. **Constraints** — project conventions, and what not to touch
5. **Verification** — the exact command that proves it works
6. **Reasoning** — one line, `REASONING: <rung>` (optionally `MODEL: <slug>`)

A spec you cannot finish writing is a decision you have not made. That is
architect work — not a reason to hand the ambiguity down to a cheaper model.

When a plan from `/agl-plan` already exists, the task's `acceptance:` criteria
supply parts 1 and 5; the architect adds Files, Interfaces, Constraints, and
the rung.

---

## The hijacked-lane hazard

`codex exec` loads the user's global `~/.codex/AGENTS.md` on every invocation.
When that file mandates an orchestration flow of its own ("read this workflow
file first", "do not skip any steps", auto-activating skills), codex will
correctly decline to bypass it — and the run comes back **exit 0, empty diff,
and a polite refusal in the final message**. Nothing in the exit code reveals
it. This is not hypothetical; it is the most common silent failure of this
pattern.

The runner prepends a scoped opt-out preamble stating that this lane's model
and effort were chosen deliberately and that the lane is an explicit exception
to any default-flow rule — while leaving every other instruction in those files
in force. That is belt-and-braces. The mechanical catch is the empty-diff check
below, which fires whatever the cause.

---

## Verification

Reports are claims. Evidence is a diff you read and a command you re-ran.

- **An empty diff is never `complete`.** Exit 0 with nothing changed is a
  refusal, not a success. The runner detects this mechanically and the lane
  reports `STATUS: refused` with the final message quoted verbatim.
- **Re-run the verification command yourself.** "The lane says it passes" is
  forbidden as evidence (core-behaviors #6). Its claim of success and your
  re-run are different facts.
- **Read the diff before accepting it.** Scope creep in a lane's output is the
  architect's problem to catch — the lane cannot know what the task did not ask
  for.
- **A wrong diff is reported, not patched.** Fix decisions belong to the
  architect: send a corrected spec.
- **A spec-level failure stops the lane.** If the spec itself is wrong, that is
  an upstream decision — consult `agl-advisor` or go back to `/agl-plan`.

Delegated work clears the same bar as hand-written work: the task's acceptance
criteria **and** `definition-of-done.md`. Delegation changes who types, never
what "done" means.

---

## Parallelism

Independent specs — no shared files, no ordering dependency — launch as
parallel agents in a single message. Sequential chains and single-file surgery
stay serial. For a high-stakes task, run the same spec twice at different rungs
and judge the two diffs; that is the fusion idea applied to code.

---

## Commitment boundaries and the final review

Consult `agl-advisor` at the moments that decide whether the next hour is
wasted:

- Before committing to an architecture, a data migration, an API shape, or a
  refactor strategy
- Whenever the same problem has resisted two distinct attempts
- **Once, at the end of a delegated deliverable**, before reporting done — it
  reads the accumulated diff against the stated goal rather than against the
  conversation, and returns ship / fix-first / rethink

Pass it the decision (or the diff), the constraints, and the options
considered. Act on the verdict or surface the disagreement — never quietly
ignore it.

One honest caveat: the advisor runs on the session model. It buys **fresh
context**, not an independent model — it reads the code without the assumptions
the architect accumulated while writing the specs. Cross-vendor independence
comes from the lane producing the code. When a deliverable deserves both, run
`/agl-review` (five-axis, adversarially verified) or an `/agl-fusion` panel on
top; the advisor is the cheap fast check, not a replacement for either.
