---
description: Gate, changelog, push — and the brain saves itself as part of shipping
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` (once per session)
and `${CLAUDE_PLUGIN_ROOT}/references/definition-of-done.md`.

## Steps

1. **Gate (all must pass — report real numbers):**
   - the Definition of Done is cleared in full — this is the release rung of
     that checklist, not a lighter version of it
   - full test suite green, build clean
   - the feature's planned verification rung reached (live UAT done if the
     plan required it — "we'll UAT later" reopens the plan, it doesn't ship)
   - no leftover `.skip`/`xfail`/debug instrumentation without a dated
     Watchlist entry
   - diff contains only what this feature's commits say it contains

2. **Version + changelog** (whenever the repo versions releases):
   - **Pick the bump by what consumers can observe, never by diff size.**
     MAJOR = they must change their code to upgrade; MINOR = new behavior,
     backward-compatible; PATCH = fix, backward-compatible. A "patch" that
     changes behavior someone relied on is a MAJOR in disguise. Unsure →
     treat it as breaking: a surprise major costs less than a broken consumer.
   - **Tag it.** A release is an immutable point in history, not a moving
     branch (`git tag -a vX.Y.Z -m "Release X.Y.Z"`, push the tag). Derive
     the shipped version from the tag rather than hand-editing it in
     scattered files, so artifact, tag, and changelog cannot disagree.
   - **Changelog entry in the repo's existing format** — outcome first (what
     the user gets), evidence last, grouped Added / Changed / Fixed /
     Deprecated / Removed. A changelog is not `git log`: it is curated by
     consumer impact. Breaking changes carry a migration note and a
     deprecation window.

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
