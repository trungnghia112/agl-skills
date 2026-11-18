# /agl-gate playbook

Read by `/agl-gate`. Everything here was done for real on 2026-11-18 (a
framework repo plus three of its forks) before it was written down; the numbers
quoted are from that run.

## The idea, short

*All Code Is Slop (Except Mine)* (Lauren Tan, AI Engineer Code Summit, 2026):
with agents, a team's code volume grows a hundredfold (her team merged ~11k PRs
in a month at a ~0.5% revert rate), and nobody can read it all. Quality holds
only if the **environment** makes the right thing the default:

1. **Codebase.** Agents copy whatever the repo already does, so every workaround
   spreads. One `setTimeout` patch became 183 timers in five weeks.
2. **Static analysis.** Every correction of an agent becomes a lint rule or a
   gate. Her lint rules went from 7 to 167 in four months; comments went from
   65,824 to 1,227, because agents used comments to justify workarounds.
3. **Verification.** The agent runs the app itself and hands over evidence
   (screenshots, video, state charts); review reads the evidence first. Formal
   methods (TLA+, Lean) are still experimental there.
4. **Prose.** Rules, skills, AGENTS.md: last, and shortest.
5. **Human review.** The most expensive layer: the one the others exist to shrink.

And: **do not automate a bad loop.** An agent factory on top of a loop that
still produces slop produces more slop. Verification first, automation after.

Read the talk's numbers with care: a fix-forward pipeline keeps the revert rate
low while bugs exist, PR counts measure volume rather than value, and the team
built its own framework on a new app. Take the method, not the numbers.

## corrections.md header

```markdown
# Agent corrections log

One row every time the owner or a reviewer corrects an agent's work in this repo.
Within the same week each row becomes a check (named in the last column) or gets
a one-line reason to stay prose. Newest first.

| Date | Where | What the agent did wrong | Check that would have caught it | Status |
| --- | --- | --- | --- | --- |
```

Status is `open`, `gated: <check>` or `prose: <why>`.

## Measuring

- **Real tool, real tree.** Run ESLint (or the gate) over the files it will
  judge, `-f json -o <file>`, and count per rule. Grep is a first guess only:
  it missed every inline test-host template and every `[src]` binding.
- **Measure a rule set without touching the repo:** an overlay config OUTSIDE
  the repo that imports the repo's config and appends the candidate rules:

  ```js
  import base from '/abs/path/to/repo/eslint.config.js';
  const ROOT = '/abs/path/to/repo';
  const candidates = [{ files: ['src/features/**/*.ts'], rules: { '@angular-eslint/prefer-signals': 'error' } }];
  export default [...base, ...candidates].map((c) => ({ ...c, basePath: ROOT }));
  ```

  Run it with `eslint -c <overlay> --no-error-on-unmatched-pattern ...` from
  the repo root, and run the repo's own config over the same files. The
  existing rules must count the same in both, or the overlay is wrong.
- **Diff the in-flight work:** measure the working tree and a clean worktree of
  `origin/<default>`. The difference is what unpushed branches will hit when
  the check lands, so it goes in the PR body.
- **A repo that never reverts** (it fixes forward) makes revert rate
  meaningless. Track the share of `fix:` commits per week instead, plus
  corrections per week and bugs users reported.

## Gate script skeleton

For what ESLint cannot see. Keep the repo's own conventions (header that says
WHAT IT STOPS / WHY A GATE / THE FIX / WHAT IT DOES NOT CLAIM / exemption
syntax / exit codes):

```js
#!/usr/bin/env node
// lint:<name> — <one line: what it stops>. Exit 0 clean, 1 findings, 2 examined nothing.
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const files = []; // walk the roots this gate owns, skip node_modules/dist/specs
// Floor BEFORE loading heavy deps: an empty tree must exit 2 without a load error.
if (files.length === 0) { console.error('examined 0 files: the walk is broken, not the code'); process.exit(2); }
const ts = createRequire(join(ROOT, 'package.json'))('typescript'); // AST, not regex, for nested code
// ... visit, collect findings, honour a per-line `// <name>-allow: <why>` exemption
// print "<N> examined, <M> findings"; exit 1 on findings, 0 otherwise
```

Prove it with fixtures: every bad shape fails, every legitimate look-alike
(`signal.set()`, `Map.set()`, a variable meant to stay `undefined`) passes.

## Fork lint

A fork's `npm run build` usually lints only the framework's code, so nothing
lints the code the fork's agents write. Measured on three forks: 105, 150 and
12 findings nobody had ever seen. The fork fixes this with files it owns only:

1. `scripts/<fork-namespace>/lint/eslint.fork.config.mjs`:

   ```js
   // <fork>: ESLint for the fork's OWN code. Fork-owned; the framework's config is not edited.
   import { fileURLToPath } from 'node:url';
   import base from '../../../eslint.config.js';

   const ROOTS = ['projects/admin/src/app/features', 'projects/admin/src/app/custom', 'functions/src/features'];
   const TS = ROOTS.map((r) => `${r}/**/*.ts`);
   const HTML = ROOTS.filter((r) => !r.startsWith('functions/')).map((r) => `${r}/**/*.html`);
   const forkRules = [
     { files: TS, rules: { /* rules the framework enforces on its own code */ } },
     { files: HTML, rules: { /* template rules */ } },
   ];
   // A RELATIVE basePath is read against the working directory, not this file: resolve it.
   const ROOT = fileURLToPath(new URL('../../..', import.meta.url));
   export default [...base, ...forkRules].map((c) => ({ ...c, basePath: ROOT }));
   ```

2. `package.json`, a namespaced script (follow the fork's existing naming):

   ```
   "lint:<fork>-eslint": "eslint -c scripts/<ns>/lint/eslint.fork.config.mjs --suppressions-location scripts/<ns>/lint/eslint-suppressions.json --no-error-on-unmatched-pattern --no-warn-ignored \"<root>/**/*.{ts,html}\" ..."
   ```

   and `&& npm run lint:<fork>-eslint` at the END of the fork's own
   `prebuild:fork` (never in the framework's `prebuild`).
3. `npm run lint:<fork>-eslint -- --suppress-all` once, to freeze today's
   findings. Then the plain run must exit 0.
4. Probe: one temp file under a fork root with one violation per rule. Every
   rule fires; delete it; green again.

## Gotchas met on the way

| Symptom | Cause | Fix |
|---|---|---|
| "zero violations" by grep, 45 by ESLint | grep misses spec test hosts and bindings | measure with the real tool |
| A `-c` config in a subfolder changes counts silently; path-scoped rules never fire | relative `basePath` resolves against the cwd | absolute `basePath` via `import.meta.url` |
| `No files matching the pattern` | a fork root that is empty or absent | `--no-error-on-unmatched-pattern` |
| Plain run exits 2 right after setup | the suppressions file does not exist yet | run `--suppress-all` first |
| A warning is still printed after suppressing | suppressions cover errors | warnings never fail the build; leave them |
| A rule fires on correct code (`prefer-ngsrc` on avatars and data URLs) | the rule is wider than the written rule | leave it off and say why in the config |
| Push exits 141 after a long pre-push hook | the SSH connection idled out while the hook ran | `ssh -o ServerAliveInterval=30` (`core.sshCommand` or `GIT_SSH_COMMAND`) |
| A fresh worktree fails a dead-reference or env gate the main checkout passes | gitignored local files (`.env*`, local notes) are not in a worktree | copy them in before building; they stay ignored |
| `gh pr create`: "No commits between main and <branch>" | the repo also has an `upstream` remote and `gh` targeted it | `gh pr create --repo <owner>/<repo>` |
| A smoke fails "gate not accounted for" | the repo keeps a registry of its gates (planted / cited / not applicable) | register the new gate there, with a planted case when it can have one |
| Build fails "driver split-brain" | the repo builds per data driver | use the repo's command for its driver (`build:dc`, …) |
| Machine stalls during lint + build + tests | heavy jobs overlapping | if the machine has a load check and a heavy-job lock, run every heavy step inside them |

## Order of rollout that worked

1. Measure, classify the agent config (AUDIT), log corrections: one week.
2. Zero-violation rules into the framework's own build first, then each fork's
   own lint with frozen findings.
3. Verification next: a feature map (what exists, how a user reaches it, what
   proves it works) and a CLI or skill that lets the agent run the app and
   capture evidence for the PR.
4. Only then automation (scheduled fuzzing of a release, fix PRs from alerts),
   and only for loops that already pass step 3.
