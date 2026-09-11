# agl-skills

`/agl-*` skills for Claude Code: a **persistent project brain** (state +
memory + sessions) paired with **senior-engineer discipline** (TDD,
mandatory evidence, scope control). Everything is triggered by explicit
`/agl-*` commands — nothing runs in the background.

## Philosophy

| Project memory | Engineering discipline |
|---|---|
| Cross-session brain (recap/save) | TDD: red test first, green code after |
| Backlog with IDs, dated watchlist | Evidence required, never "looks right" |
| Numbered menus + exactly one recommendation | State assumptions, stop when stuck, push back |
| Product-owner voice, in the user's language | Scope discipline, surgical commits, clean revert |
| `/agl-next` suggests work from the backlog | `auto` mode: approve once + hard-stop on risky tasks |

## Brain v2 — O(1) recap

Modeled on Claude Memory, not a single monolithic file:

- **`.agl/CONSTITUTION.md`** — optional, 3–7 binding principles this project
  lives by (stack, testing bar, "never do X"). Versioned and amended visibly;
  `/agl-plan`, `/agl-analyze`, and `/agl-review` enforce it as gates.
- **`.agl/STATE.md`** — small (≤150 lines), always read: what's in flight,
  backlog, watchlist. Frontmatter carries `last_commit` → recap runs
  `git log <anchor>..HEAD` to **detect staleness mechanically** instead of
  trusting old notes.
- **`.agl/memory/`** — one fact per file (gotcha/decision/learning/runbook/
  preference), each with a description for just-in-time recall; update rather
  than duplicate, delete when wrong. One-line-per-file index in `BRAIN.md`.
- **`.agl/sessions/`** — append-only daily log; history lives here and is
  never read as a whole.

→ Recap cost is **O(1)** regardless of how old the project gets.

## Install & use

Install via the marketplace:

```
/plugin marketplace add trungnghia112/agl-skills
/plugin install agl-skills@agl-skills
```

After installing: run `/agl-init` in your project → `/agl-help` for the
overview. Every command is an explicit `/agl-*` — nothing auto-activates.

```
morning:  /agl-recap
working:  /agl-spec → /agl-plan → /agl-analyze → /agl-build auto → /agl-review
done:     /agl-ship   (brain saves itself on ship; /agl-save when stopping mid-stream)
```

## Versioning

`.claude-plugin/plugin.json` carries a semver `version` field — bump it
(PATCH/MINOR/MAJOR per the usual rules) in the same commit as any
user-facing change (new/changed command, behavior change). Without it,
Claude Code falls back to labeling installs by git commit SHA, which is
illegible to users and busts the plugin cache on every commit, including
non-functional ones.

## Fusion — multi-model panels

`/agl-fusion` fans a hard question to a **blind panel of models in parallel** —
each answers independently with web + bash, none seeing the others — then Opus
judges every answer into a structured analysis (consensus / contradictions /
partial / unique / blind spots), **adversarially verifies its own synthesis**, and
writes a grounded final answer. The mechanism is *independence, then synthesis* —
no lenses, every panelist gets the task verbatim.

```
/agl-fusion         auto-pick the richest panel installed on this machine
/agl-fusion-3       session model + GPT (codex) + Gemini (agy)
/agl-fusion-gpt     session model + GPT (codex)
/agl-fusion-gemini  session model + Gemini (agy)
/agl-fusion-opus    two independent session-model runs — zero external CLI
/agl-fusion-plan    3-round iterative panel deepening an /agl-plan seed
```

Fusion **never pins or picks a model** — each panelist runs on whatever its CLI is
configured to use: Opus/judge on the **session model**, GPT on your **`codex`
account default**, Gemini on your **`agy` configured default** (choose the tier in
agy itself). Slugs name the family (`opus-gpt-gemini`), never a version, so
upgrading any CLI's default silently upgrades fusion. Optional per-run pin for
Gemini only: `AGY_MODEL="<exact model>"`. Per-panelist timeout defaults to 600s
(`FUSION_TIMEOUT`); the throwaway workdir copy the GPT panelist runs against has
its own 60s cap (`FUSION_COPY_TIMEOUT`), and can be redirected with
`FUSION_SOURCE_ROOT=<path>` or skipped with `FUSION_NO_COPY=1`.

Opus **always** judges and writes the final answer. Every panel degrades
gracefully (a missing CLI drops that panelist, never aborts). Runs are saved to
`~/.claude/fusion-runs/` and mirrored into the project's `.agl/fusion-runs/`;
panelists honor `.agl/CONSTITUTION.md` on project-scoped questions, and get a
**freshness guard** (answer as of today from primary sources; latest ≠ announced)
on time-sensitive ones. The runner scripts in `scripts/fusion/` are self-contained
(bash/perl/python3 + optional `codex`/`agy`).

## Delegation — cross-vendor implementation lanes

`/agl-delegate` (and `/agl-build delegate`) turns the session into an
**architect**: it decides, specifies, routes, and judges — and hands the typing
to GPT through the `codex` CLI, on your real working tree. The premium is spent
on the architecture and on judging the diff, not on emitting boilerplate. And
because the code comes from a different model family than the session, the
review that follows is a genuine cross-vendor check instead of same-family
self-review.

```
/agl-delegate <task>      one-off: six-part spec → lane types → you verify the diff
/agl-build delegate       the TDD loop, with the lane typing the GREEN code
```

Delegation is **opt-in** — `/agl-build` runs the session's own TDD loop by
default and nothing routes to a lane unless you asked. You always keep the RED
test, the full suite, and the commit: delegation changes *who types*, never what
"done" means.

Two agents ship with it, invoked only by those commands, never on their own:

- **`agl-codex-lane`** — delivers the spec, supervises the run, verifies
  independently, reports with evidence. It never implements the task itself:
  no `codex` means `STATUS: unavailable` and a stop, because a cross-vendor lane
  that quietly becomes a same-vendor lane is worse than a loud failure.
- **`agl-advisor`** — read-only second opinion at commitment boundaries and once
  at the end of a deliverable: ship / fix-first / rethink, under 300 words. It
  buys fresh context, not an independent model — `/agl-review` and `/agl-fusion`
  remain the deeper checks.

Two things the lane gets mechanically right, because neither can be trusted to
narration:

- **An empty diff is a refusal, not a success.** `codex exec` returns 0 when it
  declines the work, so the runner fingerprints the working tree before and
  after and reports `refused` when nothing changed.
- **A global `~/.codex/AGENTS.md` cannot hijack the lane.** A user-level file
  that mandates its own workflow makes codex decline politely with exit 0 and an
  empty diff. The runner prepends a scoped opt-out for this lane only, leaving
  every other instruction in that file in force.

Nothing is pinned: the lane runs on whatever `codex` is configured to use, and
escalation is a **reasoning-effort rung** the spec names (`low` → `ultra`),
never a hardcoded model slug. Wall clock defaults to 900s
(`AGL_LANE_TIMEOUT`); the sandbox is `workspace-write`, never full access.

## Env bundle — a clone that brings its own configuration

`.env*` files are gitignored, so a fresh clone of a private repo starts with no
configuration and somebody has to hand over six files on Slack.
`/agl-env-bundle` commits an **AES-256 encrypted** archive of them instead:

```
/agl-env-bundle            # detects restore / setup / repack
/agl-env-bundle restore    # new machine: existing files are SKIPPED, never clobbered
```

The interesting part is what it refuses to do. `pack` packs the **whole
inventory** by default, because the way this pattern really fails is a new env
file missing from a hand-typed list — the pack succeeds, the archive verifies,
and the next clone is quietly short one secret. An undeclared gap between the
archive and what is on disk **fails the pack**; leaving a file out has to be
said out loud (`ENV_BUNDLE_EXCLUDE`). It also refuses to pack without a
resolved password (never invents or defaults to one), refuses a path that
escapes the repo root, refuses to leave an unverified archive on disk, and
hard-fails preflight on a public repo. `secrets/README.md` is generated from
the archive's real contents, so the doc cannot drift from the file list.

Doctrine — password policy, threat model, and when to move to SOPS or a secret
manager: `references/env-bundle.md`.

## Structure

```
agl-skills/
├── .claude-plugin/plugin.json
├── commands/        # 23 /agl-* commands (loaded only when invoked — near-zero background tokens)
├── agents/          # agl-codex-lane (delegation) + agl-advisor (second opinion)
├── references/
│   ├── core-behaviors.md      # core rules every command follows
│   ├── brain-format.md        # .agl/ spec + memory rules
│   ├── definition-of-done.md  # the standing bar, separate from per-task acceptance
│   ├── delegation.md          # architect ↔ lane doctrine, spec contract, verification
│   └── fusion.md              # panel → judge doctrine (Track A/B + the agl upgrades)
└── scripts/
    ├── env-bundle.sh # AES-256 env bundle runner (+ test-env-bundle.sh regression suite)
    ├── fusion/      # self-contained panelist runners (codex, agy pseudo-TTY, perl timeout, provenance)
    └── delegate/    # the implementation lane runner (workspace-write, empty-diff detection)
```
