---
description: Turn an agent correction or a prose rule into a check the build runs — measure first, freeze the old findings, prove the check fires, wire it in, ship it as a PR
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md`.

Prose (CLAUDE.md, AGENTS.md, skills) is the least trustworthy thing an agent
has: it is advice, and the next agent may not read it, weigh it, or remember
it. When the owner has to correct an agent, or a written rule keeps being
broken, the fix belongs **in the repo, as a check that fails the build**, so it
holds on every machine and for every agent without anyone remembering it.

Order of trust, cheapest to fix first (the "trust pyramid" from *All Code Is
Slop (Except Mine)*, Lauren Tan, AI Engineer Code Summit 2026): **codebase**
(API design that makes the mistake impossible) → **static analysis** (lint,
types, gates) → **verification** (run the app, prove the property) → **prose**
→ **human review** (most expensive, so the one to shrink). Full playbook,
templates and gotchas: [references/gate.md](${CLAUDE_PLUGIN_ROOT}/references/gate.md).

## Mode

`$ARGUMENTS`:

| Argument | Mode |
|---|---|
| the correction or rule, in words ("never write undefined to Firestore") | **GATE** — §1 to §6 for that one rule |
| `audit` | **AUDIT** — classify every rule in this repo's agent config (§7) |
| `fork-lint` | **FORK-LINT** — lint a fork's own code in every build (references/gate.md §Fork lint) |

No argument: ask which, one numbered question, recommend one.

## 1. Log the correction

Add a row, newest first, to `corrections.md` in this repo's AGL brain
(`.agl/corrections.md`, or the brain folder the repo already uses; create it
from the header in references/gate.md if missing): date · where · what the
agent did wrong · the check that would have caught it · status (`open`).
The weekly row count is the metric "corrections per week".

## 2. Pick the cheapest check that cannot be argued with

| The mistake | The check |
|---|---|
| A forbidden API, decorator, import or syntax shape | ESLint: an existing plugin rule first (`@angular-eslint/*`, `@typescript-eslint/*`, …), else `no-restricted-syntax` / `no-restricted-imports` with a message that names the fix |
| A data or contract shape a linter cannot see (a write payload, a cross-file invariant, a config file) | a gate script in the repo's lint folder: parse with the TypeScript AST (not regex) when code is nested, and refuse to report clean when it examined nothing |
| A behaviour | a test that fails before the fix and passes after |
| Only visible in the running app (render, locale, overlay) | verification: run the app, screenshot as evidence (not a lint) |
| Taste and judgement | stays prose: say why in one line |

Prefer making the mistake impossible (an API with no wrong way to call it, a
directory layout that forbids the import) over detecting it afterwards.

## 3. Measure before enabling — never skip

- Count violations with the **real tool over the real tree**, not grep. Grep
  undercounts: "zero" by grep was 30 + 15 by ESLint the day this was written.
- **Read every hit.** A check that reports correct code gets narrowed or
  dropped, and the reason goes into its config comment: a gate that cries wolf
  stops being read.
- **Scope by ownership.** A framework repo checks its own layer; a fork checks
  its own code with its own config and never edits the framework's files (they
  conflict on every upgrade).

## 4. Enable

- **Zero violations** → `error` now. This is the common case for a rule the
  team already follows by habit, and it costs nothing.
- **Existing violations** → freeze them, do not fix them in the same change.
  ESLint: bulk suppressions (`--suppress-all --suppressions-location
  <lint dir>/eslint-suppressions.json`); a new finding fails, a fixed one leaves
  an unused suppression that fails until `--prune-suppressions`, so the file
  only shrinks. A custom gate: a committed baseline that may only shrink.
- **Wire it into what always runs** (`prebuild`, the fork's `prebuild:fork`,
  CI). A check that runs only when someone remembers is prose again.

## 5. Prove it

All four, or it is not done:

1. **It fires.** Plant one violation per rule inside the scanned tree: the check
   fails and names the file. Remove it: green.
2. **It examined something.** An empty or skeleton tree exits non-zero, not
   "OK, 0 findings".
3. **It changed nothing else.** A new or wrapped config gives the SAME per-rule
   counts as the old one on the existing rules.
4. **The repo still builds** with its real build command (some repos build per
   data driver) and passes its own hooks. Never `--no-verify` unless the repo's
   own documented procedure prescribes it for that exact failure, and the owner
   agrees.

Heavy runs (lint over the tree, build, test suites) obey the machine's load
check and lock when it has them (see references/gate.md).

## 6. Ship

- If the checkout holds someone else's uncommitted work, use a worktree from
  `origin/<default branch>` and commit only your own files.
- One PR: why (the correction), what was measured, what was left off and why,
  how it was proven, and the findings that unpushed branches will meet once the
  check lands (diff the working tree against `origin`).
- Close the loop: the corrections row becomes `gated: <check>`, and the prose
  rule shrinks to one line that names the check.

## 7. AUDIT mode

Read the repo's agent config (CLAUDE.md, AGENTS.md, an agent kernel) and put
every rule in one state, with evidence:

| State | Meaning | Evidence |
|---|---|---|
| GATED | a check already enforces it | the check's name |
| CANDIDATE | a check could | violation count measured with the real tool, proposed check |
| VERIFY | needs the running app | what would prove it |
| PROSE | judgement | why it stays |

Then offer the CANDIDATE rules with **zero** violations first: they become
checks with no code changes at all.

## Report

Product-owner voice (core-behaviors): what is now enforced and where it runs,
the numbers measured, what was left off and why, links to the PRs, numbered
next steps with exactly one recommendation.
