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

## Structure

```
agl-skills/
├── .claude-plugin/plugin.json
├── commands/        # 14 /agl-* commands (loaded only when invoked — near-zero background tokens)
└── references/
    ├── core-behaviors.md   # core rules every command follows
    └── brain-format.md     # .agl/ spec + memory rules
```
