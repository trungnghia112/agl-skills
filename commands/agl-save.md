---
description: Save the session to the brain — incremental, deduped, never grows recap cost
---

Read `${CLAUDE_PLUGIN_ROOT}/references/brain-format.md`.

## Steps

1. **Gather the delta** since the last save: `git log --oneline
   <STATE.last_commit>..HEAD`, plus what happened this session (decisions,
   gotchas hit, things shipped, things parked).

2. **Append a session entry** to `.agl/sessions/<today YYYY-MM-DD>.md`
   (create the file if absent): time, one-line outcome, commits, evidence
   (test counts / build / UAT performed), links to memory files touched,
   what was queued next. Append-only — never rewrite old entries.

3. **Extract durable knowledge → memory files.** For each NEW gotcha,
   decision, learning, or runbook change:
   - Scan BRAIN.md for an existing file covering it → **update that file**
     (bump `updated`), don't create a duplicate.
   - Otherwise create `memory/<type>-<slug>.md` per the format spec and add
     its index line to BRAIN.md.
   - Accepted risks MUST carry a `Re-report trigger:` line; put dated
     triggers into STATE.md `## Watchlist` too.
   - Do NOT save what git/CLAUDE.md/code already records. Conversation-only
     details die with the session — that's correct.
   - Delete (file + index line) any memory this session proved wrong.

4. **Rewrite STATE.md** (this file is replaced, not appended):
   - `## Now` — what's actually in flight, or "Nothing in flight."
   - `## Next` — backlog table: add new items, remove shipped ones, keep IDs
     stable, every parked item gets a "Blocked on" reason.
   - `## Recently shipped` — prepend this session's ships, trim to 7.
   - `## Watchlist` — add/remove dated obligations.
   - frontmatter: `updated` = now, `last_commit` = current HEAD short SHA.
     (Set last_commit AFTER any brain commit in step 5 — see note there.)
   - Enforce the 150-line budget: overflow goes to sessions/, not STATE.

5. **Commit** if the repo's convention commits the brain (check git history
   for prior brain commits): `chore(brain): save <date> — <one-line>`.
   Note: committing changes HEAD — set `last_commit` to the SHA of THIS brain
   commit (amend or write STATE before committing and accept the brain commit
   itself as the anchor; either way the next recap's staleness check must
   come up empty on a clean resume).

6. **Confirm** in 3 lines: what was saved, memories created/updated, and that
   the next `/agl-recap` will resume from here.
