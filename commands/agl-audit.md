---
description: Security (STRIDE threat model + AI/LLM), dependency, and performance audit — every accepted risk must carry a re-report trigger
---

Read `${CLAUDE_PLUGIN_ROOT}/references/core-behaviors.md` and
`${CLAUDE_PLUGIN_ROOT}/references/brain-format.md`.

Scope: `$ARGUMENTS` (e.g. "this diff", "the wallet module"), else the whole
project. Before starting, read prior audit reports in `docs/reports/` and
audit-related memories in BRAIN.md — re-flagging an accepted risk WITHOUT its
trigger having fired wastes everyone's time; missing a fired trigger is debt.

## Threat model first (5-min lens, not a ceremony)

Controls without a threat model are guesses. Before the checks below:
- **Map trust boundaries** — where untrusted data crosses in: HTTP, form
  fields, file uploads, webhooks, IPC, deep links, third-party APIs, and
  **LLM/model output**. Each boundary is attack surface.
- **Name the assets** — credentials, PII, payment data, admin actions, money.
- **Run STRIDE over each boundary:**

| Threat | Ask | Typical mitigation |
|---|---|---|
| **S**poofing | Impersonate a user/service? | Authn, signature verification |
| **T**ampering | Alter data in transit/at rest? | Integrity checks, parameterized queries, HTTPS |
| **R**epudiation | Deny an action later? | Audit logging of security events |
| **I**nfo disclosure | Leak data? | Encryption, field allowlists, generic errors |
| **D**enial of service | Overwhelm it? | Rate limiting, size caps, timeouts |
| **E**levation of privilege | Gain rights they shouldn't? | Authz checks, least privilege |

- **Write abuse cases next to use cases** — "how would I misuse this?" becomes
  the first test. Can't name a feature's boundaries → not ready to secure it.

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

5. **AI/LLM features** (if the app calls a model — chatbot, summarizer, agent,
   RAG): map to the OWASP Top 10 for LLM Applications:
   - **Output is untrusted (LLM05).** Never pass model output into `eval`, SQL,
     a shell, `innerHTML`, or a file path — validate/encode it like raw input.
   - **Prompts can be hijacked (LLM01).** Untrusted text in the context (user
     message, fetched page, PDF) carries instructions. The system prompt is
     NOT a security boundary — enforce permissions in code.
   - **Keep secrets/other tenants' data out of the context (LLM02/LLM07)** —
     anything in context can be echoed back.
   - **Constrain tool/agent permissions (LLM06).** Least privilege, confirm
     destructive/irreversible actions, validate every tool argument.
   - **Bound consumption (LLM10).** Cap tokens, request rate, loop/recursion
     depth so crafted input can't run up cost or hang.
   - **Isolate retrieval (LLM08).** In RAG, partition embeddings per tenant;
     validate documents before indexing so poisoned content can't steer answers.

6. **Verdicts**: each finding = Critical / Warning / Suggestion, with
   file:line + concrete exploit/failure scenario. Adversarially verify each
   (as in /agl-review) before it reaches the report.

7. **Accepted risks**: every accept REQUIRES a `Re-report trigger:` (date,
   version, or severity escalation) — written into a `decision-*` memory
   file AND, if dated, into STATE.md `## Watchlist`. An accept without a
   trigger is refused.

8. **Output**: `docs/reports/audit_<YYYYMMDD>[_<scope>].md` (findings,
   evidence, remediation order), update STATE.md, then a numbered menu:
   fix criticals+warnings now / triage to backlog with IDs / accept-with-
   triggers — one explicit recommendation.
