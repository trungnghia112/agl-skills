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

4. **Gitignore decision.** Ask the owner (numbered menu): commit `.agl/` to
   the repo (team-shared brain, recommended for solo repos) or gitignore it
   (private brain).

5. Report what was created, then end with the standard menu:

```
1️⃣ /agl-recap — xem lại trạng thái vừa dựng
2️⃣ /agl-spec <ý tưởng> — bắt đầu feature đầu tiên
3️⃣ /agl-next — gợi ý việc tiếp theo từ backlog
```
with one explicit recommendation.
