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
  **LLM/model output**. Each boundary is attack surface. **Trust follows who
  wrote the value, not the channel it arrived on:** another process's command
  line or environment, filenames on a shared volume, and paths inside job
  payloads are untrusted even when they come from "our own" system.
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

1. **Security** (cite the OWASP Top 10 **with its year**, e.g. A01:2025 —
   the numbering moved: A01 now includes SSRF, A03 is supply chain, A10 is
   mishandling exceptional conditions, i.e. fail closed): secrets in
   code/history/logs (scan without printing values: `git diff --cached -i
   -G'password|secret|api_key|token' --name-only`); input validation at every
   trust boundary (IPC, HTTP, file paths, deep links); injection (SQL/shell/
   path traversal); authz on every mutating endpoint; least privilege. Also:
   - **Paths.** For READS, prefer lexical normalization (a naive
     `canonicalize()` breaks symlinked legitimate paths). For a **delete, move
     or overwrite whose target comes from data** (a payload, a config value,
     another process): resolve symlinks (realpath) first, require an
     allowlisted root, a target at least one level below that root, and
     ownership evidence read before the call. On refusal log and stop — never
     fall back to a broader default path. Name the residual risks (an owner
     marker is self-attestation; check-then-use is a race).
   - **Privacy.** Classify personal fields; collect only for a stated purpose;
     set retention; make deletion real (backups, caches, search indexes,
     analytics); support export and delete. Sending PII to an analytics, ad or
     LLM vendor is sharing: it needs consent and a data-processing agreement.
     A "delete account" that only flips a flag is a finding.
   - **Rate limits.** An in-memory limiter is `max × instances` behind a load
     balancer and never fires on serverless: it needs a shared store.
   - **CI workflows.** Pass `${{ inputs.* }}` (and any event text) through
     `env:` and use a quoted `"$VAR"`; never interpolate it into `run:`.
2. **Dependencies**: run the project's **own** package manager's audit
   (`npm`/`pnpm`/`yarn`/`cargo`/`pip` — detect it from the committed
   lockfile, don't assume npm; competing lockfiles at one install boundary
   is itself a finding). Then:
   - **Triage by reachability, not by the severity column.** Critical/high
     reachable in runtime, build, test, or deploy paths → fix now; confirmed
     unreachable → fix soon, not a blocker; moderate dev-only → backlog. Ask
     whether the vulnerable *function* is actually on a code path, and
     whether the vuln is even exploitable in this deployment shape (a
     server-side vuln in a client-only app is not). Verify "dev-only"
     risk-accepts against the dependency tree of the RELEASE build — a later
     non-optional dep can pull the same package into production.
   - **An audit is not a trust verdict.** It matches known advisories; it
     cannot see a newly malicious or typosquatted package (`crossenv` vs
     `cross-env`). Review new deps and lockfile diffs together: ownership,
     release age, provenance, transitive graph. Check registry signatures
     where supported (`npm audit signatures`); absence is a reason to look
     closer, not proof of compromise.
   - **Never auto-apply forced remediation** (`npm audit fix --force` or
     equivalent) — it crosses declared version ranges. Preview it, read the
     changelogs, test each resulting upgrade.
   - **Install scripts are code execution.** Bootstrap with dependency
     scripts disabled, inspect what wants to run, approve the minimum, commit
     the policy, verify with a clean frozen/immutable install. Blanket
     approval is a finding.
   - **Upgrades are code changes.** One dependency per change (a bulk "bump
     deps" hides which package broke the build and ruins the revert), read
     the changelog rather than trusting the semver label, and let a green
     suite before *and* after decide — "it installed" is not verification.
     Commit the lockfile, review its diff, never hand-edit it.

   **Freshness (security facts are time-varying):** take CVE / advisory /
   fixed-version facts from the **live** audit tool + the official advisory DB
   *as of today* — never from training memory, whose cutoff hides any vuln
   disclosed since. Record the audit date; it's the reference point step 7's
   `Re-report trigger:` is measured against.
3. **Performance**: measure first (bundle size, slow paths with real
   timings); flag only what has numbers behind it. Where it applies:
   - **Queries.** `EXPLAIN ANALYZE` before and after. A wrong `rows=`
     estimate means refresh statistics, not add an index; revert an index
     that did not change the plan; composite order is equality columns, then
     range/sort.
   - **Connection pools.** One pool per process; `instances × max` stays under
     the database's `max_connections`; find what holds connections before
     resizing; serverless needs a proxy (pgbouncer, RDS Proxy).
   - **Caching.** Only reads measured as expensive. The key covers every input
     the response varies on (tenant, viewer, locale, permissions, flags). One
     invalidation strategy, with the staleness window written down. Guard hot
     keys against stampedes; negative entries get a shorter TTL; never cache
     origin errors; bound the size. Never cache balances, permissions or
     checkout inventory.
   - **Regression guard.** A CI budget on the median of repeated runs, plus an
     alert on p75 field data; when either fires, re-baseline before fixing.
4. **Money/state paths** (if present): atomicity of balance mutations,
   refund/retry economics, idempotency of webhooks and payment calls. An
   idempotency key comes from the intent (the client's header, or an
   immutable id like `charge:v1:<orderId>`), never a UUID or timestamp made per
   attempt; claim it with a unique-constraint insert (SELECT-then-INSERT is a
   race); same key with a different body is a 422; choose the in-flight
   duplicate response on purpose (409, bounded wait, or 202); record the
   intent BEFORE the external call (the outcome can be "unknown"); keep keys
   at least as long as the longest redelivery path, dead-letter queue
   included. These findings are always at least Warning severity.

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
