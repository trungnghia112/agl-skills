# Changelog

What changed in agl-skills, written for people who install it — grouped by
impact, newest first. This is not `git log`; the commit history has the
mechanics.

Versions follow [semver](https://semver.org): the bump reflects what you can
observe, not the size of the diff. Each release is the `vX.Y.Z` tag on `main`.

## [1.6.0] - 2026-08-12

### Added
- **Definition of Done** (`references/definition-of-done.md`) — one standing
  bar for the whole project, kept separate from per-task acceptance criteria.
  `/agl-plan` stops restating "tests pass" on every task, `/agl-build` grants a
  task its ✅ only when both bars are met, `/agl-ship` uses it as the release gate.
- `/agl-ship` now tells you which semver bump to pick — by what consumers can
  observe, never by diff size — requires a tag, and treats the changelog as
  curated by impact rather than generated from commits.
- `/agl-audit` triages dependency findings by whether the vulnerable code is
  actually reachable, detects the package manager from the lockfile instead of
  assuming npm, and covers supply-chain risk the audit tool cannot see:
  typosquats, provenance, install scripts as code execution, and forced
  remediation. Dependency upgrades are reviewed as code changes, one at a time.
- `/agl-review` gains real depth on the architecture axis — bolted-on
  conditionals, missing dispatchers, refactors that relocate complexity instead
  of reducing it, feature logic in shared modules, implicit type boundaries,
  and total file size rather than diff size. Every structural finding must
  carry a named remedy, and findings are ordered by leverage.
- Escape hatches for the `/agl-fusion` GPT panelist sandbox: `FUSION_NO_COPY=1`
  runs against your live working directory, `FUSION_SOURCE_ROOT=<path>` picks
  the copy root explicitly.

### Fixed
- **`/agl-fusion` no longer hangs when the GPT panelist's sandbox copy is slow.**
  The copy ran before any timeout applied, so `FUSION_TIMEOUT` never reached it;
  from a large non-git folder the run could stall indefinitely. The copy is now
  bounded by `FUSION_COPY_TIMEOUT` (60s) and exits 124, so the panel degrades to
  the remaining models instead of blocking. A non-git directory too large to
  sandbox fails immediately with an actionable message.
- The sandbox copy skips `node_modules`, `dist`, `.next`, `target`, `.venv` and
  friends — and inside a git repo, everything `.gitignore`'d — so the GPT
  panelist starts faster while still seeing your uncommitted edits.
- Leftover `fusion-codex.*` scratch directories from hard-killed runs are swept
  at startup instead of accumulating in your temp directory.
- `preflight.sh` shows which directory the GPT panelist would copy and roughly
  what it costs, so an oversized source root is visible before the run.

### Changed
- Three new anti-rationalization entries in the core behaviors: refactors that
  only look cleaner, patch-bumping an observable behavior change, and treating a
  dependency bump as "just a version bump".

## [1.5.5] - 2026-07-25

### Added
- `scripts/release.sh` — one command to publish a release (tag `v<version>`,
  push `main` and the tag). This repo is its own marketplace, so that push
  *is* the publish step.

### Fixed
- `/agl-help` listed a pinned model name in the fusion-opus row, which went
  stale as soon as the CLI's default moved on.

## [1.5.4] - 2026-07-17

### Added
- Freshness scoped per command: `/agl-plan` checks technology currency before
  recommending a dependency, `/agl-audit` takes CVE and fixed-version facts
  from live sources as of today rather than from training memory, whose cutoff
  hides anything disclosed since.

## [1.5.3] - 2026-07-17

### Added
- `/agl-fusion` injects a freshness constraint for time-sensitive questions, so
  panelists answer as of today from primary sources instead of from memory.

## [1.5.2] - 2026-07-15

### Changed
- Fusion panelists run whatever model each CLI is configured to use instead of
  a hardcoded one — upgrading a CLI's default now silently upgrades fusion, with
  nothing to change here.
- The project constitution is injected only for project-scoped questions, so
  general questions are not narrowed by rules that do not apply to them.

---

Releases before 1.5.2 predate tagging; their history lives in the commit log.
