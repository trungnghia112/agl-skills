---
description: Suggest the next piece of work from the backlog — verified against git, never from stale notes
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` (once per session).

## Steps

1. Read `.agl/STATE.md` + run the staleness check
   (`git log <last_commit>..HEAD`) — if stale, reconcile first exactly as
   /agl-recap does. Never propose work that git shows was already done.

2. Rank candidates: `## Watchlist` items due today/past first (they are owed),
   then `## Now` if something is in flight (finishing beats starting),
   then `## Next` by priority — skipping items whose "Blocked on" still
   holds (verify the blocker is still real: a "needs Windows machine" item
   stays parked; a "needs decision" item becomes a decision option).

3. Present 2–4 options as a numbered menu: each option = outcome framing
   ("làm X → được Y") + effort feel (quick / one-session / multi-session).
   Bundle naturally-sequential items into one "do them all" option.
   Exactly ONE recommendation with a one-line reason.

4. On the owner's pick, route to the right command (/agl-spec for unscoped
   ideas, /agl-build for planned work, /agl-debug for breakage) and update
   STATE.md `## Now`.
