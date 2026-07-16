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
(`FUSION_TIMEOUT`).

Opus **always** judges and writes the final answer. Every panel degrades
gracefully (a missing CLI drops that panelist, never aborts). Runs are saved to
`~/.claude/fusion-runs/` and mirrored into the project's `.agl/fusion-runs/`;
panelists honor `.agl/CONSTITUTION.md` on project-scoped questions, and get a
**freshness guard** (answer as of today from primary sources; latest ≠ announced)
on time-sensitive ones. The runner scripts in `scripts/fusion/` are self-contained
(bash/perl/python3 + optional `codex`/`agy`).

## Structure

```
agl-skills/
├── .claude-plugin/plugin.json
├── commands/        # 21 /agl-* commands (loaded only when invoked — near-zero background tokens)
├── references/
│   ├── core-behaviors.md   # core rules every command follows
│   ├── brain-format.md     # .agl/ spec + memory rules
│   └── fusion.md           # panel → judge doctrine (Track A/B + the agl upgrades)
└── scripts/fusion/  # self-contained panelist runners (codex, agy pseudo-TTY, perl timeout, provenance)
```
