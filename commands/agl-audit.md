---
description: Security, dependency, and performance audit — every accepted risk must carry a re-report trigger
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` and
`${CLAUDE_PLUGIN_ROOT}/references/brain-format.md`.

Scope: `$ARGUMENTS` (e.g. "this diff", "the wallet module"), else the whole
project. Before starting, read prior audit reports in `docs/reports/` and
audit-related memories in BRAIN.md — re-flagging an accepted risk WITHOUT its
trigger having fired wastes everyone's time; missing a fired trigger is debt.

## Steps

1. **Security**: secrets in code/history/logs; input validation at every
   trust boundary (IPC, HTTP, file paths, deep links); injection (SQL/shell/
   path traversal — beware: naive canonicalize() fixes break symlinked
   legitimate paths, prefer lexical normalization); authz on every mutating
   endpoint; least privilege.
2. **Dependencies**: `npm audit` / `cargo audit` equivalents; verify
   "dev-only" risk-accepts with the dependency tree of the RELEASE build —
   a later non-optional dep can pull the same crate into production.
3. **Performance**: measure first (bundle size, slow paths with real
   timings); flag only what has numbers behind it.
4. **Money/state paths** (if present): atomicity of balance mutations,
   refund/retry economics, idempotency of webhooks. These findings are
   always at least Warning severity.

5. **Verdicts**: each finding = Critical / Warning / Suggestion, with
   file:line + concrete exploit/failure scenario. Adversarially verify each
   (as in /agl-review) before it reaches the report.

6. **Accepted risks**: every accept REQUIRES a `Re-report trigger:` (date,
   version, or severity escalation) — written into a `decision-*` memory
   file AND, if dated, into STATE.md `## Watchlist`. An accept without a
   trigger is refused.

7. **Output**: `docs/reports/audit_<YYYYMMDD>[_<scope>].md` (findings,
   evidence, remediation order), update STATE.md, then a numbered menu:
   fix criticals+warnings now / triage to backlog with IDs / accept-with-
   triggers — one explicit recommendation.
