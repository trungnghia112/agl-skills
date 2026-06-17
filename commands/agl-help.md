---
description: How to use agl-skills — commands, flow, and the brain model
---

Show the user (in their language) this overview, adapted to their question
if `$ARGUMENTS` asks something specific:

## Commands

| Memory | |
|---|---|
| `/agl-init` | Scaffold the `.agl/` brain for this project |
| `/agl-recap` | Recall state — always reconcile against git, never trust stale notes |
| `/agl-save` | Save the session: session log + memory (one fact per file) + STATE |

| Lifecycle | |
|---|---|
| `/agl-spec <idea>` | Interview one question at a time → spec with acceptance criteria |
| `/agl-plan` | Break the spec into small verifiable tasks, tag the risky ones |
| `/agl-build` | TDD per task: red test → green code → suite → commit → stop |
| `/agl-build auto` | Approve once → run the whole plan, auto-stop at risky tasks |
| `/agl-test` | Plug test gaps + run the suite + live UAT when needed |
| `/agl-review` | Five-axis review, every finding challenged before it's reported |
| `/agl-audit` | Security/deps/perf — every risk-accept needs a dated re-report trigger |
| `/agl-debug` | Reproduce → isolate → fix → add a test that blocks regression |
| `/agl-ship` | Gate on evidence → changelog → push → auto-save the brain |
| `/agl-next` | Suggest the next task from the backlog (check git before suggesting) |

## Typical day

```
morning:  /agl-recap            → recall, pick work from the menu
working:  /agl-spec → /agl-plan → /agl-build auto → /agl-review
done:     /agl-ship             → brain saves itself during ship
(/agl-save only needed when you stop mid-stream without shipping)
```

## Core principles (always applied in every command)

- State assumptions before acting; when stuck, STOP and ask — never guess
- Allowed to push back on the owner when an approach has a concrete problem
- "Looks right" is never enough — evidence required (test counts, build,
  live UAT); UI/IPC changes must be checked in the real app
- Money / auth / data deletion / anything not undoable → stop for sign-off
- Brain: one fact per file, update don't duplicate, delete when wrong,
  verify a recalled memory against current code before trusting it

Detailed brain format: `references/brain-format.md` in this plugin.
