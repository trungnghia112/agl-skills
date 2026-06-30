---
description: Initialize the AGL brain (.agl/) in this project
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` and
`${CLAUDE_PLUGIN_ROOT}/references/brain-format.md` first.

## Steps

1. **Already initialized?** If `.agl/STATE.md` exists, say so and suggest
   `/agl-recap` instead. Stop.

2. **Survey the project** (don't ask what you can read): project name from
   package.json / Cargo.toml / README; current `git log --oneline -10` and
   `git status`; existing `docs/specs/`, `plans/`, CLAUDE.md.

3. **Scaffold** `.agl/` per brain-format.md: STATE.md (with `last_commit` =
   current HEAD short SHA), BRAIN.md, `memory/`, `sessions/`. If the repo has
   a runnable app, create one `runbook` memory capturing how to run/test it
   (dev command, test command, UAT method) — this is what `/agl-test` and
   `/agl-build` will read later.

4. **Seed a constitution (offer, don't impose).** From the survey, draft a
   short `.agl/CONSTITUTION.md` (3–7 principles per brain-format.md) of rules
   this project already lives by — e.g. the detected stack/test command as a
   "tests MUST pass before merge" principle, an obvious "never commit secrets",
   any convention visible in CLAUDE.md. Present the draft and ask the owner to
   confirm, edit, or skip — these become binding gates for `/agl-plan` and
   `/agl-review`, so they must be the owner's, not invented. If the project has
   no clear point of view yet, skip the file and note it can be added later.

5. **Gitignore decision.** Ask the owner (numbered menu): commit `.agl/` to
   the repo (team-shared brain, recommended for solo repos) or gitignore it
   (private brain).

6. Report what was created, then end with the standard menu:

```
1️⃣ /agl-recap — review the state just created
2️⃣ /agl-spec <idea> — start your first feature
3️⃣ /agl-next — suggest the next task from the backlog
```
with one explicit recommendation.
