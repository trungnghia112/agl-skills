---
description: Gate, changelog, push — and the brain saves itself as part of shipping
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` (once per session).

## Steps

1. **Gate (all must pass — report real numbers):**
   - full test suite green, build clean
   - the feature's planned verification rung reached (live UAT done if the
     plan required it — "we'll UAT later" reopens the plan, it doesn't ship)
   - no leftover `.skip`/`xfail`/debug instrumentation without a dated
     Watchlist entry
   - diff contains only what this feature's commits say it contains

2. **Changelog**: entry in the repo's existing format — outcome first (what
   the user gets), evidence last. Version bump if the repo versions releases.

3. **Commits**: history tells a clean story (per-task commits from
   /agl-build usually already do). Push. If the repo uses PRs, open one with
   summary + test evidence; otherwise push to the default branch per repo
   convention.

4. **Risk-gated deploys** (functions, infra, store releases): explicit owner
   sign-off before executing; rollback path named BEFORE deploying
   ("git revert + redeploy fn" / "previous release tag").

5. **Brain epilogue (mandatory — this replaces remembering to save):**
   run the /agl-save steps: session entry, memory extraction, STATE.md
   (shipped item moves Now → Recently shipped; backlog updated; post-ship
   obligations → Watchlist with dates), brain commit if convention.

6. Report in owner voice: what shipped → value, evidence line, then a
   numbered menu from the refreshed backlog with one recommendation.
