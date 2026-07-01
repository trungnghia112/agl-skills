---
description: Verify current changes with evidence — close test gaps, run the suite, climb to live UAT when needed
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` (once per session).

## Steps

1. **Scope**: `$ARGUMENTS` or the current diff (`git diff` + recent commits
   on this branch). Identify every behavior change.

2. **Gap check**: each changed behavior gets a test that would FAIL if the
   behavior regressed. Write the missing ones (RED→GREEN against current
   code: temporarily break the code mentally — would this test catch it?).
   Don't write tests that merely restate the implementation.

3. **Run**: full suite + build. Report real numbers ("726/726", not "tests
   pass"). A failing test is reported with its output — never silently
   skipped, .skip'd, or loosened to pass.

4. **Climb the ladder when required**: UI render, IPC/wire-format,
   CSP/network, overlay/dialog behavior → live verification. Check BRAIN.md
   for a `runbook` memory (how this project runs/UATs — dev server, MCP
   bridge, emulators). Probe the real thing, capture evidence (output,
   screenshot, raw payload). **If the plan has a `## Contracts` section**,
   diff the captured real payload against the contract field-by-field — a
   passing type check is not this rung; a match against the contract is. A
   drift (missing field, wrong type, renamed key, unexpected null) is a
   failure to report, not a rounding error.

5. **Gotchas to memory**: a surprising failure mode discovered while testing
   (flaky pattern, env trap, mock contract) → memory file per
   `${CLAUDE_PLUGIN_ROOT}/references/brain-format.md`, deduped via BRAIN.md.

6. Report: evidence summary (what rung was reached, numbers, artifacts),
   then a numbered menu (fix found issues / review / ship) with one
   recommendation.
