---
description: Restore project context in under a minute — state, backlog, watchlist — with mechanical staleness detection against git
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` (once per session)
and `${CLAUDE_PLUGIN_ROOT}/references/brain-format.md`.

## Algorithm (O(1) — never read the whole history)

1. **Load.** Read `.agl/STATE.md` and `.agl/BRAIN.md` (index only — do NOT
   read individual memory files yet).
   - No `.agl/` → offer `/agl-init` (fresh). Stop.

2. **Staleness check (mandatory — never skip).** Run:
   `git log --oneline <STATE.last_commit>..HEAD` and `git status --short`.
   - Empty → STATE is current. Trust it.
   - Non-empty → STATE IS STALE: work happened after the last save. Read the
     listed commits (and today's + the most recent `sessions/` file if it
     exists) and reconstruct reality from git, not from `## Now`. Tell the
     user plainly: "Brain was last saved at <X>; N commits happened since —
     here's the reconstructed state." Then refresh STATE.md before
     continuing (update Now / Recently shipped / last_commit).

3. **Watchlist scan.** Flag any `## Watchlist` item whose date is today or
   past — these are owed obligations, surface them in the summary.

4. **Targeted memory recall.** From the BRAIN.md index, mention (do not open)
   the 2–4 memories whose descriptions are most relevant to the likely next
   task. Open a memory file only when the user picks work it applies to.

5. **Summarize** in product-owner voice, ≤ 15 lines:
   - 📍 Where we are (Now, verified against git)
   - 🚢 Last shipped (1–2 items)
   - ⏭️ Backlog top items with IDs/priorities
   - ⚠️ Watchlist items due, if any

6. **End with a numbered menu** built from the actual backlog (2–4 options,
   bundle sequential tasks, ONE explicit recommendation).
